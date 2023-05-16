import 'package:flutter/material.dart';
import 'package:local_chat/custom_widgets/default_appbar.dart';
import 'package:local_chat/encrypt/encryption.dart';
import 'package:local_chat/screens/contacts_screen/contacts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textFieldController = TextEditingController();
  bool _validate = true;

  @override
  void dispose() {
    _textFieldController.dispose();
    super.dispose();
  }

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
              'InTalk',
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
                    showDialog(context: context, builder: (_) => nameInput());
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
                    showDialog(context: context, builder: (_) => nameInput());
                  },
                  child: const Text('Connect with Bluetooth')),
            ),
          ],
        ),
      ),
    );
  }

  AlertDialog nameInput() {
    return AlertDialog(
      title: const Text('Enter your name'),
      content: TextField(
        autofocus: true,
        autocorrect: false,
        controller: _textFieldController,
        decoration: InputDecoration(
          hintText: 'Name',
          errorText: _validate == false
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
            setState(() {
              _textFieldController.text.length > 2
                  ? _validate = true
                  : _validate = false;
            });
            if (_validate) {
              Navigator.pop(context);
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          ContactsScreen(name: _textFieldController.text)));
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
}
