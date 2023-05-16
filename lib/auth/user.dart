class User {
  String? macAddress;
  String name;
  // The socket used to communicate with the server
  int? port;
  User({required this.name, this.port, this.macAddress});
}
