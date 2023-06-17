//AuthEvent is broadcasted when a new device wants to connect to the server
import 'dart:async';
import 'dart:io';

import 'package:event/event.dart';

class AuthEventArgs extends EventArgs {
  String macAddress;
  String name;
  AuthEventArgs({required this.macAddress, required this.name});
}

class CustomStreamController {
  final StreamController<String> messageStreamController =
      StreamController.broadcast();
  Stream<String> get messageStream => messageStreamController.stream;
  Socket socket;
  CustomStreamController({required this.socket});
}
