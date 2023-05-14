import 'dart:io';

import 'package:event/event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_chat/network/client.dart';
import 'package:local_chat/network/server.dart';
import 'package:local_chat/screens/chat_screen/chat_screen.dart';
import 'package:local_chat/screens/contacts_screen/custom_widgets/add_trusted_device.dart';
import 'package:local_chat/screens/contacts_screen/custom_widgets/rejected_dialog.dart';
import 'package:local_chat/screens/home_screen.dart';
import 'package:local_chat/screens/settings_screen/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/user.dart';
import '../../utils/utility_functions.dart';
import 'custom_widgets/contact.dart';

class UserAcceptanceEventArgs extends EventArgs {
  final bool accepted;
  UserAcceptanceEventArgs({required this.accepted});
}

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
  LocalNetworkChat? server;
  LocalNetworkChatClient? client;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    handleServerClientConnections();
    subscribeToEvents();
    Utility.getLocalPath().then((value) => _localPath = value);
    getTrustedDevices();
  }

  void getTrustedDevices() async {
    ContactsScreen.trustedDevicePreferences =
        await SharedPreferences.getInstance();
  }

  @override
  void dispose() {
    super.dispose();
    server?.stop();
    client?.stop();
    _tabController.dispose();
    ContactsScreen.userAcceptanceEvent.unsubscribeAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InTalk'),
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
              logout();
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
  void handleServerClientConnections() async {
    client = LocalNetworkChatClient(user: User(name: widget.name));
    await client?.init();
    await tryConnections(client!);
    if (client!.connected) return;
    try {
      //if there is no server, become both a server and a client
      server = LocalNetworkChat(myUser: client!.user);
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
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const HomeScreen()));
        showDialog(
            context: context,
            builder: (context) {
              return const NotConnectedDialog();
            });
      }
    }
  }

  void becomeServer() async {
    if (mounted) {
      setState(() {
        ContactsScreen.loggedInUsers.clear();
      });
    }
    client = LocalNetworkChatClient(user: User(name: widget.name));
    await client?.init();

    server = LocalNetworkChat(myUser: client!.user);
    await server?.start();
    client?.connect(-1);
  }

  void connectToNewServer() async {
    if (mounted) {
      setState(() {
        ContactsScreen.loggedInUsers.clear();
      });
    }
    client = LocalNetworkChatClient(user: User(name: widget.name));
    await client?.init();

    await tryConnections(client!);
  }

  Future<void> tryConnections(LocalNetworkChatClient client) async {
    List<Future<void>> connectFutures = [];

    for (int i = 0; i < 256; i++) {
      connectFutures.add(client.connect(i));
    }
    await Future.wait(connectFutures);

    return;
  }

  void logout() async {
    if (mounted) {
      setState(() {
        ContactsScreen.loggedInUsers.clear();
      });
    }

    if (server != null) {
      await server?.stop();
    } else {
      await client?.stop();
      if (kDebugMode) {
        print("There is no server instance to stop.");
      }
    }
  }

  void subscribeToEvents() {
    //Every time someone updates the list of users, state will be set in order to update the UI.
    LocalNetworkChatClient.usersUpdatedEvent.subscribe((args) {
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
    LocalNetworkChatClient.becomeServerEvent.subscribe((args) {
      becomeServer();
    });
    LocalNetworkChatClient.connectToNewServerEvent.subscribe((args) {
      connectToNewServer();
    });

    LocalNetworkChatClient.broadcastMessageReceivedEvent
        .subscribe((args) async {
      args as NewMessageEventArgs;
      File? file;
      if (args.imageBytes != null) {
        file = File('$_localPath/${Utility.generateRandomString(5)}.jpeg');
        await file.create();
        file.writeAsBytesSync(args.imageBytes!);
      }
      if (ContactsScreen.messages[ContactsScreen.generalChatUser] == null) {
        ContactsScreen.messages[ContactsScreen.generalChatUser] = [];
      }
      ContactsScreen.messages[ContactsScreen.generalChatUser]!.insert(
          0, Message(message: args.message, sender: args.sender, image: file));
    });

    LocalNetworkChatClient.privateMessageReceivedEvent.subscribe((args) async {
      args as NewMessageEventArgs;
      File? file;
      if (args.imageBytes != null) {
        file = File('$_localPath/${Utility.generateRandomString(5)}.jpeg');
        await file.create();
        file.writeAsBytesSync(args.imageBytes!);
      }
      User sender = Utility.getUserByName(args.sender);
      if (ContactsScreen.messages[sender] == null) {
        ContactsScreen.messages[sender] = [];
      }
      ContactsScreen.messages[sender]!.insert(
          0, Message(message: args.message, sender: args.sender, image: file));
    });

    LocalNetworkChat.authEvent.subscribe(
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

    LocalNetworkChatClient.acceptanceEvent.subscribe((args) {
      args as AcceptanceEventArgs;
      if (args.accepted == false) {
        logout();
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const HomeScreen()));
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return const RejectedDialog();
          },
        );
      }
    });

    SettingsScreen.nameChangedEvent.subscribe((args) {
      args as NameChangedEventArgs;
      widget.name = args.name;
      client?.changeName(args.name);
    });
  }
}
