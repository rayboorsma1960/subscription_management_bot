import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';

class SubscriptionProvider with ChangeNotifier {
  final SubscriptionService _subscriptionService;
  List<Subscription> _subscriptions = [];

  SubscriptionProvider(SharedPreferences prefs)
      : _subscriptionService = SubscriptionService(prefs) {
    _fetchSubscriptions();
  }

  List<Subscription> get subscriptions => _subscriptions;

  Future<void> _fetchSubscriptions() async {
    try {
      _subscriptions = await _subscriptionService.getSubscriptions();
      notifyListeners();
    } catch (e) {
      print('Error fetching subscriptions: $e');
    }
  }

  Future<void> addSubscription(Subscription subscription) async {
    _subscriptions.add(subscription);
    await _subscriptionService.saveSubscriptions(_subscriptions);
    notifyListeners();
  }
}