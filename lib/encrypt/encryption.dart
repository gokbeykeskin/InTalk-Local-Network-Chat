import 'dart:io';
import 'package:encrypt/encrypt.dart';

class EncryptionPair {
  Key secretKey;
  IV iv;
  EncryptionPair({required this.secretKey, required this.iv});
}

abstract class BaseEncryption {
  //socket is null if client sends message to server
  //since clien't doesn't do a key bookkeeping, it has only the server-client key.
  //server has a map of socket-encryption pair for each client.

  String? encrypt(Socket? socket, String plainText);
  String decrypt(Socket? socket, String cipherText);
}
