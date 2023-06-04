import 'dart:io';
import 'dart:math';

import 'package:local_chat/network/messaging_protocol.dart';
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

class ServerSideEncryption extends BaseEncryption {
  Map<Socket, EncryptionPair> encryptionPairs = <Socket, EncryptionPair>{};
  Map<Socket, Encrypter> encrypters = <Socket, Encrypter>{};
  final BigInt _g = BigInt.parse('61002891148799367012041784081793');
  final BigInt _n = BigInt.parse('71015449566417566598295305556981');
  Function(String, Socket) sendOpenMessage;

  ServerSideEncryption({required this.sendOpenMessage});

  void generateKeyWithClient(Socket socket, BigInt clientsIntermediateKey) {
    BigInt myNumber = BigInt.from(Random().nextInt(4294967296));
    final iv = IV.fromLength(16);
    BigInt myIntermediateKey = _g.modPow(myNumber, _n);
    sendOpenMessage(
        '${MessagingProtocol.serverIntermediateKey}‽${myIntermediateKey.toString()}‽${iv.base64}',
        socket);
    BigInt finalKey = clientsIntermediateKey.modPow(myNumber, _n);
    if (finalKey.toString().length > 32) {
      finalKey = BigInt.parse(finalKey.toString().substring(0, 32));
    } else if (finalKey.toString().length < 32) {
      finalKey = BigInt.parse(finalKey.toString().padRight(32, '0'));
    }

    encryptionPairs[socket] =
        EncryptionPair(secretKey: Key.fromUtf8(finalKey.toString()), iv: iv);
    encrypters[socket] =
        Encrypter(AES(encryptionPairs[socket]!.secretKey, padding: null));
  }

  @override
  String? encrypt(Socket? socket, String plainText) {
    final encrypted =
        encrypters[socket]?.encrypt(plainText, iv: encryptionPairs[socket]!.iv);
    return encrypted?.base64;
  }

  @override
  String decrypt(Socket? socket, String cipherText) {
    final encrypted = Encrypted.fromBase64(cipherText);
    final decrypted =
        encrypters[socket]?.decrypt(encrypted, iv: encryptionPairs[socket]!.iv);

    return decrypted ?? '';
  }
}

class ClientSideEncryption extends BaseEncryption {
  final BigInt _g = BigInt.parse('61002891148799367012041784081793');
  final BigInt _n = BigInt.parse('71015449566417566598295305556981');
  BigInt myNumber;
  late Key secretKey;
  late IV iv;
  late Encrypter encrypter;

  ClientSideEncryption() : myNumber = BigInt.from(Random().nextInt(4294967296));
  BigInt generateIntermediateKey() {
    return _g.modPow(myNumber, _n);
  }

  void generateFinalKey(BigInt serversIntermediateKey, String iv) {
    BigInt intKey = serversIntermediateKey.modPow(myNumber, _n);
    if (intKey.toString().length > 32) {
      intKey = BigInt.parse(intKey.toString().substring(0, 32));
    } else if (intKey.toString().length < 32) {
      intKey = BigInt.parse(intKey.toString().padRight(32, '0'));
    }
    secretKey = Key.fromUtf8(intKey.toString());
    this.iv = IV.fromBase64(iv);
    encrypter = Encrypter(AES(secretKey, padding: null));
  }

  @override
  String encrypt(Socket? socket, String plainText) {
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return encrypted.base64;
  }

  @override
  String decrypt(Socket? socket, String cipherText) {
    final encrypted = Encrypted.fromBase64(cipherText);
    final decrypted = encrypter.decrypt(encrypted, iv: iv);
    return decrypted;
  }
}
