
import 'package:flutter/material.dart';

class MessageBox extends StatelessWidget {
  final String sender;
  final String message;
  final Alignment alignment;
  const MessageBox(
      {super.key,
      required this.sender,
      required this.message,
      required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 60),
          child: Card(
              child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(message),
              ],
            ),
          ))),
    );
  }
}
