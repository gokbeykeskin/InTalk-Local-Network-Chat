import 'package:flutter/material.dart';
import 'package:local_chat/network/server/server.dart';

import '../contacts_screen.dart';

class TrustedDeviceBottomSheet extends StatelessWidget {
  final AuthEventArgs args;
  const TrustedDeviceBottomSheet({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      maxChildSize: 0.4,
      minChildSize: 0.28,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "A new Device wants to connect.",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "Trust this Device?",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text("Mac Address"),
                Text(args.macAddress),
                Text("Name: ${args.name}"),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                        onPressed: () {
                          ContactsScreen.userAcceptanceEvent.broadcast(
                              UserAcceptanceEventArgs(accepted: false));
                          List<String>? bannedDeviceMACs = ContactsScreen
                                  .trustedDevicePreferences
                                  ?.getStringList('bannedDeviceMACs') ??
                              [];
                          List<String>? bannedDeviceNames = ContactsScreen
                                  .trustedDevicePreferences
                                  ?.getStringList('bannedDeviceNames') ??
                              [];
                          bannedDeviceMACs.add(args.macAddress);
                          bannedDeviceNames.add(args.name);
                          ContactsScreen.trustedDevicePreferences
                              ?.setStringList(
                                  'bannedDeviceMACs', bannedDeviceMACs);
                          ContactsScreen.trustedDevicePreferences
                              ?.setStringList(
                                  'bannedDeviceNames', bannedDeviceNames);
                          Navigator.pop(context);
                        },
                        child: const Text("No")),
                    TextButton(
                        onPressed: () {
                          ContactsScreen.userAcceptanceEvent.broadcast(
                              UserAcceptanceEventArgs(accepted: true));
                          List<String>? trustedDeviceMACs = ContactsScreen
                                  .trustedDevicePreferences
                                  ?.getStringList('trustedDeviceMACs') ??
                              [];
                          List<String>? trustedDeviceNames = ContactsScreen
                                  .trustedDevicePreferences
                                  ?.getStringList('trustedDeviceNames') ??
                              [];

                          trustedDeviceMACs.add(args.macAddress);
                          trustedDeviceNames.add(args.name);
                          ContactsScreen.trustedDevicePreferences
                              ?.setStringList(
                                  'trustedDeviceMACs', trustedDeviceMACs);
                          ContactsScreen.trustedDevicePreferences
                              ?.setStringList(
                                  'trustedDeviceNames', trustedDeviceNames);
                          Navigator.pop(context);
                        },
                        child: const Text("Yes"))
                  ],
                )
              ]),
        );
      },
    );
  }
}
