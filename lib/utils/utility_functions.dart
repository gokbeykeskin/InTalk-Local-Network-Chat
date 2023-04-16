import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

import '../backend/client.dart';
import '../screens/contacts_screen/contacts_screen.dart';

class Utility {
  static Future<String> getNetworkIPAdress() async {
    List<NetworkInterface> interfaces = await NetworkInterface.list();
    for (NetworkInterface interface in interfaces) {
      if (interface.name.startsWith('wlan') ||
          interface.name.startsWith('en')) {
        return interface.addresses.first.address;
      }
    }
    return '';
  }

  static List<Uint8List> splitImage(Uint8List data) {
    final List<Uint8List> chunks = [];
    const int chunkSize = 512; //bunu arttırarak deney yap.
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

  static int mapImageSizeToQuality(int value,
      {int maxInputValue = 150000,
      int minOutputValue = 10,
      int maxOutputValue = 100}) {
    if (value > maxInputValue) {
      return minOutputValue;
    }
    int percentage = ((maxInputValue - value) /
                (maxInputValue / (maxOutputValue - minOutputValue)))
            .round() +
        minOutputValue;
    if (kDebugMode) {
      print(
          "Quality:${percentage <= maxOutputValue ? percentage : maxOutputValue}");
    }
    return percentage <= maxOutputValue ? percentage : maxOutputValue;
  }

  static Future<File> compressImage(File file, String targetPath) async {
    int quality = mapImageSizeToQuality(file.lengthSync());
    if (quality > 80) {
      //if the calculated quality is more than 80, image does not need to be compressed.
      //since it is a small image and compression usually makes it bigger.
      return file;
    }
    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
    );

    if (kDebugMode) {
      print("Before compression:${file.lengthSync()}");
      print("After compression:${result!.lengthSync()}");
    }
    return result!;
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
    var random = Random.secure();
    var values = List<int>.generate(len, (i) => random.nextInt(255));
    return base64Encode(values);
  }
}
