import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_chat/screens/home_screen/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InTalk',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
            primary: Colors.lightGreen,
            secondary: Colors.blue,
            background: Color(0xFFE9F9EB)),
        scaffoldBackgroundColor: const Color(0xFFE9F9EB),
      ),
      home: const HomeScreen(),
    );
  }
}
