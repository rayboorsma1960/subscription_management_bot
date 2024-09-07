import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart' show kDebugMode;

class EmailScannerService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const [
      'email',
      'https://www.googleapis.com/auth/gmail.readonly',
    ],
  );

  Future<List<Map<String, dynamic>>> fetchSixMonthsEmails() async {
    try {
      if (kDebugMode) {
        print('Starting email scan for the last 6 months');
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

      // Set date range to last 6 months
      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
      final query = 'after:${sixMonthsAgo.year}-${sixMonthsAgo.month.toString().padLeft(2, '0')}-${sixMonthsAgo.day.toString().padLeft(2, '0')}';

      List<Map<String, dynamic>> allEmails = [];
      String? pageToken;
      int totalProcessed = 0;
      const maxToProcess = 1000; // Increased to accommodate 6 months of emails

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
            allEmails.add(_parseEmail(fullMessage));

            totalProcessed++;
            if (totalProcessed >= maxToProcess) break;
          }
        }

        pageToken = messages.nextPageToken;
      } while (pageToken != null && totalProcessed < maxToProcess);

      if (kDebugMode) {
        print('Scan complete. Processed $totalProcessed emails.');
      }
      return allEmails;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching emails: $e');
      }
      return [];
    }
  }

  Map<String, dynamic> _parseEmail(gmail.Message message) {
    final subject = message.payload?.headers
        ?.firstWhere((header) => header.name == 'Subject', orElse: () => gmail.MessagePartHeader())
        .value ?? '';
    final from = message.payload?.headers
        ?.firstWhere((header) => header.name == 'From', orElse: () => gmail.MessagePartHeader())
        .value ?? '';
    final date = DateTime.fromMillisecondsSinceEpoch(int.parse(message.internalDate ?? '0'));
    final body = _getEmailBody(message);

    return {
      'subject': subject,
      'from': from,
      'date': date.toIso8601String(),
      'body': body,
    };
  }

  String _getEmailBody(gmail.Message message) {
    if (message.payload == null) return '';

    String body = _getBodyFromPart(message.payload!);

    if (body.isEmpty && message.payload!.parts != null) {
      for (var part in message.payload!.parts!) {
        body = _getBodyFromPart(part);
        if (body.isNotEmpty) break;
      }
    }

    body = _decodeBody(body);

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
      return body;
    }
  }

  String _extractTextFromHtml(String htmlString) {
    final document = html_parser.parse(htmlString);
    final String parsedString = document.body?.text ?? '';
    return parsedString;
  }

  String _removeEmailAddresses(String text) {
    final emailPattern = RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w+\b');
    return text.replaceAll(emailPattern, '');
  }

  String? _extractEmailAddress(String from) {
    final match = RegExp(r'<(.+)>').firstMatch(from);
    return match?.group(1);
  }

  String _extractKeywordFromSubject(String subject) {
    final words = subject.split(' ');
    return words.firstWhere(
          (word) => !['re:', 'fwd:', 'fw:'].contains(word.toLowerCase()),
      orElse: () => '',
    );
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