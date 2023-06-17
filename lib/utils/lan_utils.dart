import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class LanUtils {
  static Future<String?> getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      // import 'dart:io'
      var iosDeviceInfo = await deviceInfo.iosInfo;
      return iosDeviceInfo.identifierForVendor; // unique ID on iOS
    } else if (Platform.isAndroid) {
      var androidDeviceInfo = await deviceInfo.androidInfo;
      return androidDeviceInfo.androidId; // unique ID on Android
    } else if (Platform.isMacOS) {
      var macOSDeviceInfo = await deviceInfo.macOsInfo;
      return macOSDeviceInfo.systemGUID;
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
}
