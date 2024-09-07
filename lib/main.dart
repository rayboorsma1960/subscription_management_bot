import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const EmailAnalysisApp());
}

class EmailAnalysisApp extends StatelessWidget {
  const EmailAnalysisApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Email Analysis',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}