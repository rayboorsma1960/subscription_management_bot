import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:html/parser.dart' as htmlparser;
import 'package:html/dom.dart';
import '../models/subscription.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class EmailScannerService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/gmail.readonly',
    ],
  );

  Future<Map<Subscription, List<SubscriptionEmail>>> scanEmailsForSubscriptions(List<Subscription> subscriptions) async {
    try {
      if (kDebugMode) {
        print('Starting email scan for existing subscriptions');
      }
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        if (kDebugMode) {
          print('Sign-in failed or was cancelled by the user');
        }
        throw Exception('Sign-in failed');
      }
      if (kDebugMode) {
        print('Successfully signed in as ${account.email}');
      }

      final headers = await account.authHeaders;
      final client = GoogleAuthClient(headers);

      if (kDebugMode) {
        print('Creating Gmail API client');
      }
      final gmailApi = gmail.GmailApi(client);

      if (kDebugMode) {
        print('Fetching messages from the last two months');
      }
      final subscriptionEmailsMap = <Subscription, List<SubscriptionEmail>>{};
      for (var subscription in subscriptions) {
        subscriptionEmailsMap[subscription] = [];
      }

      // Set date range to last 2 months
      final twoMonthsAgo = DateTime.now().subtract(Duration(days: 60));
      final query = 'after:${twoMonthsAgo.year}/${twoMonthsAgo.month.toString().padLeft(2, '0')}/${twoMonthsAgo.day.toString().padLeft(2, '0')}';

      String? pageToken;
      int totalProcessed = 0;
      const maxToProcess = 500;

      do {
        final messages = await gmailApi.users.messages.list(
          'me',
          maxResults: 100,
          q: query,
          pageToken: pageToken,
        );

        if (messages.messages != null) {
          for (var message in messages.messages!) {
            if (kDebugMode) {
              print('Processing message ${message.id}');
            }
            final fullMessage = await gmailApi.users.messages.get('me', message.id!);
            final matchedSubscription = _matchEmailToSubscription(fullMessage, subscriptions);
            if (matchedSubscription != null) {
              subscriptionEmailsMap[matchedSubscription.subscription]?.add(matchedSubscription);
              if (kDebugMode) {
                print('Found email for subscription: ${matchedSubscription.subscription.name}');
              }
            }

            totalProcessed++;
            if (totalProcessed >= maxToProcess) break;
          }
        }

        pageToken = messages.nextPageToken;
      } while (pageToken != null && totalProcessed < maxToProcess);

      if (kDebugMode) {
        print('Scan complete. Processed $totalProcessed emails. Found emails for ${subscriptionEmailsMap.values.where((emails) => emails.isNotEmpty).length} subscriptions');
      }
      return subscriptionEmailsMap;
    } catch (e) {
      if (kDebugMode) {
        print('Error scanning emails: $e');
      }
      return {};
    }
  }

  Future<List<gmail.Message>> fetchRecentEmails() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('Sign-in failed');
      }

      final headers = await account.authHeaders;
      final client = GoogleAuthClient(headers);
      final gmailApi = gmail.GmailApi(client);

      final messages = await gmailApi.users.messages.list(
        'me',
        maxResults: 20,  // Adjust this number as needed
      );

      if (messages.messages == null) {
        return [];
      }

      final fullMessages = await Future.wait(
          messages.messages!.map((message) => gmailApi.users.messages.get('me', message.id!))
      );

      return fullMessages;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching recent emails: $e');
      }
      return [];
    }
  }

  Future<List<gmail.Message>> searchEmails(String searchQuery) async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('Sign-in failed');
      }

      final headers = await account.authHeaders;
      final client = GoogleAuthClient(headers);
      final gmailApi = gmail.GmailApi(client);

      // Encode the search query to ensure it's properly formatted for the API
      final encodedQuery = Uri.encodeComponent(searchQuery);

      final messages = await gmailApi.users.messages.list(
        'me',
        maxResults: 20,  // Adjust this number as needed
        q: encodedQuery,
      );

      if (messages.messages == null) {
        return [];
      }

      final fullMessages = await Future.wait(
          messages.messages!.map((message) => gmailApi.users.messages.get('me', message.id!))
      );

      return fullMessages;
    } catch (e) {
      if (kDebugMode) {
        print('Error searching emails: $e');
      }
      return [];
    }
  }

  // New public method to get email body
  String getEmailBody(gmail.Message message) {
    return _getEmailBody(message);
  }

  SubscriptionEmail? _matchEmailToSubscription(gmail.Message message, List<Subscription> subscriptions) {
    final subject = message.payload?.headers
        ?.firstWhere((header) => header.name == 'Subject', orElse: () => gmail.MessagePartHeader())
        .value ?? '';
    final from = message.payload?.headers
        ?.firstWhere((header) => header.name == 'From', orElse: () => gmail.MessagePartHeader())
        .value ?? '';
    final body = _getEmailBody(message);

    // Remove email addresses from the text to avoid false matches
    final cleanSubject = _removeEmailAddresses(subject);
    final cleanBody = _removeEmailAddresses(body);

    for (var subscription in subscriptions) {
      if (_isSubscriptionEmail(subscription, cleanSubject, cleanBody, from)) {
        return SubscriptionEmail(
          subscription: subscription,
          subject: subject,
          from: from,
          date: DateTime.fromMillisecondsSinceEpoch(int.parse(message.internalDate ?? '0')),
          snippet: message.snippet ?? '',
          body: body,
        );
      }
    }

    return null;
  }

  String _getEmailBody(gmail.Message message) {
    if (message.payload == null) return '';

    // First, try to get the body from the payload
    String body = _getBodyFromPart(message.payload!);

    // If the body is still empty, try to get it from the parts
    if (body.isEmpty && message.payload!.parts != null) {
      for (var part in message.payload!.parts!) {
        body = _getBodyFromPart(part);
        if (body.isNotEmpty) break;
      }
    }

    // Decode the body
    body = _decodeBody(body);

    // If the body is HTML, extract the text
    if (body.toLowerCase().contains('<html')) {
      body = _extractTextFromHtml(body);
    }

    return body;
  }

  String _getBodyFromPart(gmail.MessagePart part) {
    if (part.body?.data != null) {
      return part.body!.data!;
    } else if (part.parts != null) {
      for (var subPart in part.parts!) {
        final body = _getBodyFromPart(subPart);
        if (body.isNotEmpty) return body;
      }
    }
    return '';
  }

  String _decodeBody(String body) {
    try {
      return utf8.decode(base64Url.decode(body.replaceAll('-', '+').replaceAll('_', '/')));
    } catch (e) {
      if (kDebugMode) {
        print('Error decoding body: $e');
      }
      return body; // Return original if decoding fails
    }
  }

  String _extractTextFromHtml(String htmlString) {
    final document = htmlparser.parse(htmlString);
    final String parsedString = document.body?.text ?? '';
    return parsedString;
  }

  bool _isSubscriptionEmail(Subscription subscription, String subject, String body, String from) {
    final nameLower = subscription.name.toLowerCase();
    final subjectLower = subject.toLowerCase();
    final bodyLower = body.toLowerCase();
    final fromLower = from.toLowerCase();

    // Check for required keywords
    final requiredKeywords = ['bill', 'account', 'balance', 'payment'];

    // Check if the subscription name is mentioned (ignoring case)
    bool containsSubscriptionName = subjectLower.contains(nameLower) ||
        bodyLower.contains(nameLower) ||
        fromLower.contains(nameLower);

    // Check if at least one of the required keywords is present
    bool containsRequiredKeyword = requiredKeywords.any((keyword) =>
    subjectLower.contains(keyword) || bodyLower.contains(keyword));

    // Return true only if both conditions are met
    return containsSubscriptionName && containsRequiredKeyword;
  }

  String _removeEmailAddresses(String text) {
    // This regex pattern matches most email address formats
    final emailPattern = RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w+\b');
    return text.replaceAll(emailPattern, '');
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

class SubscriptionEmail {
  final Subscription subscription;
  final String subject;
  final String from;
  final DateTime date;
  final String snippet;
  final String body;

  SubscriptionEmail({
    required this.subscription,
    required this.subject,
    required this.from,
    required this.date,
    required this.snippet,
    required this.body,
  });
}