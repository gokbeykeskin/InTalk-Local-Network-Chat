import 'package:crypto/crypto.dart';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

import '../auth/user.dart';
import '../screens/contacts_screen/contacts_screen.dart';

class Utility {
  static Future<String?> getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      // import 'dart:io'
      var iosDeviceInfo = await deviceInfo.iosInfo;
      return iosDeviceInfo.identifierForVendor; // unique ID on iOS
    } else if (Platform.isAndroid) {
      var androidDeviceInfo = await deviceInfo.androidInfo;
      return androidDeviceInfo.androidId; // unique ID on Android
    }
    return null;
  }

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
    const int chunkSize = 1024; //bunu arttırarak deney yap.
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
    const int quality = 15;
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
