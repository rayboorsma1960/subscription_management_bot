import 'package:flutter/material.dart';
import 'email_analysis_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Analysis'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _navigateToEmailAnalysis(context),
          child: const Text('Analyze Emails'),
        ),
      ),
    );
  }

  void _navigateToEmailAnalysis(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmailAnalysisScreen(),
      ),
    );
  }
}