import 'dart:io';
import 'dart:math';

import 'package:encrypt/encrypt.dart';

import '../network/messaging_protocol.dart';
import 'encryption.dart';

class ServerSideEncryption extends BaseEncryption {
  //Server keeps track of the encryption pairs and encrypters for each client
  final Map<Socket, EncryptionPair> _encryptionPairs =
      <Socket, EncryptionPair>{};
  final Map<Socket, Encrypter> _encrypters = <Socket, Encrypter>{};
  Function(String, Socket) sendOpenMessage;

  ServerSideEncryption({required this.sendOpenMessage});

  void generateKeyWithClient(Socket socket, BigInt clientsIntermediateKey) {
    BigInt myNumber = BigInt.from(Random().nextInt(4294967296));
    final iv = IV.fromLength(16);
    BigInt myIntermediateKey = g.modPow(myNumber, n);
    sendOpenMessage(
        '${MessagingProtocol.serverIntermediateKey}‽${myIntermediateKey.toString()}‽${iv.base64}',
        socket);
    BigInt intKey = clientsIntermediateKey.modPow(myNumber, n);
    if (intKey.toString().length > 32) {
      intKey = BigInt.parse(intKey.toString().substring(0, 32));
    } else if (intKey.toString().length < 32) {
      //this is for handling the extreme error case where the final key is less than 32 characters long
      //both the server and client does this. So even if the server generates a key that is less than 32 characters long
      //they both will pad it to 32 characters
      intKey = BigInt.parse(intKey.toString().padRight(32, '0'));
    }

    _encryptionPairs[socket] =
        EncryptionPair(secretKey: Key.fromUtf8(intKey.toString()), iv: iv);
    _encrypters[socket] =
        Encrypter(AES(_encryptionPairs[socket]!.secretKey, padding: null));
  }

  @override
  Future<String> encrypt(Socket? socket, String plainText) async {
    while (_encrypters[socket] == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    final encrypted = _encrypters[socket]
        ?.encrypt(plainText, iv: _encryptionPairs[socket]!.iv);
    return Future.value(encrypted!.base64);
  }

  @override
  Future<String> decrypt(Socket? socket, String cipherText) async {
    while (_encrypters[socket] == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    final encrypted = Encrypted.fromBase64(cipherText);
    final decrypted = _encrypters[socket]
        ?.decrypt(encrypted, iv: _encryptionPairs[socket]!.iv);

    return Future.value(decrypted);
  }
}
