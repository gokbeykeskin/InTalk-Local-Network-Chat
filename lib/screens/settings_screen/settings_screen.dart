import 'package:event/event.dart';
import 'package:flutter/material.dart';
import 'package:local_chat/network/client/client_events.dart';
import '../../network/server/server.dart';
import '../contacts_screen/contacts_screen.dart';

class NameChangedEventArgs extends EventArgs {
  final String name;
  NameChangedEventArgs({required this.name});
}

// Change name, list and manage trusted devices and banned devices
//ignore: must_be_immutable
class SettingsScreen extends StatefulWidget {
  String username;
  static Event nameChangedEvent = Event();
  LanServer? server;
  SettingsScreen({Key? key, required this.username, required this.server})
      : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _newUsername = '';
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  List<String> trustedDeviceMACs = ContactsScreen.trustedDevicePreferences
          ?.getStringList('trustedDeviceMACs') ??
      [];
  List<String> trustedDeviceNames = ContactsScreen.trustedDevicePreferences
          ?.getStringList('trustedDeviceNames') ??
      [];
  List<String> bannedDeviceMACs = ContactsScreen.trustedDevicePreferences
          ?.getStringList('bannedDeviceMACs') ??
      [];
  List<String> bannedDeviceNames = ContactsScreen.trustedDevicePreferences
          ?.getStringList('bannedDeviceNames') ??
      [];
  @override
  void initState() {
    _subscribeToEvents();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
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
          _trustedDevicesList(),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Banned Devices',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _bannedDevicesList(),
          const SizedBox(height: 16),
        ],
      ),
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
                Navigator.of(context).pop();

                SettingsScreen.nameChangedEvent
                    .broadcast(NameChangedEventArgs(name: _newUsername));
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _subscribeToEvents() {
    ClientEvents.usersUpdatedEvent.subscribe((args) {
      if (mounted) {
        setState(() {
          trustedDeviceMACs = ContactsScreen.trustedDevicePreferences
                  ?.getStringList('trustedDeviceMACs') ??
              [];
          trustedDeviceNames = ContactsScreen.trustedDevicePreferences
                  ?.getStringList('trustedDeviceNames') ??
              [];
          bannedDeviceMACs = ContactsScreen.trustedDevicePreferences
                  ?.getStringList('bannedDeviceMACs') ??
              [];
          bannedDeviceNames = ContactsScreen.trustedDevicePreferences
                  ?.getStringList('bannedDeviceNames') ??
              [];
        });
      }
    });
    LanServer.rejectEvent.subscribe((args) {
      if (mounted) {
        setState(() {
          bannedDeviceMACs = ContactsScreen.trustedDevicePreferences
                  ?.getStringList('bannedDeviceMACs') ??
              [];
          bannedDeviceNames = ContactsScreen.trustedDevicePreferences
                  ?.getStringList('bannedDeviceNames') ??
              [];
        });
      }
    });
  }

  Expanded _trustedDevicesList() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: trustedDeviceMACs.length,
          itemBuilder: (BuildContext context, int index) {
            return Dismissible(
              key: ValueKey(trustedDeviceMACs[index]),
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
              onDismissed: (direction) => _removeDeviceFromTrustedList(
                  trustedDeviceMACs[index], trustedDeviceNames[index]),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(trustedDeviceNames[index]),
                  subtitle: Text(trustedDeviceMACs[index]),
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
    );
  }

  void _removeDeviceFromTrustedList(String deviceMAC, String username) {
    widget.server?.sendUntrustedDeviceToAll(deviceMAC);
    try {
      widget.server?.kickUser(ContactsScreen.loggedInUsers
          .firstWhere((element) => element.macAddress == deviceMAC)
          .port!);
    } catch (e) {
      //untrusted device is not online.
    }

    setState(
      () {
        trustedDeviceMACs.remove(deviceMAC);
        ContactsScreen.trustedDevicePreferences
            ?.setStringList('trustedDeviceMACs', trustedDeviceMACs);
        trustedDeviceNames.remove(username);
        ContactsScreen.trustedDevicePreferences
            ?.setStringList('trustedDeviceNames', trustedDeviceNames);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Device removed from trusted list'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  widget.server?.sendTrustedDeviceToAll(deviceMAC, username);
                  if (mounted) {
                    setState(() {
                      trustedDeviceMACs.add(deviceMAC);
                      trustedDeviceNames.add(username);
                      ContactsScreen.trustedDevicePreferences?.setStringList(
                          'trustedDeviceMACs', trustedDeviceMACs);
                      ContactsScreen.trustedDevicePreferences?.setStringList(
                          'trustedDeviceNames', trustedDeviceNames);
                    });
                  }
                }),
          ),
        );
      },
    );
  }

  _bannedDevicesList() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bannedDeviceMACs.length,
          itemBuilder: (BuildContext context, int index) {
            return Dismissible(
              key: ValueKey(bannedDeviceMACs[index]),
              direction: DismissDirection.startToEnd,
              background: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.lightBlue,
                ),
                padding: const EdgeInsets.only(left: 16),
                alignment: Alignment.centerLeft,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (direction) => _removeDeviceFromBannedList(
                  bannedDeviceMACs[index], bannedDeviceNames[index]),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(bannedDeviceNames[index]),
                  subtitle: Text(bannedDeviceMACs[index]),
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
    );
  }

  _removeDeviceFromBannedList(String deviceMAC, String username) {
    widget.server?.sendUnbannedDeviceToAll(deviceMAC);
    setState(
      () {
        bannedDeviceMACs.remove(deviceMAC);
        ContactsScreen.trustedDevicePreferences
            ?.setStringList('bannedDeviceMACs', bannedDeviceMACs);
        bannedDeviceNames.remove(username);
        ContactsScreen.trustedDevicePreferences
            ?.setStringList('bannedDeviceNames', bannedDeviceNames);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Device removed from banned list'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  widget.server?.sendBannedDeviceToAll(deviceMAC, username);
                  if (mounted) {
                    setState(() {
                      bannedDeviceMACs.add(deviceMAC);
                      bannedDeviceNames.add(username);
                      ContactsScreen.trustedDevicePreferences
                          ?.setStringList('bannedDeviceMACs', bannedDeviceMACs);
                      ContactsScreen.trustedDevicePreferences?.setStringList(
                          'bannedDeviceNames', bannedDeviceNames);
                    });
                  }
                }),
          ),
        );
      },
    );
  }
}
