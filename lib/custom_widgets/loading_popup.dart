import 'package:flutter/material.dart';

class LoadingPopup extends StatelessWidget {
  final String message;

  const LoadingPopup(
      {Key? key, this.message = 'Searching for an access point...'})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}
