import 'package:flutter/material.dart';
import 'package:local_chat/network/client/client.dart';

import '../../chat_screen/chat_screen.dart';
import '../contacts_screen.dart';

// A contact tile in the contacts screen
class Contact extends StatelessWidget {
  final String name;
  final int port;
  final LanClient client;
  final int index;
  const Contact(
      {super.key,
      required this.name,
      required this.port,
      required this.client,
      required this.index});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: ListTile(
        title: Text(name),
        subtitle: Text(port.toString()),
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ChatScreen(
                      isGeneralChat: false,
                      meClient: client,
                      receiver: ContactsScreen.loggedInUsers[index])));
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: Colors.blue[100],
      ),
    );
  }
}
