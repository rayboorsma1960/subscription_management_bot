import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../services/email_scanner_service.dart';
import '../providers/subscription_provider.dart';

class ScanResultsScreen extends StatefulWidget {
  const ScanResultsScreen({Key? key}) : super(key: key);

  @override
  State<ScanResultsScreen> createState() => _ScanResultsScreenState();
}

class _ScanResultsScreenState extends State<ScanResultsScreen> {
  final EmailScannerService _scannerService = EmailScannerService();
  Map<Subscription, List<SubscriptionEmail>> _subscriptionEmails = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scanEmails();
  }

  Future<void> _scanEmails() async {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final subscriptions = subscriptionProvider.subscriptions;
    final results = await _scannerService.scanEmailsForSubscriptions(subscriptions);
    setState(() {
      _subscriptionEmails = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Emails')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subscriptionEmails.isEmpty
          ? const Center(child: Text('No subscription emails found'))
          : ListView.builder(
        itemCount: _subscriptionEmails.length,
        itemBuilder: (context, index) {
          final subscription = _subscriptionEmails.keys.elementAt(index);
          final emails = _subscriptionEmails[subscription] ?? [];
          return emails.isEmpty
              ? const SizedBox.shrink()
              : ExpansionTile(
            title: Text('${subscription.name} (${emails.length})'),
            children: emails.map((email) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(email.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('From: ${email.from}'),
                    Text('Date: ${_formatDate(email.date)}'),
                    const SizedBox(height: 4),
                    Text(
                      email.snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                onTap: () => _showEmailDetails(email),
              ),
            )).toList(),
          );
        },
      ),
    );
  }

  void _showEmailDetails(SubscriptionEmail email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(email.subject),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('From: ${email.from}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Date: ${_formatDate(email.date)}'),
              Text('Subscription: ${email.subscription.name}'),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Body:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(email.body),
            ],
          ),
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}