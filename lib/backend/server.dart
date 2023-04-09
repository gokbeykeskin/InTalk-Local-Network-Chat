import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:local_chat/screens/contacts_screen/contacts_screen.dart';

import '../utils/messaging_protocol.dart';
import 'client.dart';

class LocalNetworkChat {
  // Create a server socket that listens for incoming client connections
  ServerSocket? serverSocket;
  // A list of connected sockets
  List<Socket> connectedSockets = [];
  //the user which logged in from this device.
  User myUser;
  // Start the server socket and listen for incoming client connections
  LocalNetworkChat({required this.myUser});
  Future<void> start() async {
    // Get the IP address of the local device
    var ipAddress = await _getNetworkIPAdress();

    // Print the IP address to the console
    if (kDebugMode) {
      print('Local IP address: $ipAddress');
    }

    // Create a server socket that listens for incoming client connections
    serverSocket = await ServerSocket.bind(ipAddress, 12345, shared: true);
    // Listen for incoming client connections
    serverSocket?.listen((socket) {
      // Add the socket to the list of connected sockets
      connectedSockets.add(socket);
      // Listen for incoming messages from the client
      socket.listen((data) {
        // Convert the incoming data to a string
        var message = utf8.decode(data).trim();
        if (kDebugMode) {
          print('Message from Client:$message');
        }
        parseMessages(message, socket);
      }, onDone: () {
        //when a client closes a socket
        // Remove the socket from the list of connected sockets
        connectedSockets.remove(socket);
        //send the logout message to all clients
        try {
          sendMessageToAll('${MessagingProtocol.logout}@${socket.remotePort}');
        } catch (e) {
          if (kDebugMode) {
            print(
                "Server was the logged out client. No need to send logout message to other clients");
          }
        }
      });
    });
  }

  // Stop the server and close all client connections
  Future<void> stop() async {
    if (connectedSockets.length > 1) {
      //if there is another client which can become server
      sendMessage(MessagingProtocol.becomeServer, connectedSockets[1]);
      for (var i = 2; i < connectedSockets.length; i++) {
        sendMessage(MessagingProtocol.connectToNewServer, connectedSockets[i]);
      }
    }

    // Close the server socket to stop accepting new client connections
    await serverSocket?.close();

    List<Future<void>> socketFutures = [];
    // Close all existing client connections
    for (var clientSocket in connectedSockets) {
      socketFutures.add(clientSocket.close());
    }
    await Future.wait(socketFutures);
    connectedSockets.clear();
  }

  // Send a message to all connected clients
  void sendMessageToAll(String message) {
    // Send the message to all connected sockets
    for (var socket in connectedSockets) {
      socket.write('$message||');
    }
  }

  void sendMessageToAllExcept(String message, Socket socket) {
    // Send the message to all connected sockets
    for (var s in connectedSockets) {
      if (s != socket) {
        s.write('$message||');
      }
    }
  }

  void sendMessage(String message, Socket socket) {
    // Send the message to all connected sockets
    socket.write('$message||');
  }

  void sendMessageToPort(String message, int port) {
    // Send the message to all connected sockets
    Socket socket = connectedSockets.firstWhere((element) {
      return element.remotePort == port;
    });
    socket.write('$message||');
  }

  void parseMessages(String message, Socket socket) async {
    if (message.contains("||")) {
      var split = message.split("||");
      for (var i = 0; i < split.length - 1; i++) {
        processMessages(split[i], socket);
      }
    }
  }

  void processMessages(String message, Socket socket) async {
    if (message.contains("@")) {
      var split = message.split("@");
      if (split[0] == MessagingProtocol.heartbeat) {
        if (kDebugMode) {
          print("HEARTBEAT RECEIVED FROM ${split[2]}");
        }
        processHeartbeat(message, socket);
      } else if (split[0] == MessagingProtocol.broadcast) {
        if (kDebugMode) {
          print("BROADCAST RECEIVED FROM ${split[1]}");
        }
        processBroadcast(message, socket);
      } else if (split[0] == MessagingProtocol.private) {
        if (kDebugMode) {
          print("PRIVATE MESSAGE RECEIVED FROM ${split[1]}");
        }
        processPrivateMessage(message, socket);
      }
    }
  }

  void processHeartbeat(String message, Socket socket) async {
    sendMessageToAllExcept(
        message, socket); //send new client to all logged in clients
    for (var user in ContactsScreen.loggedInUsers) {
      //send all logged in clients to the new client
      sendMessage(
          '${MessagingProtocol.heartbeat}@${user.macAddress}@${user.name}@${user.port}',
          socket);
    }
    sendMessage(
        '${MessagingProtocol.heartbeat}@${myUser.macAddress}@${myUser.name}@${myUser.port}',
        socket);
  }

  void processBroadcast(String message, Socket socket) {
    sendMessageToAllExcept(message, socket);
  }

  void processPrivateMessage(String message, Socket socket) {
    var split = message.split("@");

    sendMessageToPort(message, int.parse(split[2]));
  }

  Future<String> _getNetworkIPAdress() async {
    List<NetworkInterface> interfaces = await NetworkInterface.list();
    for (NetworkInterface interface in interfaces) {
      if (interface.name.startsWith('wlan') ||
          interface.name.startsWith('en')) {
        return interface.addresses.first.address;
      }
    }
    return '';
  }
}
