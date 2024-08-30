import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'providers/subscription_provider.dart';
import 'services/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final subscriptionService = SubscriptionService(prefs);

  runApp(
    ChangeNotifierProvider(
      create: (context) => SubscriptionProvider(subscriptionService),
      child: const SubscriptionManagementApp(),
    ),
  );
}

class SubscriptionManagementApp extends StatelessWidget {
  const SubscriptionManagementApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subscription Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}