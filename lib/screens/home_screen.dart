import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../models/subscription.dart';
import 'add_subscription_screen.dart';
import 'edit_subscription_screen.dart';
import 'scan_results_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _scanEmails(context),
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
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final result = await Navigator.push<Subscription>(
      context,
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

  void _scanEmails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanResultsScreen()),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}