import 'package:flutter/material.dart';

import 'game_widget.dart';

void main() {
  runApp(const DrifterApp());
}

class DrifterApp extends StatelessWidget {
  const DrifterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drifter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F18),
      ),
      home: const Scaffold(
        body: Center(child: DrifterWidget()),
      ),
    );
  }
}
