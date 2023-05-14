import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:event/event.dart';
import 'package:flutter/foundation.dart';

import '../auth/user.dart';
import 'messaging_protocol.dart';
import '../screens/contacts_screen/contacts_screen.dart';
import '../utils/utility_functions.dart';

class NewMessageEventArgs extends EventArgs {
  final String message;
  final String sender;
  final String receiver;
  List<int>? imageBytes;
  NewMessageEventArgs(
      {required this.message,
      required this.sender,
      required this.receiver,
      this.imageBytes});
}

class AcceptanceEventArgs extends EventArgs {
  bool accepted;
  AcceptanceEventArgs({required this.accepted});
}

class LocalNetworkChatClient {
  User user;
  Socket? socket;
  static var broadcastMessageReceivedEvent = Event();
  static var privateMessageReceivedEvent = Event();
  static var usersUpdatedEvent = Event();
  static var becomeServerEvent = Event();
  static var connectToNewServerEvent = Event();
  static var acceptanceEvent = Event();
  String? _networkIpAdress;
  String? _networkIpWithoutLastDigits;

  bool connected = false;

  final List<int> _currentImageBytes = [];
  String? _currentImageSenderMac;

  LocalNetworkChatClient({required this.user});

  // A stream controller for sending messages to the server
  StreamController<String> messageStreamController =
      StreamController.broadcast();

  // A stream for receiving messages from the server
  Stream<String> get messageStream => messageStreamController.stream;

  Future<void> init() async {
    _networkIpAdress = await Utility.getNetworkIPAdress();

    List<String> components = _networkIpAdress!.split('.');

    // Remove the last subpart
    components.removeLast();

    // Join the remaining subpart back into an IP address string
    _networkIpWithoutLastDigits = '${components.join('.')}.';

    try {
      user.macAddress = (await Utility.getDeviceId())!;
    } catch (e) {
      if (kDebugMode) {
        print("MAC ADDRESS GET FAILED:$e");
        user.macAddress = "11223344"; //for macos debugging
      }
    }

    messageStream.listen((message) {
      parseMessages(message);
    });
  }

  // Connect to the server
  Future<void> connect(int lastIpDigit) async {
    var ipAddress = lastIpDigit == -1
        ? _networkIpAdress
        : _networkIpWithoutLastDigits! + lastIpDigit.toString();

    // Connect to the server socket
    try {
      socket = await Socket.connect(ipAddress, 12345,
          timeout: const Duration(milliseconds: 2000));
      user.port = socket?.port;
      connected = true;
      if (kDebugMode) {
        print('Successfully connected to the server: $ipAddress:12345');
      }
    } catch (e) {
      if (kDebugMode) {
        print("Tried:$ipAddress");
        return;
      }
    }
    // Listen for incoming messages from the server
    socket?.listen((data) {
      // Convert the incoming data to a string
      var message = utf8.decode(data).trim();
      messageStreamController.add(message);
    });
    sendMessage(
        "${MessagingProtocol.heartbeat}@${user.macAddress}@${user.name}@${socket?.port}");
  }

  Future<void> stop() async {
    // Close the client socket to disconnect from the server
    usersUpdatedEvent.unsubscribeAll();
    becomeServerEvent.unsubscribeAll();
    connectToNewServerEvent.unsubscribeAll();
    broadcastMessageReceivedEvent.unsubscribeAll();
    privateMessageReceivedEvent.unsubscribeAll();
    acceptanceEvent.unsubscribeAll();

    await socket?.close();
  }

  void sendBroadcastMessage(String message) {
    sendMessage("${MessagingProtocol.broadcast}@${user.macAddress}@$message");
  }

  void sendPrivateMessage(String message, User receiver) {
    sendMessage(
        "${MessagingProtocol.private}@${user.macAddress}@${receiver.port}@$message");
  }

  Future<void> sendBroadcastImage(Uint8List base64Image) async {
    List<Uint8List> bytes = Utility.splitImage(base64Image);
    List<int> hashedBytes = Utility.hashImage(base64Image);
    sendMessage("${MessagingProtocol.broadcastImage}@${user.macAddress}");
    for (var i = 0; i < bytes.length; i++) {
      await Future.delayed(
        const Duration(milliseconds: 50),
      ); //bu delay arttırılarak büyük resimlerdeki hata düzeltilebilir, ama büyük resimler zaten çok uzun sürüyor.
      sendMessage(
          '${MessagingProtocol.broadcastImageContd}@${base64Encode(bytes[i])}');
    }
    sendMessage(
        '${MessagingProtocol.broadcastImageEnd}@${base64Encode(hashedBytes)}');
  }

  Future<void> sendPrivateImage(Uint8List base64Image, User receiver) async {
    List<Uint8List> bytes = Utility.splitImage(base64Image);
    List<int> hashedBytes = Utility.hashImage(base64Image);
    sendMessage(
        "${MessagingProtocol.privateImage}@${user.macAddress}@${receiver.port}");
    for (var i = 0; i < bytes.length; i++) {
      await Future.delayed(
        const Duration(milliseconds: 50),
      );
      sendMessage(
          '${MessagingProtocol.privateImageContd}@${base64Encode(bytes[i])}');
    }
    sendMessage(
        '${MessagingProtocol.privateImageEnd}@${base64Encode(hashedBytes)}');
  }

  void changeName(String newName) {
    user.name = newName;
    sendMessage(
        "${MessagingProtocol.nameUpdate}@${user.macAddress}@${user.name}");
  }

  // Send a message to the server
  void sendMessage(String message) {
    socket?.write('$message||');
  }

  // Messages are received in the following format
  // message1_identifier@message1_data||message2_identifier@message2_data||message3_identifier@message3_data
  // This function parses the messages and calls handler
  void parseMessages(String message) {
    if (message.contains("||")) {
      var split = message.split('||');
      for (var i = 0; i < split.length - 1; i++) {
        if (split[i] != "") {
          handleMessage(split[i]);
        }
      }
    }
  }

  //Splits the message and calls the appropriate handler
  void handleMessage(String message) {
    // if (kDebugMode) {
    //   print("Message from server: $message");
    // }
    var split = message.split("@");
    if (split[0] == MessagingProtocol.heartbeat) {
      if (kDebugMode) {
        print("Client: Heartbeat received from ${split[2]}");
      }
      handleHeartbeat(split);
    } else if (split[0] == MessagingProtocol.trustedDevice) {
      if (kDebugMode) {
        print("Client: Trusted device ${split[1]} received.");
      }
      handleTrustedDevice(split[1]);
    } else if (split[0] == MessagingProtocol.logout) {
      if (kDebugMode) {
        print("Client: Logout received from ${split[1]}");
      }
      handleLogout(split);
    } else if (split[0] == MessagingProtocol.becomeServer) {
      if (kDebugMode) {
        print("Client: Become server received from server");
      }
      handleBecomeServer(split);
    } else if (split[0] == MessagingProtocol.connectToNewServer) {
      if (kDebugMode) {
        print("Client: Connect to new server received from server");
      }
      handleConnectToNewServer(split);
    } else if (split[0] == MessagingProtocol.broadcast) {
      if (kDebugMode) {
        print("Client: Broadcast message received from ${split[1]}");
      }
      handleBroadcastMessage(split);
    } else if (split[0] == MessagingProtocol.private) {
      if (kDebugMode) {
        print("Client: Private message received from ${split[1]}");
      }
      handlePrivateMessage(split);
    } else if (split[0] == MessagingProtocol.broadcastImage ||
        split[0] == MessagingProtocol.broadcastImageContd ||
        split[0] == MessagingProtocol.broadcastImageEnd) {
      handleBroadcastImage(split);
    } else if (split[0] == MessagingProtocol.privateImage ||
        split[0] == MessagingProtocol.privateImageContd ||
        split[0] == MessagingProtocol.privateImageEnd) {
      handlePrivateImage(split);
    } else if (split[0] == MessagingProtocol.nameUpdate) {
      if (kDebugMode) {
        print("Client: Name update received from ${split[1]}");
      }
      handleNameUpdate(split);
    } else if (split[0] == MessagingProtocol.rejected) {
      if (kDebugMode) {
        print("Client: Server Rejected the connection.");
      }
      acceptanceEvent.broadcast(AcceptanceEventArgs(accepted: false));
    }
  }

  void handleHeartbeat(List<String> split) {
    if (split[1] != user.macAddress) {
      if (kDebugMode) {
        print("New user added: ${split[2]}");
      }
      ContactsScreen.loggedInUsers.add(User(
          macAddress: split[1], name: split[2], port: int.parse(split[3])));
      usersUpdatedEvent.broadcast();
    }
  }

  void handleTrustedDevice(String macAddress) {
    List<String>? trustedDevices = ContactsScreen.trustedDevicePreferences
        ?.getStringList('trustedDevices');
    trustedDevices ??= [];
    if (!trustedDevices.contains(macAddress)) {
      trustedDevices.add(macAddress);
      ContactsScreen.trustedDevicePreferences
          ?.setStringList('trustedDevices', trustedDevices);
    }
  }

//handle when some other client logs out
  void handleLogout(List<String> split) {
    if (kDebugMode) {
      print("User logged out: ${split[1]}");
    }
    ContactsScreen.loggedInUsers
        .removeWhere((element) => element.port.toString() == split[1]);
    usersUpdatedEvent.broadcast();
  }

  void handleBecomeServer(List<String> split) {
    becomeServerEvent.broadcast();
  }

  void handleConnectToNewServer(List<String> split) {
    connectToNewServerEvent.broadcast();
  }

  void handleBroadcastMessage(List<String> split) async {
    if (split[1] != user.macAddress) {
      broadcastMessageReceivedEvent.broadcast(
        NewMessageEventArgs(
            message: split[2], //message
            sender: ContactsScreen.loggedInUsers
                .firstWhere((element) => element.macAddress == split[1])
                .name,
            receiver: "General Message" //sender
            ),
      );
    }
  }

  void handlePrivateMessage(List<String> split) async {
    privateMessageReceivedEvent.broadcast(
      NewMessageEventArgs(
          message: split[3], //message
          sender: ContactsScreen.loggedInUsers
              .firstWhere((element) => element.macAddress == split[1])
              .name,
          receiver: "Private Message"),
    );
  }

  void handleBroadcastImage(List<String> split) async {
    if (split[0] == MessagingProtocol.broadcastImage) {
      if (kDebugMode) {
        print("Broadcast image received from ${split[1]}");
      }
      _currentImageSenderMac = split[1];
      _currentImageBytes.clear();
    } else if (split[0] == MessagingProtocol.broadcastImageContd) {
      _currentImageBytes.addAll(base64Decode(split[1]));
    } else if (split[0] == MessagingProtocol.broadcastImageEnd) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (listEquals(
          Utility.hashImage(_currentImageBytes), base64Decode(split[1]))) {
        await Future.delayed(const Duration(milliseconds: 50));

        broadcastMessageReceivedEvent.broadcast(
          NewMessageEventArgs(
            message: '',
            imageBytes: _currentImageBytes,
            sender: ContactsScreen.loggedInUsers
                .firstWhere(
                    (element) => element.macAddress == _currentImageSenderMac)
                .name,
            receiver: "General Message", //sender
          ),
        );
      } else {
        broadcastMessageReceivedEvent.broadcast(
          NewMessageEventArgs(
            message: 'Sent an image, but it was corrupted.',
            sender: ContactsScreen.loggedInUsers
                .firstWhere(
                    (element) => element.macAddress == _currentImageSenderMac)
                .name,
            receiver: "General Message", //sender
          ),
        );
      }
    }
  }

  void handlePrivateImage(List<String> split) async {
    if (split[0] == MessagingProtocol.privateImage) {
      if (kDebugMode) {
        print("Private image received from ${split[1]}");
      }
      _currentImageSenderMac = split[1];
      _currentImageBytes.clear();
    } else if (split[0] == MessagingProtocol.privateImageContd) {
      _currentImageBytes.addAll(base64Decode(split[1]));
    } else if (split[0] == MessagingProtocol.privateImageEnd) {
      if (listEquals(
          Utility.hashImage(_currentImageBytes), base64Decode(split[1]))) {
        await Future.delayed(const Duration(milliseconds: 50));
        privateMessageReceivedEvent.broadcast(
          NewMessageEventArgs(
            message: '',
            imageBytes: _currentImageBytes,
            sender: ContactsScreen.loggedInUsers
                .firstWhere(
                    (element) => element.macAddress == _currentImageSenderMac)
                .name,
            receiver: "Private Message", //sender
          ),
        );
      } else {
        privateMessageReceivedEvent.broadcast(
          NewMessageEventArgs(
            message: 'Sent an image, but it was corrupted.',
            sender: ContactsScreen.loggedInUsers
                .firstWhere(
                    (element) => element.macAddress == _currentImageSenderMac)
                .name,
            receiver: "Private Message", //sender
          ),
        );
      }
    }
  }

  void handleNameUpdate(List<String> split) {
    if (split[1] != user.macAddress) {
      if (kDebugMode) {
        print("Name update received from ${split[1]}");
      }
      ContactsScreen.loggedInUsers
          .firstWhere((element) => element.macAddress == split[1])
          .name = split[2];
      usersUpdatedEvent.broadcast();
    }
  }
}
