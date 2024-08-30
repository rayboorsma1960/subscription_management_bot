import 'package:flutter/foundation.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';

class SubscriptionProvider with ChangeNotifier {
  final SubscriptionService _subscriptionService;
  List<Subscription> _subscriptions = [];

  SubscriptionProvider(this._subscriptionService) {
    _fetchSubscriptions();
  }

  List<Subscription> get subscriptions => _subscriptions;

  Future<void> _fetchSubscriptions() async {
    try {
      _subscriptions = await _subscriptionService.getSubscriptions();
      notifyListeners();
    } catch (e) {
      print('Error fetching subscriptions: $e');
      // You might want to handle this error more gracefully
    }
  }

  Future<void> addSubscription(Subscription subscription) async {
    try {
      _subscriptions.add(subscription);
      await _subscriptionService.saveSubscriptions(_subscriptions);
      notifyListeners();
    } catch (e) {
      print('Error adding subscription: $e');
      // You might want to handle this error more gracefully
    }
  }

  Future<void> updateSubscription(Subscription updatedSubscription) async {
    try {
      final index = _subscriptions.indexWhere((sub) => sub.id == updatedSubscription.id);
      if (index != -1) {
        _subscriptions[index] = updatedSubscription;
        await _subscriptionService.saveSubscriptions(_subscriptions);
        notifyListeners();
      } else {
        print('Subscription not found for update');
        // You might want to handle this case more gracefully
      }
    } catch (e) {
      print('Error updating subscription: $e');
      // You might want to handle this error more gracefully
    }
  }

  Future<void> deleteSubscription(String id) async {
    try {
      _subscriptions.removeWhere((sub) => sub.id == id);
      await _subscriptionService.saveSubscriptions(_subscriptions);
      notifyListeners();
    } catch (e) {
      print('Error deleting subscription: $e');
      // You might want to handle this error more gracefully
    }
  }

  double get totalMonthlyExpense {
    return _subscriptions.fold(0, (sum, subscription) => sum + subscription.price);
  }

  List<Subscription> getUpcomingRenewals({int days = 7}) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));
    return _subscriptions.where((sub) => sub.billingDate.isBefore(cutoff)).toList();
  }
}