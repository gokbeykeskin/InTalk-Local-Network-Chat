import 'dart:io';

import 'package:event/event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_chat/network/client/client.dart';
import 'package:local_chat/network/client/client_events.dart';
import 'package:local_chat/network/server/server.dart';
import 'package:local_chat/screens/chat_screen/chat_screen.dart';
import 'package:local_chat/screens/chat_screen/custom_widgets/user_logged_out_dialog.dart';
import 'package:local_chat/screens/contacts_screen/custom_widgets/add_trusted_device.dart';
import 'package:local_chat/screens/contacts_screen/custom_widgets/rejected_dialog.dart';
import 'package:local_chat/screens/home_screen/custom_widgets/waiting_dialog.dart';
import 'package:local_chat/screens/home_screen/home_screen.dart';
import 'package:local_chat/screens/settings_screen/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/user.dart';
import '../../network/server/server_helpers.dart';
import '../../utils/image_utils.dart';
import 'custom_widgets/contact.dart';

//Broadcasted when host accepts or rejects a connection request.
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
  //broadcasted when host accepts or rejects a connection request.
  static Event userAcceptanceEvent = Event();
  static SharedPreferences? trustedDevicePreferences;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LanServer? _server;
  LanClient? _client;
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
    print("Contacts Screen disposed");
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
        title: _server == null
            ? const Text('InTalk')
            : const Text('InTalk (HOST)'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SettingsScreen(
                            username: widget.name,
                            server: _server,
                          )));
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
      body: _server == null && ContactsScreen.loggedInUsers.isEmpty
          ? const WaitingDialog()
          : TabBarView(
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
        meClient: _client!,
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
                        client: _client!,
                        index: index);
                  }),
            )
          ],
        ));
  }

//tries to connect to a server. If there is no server, it will establish a server and connect to it.
//this is called on a new login.
  void _handleServerClientConnections() async {
    //create a client and try to connect each ip in the subnet.
    _client = LanClient(user: User(name: widget.name));
    await _client?.start();
    await _tryConnections(_client!);
    //if the connection is successful, job is done. Simply return.
    if (_client!.isConnected) return;

    //if there is no server to connect, try to become both a server and a client
    //if this also fails, the most likely reason is that there is no LAN connection.
    //In this case, show a dialog and return.
    try {
      if (mounted) {
        setState(() {
          _server = LanServer(myUser: _client!.user);
        });
      }
      await _server?.start();
      _client?.connect(-1); //connect to your own ip.
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

  //When server logs out and you are the first
  //candidate to become the new server, this method is called.
  void _becomeServer() async {
    if (mounted) {
      setState(() {
        ContactsScreen.loggedInUsers.clear();
      });
    }
    _client = LanClient(user: User(name: widget.name));
    await _client?.start();
    _server = LanServer(myUser: _client!.user);
    await _server?.start();
    _client?.connect(-1);
  }

  //When server logs out and you are not the first candidate to become the
  //new server, this method is called.
  void _connectToNewServer() async {
    //Give the server some time to start.
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        ContactsScreen.loggedInUsers.clear();
      });
    }
    _client = LanClient(user: User(name: widget.name));
    await _client?.start();

    await _tryConnections(_client!);
  }

  //tries to connect to each ip in the subnet.
  Future<void> _tryConnections(LanClient client) async {
    List<Future<void>> connectFutures = [];
    for (int i = 0; i < 256; i++) {
      connectFutures.add(client.connect(i));
    }
    await Future.wait(connectFutures);

    return;
  }

  //stops the server and client.
  void _logout() async {
    ContactsScreen.loggedInUsers.clear();
    ClientEvents.connectionLostEvent.unsubscribeAll();
    if (_server != null) {
      await _server?.stop();
      _server = null;
    } else {
      if (kDebugMode) {
        print("There is no server instance to stop.");
      }
    }
    _client?.stop();
  }

  //Most of the job is done in the ContactScreen because it is the one that
  //comes after the login page and before all other screens.
  //So it can pass anything to those screens. That's why there are lots of
  //event listeners in this screen.
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

    //When a new device wants to connect, this event is broadcasted.
    //args are the mac address and the name of the device.
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
    //When you are rejected by the host, this event is broadcasted.
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
    // No LAN connection
    ClientEvents.connectionLostEvent.subscribe((args) {
      if (kDebugMode) {
        print("Connection lost.");
      }
      if (mounted) {
        _noConnection();
      }
    });
    //You changed your name in the settings screen.
    SettingsScreen.nameChangedEvent.subscribe((args) {
      args as NameChangedEventArgs;
      widget.name = args.name;
      _client?.clientTransmit.changeName(args.name);
    });
  }

  //When there is no LAN connection, this method is called.
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
