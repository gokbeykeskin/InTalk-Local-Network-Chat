import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:event/event.dart';
import 'package:flutter/foundation.dart';

import '../screens/chat_screen/chat_screen.dart';
import '../screens/chat_screen/custom_widgets/message_box.dart';
import '../utils/messaging_protocol.dart';
import '../screens/contacts_screen.dart';

class NewMessageEventArgs extends EventArgs {
  final String message;
  final String sender;
  NewMessageEventArgs(this.message, this.sender);
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
  static var usersUpdatedEvent = Event();
  static var becomeServerEvent = Event();
  static var connectToNewServerEvent = Event();
  bool connected = false;
  LocalNetworkChatClient({required this.user});

  // Connect to the server
  Future<void> connect(int lastIpDigit) async {
    try {
      user.macAddress = (await GetMacAddress.getId())!;
    } catch (e) {
      if (kDebugMode) {
        print("MAC ADDRESS GET FAILED:$e");
        user.macAddress = "11223344"; //for macos debugging
      }
    }
    var ipAddress = lastIpDigit == -1
        ? await _getNetworkIPAdress()
        : await _getNetworkIpWithoutLastDigits() + lastIpDigit.toString();

    // Connect to the server socket
    try {
      socket = await Socket.connect(ipAddress, 12345,
          timeout: const Duration(milliseconds: 80));
      user.port = socket?.port;
      connected = true;
      print('Successfully connected to the server: $ipAddress:12345');
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
    await socket?.close();
  }

  void sendBroadcastMessage(String message) {
    sendMessage("${MessagingProtocol.broadcast}@${user.macAddress}@$message");
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
    }
  }

  void handleHeartbeat(List<String> split) {
    //if (split[1] != user.macAddress) {
    //kendini listelemek istiyosan bunu aç.
    if (kDebugMode) {
      print("New user added: ${split[2]}");
    }
    ContactsScreen.loggedInUsers.add(
        User(macAddress: split[1], name: split[2], port: int.parse(split[3])));
    usersUpdatedEvent.broadcast();
    //}
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
        split[2], //message
        ContactsScreen.loggedInUsers
            .firstWhere((element) => element.macAddress == split[1])
            .name, //sender
      ));
    }
  }

  //util functions--------------------------------------------------------------
  Future<String> _getNetworkIpWithoutLastDigits() async {
    String ipAddress = '';
    List<NetworkInterface> interfaces = await NetworkInterface.list();
    for (NetworkInterface interface in interfaces) {
      if (interface.name.startsWith('wlan') ||
          interface.name.startsWith('en')) {
        ipAddress = interface.addresses.first.address;
        break;
      }
    }
    // Split the IP address into subparts
    List<String> components = ipAddress.split('.');

    // Remove the last subpart
    components.removeLast();

    // Join the remaining subpart back into an IP address string
    return '${components.join('.')}.';
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
