import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:event/event.dart';
import 'package:flutter/foundation.dart';
import 'package:local_chat/network/client/client_events.dart';
import 'package:local_chat/screens/contacts_screen/contacts_screen.dart';

import '../../auth/user.dart';
import '../../encrypt/server_encryption.dart';
import '../messaging_protocol.dart';
import '../../utils/lan_utils.dart';

//AuthEvent is broadcasted when a new device wants to connect to the server
class AuthEventArgs extends EventArgs {
  String macAddress;
  String name;
  AuthEventArgs({required this.macAddress, required this.name});
}

class CustomStreamController {
  final StreamController<String> _messageStreamController =
      StreamController.broadcast();
  Stream<String> get _messageStream => _messageStreamController.stream;
  Socket socket;
  CustomStreamController({required this.socket});
}

class LanServer {
  // server socket that listens for incoming client connections
  ServerSocket? _serverSocket;
  // A map of connected sockets and client numbers.
  final Map<Socket, int> _connectedClients = {};
  //the user which logged in from this device.
  final User _myUser;

  late Timer _hearbeatTimer;

  LanServer({required User myUser}) : _myUser = myUser;

  //When a new device wants to connect, this event is broadcasted to ask
  //the user if they wants to accept the new device
  static Event authEvent = Event();
  //When a new device is rejected, this event is broadcasted to update
  //banned devices list on the settings screen
  static Event rejectEvent = Event();

  bool? _isUserAccepted;
  // A stream controller list for sending messages to all connected clients
  final List<CustomStreamController> _messageStreamControllers = [];

  late ServerSideEncryption serverSideEncryption;

  Future<void> start() async {
    serverSideEncryption = ServerSideEncryption(
        sendOpenMessage: (message, socket) =>
            _sendOpenMessage(message, socket));
    // Get the IP address of the local device
    var ipAddress = await LanUtils.getNetworkIPAdress();

    // Print the IP address to the console
    if (kDebugMode) {
      print('Local IP address: $ipAddress');
    }

    ContactsScreen.userAcceptanceEvent.subscribe((args) {
      args as UserAcceptanceEventArgs;
      _isUserAccepted = args.accepted;
    });

    try {
      // Create a server socket that listens for incoming client connections
      _serverSocket = await ServerSocket.bind(ipAddress, 12345, shared: true);
    } catch (e) {
      if (kDebugMode) {
        print(
            "Server socket could not be created. Maybe another server is running?:$e");
      }
      ClientEvents.connectionLostEvent.broadcast();
      return;
    }
    _heartbeat();
    // Listen for incoming client connections
    _serverSocket?.listen((socket) {
      _connectedClients[socket] = _connectedClients.length;

      // Add the socket to the list of connected sockets
      _messageStreamControllers.add(CustomStreamController(socket: socket));

      _messageStreamControllers.last._messageStream.listen((message) {
        _parseMessages(message, socket);
      });
      // Listen for incoming messages from the client
      socket.listen((data) {
        // Convert the incoming data to a string
        var message = utf8.decode(data).trim();

        _messageStreamControllers
            .firstWhere((element) => element.socket == socket)
            ._messageStreamController
            .add(message);
      }, onDone: () {
        //when a client closes a socket
        // Remove the socket from the list of connected sockets
        //send the logout message to all clients
        try {
          _sendMessageToAllExcept(
              '${MessagingProtocol.logout}‽${socket.remotePort}', socket);
          for (var connectedSocket in _connectedClients.keys) {
            if (_connectedClients[connectedSocket]! >
                _connectedClients[socket]!) {
              _connectedClients[connectedSocket] =
                  _connectedClients[connectedSocket]! - 1;
              _sendMessage(
                  '${MessagingProtocol.clientNumber}‽${_connectedClients[connectedSocket]}',
                  connectedSocket);
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print(
                "Server was the logged out client. No need to send logout message to other clients");
          }
        }
        _connectedClients.remove(socket);
      });
    });
  }

  // Stop the server and close all client connections
  Future<void> stop() async {
    if (kDebugMode) {
      print("Stopping Server");
    }
    authEvent.unsubscribeAll();
    rejectEvent.unsubscribeAll();
    _hearbeatTimer.cancel();
    // Close the server socket to stop accepting new client connections
    await _serverSocket?.close();

    //List<Future<void>> socketFutures = [];
    // Close all existing client connections
    for (var clientSocket in _connectedClients.keys.toList()) {
      clientSocket.destroy();
    }
    _connectedClients.clear();
    for (var element in _messageStreamControllers) {
      element._messageStreamController.close();
    }
    _messageStreamControllers.clear();
  }

  void _sendMessageToAllExcept(String message, Socket socket) {
    for (var s in _connectedClients.keys) {
      if (s != socket) {
        _sendMessage(message, s);
      }
    }
  }

  void _sendMessage(String message, Socket socket) async {
    // Encrypt and send a message to a socket.
    String encryptedMessage =
        await serverSideEncryption.encrypt(socket, message);
    socket.write('$encryptedMessage◊');
  }

  void _sendOpenMessage(String message, Socket socket) {
    // Send the message to a socket without encryption.
    socket.write('$message◊');
  }

  void _sendMessageToPort(String message, int port) {
    Socket socket = _connectedClients.keys.firstWhere((element) {
      return element.remotePort == port;
    });
    _sendMessage(message, socket);
  }

  void _sendMessageToAll(String message) {
    for (var socket in _connectedClients.keys) {
      _sendMessage(message, socket);
    }
  }

  void sendTrustedDeviceToAll(String macAddress, String name) {
    _sendMessageToAll('${MessagingProtocol.trustedDevice}‽$macAddress‽$name');
  }

  void sendBannedDeviceToAll(String macAddress, String name) {
    _sendMessageToAll('${MessagingProtocol.bannedDevice}‽$macAddress‽$name');
  }

  void sendUntrustedDeviceToAll(String macAddress) {
    _sendMessageToAll('${MessagingProtocol.untrustDevice}‽$macAddress');
  }

  void sendUnbannedDeviceToAll(String macAddress) {
    _sendMessageToAll('${MessagingProtocol.unbanDevice}‽$macAddress');
  }

  // Parse incoming messages
  void _parseMessages(String message, Socket socket) async {
    if (message.contains("◊")) {
      var splits = message.split("◊");
      for (var split in splits) {
        _processMessage(split, socket);
      }
    }
  }

  // Process parsed messages
  void _processMessage(String message, Socket socket) async {
    var split = message.split("‽");
    //All messages except login messages are encrypted
    //so we need to decrypt them
    if (!(split[0] == MessagingProtocol.login)) {
      message = (await serverSideEncryption.decrypt(socket, message)).trim();
      split = message.split("‽");
    }

    if (split[0] == MessagingProtocol.login) {
      if (kDebugMode) {
        print("Server: Login received from ${split[2]}");
      }
      serverSideEncryption.generateKeyWithClient(
          socket, BigInt.parse(split[4]));
      _processLogin(message, socket);
    } else if (split[0] == MessagingProtocol.broadcastMessage) {
      if (kDebugMode) {
        print("Server: broadcast message received from ${split[1]}");
      }
      _processBroadcastMessage(message, socket);
    } else if (split[0] == MessagingProtocol.privateMessage) {
      if (kDebugMode) {
        print("Server: private message received from ${split[1]}");
      }
      _processPrivateMessage(message, socket);
    } else if (split[0] == MessagingProtocol.broadcastImageStart ||
        split[0] == MessagingProtocol.broadcastImageContd ||
        split[0] == MessagingProtocol.broadcastImageEnd) {
      _processBroadcastImage(message, socket);
    } else if (split[0] == MessagingProtocol.privateImageStart ||
        split[0] == MessagingProtocol.privateImageContd ||
        split[0] == MessagingProtocol.privateImageEnd) {
      _processPrivateImage(message, socket);
    } else if (split[0] == MessagingProtocol.nameUpdate) {
      if (kDebugMode) {
        print("Server: name update received from ${split[1]}");
      }
      _processNameUpdate(message, socket);
    }
  }

  Future<void> _processLogin(String message, Socket socket) async {
    var split = message.split("‽");
    List<String>? trustedDeviceMACs = ContactsScreen.trustedDevicePreferences
            ?.getStringList('trustedDeviceMACs') ??
        [];
    List<String>? trustedDeviceNames = ContactsScreen.trustedDevicePreferences
            ?.getStringList('trustedDeviceNames') ??
        [];
    List<String>? bannedDeviceMACs = ContactsScreen.trustedDevicePreferences
            ?.getStringList('bannedDeviceMACs') ??
        [];
    List<String>? bannedDeviceNames = ContactsScreen.trustedDevicePreferences
            ?.getStringList('bannedDeviceNames') ??
        [];
    if (bannedDeviceMACs.contains(split[1])) {
      _kickUser(socket);
      return;
    } else if (!trustedDeviceMACs.contains(split[1]) &&
        split[1] != _myUser.macAddress) {
      authEvent.broadcast(AuthEventArgs(macAddress: split[1], name: split[2]));

      //wait until host user accepts or rejects the new client
      while (_isUserAccepted == null) {
        await Future.delayed(const Duration(
            milliseconds:
                500)); // wait for 500 milliseconds before checking again
      }
      if (!_isUserAccepted!) {
        sendBannedDeviceToAll(split[1], split[2]);
        _kickUser(socket);
        return;
      }
      _isUserAccepted = null;
    }
    //send new client to all logged in clients
    _sendMessageToAllExcept(message, socket);
    //send all logged in clients to the new client
    for (var user in ContactsScreen.loggedInUsers) {
      _sendMessage(
          '${MessagingProtocol.login}‽${user.macAddress}‽${user.name}‽${user.port}',
          socket);
    }
    _sendMessage(
        //send yourself to the new client since it is not in the list of logged in clients
        '${MessagingProtocol.login}‽${_myUser.macAddress}‽${_myUser.name}‽${_myUser.port}',
        socket);
    sendTrustedDeviceToAll(split[1], split[2]);
    //send all trusted devices to the new client
    for (int i = 0; i < trustedDeviceMACs.length; i++) {
      _sendMessage(
          '${MessagingProtocol.trustedDevice}‽${trustedDeviceMACs[i]}‽${trustedDeviceNames[i]}',
          socket);
    }
    //send this device to the new client as a trusted device
    _sendMessage(
        '${MessagingProtocol.trustedDevice}‽${_myUser.macAddress}‽${_myUser.name}',
        socket);
    for (int i = 0; i < bannedDeviceMACs.length; i++) {
      //send all banned devices to the new client
      _sendMessage(
          '${MessagingProtocol.bannedDevice}‽${bannedDeviceMACs[i]}‽${bannedDeviceNames[i]}',
          socket);
    }
    //Assign a client number to the new client. This number is used to choose
    // next server candidate when host device is disconnected.
    _sendMessage(
        '${MessagingProtocol.clientNumber}‽${_connectedClients[socket]}',
        socket);
  }

  // General message, send it to all clients except the sender
  void _processBroadcastMessage(String message, Socket socket) {
    _sendMessageToAllExcept(message, socket);
  }

  // Private message, send it to the specified client
  void _processPrivateMessage(String message, Socket socket) {
    var split = message.split("‽");
    _sendMessageToPort(message, int.parse(split[2]));
  }

  // Part of a broadcast image, send it to all clients except the sender
  void _processBroadcastImage(String message, Socket socket) {
    _sendMessageToAllExcept(message, socket);
  }

  //Part of a private image, send it to the specified client
  void _processPrivateImage(String message, Socket socket) {
    var split = message.split("‽");
    if (split[0] == MessagingProtocol.privateImageStart) {
      _sendMessageToPort(message, int.parse(split[2]));
    } else {
      _sendMessageToPort(message, int.parse(split[3]));
    }
  }

  // Someone changed their name, send it to all clients except the changer
  void _processNameUpdate(String message, Socket socket) {
    _sendMessageToAllExcept(message, socket);
  }

  //User rejected the new client, kick it.
  void _kickUser(Socket socket) async {
    _sendMessage('${MessagingProtocol.rejected}‽', socket);
    await Future.delayed(const Duration(milliseconds: 200));
    _isUserAccepted = null;
    socket.destroy();
    _connectedClients.remove(socket);
    rejectEvent.broadcast();
  }

  void _heartbeat() {
    _hearbeatTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _sendMessageToAll('${MessagingProtocol.heartbeat}‽');
    });
  }
}
