import 'package:flutter/material.dart';
import 'screens/connect_screen.dart';

void main() {
  runApp(const LinuxRemoteApp());
}

class LinuxRemoteApp extends StatelessWidget {
  const LinuxRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Linux Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ConnectScreen(),
    );
  }
}
