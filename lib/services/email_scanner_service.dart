import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailScannerService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/gmail.readonly',
    ],
  );

  Future<List<PotentialSubscription>> scanEmails() async {
    try {
      print('Starting email scan');
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        print('Sign-in failed or was cancelled by the user');
        throw Exception('Sign-in failed');
      }
      print('Successfully signed in as ${account.email}');

      final GoogleSignInAuthentication googleAuth = await account.authentication;
      final headers = await account.authHeaders;
      final client = GoogleAuthClient(headers);

      print('Creating Gmail API client');
      final gmailApi = gmail.GmailApi(client);

      print('Fetching messages');
      final messages = await gmailApi.users.messages.list('me', maxResults: 100);
      print('Fetched ${messages.messages?.length ?? 0} messages');

      final potentialSubscriptions = <PotentialSubscription>[];

      if (messages.messages != null) {
        for (var message in messages.messages!) {
          print('Processing message ${message.id}');
          final fullMessage = await gmailApi.users.messages.get('me', message.id!);
          final subscription = _parseEmailForSubscription(fullMessage);
          if (subscription != null) {
            potentialSubscriptions.add(subscription);
            print('Found potential subscription: ${subscription.serviceName}');
          }
        }
      }

      print('Scan complete. Found ${potentialSubscriptions.length} potential subscriptions');
      return potentialSubscriptions;
    } catch (e) {
      print('Error scanning emails: $e');
      return [];
    }
  }

  PotentialSubscription? _parseEmailForSubscription(gmail.Message message) {
    final subject = message.payload?.headers
        ?.firstWhere((header) => header.name == 'Subject', orElse: () => gmail.MessagePartHeader())
        .value ?? '';
    final from = message.payload?.headers
        ?.firstWhere((header) => header.name == 'From', orElse: () => gmail.MessagePartHeader())
        .value ?? '';
    final body = _getEmailBody(message);

    print('Parsing email - Subject: $subject, From: $from');

    // Check for common subscription-related keywords
    final subscriptionKeywords = ['subscription', 'billing', 'payment', 'renew', 'account'];
    final isSubscriptionRelated = subscriptionKeywords.any((keyword) =>
    subject.toLowerCase().contains(keyword) || body.toLowerCase().contains(keyword));

    if (isSubscriptionRelated) {
      // Extract potential service name (this is a simple example and might need refinement)
      final serviceName = _extractServiceName(from, subject);

      // Try to extract price (this is a simple example and might need refinement)
      final price = _extractPrice(body);

      // Assume monthly billing for this example
      const billingDate = Duration(days: 30);

      print('Found potential subscription: $serviceName, Price: $price');

      return PotentialSubscription(
        serviceName: serviceName,
        price: price,
        billingDate: billingDate,
        fromAddress: from,
        subject: subject,
      );
    }

    return null;
  }

  String _getEmailBody(gmail.Message message) {
    final parts = message.payload?.parts ?? [];
    final body = parts.firstWhere(
          (part) => part.mimeType == 'text/plain',
      orElse: () => gmail.MessagePart(),
    ).body?.data ?? '';
    return utf8.decode(base64Url.decode(body.replaceAll('-', '+').replaceAll('_', '/')));
  }

  String _extractServiceName(String from, String subject) {
    // This is a simple extraction and might need to be more sophisticated
    final fromParts = from.split('@');
    if (fromParts.length > 1) {
      return fromParts[1].split('.')[0];
    }
    // If we can't extract from the 'from' field, try the subject
    final words = subject.split(' ');
    return words.isNotEmpty ? words[0] : 'Unknown Service';
  }

  double _extractPrice(String body) {
    // This is a simple price extraction and might need to be more sophisticated
    final priceRegex = RegExp(r'\$\d+(\.\d{2})?');
    final match = priceRegex.firstMatch(body);
    if (match != null) {
      return double.parse(match.group(0)!.substring(1));
    }
    return 0.0;
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class PotentialSubscription {
  final String serviceName;
  final double price;
  final Duration billingDate;
  final String fromAddress;
  final String subject;

  const PotentialSubscription({
    required this.serviceName,
    required this.price,
    required this.billingDate,
    required this.fromAddress,
    required this.subject,
  });
}