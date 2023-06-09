import 'dart:io';

import 'package:event/event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_chat/network/client/client.dart';
import 'package:local_chat/network/client/client_events.dart';
import 'package:local_chat/network/server/server.dart';
import 'package:local_chat/screens/chat_screen/chat_screen.dart';
import 'package:local_chat/screens/contacts_screen/custom_widgets/add_trusted_device.dart';
import 'package:local_chat/screens/contacts_screen/custom_widgets/rejected_dialog.dart';
import 'package:local_chat/screens/home_screen/home_screen.dart';
import 'package:local_chat/screens/settings_screen/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/user.dart';
import '../../utils/image_utils.dart';
import 'custom_widgets/contact.dart';

class UserAcceptanceEventArgs extends EventArgs {
  final bool accepted;
  UserAcceptanceEventArgs({required this.accepted});
}

//ignore: must_be_immutable
class ContactsScreen extends StatefulWidget {
  String name;
  static final User generalChatUser = User(name: "General Chat", port: 0);
  ContactsScreen({super.key, required this.name});
  static List<User> loggedInUsers = [];
  //holds all the messages for each receiver.
  static Map<User, List<Message>> messages = {};
  static bool ongoingImageSend = false;
  static Event userAcceptanceEvent = Event();
  static SharedPreferences? trustedDevicePreferences;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LanServer? server;
  LanClient? client;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _handleServerClientConnections();
    _subscribeToEvents();
    ImageUtils.getLocalPath().then((value) => _localPath = value);
    _getTrustedDevices();
  }

  void _getTrustedDevices() async {
    ContactsScreen.trustedDevicePreferences =
        await SharedPreferences.getInstance();
  }

  @override
  void dispose() {
    _logout();
    super.dispose();
    _tabController.dispose();
    ContactsScreen.userAcceptanceEvent.unsubscribeAll();
    SettingsScreen.nameChangedEvent.unsubscribeAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            server == null ? const Text('InTalk') : const Text('InTalk (HOST)'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          SettingsScreen(username: widget.name)));
            },
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(
              icon: Icon(Icons.contacts),
              text: 'Contacts',
            ),
            Tab(
              icon: Icon(Icons.chat),
              text: 'General Chat',
            ),
          ],
          onTap: (index) {},
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _createContactsTab(),
          _createGeneralChatTab(),
        ],
      ),
    );
  }

  _createGeneralChatTab() {
    return Center(
      child: ChatScreen(
        isGeneralChat: true,
        receiver: ContactsScreen.generalChatUser,
        meClient: client!,
      ),
    );
  }

  _createContactsTab() {
    return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                  itemCount: ContactsScreen.loggedInUsers.length,
                  itemBuilder: (context, index) {
                    User user = ContactsScreen.loggedInUsers[index];
                    return Contact(
                        name: user.name,
                        port: user.port!,
                        client: client!,
                        index: index);
                  }),
            )
          ],
        ));
  }

//tries to connect to a server. If there is no server, it will establish a server and connect to it.
//this is called on a new login and it is the generic case.
  void _handleServerClientConnections() async {
    client = LanClient(user: User(name: widget.name));
    await client?.start();
    await tryConnections(client!);
    if (client!.connected) return;
    try {
      //if there is no server, become both a server and a client
      server = LanServer(myUser: client!.user);
      await server?.start();
      client?.connect(-1); //connect to your own ip.
      if (kDebugMode) {
        print('Server started');
      }
    } catch (e) {
      if (kDebugMode) {
        print("Can't create server.: $e");
      }
      if (mounted) {
        _noConnection();
      }
    }
  }

  void _becomeServer() async {
    if (mounted) {
      setState(() {
        ContactsScreen.loggedInUsers.clear();
      });
    }
    client = LanClient(user: User(name: widget.name));
    await client?.start();

    server = LanServer(myUser: client!.user);
    await server?.start();
    client?.connect(-1);
  }

  void _connectToNewServer() async {
    if (mounted) {
      setState(() {
        ContactsScreen.loggedInUsers.clear();
      });
    }
    client = LanClient(user: User(name: widget.name));
    await client?.start();

    await tryConnections(client!);
  }

  Future<void> tryConnections(LanClient client) async {
    List<Future<void>> connectFutures = [];
    for (int i = 0; i < 256; i++) {
      connectFutures.add(client.connect(i));
    }
    await Future.wait(connectFutures);

    return;
  }

  void _logout() async {
    ContactsScreen.loggedInUsers.clear();
    ClientEvents.connectionLostEvent.unsubscribeAll();
    if (server != null) {
      await server?.stop();
    } else {
      if (kDebugMode) {
        print("There is no server instance to stop.");
      }
    }
    client?.stop();
  }

  void _subscribeToEvents() {
    //Every time someone updates the list of users, state will be set in order to update the UI.
    ClientEvents.usersUpdatedEvent.subscribe((args) {
      if (kDebugMode) {
        print(
            "Users updated. New Length:${ContactsScreen.loggedInUsers.length}");
      }
      if (mounted) {
        setState(() {
          ContactsScreen
              .loggedInUsers; //update the loggedInUsers list on screen.
        });
      }
    });
    ClientEvents.becomeServerEvent.subscribe((args) {
      _becomeServer();
    });
    ClientEvents.connectToNewServerEvent.subscribe((args) {
      _connectToNewServer();
    });

    ClientEvents.broadcastMessageReceivedEvent.subscribe((args) async {
      args as NewMessageEventArgs;
      File? file;
      if (args.imageBytes != null) {
        file = File('$_localPath/${ImageUtils.generateRandomString(5)}.jpeg');
        await file.create();
        file.writeAsBytesSync(args.imageBytes!);
      }
      if (ContactsScreen.messages[ContactsScreen.generalChatUser] == null) {
        ContactsScreen.messages[ContactsScreen.generalChatUser] = [];
      }
      ContactsScreen.messages[ContactsScreen.generalChatUser]!.insert(
          0,
          Message(
              message: args.message,
              sender: args.sender,
              senderMac: args.senderMac,
              image: file));
    });

    ClientEvents.privateMessageReceivedEvent.subscribe((args) async {
      args as NewMessageEventArgs;
      File? file;
      if (args.imageBytes != null) {
        file = File('$_localPath/${ImageUtils.generateRandomString(5)}.jpeg');
        await file.create();
        file.writeAsBytesSync(args.imageBytes!);
      }
      User sender = ImageUtils.getUserByName(args.sender);
      if (ContactsScreen.messages[sender] == null) {
        ContactsScreen.messages[sender] = [];
      }
      ContactsScreen.messages[sender]!.insert(
          0,
          Message(
              message: args.message,
              senderMac: args.senderMac,
              sender: args.sender,
              image: file));
    });

    LanServer.authEvent.subscribe(
      (args) {
        args as AuthEventArgs;
        if (mounted) {
          showModalBottomSheet(
            isDismissible: false,
            isScrollControlled: true,
            context: context,
            builder: (context) => TrustedDeviceBottomSheet(args: args),
          );
        }
      },
    );

    ClientEvents.rejectedEvent.subscribe((args) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const HomeScreen()));
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return const RejectedDialog();
        },
      );
    });

    ClientEvents.connectionLostEvent.subscribe((args) {
      if (kDebugMode) {
        print("Connection lost.");
      }
      if (mounted) {
        _noConnection();
      }
    });
    SettingsScreen.nameChangedEvent.subscribe((args) {
      args as NameChangedEventArgs;
      widget.name = args.name;
      client?.clientTransmit.changeName(args.name);
    });
  }

  void _noConnection() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    showDialog(
      context: context,
      builder: (context) {
        return const NotConnectedDialog();
      },
    );
  }
}
