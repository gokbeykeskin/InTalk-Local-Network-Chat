import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
    const int chunkSize = 256; //bunu arttırarak deney yap.
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
