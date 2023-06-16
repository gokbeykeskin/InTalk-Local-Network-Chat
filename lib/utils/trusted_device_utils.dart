import '../network/client/client_events.dart';
import '../screens/contacts_screen/contacts_screen.dart';

class TrustedDeviceUtils {
  //when a user changes their name, update the name in the trusted device list.
  static void updateTrustedDeviceNames(String mac, String name) {
    List<String> trustedDeviceMACs = ContactsScreen.trustedDevicePreferences
            ?.getStringList('trustedDeviceMACs') ??
        [];
    List<String> trustedDeviceNames = ContactsScreen.trustedDevicePreferences
            ?.getStringList('trustedDeviceNames') ??
        [];
    if (trustedDeviceMACs.contains(mac)) {
      trustedDeviceNames[trustedDeviceMACs.indexOf(mac)] = name;
      ContactsScreen.trustedDevicePreferences
          ?.setStringList('trustedDeviceNames', trustedDeviceNames);
    }
    ClientEvents.usersUpdatedEvent.broadcast();
  }

  static void handleUntrustedDevice(String mac) {
    List<String> trustedDeviceMACs = ContactsScreen.trustedDevicePreferences
            ?.getStringList('trustedDeviceMACs') ??
        [];
    List<String> trustedDeviceNames = ContactsScreen.trustedDevicePreferences
            ?.getStringList('trustedDeviceNames') ??
        [];
    int macIndex = trustedDeviceMACs.indexOf(mac);
    if (macIndex != -1) {
      trustedDeviceMACs.removeAt(macIndex);
      trustedDeviceNames.removeAt(macIndex);
      ContactsScreen.trustedDevicePreferences
          ?.setStringList('trustedDeviceMACs', trustedDeviceMACs);
      ContactsScreen.trustedDevicePreferences
          ?.setStringList('trustedDeviceNames', trustedDeviceNames);
    }
    ClientEvents.usersUpdatedEvent.broadcast();
  }

  static void handleunbannedDevice(String mac) {
    List<String> bannedDeviceMACs = ContactsScreen.trustedDevicePreferences
            ?.getStringList('bannedDeviceMACs') ??
        [];
    List<String> bannedDeviceNames = ContactsScreen.trustedDevicePreferences
            ?.getStringList('bannedDeviceNames') ??
        [];
    int macIndex = bannedDeviceMACs.indexOf(mac);
    if (macIndex != -1) {
      bannedDeviceMACs.removeAt(macIndex);
      bannedDeviceNames.removeAt(macIndex);
      ContactsScreen.trustedDevicePreferences
          ?.setStringList('bannedDeviceMACs', bannedDeviceMACs);
      ContactsScreen.trustedDevicePreferences
          ?.setStringList('bannedDeviceNames', bannedDeviceNames);
    }
    ClientEvents.usersUpdatedEvent.broadcast();
  }
}
