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

  Future<List<Map<String, dynamic>>> fetchEmailsFromLastSixMonths({
    int limit = 100,
    Function(int processed, int total)? onProgress,
  }) async {
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
      int batchCount = 0;
      final int maxBatches = 10;
      int totalEmails = 0;

      while (batchCount < maxBatches) {
        final messages = await gmailApi.users.messages.list(
          'me',
          maxResults: 100,  // Request 100 emails at a time
          q: query,
          pageToken: pageToken,
        );

        if (messages.messages == null || messages.messages!.isEmpty) {
          break;  // No more emails to fetch
        }

        totalEmails += messages.messages!.length;
        final batch = await _fetchEmailBatch(gmailApi, messages.messages!);
        allEmails.addAll(batch);

        // Report progress
        if (onProgress != null) {
          onProgress(allEmails.length, totalEmails);
        }

        batchCount++;
        if (kDebugMode) {
          print('Fetched batch $batchCount of $maxBatches');
        }

        if (batchCount >= maxBatches || allEmails.length >= limit) {
          break;
        }

        pageToken = messages.nextPageToken;
        if (pageToken == null) {
          break;  // No more pages to fetch
        }
      }

      if (allEmails.length > limit) {
        allEmails = allEmails.sublist(0, limit);
      }

      if (kDebugMode) {
        print('Scan complete. Processed ${allEmails.length} emails.');
      }
      return allEmails;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching emails: $e');
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchEmailBatch(gmail.GmailApi gmailApi, List<gmail.Message> messages) async {
    final batch = await Future.wait(
        messages.map((message) => gmailApi.users.messages.get('me', message.id!))
    );
    return batch.map(_parseEmail).toList();
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