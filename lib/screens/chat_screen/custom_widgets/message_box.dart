import 'dart:io';

import 'package:flutter/material.dart';

import 'fullscreen_image.dart';

// Displays a message in a card
class MessageBox extends StatelessWidget {
  final String sender;
  final String message;
  final Alignment alignment;
  final File? image;
  const MessageBox(
      {super.key,
      required this.sender,
      required this.message,
      required this.alignment,
      this.image});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 60),
          child: Card(
              color: alignment == Alignment.centerLeft
                  ? Colors.blue[100]
                  : Colors.green[100],
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
                    getImage(context),
                    Text(message),
                  ],
                ),
              ))),
    );
  }

  Widget getImage(BuildContext context) {
    if (image == null) {
      return const SizedBox(width: 0, height: 0);
    } else {
      return InkWell(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => FullScreenImage(image!)));
          },
          child: Image.file(image!));
    }
  }
}
