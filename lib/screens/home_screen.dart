import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../models/subscription.dart';
import '../services/email_scanner_service.dart';
import 'add_subscription_screen.dart';
import 'edit_subscription_screen.dart';
import 'select_email_screen.dart';
import 'subscription_history_screen.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.email),
            onPressed: () => _selectSubscriptionEmail(context),
          ),
        ],
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, subscriptionProvider, child) {
          final subscriptions = subscriptionProvider.subscriptions;
          final totalMonthlyFees = subscriptionProvider.totalMonthlyFees;

          return Column(
            children: [
              // Total monthly fees card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Monthly Fees:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$${totalMonthlyFees.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
              // Subscription list
              Expanded(
                child: subscriptions.isEmpty
                    ? const Center(
                  child: Text('No subscriptions yet. Add one to get started!'),
                )
                    : ListView.builder(
                  itemCount: subscriptions.length,
                  itemBuilder: (context, index) {
                    final subscription = subscriptions[index];
                    return Dismissible(
                      key: Key(subscription.id),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        subscriptionProvider.deleteSubscription(subscription.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${subscription.name} deleted')),
                        );
                      },
                      child: ListTile(
                        title: Text(subscription.name),
                        subtitle: Text(
                          'Price: \$${subscription.price.toStringAsFixed(2)} | Next billing: ${_formatDate(subscription.billingDate)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editSubscription(context, subscription),
                        ),
                        onTap: () => _viewSubscriptionHistory(context, subscription),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addSubscription(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addSubscription(BuildContext context) async {
    final navigator = Navigator.of(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final result = await navigator.push<Subscription>(
      MaterialPageRoute(builder: (context) => const AddSubscriptionScreen()),
    );
    if (result != null) {
      subscriptionProvider.addSubscription(result);
    }
  }

  void _editSubscription(BuildContext context, Subscription subscription) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSubscriptionScreen(subscription: subscription),
      ),
    );
  }

  void _selectSubscriptionEmail(BuildContext context) async {
    final navigator = Navigator.of(context);
    final result = await navigator.push<gmail.Message>(
      MaterialPageRoute(builder: (context) => const SelectEmailScreen()),
    );
    if (result != null) {
      _processSelectedEmail(context, result);
    }
  }

  void _processSelectedEmail(BuildContext context, gmail.Message email) {
    final EmailScannerService emailScannerService = EmailScannerService();
    final SubscriptionProvider subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);

    final subject = email.payload?.headers
        ?.firstWhere((header) => header.name == 'Subject', orElse: () => gmail.MessagePartHeader())
        .value ?? '';
    final from = email.payload?.headers
        ?.firstWhere((header) => header.name == 'From', orElse: () => gmail.MessagePartHeader())
        .value ?? '';
    final body = emailScannerService.getEmailBody(email);

    // Extract subscription information
    final name = _extractSubscriptionName(subject, from, body);
    final price = _extractPrice(body);
    final billingDate = _extractBillingDate(body);

    if (name != null && price != null) {
      final newSubscription = Subscription(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        price: price,
        billingDate: billingDate ?? DateTime.now(),
      );

      subscriptionProvider.addSubscription(newSubscription);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added subscription')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not extract subscription information from the email')),
      );
    }
  }

  void _viewSubscriptionHistory(BuildContext context, Subscription subscription) async {
    final EmailScannerService emailScannerService = EmailScannerService();
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Fetch subscription history
      final historyEmails = await emailScannerService.fetchSubscriptionHistory(subscription.name);

      // Hide loading indicator
      navigator.pop();

      // Navigate to subscription history screen
      navigator.push(
        MaterialPageRoute(
          builder: (context) => SubscriptionHistoryScreen(emails: historyEmails),
        ),
      );
    } catch (e) {
      // Hide loading indicator
      navigator.pop();

      // Show error message
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Failed to fetch subscription history')),
      );
    }
  }

  String? _extractSubscriptionName(String subject, String from, String body) {
    // Implement logic to extract subscription name
    // This is a simple example and may need to be refined
    final fromParts = from.split('<');
    if (fromParts.isNotEmpty) {
      return fromParts[0].trim();
    }
    return null;
  }

  double? _extractPrice(String body) {
    // Implement logic to extract price
    // This is a simple example and may need to be refined
    final priceRegex = RegExp(r'\$\d+(\.\d{2})?');
    final match = priceRegex.firstMatch(body);
    if (match != null) {
      return double.tryParse(match.group(0)!.substring(1));
    }
    return null;
  }

  DateTime? _extractBillingDate(String body) {
    // Implement logic to extract billing date
    // This is a placeholder and needs to be implemented based on email content
    return DateTime.now().add(const Duration(days: 30));  // Default to 30 days from now
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}