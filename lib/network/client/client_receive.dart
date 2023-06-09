import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:local_chat/encrypt/encryption.dart';

import '../../auth/user.dart';
import '../../screens/contacts_screen/contacts_screen.dart';
import '../../utils/image_utils.dart';
import '../messaging_protocol.dart';
import 'client_events.dart';

class ClientReceive {
  ClientSideEncryption clientSideEncryption;
  User user;

  ClientReceive({required this.user, required this.clientSideEncryption});

  final List<int> _currentImageBytes = [];
  String? _currentImageSenderMac;

  // Messages are received in the following format
  // message1_identifier‽message1_data◊message2_identifier‽message2_data◊message3_identifier‽message3_data
  // This function parses the messages and calls handler
  void parseMessages(String message) {
    if (message.contains("◊")) {
      var split = message.split('◊');
      for (var i = 0; i < split.length; i++) {
        if (split[i] != "") {
          handleMessage(split[i]);
        }
      }
    }
  }

  //Splits the message and calls the appropriate handler
  void handleMessage(String message) {
    var split = message.split("‽");

    if (!(split[0] == MessagingProtocol.serverIntermediateKey)) {
      message = clientSideEncryption.decrypt(null, message);
      split = message.split("‽");
    }

    if (split[0] == MessagingProtocol.heartbeat) {
      if (kDebugMode) {
        print("Client: Heartbeat received from ${split[2]}");
      }
      handleHeartbeat(split);
    } else if (split[0] == MessagingProtocol.trustedDevice) {
      if (kDebugMode) {
        print("Client: Trusted device ${split[1]} received.");
      }
      handleTrustedDevice(split[1], split[2]);
    } else if (split[0] == MessagingProtocol.bannedDevice) {
      if (kDebugMode) {
        print("Client: Banned device ${split[1]} received.");
      }
      handleBannedDevice(split[1], split[2]);
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
    } else if (split[0] == MessagingProtocol.broadcastMessage) {
      if (kDebugMode) {
        print("Client: Broadcast message received from ${split[1]}");
      }
      handleBroadcastMessage(split);
    } else if (split[0] == MessagingProtocol.privateMessage) {
      if (kDebugMode) {
        print("Client: Private message received from ${split[1]}");
      }
      handlePrivateMessage(split);
    } else if (split[0] == MessagingProtocol.broadcastImageStart ||
        split[0] == MessagingProtocol.broadcastImageContd ||
        split[0] == MessagingProtocol.broadcastImageEnd) {
      handleBroadcastImage(split);
    } else if (split[0] == MessagingProtocol.privateImageStart ||
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
      ClientEvents.acceptanceEvent
          .broadcast(AcceptanceEventArgs(accepted: false));
    } else if (split[0] == MessagingProtocol.serverIntermediateKey) {
      if (kDebugMode) {
        print("Client: Server intermediate key received.");
      }
      clientSideEncryption.generateFinalKey(BigInt.parse(split[1]), split[2]);
    }
  }

  void handleHeartbeat(List<String> split) {
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

  void handleTrustedDevice(String macAddress, String userName) {
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

  void handleBannedDevice(String macAddress, String userName) {
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
  void handleLogout(List<String> split) {
    if (kDebugMode) {
      print("User logged out: ${split[1]}");
    }
    ContactsScreen.loggedInUsers
        .removeWhere((element) => element.port.toString() == split[1]);
    ClientEvents.usersUpdatedEvent.broadcast();
  }

  void handleBecomeServer(List<String> split) {
    ClientEvents.becomeServerEvent.broadcast();
  }

  void handleConnectToNewServer(List<String> split) {
    ClientEvents.connectToNewServerEvent.broadcast();
  }

  void handleBroadcastMessage(List<String> split) async {
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

  void handlePrivateMessage(List<String> split) async {
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

  void handleBroadcastImage(List<String> split) async {
    if (split[0] == MessagingProtocol.broadcastImageStart) {
      if (kDebugMode) {
        print("Broadcast image received from ${split[1]}");
      }
      _currentImageSenderMac = split[1];
      _currentImageBytes.clear();
    } else if (split[0] == MessagingProtocol.broadcastImageContd) {
      if (split[1].length % 4 > 0) {
        if (kDebugMode) {
          print("Base64 image corrupted, trying to fix it.");
        }
        split[1] += 'c' * (4 - split[1].length % 4); //split should be base64
      }
      _currentImageBytes.addAll(base64Decode(split[1]));
    } else if (split[0] == MessagingProtocol.broadcastImageEnd) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (listEquals(
          ImageUtils.hashImage(_currentImageBytes), base64Decode(split[1]))) {
        ClientEvents.broadcastMessageReceivedEvent.broadcast(
          NewMessageEventArgs(
            senderMac: _currentImageSenderMac!,
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
        ClientEvents.broadcastMessageReceivedEvent.broadcast(
          NewMessageEventArgs(
            senderMac: _currentImageSenderMac!,
            message: 'Sent an image, but it was corrupted.',
            imageBytes: _currentImageBytes,
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
    if (split[0] == MessagingProtocol.privateImageStart) {
      if (kDebugMode) {
        print("Private image received from ${split[1]}");
      }
      _currentImageSenderMac = split[1];
      _currentImageBytes.clear();
    } else if (split[0] == MessagingProtocol.privateImageContd) {
      if (split[1].length % 4 > 0) {
        if (kDebugMode) {
          print("Base64 image corrupted, trying to fix it.");
        }
        split[1] += 'c' * (4 - split[1].length % 4); //split should be base64
      }
      _currentImageBytes.addAll(base64Decode(split[1]));
    } else if (split[0] == MessagingProtocol.privateImageEnd) {
      await Future.delayed(const Duration(milliseconds: 80));

      if (listEquals(
          ImageUtils.hashImage(_currentImageBytes), base64Decode(split[1]))) {
        ClientEvents.privateMessageReceivedEvent.broadcast(
          NewMessageEventArgs(
            senderMac: _currentImageSenderMac!,
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
        ClientEvents.privateMessageReceivedEvent.broadcast(
          NewMessageEventArgs(
            senderMac: _currentImageSenderMac!,
            message: 'Sent an image, but it was corrupted.',
            imageBytes: _currentImageBytes,
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
