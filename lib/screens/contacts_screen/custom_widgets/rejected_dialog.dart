import 'package:flutter/material.dart';

class RejectedDialog extends StatelessWidget {
  const RejectedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Kicked"),
      content: const Text("Contact Host Device to get access."),
      actions: [
        TextButton(
          child: const Text("OK"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class NotConnectedDialog extends StatelessWidget {
  const NotConnectedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Something went wrong."),
      content: const Text(
          "You are probably not connected to a local network or the access point is closed unexpectedly. Connect a local network and try again."),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("OK"))
      ],
    );
  }
}
