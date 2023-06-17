import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:local_chat/network/client/client_events.dart';
import 'package:local_chat/network/client/client_receive.dart';
import 'package:local_chat/network/client/client_transmit.dart';

import '../../auth/user.dart';
import '../../encrypt/client_encryption.dart';
import '../messaging_protocol.dart';
import '../../utils/lan_utils.dart';

class LanClient {
  User user;
  Socket? socket;
  bool isConnected = false;
  late String _networkIpAdress;
  late String _networkIpWithoutLastDigits;
  late BigInt _intermediateKey;
  late ClientTransmitter clientTransmit;
  late ClientReceiver _clientReceive;

  ClientSideEncryption clientSideEncryption = ClientSideEncryption();

  LanClient({required this.user});

  // A stream controller for sending messages to the server
  final StreamController<String> _messageStreamController =
      StreamController.broadcast();

  // A stream for receiving messages from the server
  Stream<String> get _messageStream => _messageStreamController.stream;

  Future<void> start() async {
    _networkIpAdress = await LanUtils.getNetworkIPAdress();

    List<String> ipSubParts = _networkIpAdress.split('.');

    // Remove the last subpart
    ipSubParts.removeLast();

    // Join the remaining subparts back into an IP address string
    _networkIpWithoutLastDigits = '${ipSubParts.join('.')}.';

    try {
      user.macAddress = (await LanUtils.getDeviceId())!;
    } catch (e) {
      if (kDebugMode) {
        print(
            "Unsupported Device Type. Creating a random mac address for debug purposes:$e");
        user.macAddress = Random().nextInt(1000000000).toString();
      }
    }
    _messageStream.listen((message) {
      _clientReceive.parseMessages(message);
    });
  }

  // Connect to the server with given lastIpDigit
  //if lastIpDigit is -1, it will directly connect to itself(Server is running on this device)
  Future<void> connect(int lastIpDigit) async {
    var ipAddress = lastIpDigit == -1
        ? _networkIpAdress
        : _networkIpWithoutLastDigits + lastIpDigit.toString();

    // Connect to the server socket
    try {
      socket = await Socket.connect(ipAddress, 12345,
          timeout: const Duration(milliseconds: 2000));
      user.port = socket?.port;
      isConnected = true;
      if (kDebugMode) {
        print('Successfully connected to the server: $ipAddress:12345');
      }
    } catch (e) {
      return;
    }
    clientTransmit = ClientTransmitter(
        user: user,
        socket: socket!,
        clientSideEncryption: clientSideEncryption);
    _clientReceive = ClientReceiver(
        user: user,
        clientSideEncryption: clientSideEncryption,
        connected: isConnected);
    _intermediateKey = clientSideEncryption.generateIntermediateKey();
    //send login to server
    clientTransmit.sendOpenMessage(
        "${MessagingProtocol.login}‽${user.macAddress}‽${user.name}‽${socket!.port}‽$_intermediateKey");
    // Listen for incoming messages from the server
    socket!.listen((data) {
      // Convert the incoming data to a string
      var message = utf8.decode(data).trim();
      _messageStreamController.add(message);
    }).onDone(() {
      //When server is closed, if you are the next candidate , you will become server.
      //otherwise you will connect to new server.
      try {
        _clientReceive.clientNum -= 1;
        if (_clientReceive.clientNum <= 0) {
          ClientEvents.becomeServerEvent.broadcast();
        } else {
          ClientEvents.connectToNewServerEvent.broadcast();
        }
      } catch (e) {
        if (kDebugMode) {
          print("Client is kicked.");
        }
      }
      _clientReceive.stopHeartbeatTimer();
    });
    //Check connection every 10 seconds
    _clientReceive.checkHeartbeat();
  }

  void stop() {
    isConnected = false;
    ClientEvents.stop();
    // Close the client socket to disconnect from the server
    socket?.destroy();
    _messageStreamController.close();
    _clientReceive.stopHeartbeatTimer();
  }
}
