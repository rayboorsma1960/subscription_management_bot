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

  double get totalMonthlyFees {
    return _subscriptions.fold(0, (sum, subscription) => sum + subscription.price);
  }

  Future<void> _fetchSubscriptions() async {
    try {
      _subscriptions = await _subscriptionService.getSubscriptions();
      notifyListeners();
    } catch (e) {
      print('Error fetching subscriptions: $e');
    }
  }

  Future<void> addSubscription(Subscription subscription) async {
    try {
      _subscriptions.add(subscription);
      await _subscriptionService.saveSubscriptions(_subscriptions);
      notifyListeners();
    } catch (e) {
      print('Error adding subscription: $e');
    }
  }

  Future<void> updateSubscription(Subscription updatedSubscription) async {
    try {
      final index = _subscriptions.indexWhere((sub) => sub.id == updatedSubscription.id);
      if (index != -1) {
        _subscriptions[index] = updatedSubscription;
        await _subscriptionService.saveSubscriptions(_subscriptions);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating subscription: $e');
    }
  }

  Future<void> deleteSubscription(String id) async {
    try {
      _subscriptions.removeWhere((sub) => sub.id == id);
      await _subscriptionService.saveSubscriptions(_subscriptions);
      notifyListeners();
    } catch (e) {
      print('Error deleting subscription: $e');
    }
  }
}