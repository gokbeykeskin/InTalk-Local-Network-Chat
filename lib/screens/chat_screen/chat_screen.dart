import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_chat/network/client/client_events.dart';
import 'package:local_chat/screens/chat_screen/custom_widgets/chat_title.dart';
import 'package:local_chat/screens/chat_screen/custom_widgets/message_box.dart';
import 'package:local_chat/screens/chat_screen/custom_widgets/user_logged_out_dialog.dart';
import 'package:local_chat/screens/contacts_screen/contacts_screen.dart';
import 'package:local_chat/utils/image_utils.dart';
import '../../auth/user.dart';
import '../../network/client/client.dart';
import 'custom_widgets/select_photo_options_screen.dart';

class Message {
  final String? sender;
  final String? senderMac;
  final String message;
  final File? image;
  Message(
      {required this.message,
      required this.senderMac,
      required this.sender,
      this.image});
}

class ChatScreen extends StatefulWidget {
  final bool isGeneralChat;
  final User receiver;
  final LanClient meClient;
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
  final textFieldController = TextEditingController();
  late ScaffoldMessengerState _scaffoldMessengerState;

  @override
  void didChangeDependencies() {
    _scaffoldMessengerState = ScaffoldMessenger.of(context);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _scaffoldMessengerState.clearSnackBars();
    ContactsScreen.ongoingImageSend = false;
    super.dispose();
    textFieldController.dispose();
  }

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
      ClientEvents.broadcastMessageReceivedEvent.subscribe((args) async {
        await Future.delayed(const Duration(milliseconds: 10));
        if (mounted) {
          setState(() {
            messages;
          });
        }
      });
    } else {
      ClientEvents.privateMessageReceivedEvent.subscribe((args) async {
        await Future.delayed(const Duration(milliseconds: 10));
        if (mounted) {
          setState(() {
            messages;
          });
        }
      });
    }
    //if the person you are chatting logs out, pop to main window and show a dialog. (only for private chats)
    ClientEvents.usersUpdatedEvent.subscribe((args) {
      if (!ContactsScreen.loggedInUsers
              .any((user) => user.port == widget.receiver.port) &&
          !widget.isGeneralChat) {
        if (mounted) {
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return const UserLoggedOutDialog();
            },
          );
        }
      }
    });
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
            if (messages[index].senderMac == widget.meClient.user.macAddress) {
              return MessageBox(
                  sender: messages[index].sender!,
                  message: messages[index].message,
                  image: messages[index].image,
                  alignment: Alignment.centerRight);
            } else {
              return MessageBox(
                  sender: messages[index].sender!,
                  message: messages[index].message,
                  image: messages[index].image,
                  alignment: Alignment.centerLeft);
            }
          }),
    );
  }

//consists of message typing field and send image button
  _createBottomChatArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 35),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: textFieldController,
            autofocus: true,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Type a message',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            keyboardType: TextInputType.name,
            onSubmitted: (value) {
              if (mounted) {
                setState(() {
                  messages.insert(
                      0,
                      Message(
                          sender: widget.meClient.user.name,
                          senderMac: widget.meClient.user.macAddress,
                          message: value));
                });
              }

              if (widget.isGeneralChat) {
                widget.meClient.clientTransmit.sendBroadcastMessage(value);
              } else {
                widget.meClient.clientTransmit
                    .sendPrivateMessage(value, widget.receiver);
              }
              if (value.isNotEmpty) {
                textFieldController.clear();
              }
            },
          ),
        ),
        SizedBox(
          width: 50,
          height: 50,
          child: IconButton(
              padding: const EdgeInsets.all(0.0),
              onPressed: () {
                ContactsScreen.ongoingImageSend
                    ? null
                    : _showSelectPhotoOptions(context);
              },
              color:
                  ContactsScreen.ongoingImageSend ? Colors.grey : Colors.blue,
              icon: const Icon(Icons.image, size: 50)),
        ),
      ]),
    );
  }

  Future _pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;
      File? img = File(image.path);
      img = await ImageUtils.cropImage(imageFile: img);
      if (img == null) return;
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(_imageSendingSnackBar());
        setState(() {
          ContactsScreen.ongoingImageSend = true;
        });
      }
      img = await ImageUtils.compressImage(img, '${img.path}compressed.jpeg');
      if (widget.isGeneralChat) {
        await widget.meClient.clientTransmit
            .sendBroadcastImage(img.readAsBytesSync());
      } else {
        await widget.meClient.clientTransmit
            .sendPrivateImage(img.readAsBytesSync(), widget.receiver);
      }
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() {
          ContactsScreen.ongoingImageSend = false;
        });
      }
      if (mounted) {
        setState(() {
          messages.insert(
              0,
              Message(
                  sender: widget.meClient.user.name,
                  senderMac: widget.meClient.user.macAddress,
                  message: "",
                  image: img));
        });
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print(e);
      }
      Navigator.of(context).pop();
    }
  }

  void _showSelectPhotoOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25.0),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.28,
          maxChildSize: 0.4,
          minChildSize: 0.28,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: SelectPhotoOptionsScreen(
                onTap: _pickImage,
              ),
            );
          }),
    );
  }

  SnackBar _imageSendingSnackBar() {
    return SnackBar(
      behavior: SnackBarBehavior.fixed,
      duration: const Duration(minutes: 30),
      content: SizedBox(
        height: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Sending Image',
              overflow: TextOverflow.visible,
            ),
            SizedBox(width: 50),
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
