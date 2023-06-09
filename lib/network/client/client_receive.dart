import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../auth/user.dart';
import '../../encrypt/client_encryption.dart';
import '../../screens/contacts_screen/contacts_screen.dart';
import '../../utils/image_utils.dart';
import '../messaging_protocol.dart';
import 'client_events.dart';

class ImageSender {
  final String senderMac;
  final List<int> imageBytes;
  ImageSender({required this.senderMac, required this.imageBytes});
}

//Handles all the messages received by the server
class ClientReceiver {
  //for handling access point transfers. When server quits 1st client becomes server
  //and the rest of the clients connect to the new server.
  late int clientNum;
  final ClientSideEncryption clientSideEncryption;
  //Your information.
  final User user;

  ClientReceiver({required this.user, required this.clientSideEncryption});

  //MAC-Image bytes
  //This is used to keep track of the image bytes received from each client since
  //the image bytes are received in chunks.
  final Map<String, List<int>> _currentImageSenders = {};
  // Messages are received in the following format
  // message1_identifier‽message1_data◊message2_identifier‽message2_data◊message3_identifier‽message3_data
  // This function parses the messages and calls handler
  void parseMessages(String message) {
    if (message.contains("◊")) {
      var split = message.split('◊');
      for (var i = 0; i < split.length; i++) {
        if (split[i] != "") {
          _handleMessage(split[i]);
        }
      }
    }
  }

  //Splits the message and calls the appropriate handler
  void _handleMessage(String message) {
    var split = message.split("‽");

    //All the messages except the server intermediate key are encrypted
    //So we need to decrypt them before handling them.
    if (!(split[0] == MessagingProtocol.serverIntermediateKey)) {
      message = clientSideEncryption.decrypt(null, message);
      split = message.split("‽");
    }

    if (split[0] == MessagingProtocol.login) {
      if (kDebugMode) {
        print("Client: Login received from ${split[2]}");
      }
      _handleLogin(split);
    } else if (split[0] == MessagingProtocol.trustedDevice) {
      if (kDebugMode) {
        print("Client: Trusted device ${split[1]} received.");
      }
      _handleTrustedDevice(split[1], split[2]);
    } else if (split[0] == MessagingProtocol.bannedDevice) {
      if (kDebugMode) {
        print("Client: Banned device ${split[1]} received.");
      }
      _handleBannedDevice(split[1], split[2]);
    } else if (split[0] == MessagingProtocol.logout) {
      if (kDebugMode) {
        print("Client: Logout received from ${split[1]}");
      }
      _handleLogout(split);
    } else if (split[0] == MessagingProtocol.broadcastMessage) {
      if (kDebugMode) {
        print("Client: Broadcast message received from ${split[1]}");
      }
      _handleBroadcastMessage(split);
    } else if (split[0] == MessagingProtocol.privateMessage) {
      if (kDebugMode) {
        print("Client: Private message received from ${split[1]}");
      }
      _handlePrivateMessage(split);
    } else if (split[0] == MessagingProtocol.broadcastImageStart ||
        split[0] == MessagingProtocol.broadcastImageContd ||
        split[0] == MessagingProtocol.broadcastImageEnd) {
      _handleBroadcastImage(split);
    } else if (split[0] == MessagingProtocol.privateImageStart ||
        split[0] == MessagingProtocol.privateImageContd ||
        split[0] == MessagingProtocol.privateImageEnd) {
      _handlePrivateImage(split);
    } else if (split[0] == MessagingProtocol.nameUpdate) {
      if (kDebugMode) {
        print("Client: Name update received from ${split[1]}");
      }
      _handleNameUpdate(split);
    } else if (split[0] == MessagingProtocol.rejected) {
      if (kDebugMode) {
        print("Client: Server Rejected the connection.");
      }
      ClientEvents.rejectedEvent.broadcast();
    } else if (split[0] == MessagingProtocol.serverIntermediateKey) {
      if (kDebugMode) {
        print("Client: Server intermediate key received.");
      }
      clientSideEncryption.generateFinalKey(BigInt.parse(split[1]), split[2]);
    } else if (split[0] == MessagingProtocol.clientNumber) {
      clientNum = int.parse(split[1]);
      print("My Client Number: ${clientNum}");
    } else if (split[0] == MessagingProtocol.decreaseClientNumber) {
      clientNum -= 1;
      print("Decrease Number, My New Client Number: ${clientNum}");
    }
  }

  void _handleLogin(List<String> split) {
    if (split[1] != user.macAddress) {
      if (kDebugMode) {
        print("New user added: ${split[2]}");
      }
      ContactsScreen.loggedInUsers.add(User(
          macAddress: split[1], name: split[2], port: int.parse(split[3])));
      _updateTrustedDeviceNames(split[1], split[2]);
      ClientEvents.usersUpdatedEvent.broadcast();
    }
  }

  void _handleTrustedDevice(String macAddress, String userName) {
    List<String>? trustedDeviceMACs = ContactsScreen.trustedDevicePreferences
        ?.getStringList('trustedDeviceMACs');
    trustedDeviceMACs ??= [];
    List<String>? trustedDeviceNames = ContactsScreen.trustedDevicePreferences
        ?.getStringList('trustedDeviceNames');
    trustedDeviceNames ??= [];
    if (!trustedDeviceMACs.contains(macAddress)) {
      trustedDeviceMACs.add(macAddress);
      trustedDeviceNames.add(userName);
      ContactsScreen.trustedDevicePreferences
          ?.setStringList('trustedDeviceMACs', trustedDeviceMACs);
      ContactsScreen.trustedDevicePreferences
          ?.setStringList('trustedDeviceNames', trustedDeviceNames);
    }
  }

  void _handleBannedDevice(String macAddress, String userName) {
    List<String>? bannedDeviceMACs = ContactsScreen.trustedDevicePreferences
        ?.getStringList('bannedDeviceMACs');
    bannedDeviceMACs ??= [];
    List<String>? bannedDeviceNames = ContactsScreen.trustedDevicePreferences
        ?.getStringList('bannedDeviceNames');
    bannedDeviceNames ??= [];
    if (!bannedDeviceMACs.contains(macAddress)) {
      bannedDeviceMACs.add(macAddress);
      bannedDeviceNames.add(userName);
      ContactsScreen.trustedDevicePreferences
          ?.setStringList('bannedDeviceMACs', bannedDeviceMACs);
      ContactsScreen.trustedDevicePreferences
          ?.setStringList('bannedDeviceNames', bannedDeviceNames);
    }
  }

//handle when some other client logs out
  void _handleLogout(List<String> split) {
    if (kDebugMode) {
      print("User logged out: ${split[1]}");
    }
    ContactsScreen.loggedInUsers
        .removeWhere((element) => element.port.toString() == split[1]);
    ClientEvents.usersUpdatedEvent.broadcast();
  }

  void _handleBroadcastMessage(List<String> split) async {
    if (split[1] != user.macAddress) {
      ClientEvents.broadcastMessageReceivedEvent.broadcast(
        NewMessageEventArgs(
            senderMac: split[1],
            message: split[2], //message
            sender: ContactsScreen.loggedInUsers
                .firstWhere((element) => element.macAddress == split[1])
                .name,
            receiver: "General Message" //sender
            ),
      );
    }
  }

  void _handlePrivateMessage(List<String> split) async {
    ClientEvents.privateMessageReceivedEvent.broadcast(
      NewMessageEventArgs(
          senderMac: split[1],
          message: split[3], //message
          sender: ContactsScreen.loggedInUsers
              .firstWhere((element) => element.macAddress == split[1])
              .name,
          receiver: "Private Message"),
    );
  }

  void _handleBroadcastImage(List<String> split) async {
    if (split[0] == MessagingProtocol.broadcastImageStart) {
      if (kDebugMode) {
        print("Broadcast image received from ${split[1]}");
      }
      _currentImageSenders[split[1]] = [];
    } else if (split[0] == MessagingProtocol.broadcastImageContd) {
      if (split[1].length % 4 > 0) {
        if (kDebugMode) {
          print("Base64 image corrupted, trying to fix it.");
        }
        split[1] += 'c' * (4 - split[1].length % 4); //split should be base64
      }
      //add incoming image bytes to senders list
      _currentImageSenders[split[2]]!.addAll(base64Decode(split[1]));
    } else if (split[0] == MessagingProtocol.broadcastImageEnd) {
      await Future.delayed(const Duration(milliseconds: 80));
      ClientEvents.broadcastMessageReceivedEvent.broadcast(
        NewMessageEventArgs(
          senderMac: split[2],
          //if the received hash is equal to the hash of the received image, then the image is not corrupted.
          message: listEquals(
                  ImageUtils.hashImage(_currentImageSenders[split[2]]!),
                  base64Decode(split[1]))
              ? ''
              : 'Sent an image, but it was corrupted.',
          imageBytes: _currentImageSenders[split[2]]!,
          sender: ContactsScreen.loggedInUsers
              .firstWhere((element) => element.macAddress == split[2])
              .name,
          receiver: "General Message", //sender
        ),
      );
      _currentImageSenders.remove(split[2]);
    }
  }

  void _handlePrivateImage(List<String> split) async {
    if (split[0] == MessagingProtocol.privateImageStart) {
      if (kDebugMode) {
        print("Private image received from ${split[1]}");
      }
      _currentImageSenders[split[1]] = [];
    } else if (split[0] == MessagingProtocol.privateImageContd) {
      if (split[1].length % 4 > 0) {
        if (kDebugMode) {
          print("Base64 image corrupted, trying to fix it.");
        }
        split[1] += 'c' * (4 - split[1].length % 4); //split should be base64
      }
      _currentImageSenders[split[2]]!.addAll(base64Decode(split[1]));
    } else if (split[0] == MessagingProtocol.privateImageEnd) {
      await Future.delayed(const Duration(milliseconds: 80));

      ClientEvents.privateMessageReceivedEvent.broadcast(
        NewMessageEventArgs(
          senderMac: split[2],
          message: listEquals(
                  ImageUtils.hashImage(_currentImageSenders[split[2]]!),
                  base64Decode(split[1]))
              ? ''
              : 'Sent an image, but it was corrupted.',
          imageBytes: _currentImageSenders[split[2]]!,
          sender: ContactsScreen.loggedInUsers
              .firstWhere((element) => element.macAddress == split[2])
              .name,
          receiver: "Private Message", //sender
        ),
      );
      _currentImageSenders.remove(split[2]);
    }
  }

  void _handleNameUpdate(List<String> split) {
    if (split[1] != user.macAddress) {
      if (kDebugMode) {
        print("Name update received from ${split[1]}");
      }
      _updateTrustedDeviceNames(split[1], split[2]);
      ContactsScreen.loggedInUsers
          .firstWhere((element) => element.macAddress == split[1])
          .name = split[2];
      ClientEvents.usersUpdatedEvent.broadcast();
    }
  }

  //when a user changes their name, update the name in the trusted device list.
  void _updateTrustedDeviceNames(String mac, String name) {
    List<String> trustedDeviceMACs = ContactsScreen.trustedDevicePreferences
            ?.getStringList('trustedDeviceMACs') ??
        [];
    List<String> trustedDeviceNames = ContactsScreen.trustedDevicePreferences
            ?.getStringList('trustedDeviceNames') ??
        [];
    if (trustedDeviceMACs.contains(mac)) {
      trustedDeviceNames[trustedDeviceMACs.indexOf(mac)] = name;
      ContactsScreen.trustedDevicePreferences
          ?.setStringList('trustedDeviceNames', trustedDeviceNames);
    }
  }
}
