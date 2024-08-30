import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';

class SubscriptionService {
  static const String _storageKey = 'subscriptions';
  final SharedPreferences _prefs;

  SubscriptionService(this._prefs);

  Future<List<Subscription>> getSubscriptions() async {
    try {
      final String? subscriptionsJson = _prefs.getString(_storageKey);

      if (subscriptionsJson != null) {
        final List<dynamic> jsonList = jsonDecode(subscriptionsJson);
        return jsonList.map((json) => Subscription.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error retrieving subscriptions: $e');
    }

    return [];
  }

  Future<void> saveSubscriptions(List<Subscription> subscriptions) async {
    try {
      final String subscriptionsJson = jsonEncode(
        subscriptions.map((subscription) => subscription.toJson()).toList(),
      );
      await _prefs.setString(_storageKey, subscriptionsJson);
    } catch (e) {
      print('Error saving subscriptions: $e');
    }
  }
}