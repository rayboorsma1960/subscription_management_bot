import 'package:flutter/material.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import '../services/email_scanner_service.dart';

class SubscriptionHistoryScreen extends StatelessWidget {
  final List<gmail.Message> emails;
  final EmailScannerService emailScannerService = EmailScannerService();

  SubscriptionHistoryScreen({Key? key, required this.emails}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription History'),
      ),
      body: ListView.builder(
        itemCount: emails.length,
        itemBuilder: (context, index) {
          final email = emails[index];
          final subject = email.payload?.headers
              ?.firstWhere((header) => header.name == 'Subject', orElse: () => gmail.MessagePartHeader())
              .value ?? 'No Subject';
          final date = DateTime.fromMillisecondsSinceEpoch(int.parse(email.internalDate ?? '0'));
          final body = emailScannerService.getEmailBody(email);
          final amount = _extractAmount(body);

          return ListTile(
            title: Text(subject),
            subtitle: Text('Date: ${date.toString().split(' ')[0]} | Amount: ${amount ?? 'N/A'}'),
            onTap: () {
              _showEmailDetails(context, email);
            },
          );
        },
      ),
    );
  }

  void _showEmailDetails(BuildContext context, gmail.Message email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(email.payload?.headers
            ?.firstWhere((header) => header.name == 'Subject', orElse: () => gmail.MessagePartHeader())
            .value ?? 'No Subject'),
        content: SingleChildScrollView(
          child: Text(emailScannerService.getEmailBody(email)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String? _extractAmount(String body) {
    final match = RegExp(r'\$\d+(\.\d{2})?').firstMatch(body);
    return match?.group(0);
  }
}