import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../auth/user.dart';
import '../../encrypt/client_encryption.dart';
import '../../screens/contacts_screen/contacts_screen.dart';
import '../../utils/image_utils.dart';
import '../../utils/trusted_device_utils.dart';
import '../messaging_protocol.dart';
import 'client_events.dart';

//Handles all the messages received by the server
class ClientReceiver {
  //for handling access point transfers. When server quits 1st client becomes server
  //and the rest of the clients connect to the new server.
  late int clientNum;
  final ClientSideEncryption clientSideEncryption;
  //Your information.
  final User user;
  DateTime _lastHeartbeat = DateTime.now();
  bool connected;

  late Timer _heartBeatTimer;
  ClientReceiver(
      {required this.connected,
      required this.user,
      required this.clientSideEncryption});
  //MAC-Image bytes
  //This is used to keep track of the image bytes received from each client since
  //the image bytes are received in chunks.
  final Map<String, List<int>> _currentImageSenders = {};
  // Messages are received in the following format
  // message1_identifier‽message1_data◊message2_identifier‽message2_data◊message3_identifier‽message3_data
  // This function parses the messages and calls handler
  void parseMessages(String message) {
    if (message.contains("◊")) {
      var tokens = message.split('◊');
      for (var i = 0; i < tokens.length; i++) {
        if (tokens[i] != "") {
          _handleMessage(tokens[i]);
        }
      }
    }
  }

  //Splits the message and calls the appropriate handler
  Future<void> _handleMessage(String message) async {
    var tokens = message.split("‽");
    //All the messages except the server intermediate key are encrypted
    //So we need to decrypt them before handling them.
    if (!(tokens[0] == MessagingProtocol.serverIntermediateKey)) {
      message = await clientSideEncryption.decrypt(null, message);
      tokens = message.split("‽");
    }

    if (tokens[0] == MessagingProtocol.login) {
      if (kDebugMode) {
        print("Client: Login received from ${tokens[2]}");
      }
      _handleLogin(tokens);
    } else if (tokens[0] == MessagingProtocol.heartbeat) {
      if (kDebugMode) {
        print("Client: Heartbeat received from server.");
      }
      _lastHeartbeat = DateTime.now();
    } else if (tokens[0] == MessagingProtocol.trustedDevice) {
      if (kDebugMode) {
        print("Client: Trusted device ${tokens[1]} received.");
      }
      _handleTrustedDevice(tokens[1], tokens[2]);
    } else if (tokens[0] == MessagingProtocol.bannedDevice) {
      if (kDebugMode) {
        print("Client: Banned device ${tokens[1]} received.");
      }
      _handleBannedDevice(tokens[1], tokens[2]);
    } else if (tokens[0] == MessagingProtocol.untrustDevice) {
      if (kDebugMode) {
        print("Client: Trusted device ${tokens[1]} received.");
      }
      TrustedDeviceUtils.handleUntrustedDevice(tokens[1]);
    } else if (tokens[0] == MessagingProtocol.unbanDevice) {
      if (kDebugMode) {
        print("Client: Banned device ${tokens[1]} received.");
      }
      TrustedDeviceUtils.handleUnbannedDevice(tokens[1]);
    } else if (tokens[0] == MessagingProtocol.logout) {
      if (kDebugMode) {
        print("Client: Logout received from ${tokens[1]}");
      }
      _handleLogout(tokens);
    } else if (tokens[0] == MessagingProtocol.broadcastMessage) {
      if (kDebugMode) {
        print("Client: Broadcast message received from ${tokens[1]}");
      }
      _handleBroadcastMessage(tokens);
    } else if (tokens[0] == MessagingProtocol.privateMessage) {
      if (kDebugMode) {
        print("Client: Private message received from ${tokens[1]}");
      }
      _handlePrivateMessage(tokens);
    } else if (tokens[0] == MessagingProtocol.broadcastImageStart ||
        tokens[0] == MessagingProtocol.broadcastImageContd ||
        tokens[0] == MessagingProtocol.broadcastImageEnd) {
      _handleBroadcastImage(tokens);
    } else if (tokens[0] == MessagingProtocol.privateImageStart ||
        tokens[0] == MessagingProtocol.privateImageContd ||
        tokens[0] == MessagingProtocol.privateImageEnd) {
      _handlePrivateImage(tokens);
    } else if (tokens[0] == MessagingProtocol.nameUpdate) {
      if (kDebugMode) {
        print("Client: Name update received from ${tokens[1]}");
      }
      _handleNameUpdate(tokens);
    } else if (tokens[0] == MessagingProtocol.rejected) {
      if (kDebugMode) {
        print("Client: Server Rejected the connection.");
      }
      ClientEvents.rejectedEvent.broadcast();
    } else if (tokens[0] == MessagingProtocol.serverIntermediateKey) {
      if (kDebugMode) {
        print("Client: Server intermediate key received.");
      }
      clientSideEncryption.generateFinalKey(BigInt.parse(tokens[1]), tokens[2]);
    } else if (tokens[0] == MessagingProtocol.clientNumber) {
      clientNum = int.parse(tokens[1]);

      if (kDebugMode) {
        print("Client: Number Received: $clientNum");
      }
    }
  }

  void _handleLogin(List<String> tokens) {
    if (tokens[1] != user.macAddress) {
      if (kDebugMode) {
        print("New user added: ${tokens[2]}");
      }
      if (ContactsScreen.loggedInUsers
          .where((element) => element.macAddress == tokens[1])
          .isEmpty) {
        ContactsScreen.loggedInUsers.add(User(
            macAddress: tokens[1],
            name: tokens[2],
            port: int.parse(tokens[3])));
      }
      TrustedDeviceUtils.updateTrustedDeviceNames(tokens[1], tokens[2]);
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
    ClientEvents.usersUpdatedEvent.broadcast();
  }

  void _handleBannedDevice(String macAddress, String userName) {
    List<String>? bannedDeviceMACs = ContactsScreen.trustedDevicePreferences
        ?.getStringList('bannedDeviceMACs');
    bannedDeviceMACs ??= [];
    List<String>? bannedDeviceNames = ContactsScreen.trustedDevicePreferences
        ?.getStringList('bannedDeviceNames');
    bannedDeviceNames ??= [];
    if (!bannedDeviceMACs.contains(macAddress) &&
        macAddress != user.macAddress) {
      bannedDeviceMACs.add(macAddress);
      bannedDeviceNames.add(userName);
      ContactsScreen.trustedDevicePreferences
          ?.setStringList('bannedDeviceMACs', bannedDeviceMACs);
      ContactsScreen.trustedDevicePreferences
          ?.setStringList('bannedDeviceNames', bannedDeviceNames);
    }
    ClientEvents.usersUpdatedEvent.broadcast();
  }

//handle when some other client logs out
  void _handleLogout(List<String> tokens) {
    if (kDebugMode) {
      print("User logged out: ${tokens[1]}");
    }
    ContactsScreen.loggedInUsers
        .removeWhere((element) => element.port.toString() == tokens[1]);
    ClientEvents.usersUpdatedEvent.broadcast();
  }

  void _handleBroadcastMessage(List<String> tokens) {
    if (tokens[1] != user.macAddress) {
      if (kDebugMode) {
        print("Received a broadcast message at time ${DateTime.now()}");
      }
      ClientEvents.broadcastMessageReceivedEvent.broadcast(
        NewMessageEventArgs(
            senderMac: tokens[1],
            message: tokens[2],
            sender: ContactsScreen.loggedInUsers
                .firstWhere((element) => element.macAddress == tokens[1])
                .name,
            receiver: "General Message"),
      );
    }
  }

  void _handlePrivateMessage(List<String> tokens) {
    ClientEvents.privateMessageReceivedEvent.broadcast(
      NewMessageEventArgs(
          senderMac: tokens[1],
          message: tokens[3],
          sender: ContactsScreen.loggedInUsers
              .firstWhere((element) => element.macAddress == tokens[1])
              .name,
          receiver: "Private Message"),
    );
  }

  void _handleBroadcastImage(List<String> tokens) async {
    if (tokens[0] == MessagingProtocol.broadcastImageStart) {
      if (kDebugMode) {
        print("Broadcast image received from ${tokens[1]}");
      }
      _currentImageSenders[tokens[1]] = List.generate(
          int.parse(tokens[2]) * (ImageUtils.chunkSize), (index) => 0);
    } else if (tokens[0] == MessagingProtocol.broadcastImageContd) {
      if (tokens[1].length % 4 > 0) {
        if (kDebugMode) {
          print("Base64 image corrupted, trying to fix it.");
        }
        tokens[1] += 'c' * (4 - tokens[1].length % 4); //token should be base64
      }
      //add incoming image bytes to senders list
      int index = int.parse(tokens[3]) * ImageUtils.chunkSize;
      _currentImageSenders[tokens[2]]!.replaceRange(
          index, index + ImageUtils.chunkSize, base64Decode(tokens[1]));
    } else if (tokens[0] == MessagingProtocol.broadcastImageEnd) {
      ClientEvents.broadcastMessageReceivedEvent.broadcast(
        NewMessageEventArgs(
          senderMac: tokens[2],
          //if the received hash is equal to the hash of the received image, then the image is not corrupted.
          message: listEquals(
                  ImageUtils.hashImage(_currentImageSenders[tokens[2]]!),
                  base64Decode(tokens[1]))
              ? ''
              : 'Sent an image, but it was corrupted.',

          imageBytes: _currentImageSenders[tokens[2]]!,
          sender: ContactsScreen.loggedInUsers
              .firstWhere((element) => element.macAddress == tokens[2])
              .name,
          receiver: "General Message",
        ),
      );
      _currentImageSenders.remove(tokens[2]);
    }
  }

  void _handlePrivateImage(List<String> tokens) async {
    if (tokens[0] == MessagingProtocol.privateImageStart) {
      if (kDebugMode) {
        print("Private image received from ${tokens[1]}");
      }
      _currentImageSenders[tokens[1]] = List.generate(
          int.parse(tokens[3]) * ImageUtils.chunkSize, (index) => 0);
    } else if (tokens[0] == MessagingProtocol.privateImageContd) {
      if (tokens[1].length % 4 > 0) {
        if (kDebugMode) {
          print("Base64 image corrupted, trying to fix it.");
        }
        tokens[1] += 'c' * (4 - tokens[1].length % 4); //token should be base64
      }
      int index = int.parse(tokens[4]) * ImageUtils.chunkSize;
      _currentImageSenders[tokens[2]]!.replaceRange(
          index, index + ImageUtils.chunkSize, base64Decode(tokens[1]));
    } else if (tokens[0] == MessagingProtocol.privateImageEnd) {
      ClientEvents.privateMessageReceivedEvent.broadcast(
        NewMessageEventArgs(
          senderMac: tokens[2],
          message: listEquals(
                  ImageUtils.hashImage(_currentImageSenders[tokens[2]]!),
                  base64Decode(tokens[1]))
              ? ''
              : 'Sent an image, but it was corrupted.',
          imageBytes: _currentImageSenders[tokens[2]]!,
          sender: ContactsScreen.loggedInUsers
              .firstWhere((element) => element.macAddress == tokens[2])
              .name,
          receiver: "Private Message",
        ),
      );
      _currentImageSenders.remove(tokens[2]);
    }
  }

  void _handleNameUpdate(List<String> tokens) {
    if (tokens[1] != user.macAddress) {
      if (kDebugMode) {
        print("Name update received from ${tokens[1]}");
      }
      TrustedDeviceUtils.updateTrustedDeviceNames(tokens[1], tokens[2]);
      ContactsScreen.loggedInUsers
          .firstWhere((element) => element.macAddress == tokens[1])
          .name = tokens[2];
      ClientEvents.usersUpdatedEvent.broadcast();
    }
  }

  void checkHeartbeat() {
    _heartBeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (DateTime.now().difference(_lastHeartbeat) >
          const Duration(seconds: 5)) {
        if (kDebugMode) {
          print("Heartbeat timed out, disconnecting.");
        }
        //Connection is lost
        connected = false;
        timer.cancel();
        ClientEvents.connectionLostEvent.broadcast();
      }
    });
  }

  void stopHeartbeatTimer() {
    _heartBeatTimer.cancel();
  }
}
