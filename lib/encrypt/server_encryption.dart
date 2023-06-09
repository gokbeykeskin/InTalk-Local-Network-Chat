import 'dart:io';
import 'dart:math';

import 'package:encrypt/encrypt.dart';

import '../network/messaging_protocol.dart';
import 'encryption.dart';

class ServerSideEncryption extends BaseEncryption {
  //Server keeps track of the encryption pairs and encrypters for each client
  Map<Socket, EncryptionPair> encryptionPairs = <Socket, EncryptionPair>{};
  Map<Socket, Encrypter> encrypters = <Socket, Encrypter>{};
  //These are the values of g and n that are used in the Diffie-Hellman key exchange

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
      //this is for handling the extreme error case where the final key is less than 32 characters long
      //both the server and client does this so even if the server generates a key that is less than 32 characters long
      //they both will pad it to 32 characters
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
