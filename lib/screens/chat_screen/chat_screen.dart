import 'package:flutter/material.dart';
import 'package:local_chat/screens/chat_screen/custom_widgets/chat_title.dart';
import 'package:local_chat/screens/chat_screen/custom_widgets/message_box.dart';
import 'package:local_chat/screens/contacts_screen/contacts_screen.dart';

import '../../backend/client.dart';

class Message {
  final String? sender;
  final String message;
  Message({required this.message, this.sender});
}

class ChatScreen extends StatefulWidget {
  final bool isGeneralChat;
  final User receiver;
  final LocalNetworkChatClient meClient;
  const ChatScreen(
      {super.key,
      required this.isGeneralChat,
      required this.receiver,
      required this.meClient});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Message> messages = [];

  @override
  void initState() {
    super.initState();
    if (mounted) {
      if (ContactsScreen.messages[widget.receiver] == null) {
        //if there is no message for this receiver, create a new list.
        ContactsScreen.messages[widget.receiver] = messages;
      } else {
        //if there is a message for this receiver, get it from the map.
        setState(() {
          messages = ContactsScreen.messages[widget.receiver]!;
        });
      }
    }
    if (widget.isGeneralChat) {
      LocalNetworkChatClient.broadcastMessageReceivedEvent.subscribe((args) {
        if (mounted) {
          setState(() {
            messages;
          });
        }
      });
    } else {
      LocalNetworkChatClient.privateMessageReceivedEvent.subscribe((args) {
        if (mounted) {
          setState(() {
            messages;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _createChatAppBar(),
      body: Column(children: [
        _createCentralChatArea(),
        _createBottomChatArea(),
      ]),
    );
  }

  _createChatAppBar() {
    return !widget.isGeneralChat
        ? AppBar(
            title: ChatTitle(
              toChatUser: User(name: widget.receiver.name),
            ),
            centerTitle: true,
          )
        : null;
  }

//returns the area which contains chat messages
  _createCentralChatArea() {
    return Expanded(
      child: ListView.builder(
          itemCount: messages.length,
          reverse: true,
          itemBuilder: (context, index) {
            if (messages[index].sender == widget.meClient.user.name) {
              return MessageBox(
                  sender: messages[index].sender!,
                  message: messages[index].message,
                  alignment: Alignment.centerRight);
            } else {
              return MessageBox(
                  sender: messages[index].sender!,
                  message: messages[index].message,
                  alignment: Alignment.centerLeft);
            }
          }),
    );
  }

//consists of message typing and send image button
  _createBottomChatArea() {
    final textFieldController = TextEditingController();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30),
      child: Row(children: [
        Expanded(
            child: TextField(
          controller: textFieldController,
          decoration: InputDecoration(
            hintText: 'Type a message',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          keyboardType: TextInputType.name,
          onSubmitted: (value) {
            if (mounted) {
              setState(() {
                messages.insert(0,
                    Message(sender: widget.meClient.user.name, message: value));
              });
            }

            if (widget.isGeneralChat) {
              widget.meClient.sendBroadcastMessage(value);
            } else {
              widget.meClient.sendPrivateMessage(value, widget.receiver);
            }
            if (value.isNotEmpty) {
              textFieldController.clear();
            }
          },
        )),
        SizedBox(
          width: 50,
          height: 50,
          child: IconButton(
              padding: const EdgeInsets.all(0.0),
              onPressed: () {},
              color: Colors.blue,
              icon: const Icon(Icons.image, size: 50)),
        ),
      ]),
    );
  }
}
