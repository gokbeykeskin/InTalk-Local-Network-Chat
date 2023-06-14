import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../auth/user.dart';
import '../../encrypt/client_encryption.dart';
import '../../utils/image_utils.dart';
import '../messaging_protocol.dart';

class ClientTransmit {
  ClientSideEncryption clientSideEncryption;
  User user;
  Socket socket;
  ClientTransmit(
      {required this.user,
      required this.socket,
      required this.clientSideEncryption});

  //send a message to general chat
  void sendBroadcastMessage(String message) {
    print("Sending a broadcast message at time ${DateTime.now()}");
    _sendMessage(
        "${MessagingProtocol.broadcastMessage}‽${user.macAddress}‽$message");
  }

  //send a message to a specific person.
  void sendPrivateMessage(String message, User receiver) {
    _sendMessage(
        "${MessagingProtocol.privateMessage}‽${user.macAddress}‽${receiver.port}‽$message");
  }

  //send an image to general chat
  Future<void> sendBroadcastImage(Uint8List base64Image) async {
    List<Uint8List> bytes = ImageUtils.splitImage(base64Image);
    List<int> hashedBytes = ImageUtils.hashImage(base64Image);
    _sendMessage("${MessagingProtocol.broadcastImageStart}‽${user.macAddress}");
    for (var i = 0; i < bytes.length; i++) {
      await Future.delayed(
        const Duration(milliseconds: 50),
      );
      _sendMessage(
          '${MessagingProtocol.broadcastImageContd}‽${base64Encode(bytes[i])}‽${user.macAddress}');
    }
    _sendMessage(
        '${MessagingProtocol.broadcastImageEnd}‽${base64Encode(hashedBytes)}‽${user.macAddress}');
  }

  //send an image to a specific person.
  Future<void> sendPrivateImage(Uint8List base64Image, User receiver) async {
    List<Uint8List> bytes = ImageUtils.splitImage(base64Image);
    List<int> hashedBytes = ImageUtils.hashImage(base64Image);
    _sendMessage(
        "${MessagingProtocol.privateImageStart}‽${user.macAddress}‽${receiver.port}");
    for (var i = 0; i < bytes.length; i++) {
      await Future.delayed(
        const Duration(milliseconds: 50),
      );
      _sendMessage(
          '${MessagingProtocol.privateImageContd}‽${base64Encode(bytes[i])}‽${user.macAddress}‽${receiver.port}');
    }
    _sendMessage(
        '${MessagingProtocol.privateImageEnd}‽${base64Encode(hashedBytes)}‽${user.macAddress}‽${receiver.port}');
  }

  //send a request to the server to server to change your name.
  void changeName(String newName) {
    user.name = newName;
    _sendMessage(
        "${MessagingProtocol.nameUpdate}‽${user.macAddress}‽${user.name}");
  }

  // Send a message to the server (all above methods use this )
  void _sendMessage(String message) async {
    message = await clientSideEncryption.encrypt(null, message);
    socket.write('$message◊');
  }

  // Send a message to the server without encrypting (for key exchange)
  void sendOpenMessage(String message) {
    socket.write('$message◊');
  }
}
