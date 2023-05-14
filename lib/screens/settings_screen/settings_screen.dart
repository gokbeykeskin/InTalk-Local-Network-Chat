import 'package:event/event.dart';
import 'package:flutter/material.dart';
import 'package:local_chat/network/client.dart';

import '../contacts_screen/contacts_screen.dart';

class NameChangedEventArgs extends EventArgs {
  final String name;
  NameChangedEventArgs({required this.name});
}

class SettingsScreen extends StatefulWidget {
  String username;
  static Event nameChangedEvent = Event();

  SettingsScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _newUsername = '';
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  List<String> trustedDevices = ContactsScreen.trustedDevicePreferences
          ?.getStringList('trustedDevices') ??
      [];
  @override
  void initState() {
    super.initState();
    _subscribeToEvents();
  }

  @override
  void dispose() {
    super.dispose();
    LocalNetworkChatClient.usersUpdatedEvent.unsubscribeAll();
    _scaffoldMessengerKey.currentState?.clearSnackBars();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () {
              _showChangeUsernameDialog();
            },
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.username,
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Trusted Devices',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: trustedDevices.length,
                itemBuilder: (BuildContext context, int index) {
                  return Dismissible(
                    key: ValueKey(trustedDevices[index]),
                    direction: DismissDirection.startToEnd,
                    background: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.red,
                      ),
                      padding: const EdgeInsets.only(left: 16),
                      alignment: Alignment.centerLeft,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) =>
                        _removeDeviceFromTrustedList(trustedDevices[index]),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(trustedDevices[index]),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // Handle the button tap event
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  ContactsScreen.trustedDevicePreferences
                      ?.setStringList('trustedDevices', []);
                  trustedDevices = [];
                });
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Forget all trusted devices'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _subscribeToEvents() {
    LocalNetworkChatClient.usersUpdatedEvent.subscribe((args) {
      if (mounted) {
        setState(() {
          trustedDevices = ContactsScreen.trustedDevicePreferences
                  ?.getStringList('trustedDevices') ??
              [];
        });
      }
    });
  }

  void _removeDeviceFromTrustedList(String deviceName) {
    setState(
      () {
        trustedDevices.remove(deviceName);
        ContactsScreen.trustedDevicePreferences
            ?.setStringList('trustedDevices', trustedDevices.toList());
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Device removed from trusted list'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      trustedDevices.add(deviceName);
                      ContactsScreen.trustedDevicePreferences?.setStringList(
                          'trustedDevices', trustedDevices.toList());
                    });
                  }
                }),
          ),
        );
      },
    );
  }

  void _showChangeUsernameDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change username'),
          content: TextField(
            autofocus: true,
            onChanged: (value) {
              _newUsername = value;
            },
            decoration: const InputDecoration(
              hintText: 'Enter new username',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.username = _newUsername;
                });
                SettingsScreen.nameChangedEvent
                    .broadcast(NameChangedEventArgs(name: _newUsername));
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
