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

class AcceptanceEventArgs extends EventArgs {
  bool accepted;
  AcceptanceEventArgs({required this.accepted});
}

class ClientEvents {
  static var broadcastMessageReceivedEvent = Event();
  static var privateMessageReceivedEvent = Event();
  static var usersUpdatedEvent = Event();
  static var becomeServerEvent = Event();
  static var connectToNewServerEvent = Event();
  static var acceptanceEvent = Event();
  static var connectionLostEvent = Event();

  static void stop() {
    usersUpdatedEvent.unsubscribeAll();
    becomeServerEvent.unsubscribeAll();
    connectToNewServerEvent.unsubscribeAll();
    broadcastMessageReceivedEvent.unsubscribeAll();
    privateMessageReceivedEvent.unsubscribeAll();
    acceptanceEvent.unsubscribeAll();
    connectionLostEvent.unsubscribeAll();
  }
}
