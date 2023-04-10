import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:event/event.dart';
import 'package:flutter/foundation.dart';

import '../utils/messaging_protocol.dart';
import '../screens/contacts_screen/contacts_screen.dart';

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

class GetMacAddress {
  static Future<String?> getId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      // import 'dart:io'
      var iosDeviceInfo = await deviceInfo.iosInfo;
      return iosDeviceInfo.identifierForVendor; // unique ID on iOS
    } else if (Platform.isAndroid) {
      var androidDeviceInfo = await deviceInfo.androidInfo;
      return androidDeviceInfo.androidId; // unique ID on Android
    }
    return null;
  }
}

class User {
  String? macAddress;
  String name;
  // The socket used to communicate with the server
  int? port;

  User({required this.name, this.port, this.macAddress});
}

class LocalNetworkChatClient {
  User user;
  Socket? socket;
  static var broadcastMessageReceivedEvent = Event();
  static var privateMessageReceivedEvent = Event();
  static var usersUpdatedEvent = Event();
  static var becomeServerEvent = Event();
  static var connectToNewServerEvent = Event();

  String? _networkIpAdress;
  String? _networkIpWithoutLastDigits;

  bool connected = false;

  List<int> _currentImageBytes = [];
  String? _currentImageSender;

  LocalNetworkChatClient({required this.user});

  Future<void> init() async {
    _networkIpAdress = await _getNetworkIPAdress();

    List<String> components = _networkIpAdress!.split('.');

    // Remove the last subpart
    components.removeLast();

    // Join the remaining subpart back into an IP address string
    _networkIpWithoutLastDigits = '${components.join('.')}.';

    try {
      user.macAddress = (await GetMacAddress.getId())!;
    } catch (e) {
      if (kDebugMode) {
        print("MAC ADDRESS GET FAILED:$e");
        user.macAddress = "11223344"; //for macos debugging
      }
    }
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
      parseMessages(message);
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
    await socket?.close();
  }

  void sendBroadcastMessage(String message) {
    sendMessage("${MessagingProtocol.broadcast}@${user.macAddress}@$message");
  }

  void sendPrivateMessage(String message, User receiver) {
    sendMessage(
        "${MessagingProtocol.private}@${user.macAddress}@${receiver.port}@$message");
  }

  void sendBroadcastImage(Uint8List base64Image) async {
    List<Uint8List> bytes = splitImage(base64Image);
    for (var i = 0; i < bytes.length; i++) {
      if (i == 0) {
        sendMessage(
            "${MessagingProtocol.broadcastImage}@${user.macAddress}@${base64Encode(bytes[i])}");
      } else if (i == bytes.length - 1) {
        sendMessage(
            '${MessagingProtocol.broadcastImageEnd}@${base64Encode(bytes[i])}');
      } else {
        sendMessage(
            '${MessagingProtocol.broadcastImageContd}@${base64Encode(bytes[i])}');
      }
      await Future.delayed(const Duration(
          milliseconds:
              10)); //bu delay arttırılarak büyük resimlerdeki hata düzeltilebilir, ama büyük resimler zaten çok uzun sürüyor.
    }
  }

  // Send a message to the server
  void sendMessage(String message) {
    socket?.write('$message||');
  }

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

  void handleMessage(String message) {
    if (kDebugMode) {
      print("Message from server: $message");
    }
    var split = message.split("@");
    if (split[0] == MessagingProtocol.heartbeat) {
      handleHeartbeat(split);
    } else if (split[0] == MessagingProtocol.logout) {
      handleLogout(split);
    } else if (split[0] == MessagingProtocol.becomeServer) {
      handleBecomeServer(split);
    } else if (split[0] == MessagingProtocol.connectToNewServer) {
      handleConnectToNewServer(split);
    } else if (split[0] == MessagingProtocol.broadcast) {
      handleBroadcastMessage(split);
    } else if (split[0] == MessagingProtocol.private) {
      handlePrivateMessage(split);
    } else if (split[0] == MessagingProtocol.broadcastImage ||
        split[0] == MessagingProtocol.broadcastImageContd ||
        split[0] == MessagingProtocol.broadcastImageEnd) {
      handleBroadcastImage(split);
    }
  }

  void handleHeartbeat(List<String> split) {
    if (split[1] != user.macAddress) {
      //kendini listelemek istiyosan bunu aç.
      if (kDebugMode) {
        print("New user added: ${split[2]}");
      }
      ContactsScreen.loggedInUsers.add(User(
          macAddress: split[1], name: split[2], port: int.parse(split[3])));
      usersUpdatedEvent.broadcast();
    }
  }

//handle when some other client logged out
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

  void handleBroadcastMessage(List<String> split) {
    if (split[1] != user.macAddress) {
      broadcastMessageReceivedEvent.broadcast(NewMessageEventArgs(
          message: split[2], //message
          sender: ContactsScreen.loggedInUsers
              .firstWhere((element) => element.macAddress == split[1])
              .name,
          receiver: "General Message" //sender
          ));
    }
  }

  void handlePrivateMessage(List<String> split) {
    privateMessageReceivedEvent.broadcast(NewMessageEventArgs(
        message: split[3], //message
        sender: ContactsScreen.loggedInUsers
            .firstWhere((element) => element.macAddress == split[1])
            .name,
        receiver: "Private Message"));
  }

  void handleBroadcastImage(List<String> split) {
    if (split[0] == MessagingProtocol.broadcastImage) {
      _currentImageSender = split[1];
      _currentImageBytes.clear();
      _currentImageBytes.addAll(base64Decode(split[2]));
    } else if (split[0] == MessagingProtocol.broadcastImageContd) {
      _currentImageBytes.addAll(base64Decode(split[1]));
    } else if (split[0] == MessagingProtocol.broadcastImageEnd) {
      _currentImageBytes.addAll(base64Decode(split[1]));
      broadcastMessageReceivedEvent.broadcast(NewMessageEventArgs(
          message: '',
          imageBytes: _currentImageBytes,
          sender: ContactsScreen.loggedInUsers
              .firstWhere(
                  (element) => element.macAddress == _currentImageSender)
              .name,
          receiver: "General Message" //sender
          ));
    }
  }

  //util functions--------------------------------------------------------------

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

  List<Uint8List> splitImage(Uint8List data) {
    final List<Uint8List> chunks = [];
    const int chunkSize = 256; //bunu arttırarak deney yap.
    int offset = 0;
    int remaining = data.length;

    while (remaining > 0) {
      final int currentChunkSize =
          (remaining < chunkSize) ? remaining : chunkSize;
      final Uint8List chunk = data.sublist(offset, offset + currentChunkSize);
      chunks.add(chunk);
      remaining -= currentChunkSize;
      offset += currentChunkSize;
    }

    return chunks;
  }
}
