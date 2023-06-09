import 'package:event/event.dart';

class NewMessageEventArgs extends EventArgs {
  final String message;
  final String sender;
  final String receiver;
  final String senderMac;
  List<int>? imageBytes;
  NewMessageEventArgs(
      {required this.message,
      required this.sender,
      required this.senderMac,
      required this.receiver,
      this.imageBytes});
}

class ClientEvents {
  //When a new broadcast message is received
  static var broadcastMessageReceivedEvent = Event();
  //When a new private message is received
  static var privateMessageReceivedEvent = Event();
  //When a logout or login occurs
  static var usersUpdatedEvent = Event();
  //When server exits and you are the first candidate to become the new server
  static var becomeServerEvent = Event();
  //When server exits and you are not the first candidate to become the new server
  static var connectToNewServerEvent = Event();
  //When you try to connect but host rejects you
  static var rejectedEvent = Event();
  //When you lose connection to LAN
  static var connectionLostEvent = Event();

  static void stop() {
    usersUpdatedEvent.unsubscribeAll();
    becomeServerEvent.unsubscribeAll();
    connectToNewServerEvent.unsubscribeAll();
    broadcastMessageReceivedEvent.unsubscribeAll();
    privateMessageReceivedEvent.unsubscribeAll();
    rejectedEvent.unsubscribeAll();
    connectionLostEvent.unsubscribeAll();
  }
}
