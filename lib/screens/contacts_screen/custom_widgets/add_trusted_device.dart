import 'package:flutter/material.dart';
import 'package:local_chat/network/server.dart';

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
          child: Column(children: [
            const Text("A new Device wants to connect."),
            const Text("Trust this Device?"),
            Text("Mac Address: ${args.macAddress}"),
            Text("Name: ${args.name}"),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                    onPressed: () {
                      ContactsScreen.userAcceptanceEvent
                          .broadcast(UserAcceptanceEventArgs(accepted: false));
                      Navigator.pop(context);
                    },
                    child: const Text("No")),
                TextButton(
                    onPressed: () {
                      ContactsScreen.userAcceptanceEvent
                          .broadcast(UserAcceptanceEventArgs(accepted: true));
                      List<String>? trustedDevices = ContactsScreen
                          .trustedDevicePreferences
                          ?.getStringList('trustedDevices');
                      trustedDevices ??= [];
                      trustedDevices.add(args.macAddress);
                      ContactsScreen.trustedDevicePreferences
                          ?.setStringList('trustedDevices', trustedDevices);
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
