import 'package:flutter/material.dart';

// Displays a dialog when the user you are chatting logs out
class UserLoggedOutDialog extends StatelessWidget {
  const UserLoggedOutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("The user you are talking to went offline."),
      content: const Text("You are directed to main screen."),
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
          "You are probably not connected to a local network. Connect a local network and try again."),
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
