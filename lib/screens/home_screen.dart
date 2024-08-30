import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../models/subscription.dart';
import 'add_subscription_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subscriptions'),
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, provider, child) {
          if (provider.subscriptions.isEmpty) {
            return const Center(child: Text('No subscriptions yet'));
          }
          return ListView.builder(
            itemCount: provider.subscriptions.length,
            itemBuilder: (context, index) {
              final subscription = provider.subscriptions[index];
              return ListTile(
                title: Text(subscription.name),
                subtitle: Text('\$${subscription.price.toStringAsFixed(2)}'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<Subscription>(
            context,
            MaterialPageRoute(builder: (context) => const AddSubscriptionScreen()),
          );
          if (result != null) {
            Provider.of<SubscriptionProvider>(context, listen: false).addSubscription(result);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}