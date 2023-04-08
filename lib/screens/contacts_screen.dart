import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_chat/backend/client.dart';
import 'package:local_chat/backend/server.dart';
import 'package:local_chat/screens/chat_screen/chat_screen.dart';
import 'package:local_chat/screens/home_screen.dart';

import '../utils/messaging_protocol.dart';

class ContactsScreen extends StatefulWidget {
  final String name;
  const ContactsScreen({super.key, required this.name});
  static List<User> loggedInUsers = [];

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LocalNetworkChat? server;
  LocalNetworkChatClient? client;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    handleServerClientConnections();

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
  }

  @override
  void dispose() {
    super.dispose();
    server?.stop();
    client?.stop();
    _tabController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InChat'),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                logout();
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HomeScreen()));
              }),
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
        receiver: null,
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: ListTile(
                        title: Text(user.name),
                        subtitle: Text(user.port.toString()),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                      isGeneralChat: false,
                                      meClient: client!,
                                      receiver: ContactsScreen
                                          .loggedInUsers[index])));
                        },
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        tileColor: Colors.blue[100],
                      ),
                    );
                  }),
            )
          ],
        ));
  }

//tries to connect to a server. If there is no server, it will establish a server and connect to it.
//this is called on a new login and it is the generic case.
  void handleServerClientConnections() async {
    client = LocalNetworkChatClient(user: User(name: widget.name));
    await tryConnections(client!);
    if (client!.connected) return;
    try {
      //if there is no server, become both a server and a client
      server = LocalNetworkChat();
      server?.start();
      client?.connect(-1); //connect to your own ip.
      if (kDebugMode) {
        print('Server started');
      }
    } catch (e) {
      if (kDebugMode) {
        print("Can't create server.: $e");
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
    server = LocalNetworkChat();
    server?.start();
    client?.connect(-1);
  }

  void connectToNewServer() async {
    if (mounted) {
      setState(() {
        ContactsScreen.loggedInUsers.clear();
      });
    }
    await Future.delayed(Duration(seconds: 1));
    client = LocalNetworkChatClient(user: User(name: widget.name));
    await tryConnections(client!);
  }

  Future<void> tryConnections(LocalNetworkChatClient client) async {
    /*await client.connect(i) zaman alan kısım. ama bunu yapmazsam bütün ipleri
    deneyemeden access point açıyor. normalde bu range 256'ya kadar olmalı ama
    80'in üstünde cihaz olduğunu henüz görmedim. 80 3-5 cihazı kurtarıyor.*/
    for (int i = 0; i < 80; i++) {
      if (client.connected) break;
      await client.connect(i);
    }
    //await Future.delayed(const Duration(milliseconds: 2000));

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
}
