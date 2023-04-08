import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_chat/screens/home_screen.dart';

void main() {
  //ProviderScope ile wrapleme sebebi: riverpod ile state management yapmak
  //Bu paket sayesinde stateleri widgetler arası taşıyabiliyoruz.
  //Örnek: Mesajları ana ekrana taşımak ve mesaj ekranı kapatıp açıldığında
  //mesajları korumak.
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InChat',
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
