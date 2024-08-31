// scan_results_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../services/email_scanner_service.dart';
import '../providers/subscription_provider.dart';

class ScanResultsScreen extends StatefulWidget {
  const ScanResultsScreen({super.key});

  @override
  State<ScanResultsScreen> createState() => _ScanResultsScreenState();
}

class _ScanResultsScreenState extends State<ScanResultsScreen> {
  final EmailScannerService _scannerService = EmailScannerService();
  List<PotentialSubscription> _potentialSubscriptions = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _scanEmails();
  }

  Future<void> _scanEmails() async {
    final results = await _scannerService.scanEmails();
    setState(() {
      _potentialSubscriptions = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_potentialSubscriptions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scanning Emails')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final current = _potentialSubscriptions[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Potential Subscription Found')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: ${current.serviceName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Price: \$${current.price.toStringAsFixed(2)}'),
            Text('Next Billing Date: ${_formatDate(DateTime.now().add(current.billingDate))}'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _addSubscription,
                  child: const Text('Add'),
                ),
                ElevatedButton(
                  onPressed: _skipSubscription,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addSubscription() {
    final current = _potentialSubscriptions[_currentIndex];
    final newSubscription = Subscription(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: current.serviceName,
      price: current.price,
      billingDate: DateTime.now().add(current.billingDate),
    );
    // Add to provider
    Provider.of<SubscriptionProvider>(context, listen: false).addSubscription(newSubscription);
    _nextSubscription();
  }

  void _skipSubscription() {
    _nextSubscription();
  }

  void _nextSubscription() {
    if (_currentIndex < _potentialSubscriptions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      Navigator.of(context).pop(); // Return to home screen when done
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}