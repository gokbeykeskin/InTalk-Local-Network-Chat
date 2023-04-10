import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_chat/screens/chat_screen/custom_widgets/chat_title.dart';
import 'package:local_chat/screens/chat_screen/custom_widgets/message_box.dart';
import 'package:local_chat/screens/contacts_screen/contacts_screen.dart';

import '../../backend/client.dart';
import '../select_photo_options_screen.dart';

class Message {
  final String? sender;
  final String message;
  final File? image;
  Message({required this.message, this.sender, this.image});
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
              onPressed: () {
                _showSelectPhotoOptions(context);
              },
              color: Colors.blue,
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
      img = await _cropImage(imageFile: img);

      widget.meClient.sendBroadcastImage(img!.readAsBytesSync());
      setState(() {
        messages.insert(
            0,
            Message(
                sender: widget.meClient.user.name, message: "", image: img));
        Navigator.of(context).pop();
      });
    } on PlatformException catch (e) {
      print(e);
      Navigator.of(context).pop();
    }
  }

  Future<File?> _cropImage({required File imageFile}) async {
    CroppedFile? croppedImage =
        await ImageCropper().cropImage(sourcePath: imageFile.path);
    if (croppedImage == null) return null;
    return File(croppedImage.path);
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
}
