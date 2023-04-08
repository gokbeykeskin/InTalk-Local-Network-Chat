import 'package:flutter/material.dart';

import '../../../backend/client.dart';

class ChatTitle extends StatelessWidget {
  const ChatTitle({super.key, required this.toChatUser});

  final User toChatUser;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 25, maxWidth: 200),
      child: Container(
          alignment: Alignment.center,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                toChatUser.name,
                style: const TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )),
    );
  }
}
