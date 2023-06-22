class User {
  String? macAddress;
  String name;
  // The port of the socket which is used for communicating with the server
  int? port;
  User({required this.name, this.port, this.macAddress});
}
