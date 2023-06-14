import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

import '../auth/user.dart';
import '../screens/contacts_screen/contacts_screen.dart';

class ImageUtils {
  static List<Uint8List> splitImage(Uint8List data) {
    final List<Uint8List> chunks = [];
    const int chunkSize = 512;
    int offset = 0;
    int remaining = data.length;

    while (remaining > 0) {
      final int currentChunkSize =
          (remaining < chunkSize) ? remaining : chunkSize;
      final Uint8List chunk = data.sublist(offset, offset + currentChunkSize);
      chunks.add(chunk);
      remaining -= currentChunkSize;
      offset += currentChunkSize;
    }
    return chunks;
  }

  static Future<File?> cropImage({required File imageFile}) async {
    CroppedFile? croppedImage =
        await ImageCropper().cropImage(sourcePath: imageFile.path);
    if (croppedImage == null) return null;
    return File(croppedImage.path);
  }

  static Future<File> compressImage(File file, String targetPath) async {
    const int quality = 10;
    XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
    );

    if (kDebugMode) {
      print("Before compression:${file.lengthSync()}");
      print("After compression:${result!.length}");
    }
    return File(result!.path);
  }

  static User getUserByName(String name) {
    return ContactsScreen.loggedInUsers.firstWhere((element) {
      return element.name == name;
    });
  }

  static Future<String> getLocalPath() async {
    final directory = await getTemporaryDirectory();

    return directory.path;
  }

  static String generateRandomString(int len) {
    const alphanumericChars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final buffer = StringBuffer();

    for (int i = 0; i < 8; i++) {
      buffer.write(alphanumericChars[random.nextInt(alphanumericChars.length)]);
    }

    final randomString = buffer.toString();
    return randomString;
  }

  static List<int> hashImage(List<int> base64Image) {
    return sha256.convert(base64Image).bytes;
  }
}
