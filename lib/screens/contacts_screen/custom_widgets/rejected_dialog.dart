import 'package:flutter/material.dart';

// Displays a dialog when the host device rejects you.
class RejectedDialog extends StatelessWidget {
  const RejectedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Rejected!"),
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
