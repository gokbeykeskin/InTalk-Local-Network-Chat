import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:local_chat/encrypt/encryption.dart';
import 'package:local_chat/network/client/client_events.dart';
import 'package:local_chat/network/client/client_receive.dart';
import 'package:local_chat/network/client/client_transmit.dart';
import '../../auth/user.dart';
import '../messaging_protocol.dart';
import '../../utils/lan_utils.dart';

class LanClient {
  User user;
  Socket? socket;

  String? _networkIpAdress;
  String? _networkIpWithoutLastDigits;
  BigInt? intermediateKey;
  bool connected = false;
  late ClientTransmit clientTransmit;
  late ClientReceive clientReceive;

  ClientSideEncryption clientSideEncryption = ClientSideEncryption();

  LanClient({required this.user});

  // A stream controller for sending messages to the server
  StreamController<String> messageStreamController =
      StreamController.broadcast();

  // A stream for receiving messages from the server
  Stream<String> get messageStream => messageStreamController.stream;

  Future<void> init() async {
    _networkIpAdress = await LanUtils.getNetworkIPAdress();

    List<String> components = _networkIpAdress!.split('.');

    // Remove the last subpart
    components.removeLast();

    // Join the remaining subpart back into an IP address string
    _networkIpWithoutLastDigits = '${components.join('.')}.';

    try {
      user.macAddress = (await LanUtils.getDeviceId())!;
    } catch (e) {
      if (kDebugMode) {
        print("MAC ADDRESS GET FAILED:$e");
        user.macAddress = "11223344"; //for macos debugging
      }
    }
    messageStream.listen((message) {
      clientReceive.parseMessages(message);
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
        //print("Tried:$ipAddress");
        return;
      }
    }
    clientTransmit = ClientTransmit(
        user: user, socket: socket, clientSideEncryption: clientSideEncryption);
    clientReceive =
        ClientReceive(user: user, clientSideEncryption: clientSideEncryption);
    intermediateKey = clientSideEncryption.generateIntermediateKey();
    clientTransmit.sendOpenMessage(
        "${MessagingProtocol.heartbeat}‽${user.macAddress}‽${user.name}‽${socket?.port}‽$intermediateKey");
    // Listen for incoming messages from the server
    socket?.listen((data) {
      // Convert the incoming data to a string
      var message = utf8.decode(data).trim();
      messageStreamController.add(message);
    });

    checkConnectionPeriodically();
  }

  Future<void> stop() async {
    connected = false;
    ClientEvents.stop();
    // Close the client socket to disconnect from the server

    await socket?.close();
  }

  //Potential Bug! Not tested enough.
  void checkConnectionPeriodically() {
    Timer.periodic(const Duration(seconds: 10), (Timer timer) async {
      if (connected) {
        try {
          Socket tempSock = await Socket.connect(socket!.address, 12345,
              timeout: const Duration(milliseconds: 3000));
          await tempSock.close();
        } catch (e) {
          socket?.close();
          connected = false;
          timer.cancel();
          ClientEvents.connectionLostEvent.broadcast();
        }
      }
    });
  }
}
