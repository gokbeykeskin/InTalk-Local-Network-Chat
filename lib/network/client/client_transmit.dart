import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:local_chat/encrypt/encryption.dart';

import '../../auth/user.dart';
import '../../utils/image_utils.dart';
import '../messaging_protocol.dart';

class ClientTransmit {
  ClientSideEncryption clientSideEncryption;
  User user;
  Socket? socket;
  ClientTransmit(
      {required this.user,
      required this.socket,
      required this.clientSideEncryption});
  void sendBroadcastMessage(String message) {
    sendMessage(
        "${MessagingProtocol.broadcastMessage}‽${user.macAddress}‽$message");
  }

  void sendPrivateMessage(String message, User receiver) {
    sendMessage(
        "${MessagingProtocol.privateMessage}‽${user.macAddress}‽${receiver.port}‽$message");
  }

  Future<void> sendBroadcastImage(Uint8List base64Image) async {
    List<Uint8List> bytes = ImageUtils.splitImage(base64Image);
    List<int> hashedBytes = ImageUtils.hashImage(base64Image);
    sendMessage("${MessagingProtocol.broadcastImageStart}‽${user.macAddress}");
    for (var i = 0; i < bytes.length; i++) {
      await Future.delayed(
        const Duration(milliseconds: 50),
      ); //bu delay arttırılarak büyük resimlerdeki hata düzeltilebilir, ama büyük resimler zaten çok uzun sürüyor.
      sendMessage(
          '${MessagingProtocol.broadcastImageContd}‽${base64Encode(bytes[i])}‽${user.macAddress}');
    }
    sendMessage(
        '${MessagingProtocol.broadcastImageEnd}‽${base64Encode(hashedBytes)}‽${user.macAddress}');
  }

  Future<void> sendPrivateImage(Uint8List base64Image, User receiver) async {
    List<Uint8List> bytes = ImageUtils.splitImage(base64Image);
    List<int> hashedBytes = ImageUtils.hashImage(base64Image);
    sendMessage(
        "${MessagingProtocol.privateImageStart}‽${user.macAddress}‽${receiver.port}");
    for (var i = 0; i < bytes.length; i++) {
      await Future.delayed(
        const Duration(milliseconds: 50),
      );
      sendMessage(
          '${MessagingProtocol.privateImageContd}‽${base64Encode(bytes[i])}‽${user.macAddress}');
    }
    sendMessage(
        '${MessagingProtocol.privateImageEnd}‽${base64Encode(hashedBytes)}‽${user.macAddress}');
  }

  void changeName(String newName) {
    user.name = newName;
    sendMessage(
        "${MessagingProtocol.nameUpdate}‽${user.macAddress}‽${user.name}");
  }

  // Send a message to the server
  void sendMessage(String message) {
    message = clientSideEncryption.encrypt(null, message);
    socket?.write('$message◊');
  }

  void sendOpenMessage(String message) {
    socket?.write('$message◊');
  }
}
