// email_scanner_service.dart

class EmailScannerService {
  Future<List<PotentialSubscription>> scanEmails() async {
    // This is a placeholder. Actual implementation will depend on the email API we use.
    // For demonstration, let's return some mock data.
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay
    return [
      PotentialSubscription(
        serviceName: 'Netflix',
        price: 12.99,
        billingDate: const Duration(days: 7),
      ),
      PotentialSubscription(
        serviceName: 'Spotify',
        price: 9.99,
        billingDate: const Duration(days: 14),
      ),
    ];
  }
}

class PotentialSubscription {
  final String serviceName;
  final double price;
  final Duration billingDate;

  const PotentialSubscription({
    required this.serviceName,
    required this.price,
    required this.billingDate,
  });

  DateTime get nextBillingDate => DateTime.now().add(billingDate);
}