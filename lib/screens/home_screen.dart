import 'package:flutter/material.dart';
import 'package:local_chat/custom_widgets/inchat_appbar.dart';
import 'package:local_chat/screens/contacts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textFieldController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DefaultAppBar(),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(38.0, 0.0, 38.0, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            const Text(
              'InChat',
              style: TextStyle(
                  fontSize: 50.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Lobster'),
            ),
            const SizedBox(
              height: 24.0,
            ),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (_) =>
                            nameInput(_textFieldController, context));
                  },
                  child: const Text('Connect with LAN')),
            ),
            const SizedBox(
              height: 24,
            ),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (_) =>
                            nameInput(_textFieldController, context));
                  },
                  child: const Text('Connect with Bluetooth')),
            ),
          ],
        ),
      ),
    );
  }
}

AlertDialog nameInput(
    TextEditingController textFieldController, BuildContext context) {
  return AlertDialog(
    title: const Text('Continue as guest'),
    content: TextField(
      controller: textFieldController,
      decoration: InputDecoration(
        hintText: 'Name',
        errorText: textFieldController.text.length < 3
            ? 'Name should be at least 3 characters'
            : null,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () {
          if (textFieldController.text.length > 2) {
            Navigator.pop(context);
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        ContactsScreen(name: textFieldController.text)));
          }
        },
        child: const Text('Continue'),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text('Cancel'),
      ),
    ],
  );
}
