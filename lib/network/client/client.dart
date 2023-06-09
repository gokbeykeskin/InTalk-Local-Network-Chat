import 'dart:convert';
import 'dart:io';
import 'dart:async';

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
  late Socket socket;
  bool connected = false;

  late String _networkIpAdress;
  late String _networkIpWithoutLastDigits;
  late BigInt _intermediateKey;
  late ClientTransmit clientTransmit;
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
        print("MAC ADDRESS GET FAILED:$e");
        user.macAddress = "11223344"; //for macos debugging
      }
    }
    _messageStream.listen((message) {
      _clientReceive.parseMessages(message);
    });
  }

  // Connect to the server
  //if lastIpDigit is -1, it will directly connect to itself
  //(Server is running on this device)
  Future<void> connect(int lastIpDigit) async {
    var ipAddress = lastIpDigit == -1
        ? _networkIpAdress
        : _networkIpWithoutLastDigits + lastIpDigit.toString();

    // Connect to the server socket
    try {
      socket = await Socket.connect(ipAddress, 12345,
          timeout: const Duration(milliseconds: 2000));
      user.port = socket.port;
      connected = true;
      if (kDebugMode) {
        print('Successfully connected to the server: $ipAddress:12345');
      }
    } catch (e) {
      if (kDebugMode) {
        //print("Tried:$ipAddress");
        return;
      }
    }
    clientTransmit = ClientTransmit(
        user: user, socket: socket, clientSideEncryption: clientSideEncryption);
    _clientReceive =
        ClientReceiver(user: user, clientSideEncryption: clientSideEncryption);
    _intermediateKey = clientSideEncryption.generateIntermediateKey();
    clientTransmit.sendOpenMessage(
        "${MessagingProtocol.login}‽${user.macAddress}‽${user.name}‽${socket.port}‽$_intermediateKey");
    // Listen for incoming messages from the server
    socket.listen((data) {
      // Convert the incoming data to a string
      var message = utf8.decode(data).trim();
      _messageStreamController.add(message);
    }).onDone(() {
      //When server is closed, if you are the next candidate , you will become server.
      //otherwise you will connect to new server.
      _clientReceive.clientNum -= 1;
      if (_clientReceive.clientNum == 0) {
        ClientEvents.becomeServerEvent.broadcast();
      } else {
        ClientEvents.connectToNewServerEvent.broadcast();
      }
    });
    //Check connection every 10 seconds
    _heartbeat();
  }

  void stop() {
    connected = false;
    ClientEvents.stop();
    // Close the client socket to disconnect from the server
    socket.destroy();
    _messageStreamController.close();
  }

  //Try to connect to server every 10 seconds to check if connection is lost.
  void _heartbeat() {
    Timer.periodic(const Duration(seconds: 10), (Timer timer) async {
      if (connected) {
        try {
          Socket tempSock = await Socket.connect(socket.address, 12345,
              timeout: const Duration(milliseconds: 8000));
          tempSock.destroy();
        } catch (e) {
          if (kDebugMode) {
            print("Periodic check (connection lost):$e");
          }
          connected = false;
          timer.cancel();
          ClientEvents.connectionLostEvent.broadcast();
        } finally {}
      }
    });
  }
}
