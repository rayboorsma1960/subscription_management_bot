import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../models/subscription.dart';
import 'add_subscription_screen.dart';
import 'edit_subscription_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subscriptions'),
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, subscriptionProvider, child) {
          final subscriptions = subscriptionProvider.subscriptions;
          if (subscriptions.isEmpty) {
            return const Center(
              child: Text('No subscriptions yet. Add one to get started!'),
            );
          }
          return ListView.builder(
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
    final result = await Navigator.push<Subscription>(
      context,
      MaterialPageRoute(builder: (context) => const AddSubscriptionScreen()),
    );
    if (result != null) {
      Provider.of<SubscriptionProvider>(context, listen: false)
          .addSubscription(result);
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}