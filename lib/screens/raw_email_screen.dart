import 'package:flutter/material.dart';
import '../services/email_scanner_service.dart';

class RawEmailScreen extends StatelessWidget {
  final String emailId;
  final EmailScannerService emailScannerService;

  const RawEmailScreen({
    Key? key,
    required this.emailId,
    required this.emailScannerService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raw Email')),
      body: FutureBuilder<String>(
        future: emailScannerService.fetchRawEmail(emailId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No email content available'));
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(snapshot.data!),
            );
          }
        },
      ),
    );
  }
}