import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'dart:convert';
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
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('Sign-in failed');
      }

      final headers = await account.authHeaders;
      final client = GoogleAuthClient(headers);
      final gmailApi = gmail.GmailApi(client);

      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
      final query = 'after:${sixMonthsAgo.year}-${sixMonthsAgo.month.toString().padLeft(2, '0')}-${sixMonthsAgo.day.toString().padLeft(2, '0')}';

      List<Map<String, dynamic>> allEmails = [];
      String? pageToken;
      int totalEmails = 0;

      while (allEmails.length < limit) {
        final messages = await gmailApi.users.messages.list(
          'me',
          maxResults: 100,
          q: query,
          pageToken: pageToken,
        );

        if (messages.messages == null || messages.messages!.isEmpty) {
          break;
        }

        totalEmails += messages.messages!.length;
        final batch = await _fetchEmailBatch(gmailApi, messages.messages!);
        allEmails.addAll(batch);

        if (onProgress != null) {
          onProgress(allEmails.length, totalEmails);
        }

        if (messages.nextPageToken == null) {
          break;
        }
        pageToken = messages.nextPageToken;
      }

      return allEmails.take(limit).toList();
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
    final headers = message.payload?.headers ?? [];
    final subject = headers.firstWhere((header) => header.name == 'Subject', orElse: () => gmail.MessagePartHeader()).value ?? '';
    final from = headers.firstWhere((header) => header.name == 'From', orElse: () => gmail.MessagePartHeader()).value ?? '';
    final date = DateTime.fromMillisecondsSinceEpoch(int.parse(message.internalDate ?? '0'));
    final body = _getEmailBody(message);

    return {
      'id': message.id,
      'subject': subject,
      'from': from,
      'date': date.toIso8601String(),
      'body': body,
    };
  }

  String _getEmailBody(gmail.Message message) {
    if (message.payload == null) return '';

    String body = _getBodyFromPart(message.payload!);
    body = _decodeBody(body);

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

  Future<String> fetchRawEmail(String emailId) async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('Sign-in failed');
      }

      final headers = await account.authHeaders;
      final client = GoogleAuthClient(headers);
      final gmailApi = gmail.GmailApi(client);

      final message = await gmailApi.users.messages.get('me', emailId, format: 'raw');
      if (message.raw == null) {
        return 'No raw email content available';
      }

      return utf8.decode(base64Url.decode(message.raw!));
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching raw email: $e');
      }
      return 'Error fetching raw email: $e';
    }
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