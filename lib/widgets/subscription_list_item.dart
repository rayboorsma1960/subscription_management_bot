import 'package:flutter/material.dart';
import '../models/subscription.dart';

class SubscriptionListItem extends StatelessWidget {
  final Subscription subscription;

  SubscriptionListItem({required this.subscription});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(subscription.name),
      subtitle: Text('Price: \$${subscription.price.toStringAsFixed(2)}'),
      trailing: Text('Next billing: ${subscription.billingDate.toString().split(' ')[0]}'),
    );
  }
}