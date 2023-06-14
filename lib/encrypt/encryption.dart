import 'dart:io';
import 'package:encrypt/encrypt.dart';
import 'package:meta/meta.dart';

class EncryptionPair {
  Key secretKey;
  IV iv;
  EncryptionPair({required this.secretKey, required this.iv});
}

abstract class BaseEncryption {
  //These are the values of g and n that are used in the Diffie-Hellman key exchange
  //They are public and can be used by anyone
  @protected
  final BigInt g = BigInt.parse('61002891148799367012041784081793');
  @protected
  final BigInt n = BigInt.parse('71015449566417566598295305556981');

  //socket is null if client sends message to server
  //since clien't doesn't do a key bookkeeping, it has only the server-client key.
  //server has a map of socket-encryption pair for each client.
  Future<String> encrypt(Socket? socket, String plainText);
  Future<String> decrypt(Socket? socket, String cipherText);
}
