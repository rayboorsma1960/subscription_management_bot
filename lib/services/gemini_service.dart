import 'package:http/http.dart' as http;
import 'dart:convert';

class GeminiService {
  final String apiKey;
  final String apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  GeminiService(this.apiKey);

  Future<String> analyzeEmails(List<Map<String, dynamic>> emails) async {
    try {
      final prompt = _createPrompt(emails);
      final response = await http.post(
        Uri.parse('$apiEndpoint?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          },
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['candidates'][0]['content']['parts'][0]['text'];
      } else {
        throw Exception('Failed to analyze emails: ${response.body}');
      }
    } catch (e) {
      print('Error in analyzeEmails: $e');
      rethrow;
    }
  }

  String _createPrompt(List<Map<String, dynamic>> emails) {
    final emailSummaries = emails.map((email) =>
    "Subject: ${email['subject']}\n"
        "From: ${email['from']}\n"
        "Date: ${email['date']}\n"
        "Body: ${email['body'].substring(0, min(200, email['body'].length))}..."
    ).join('\n\n---\n\n');

    return """
    Analyze the following 10 emails and provide insights about their content, themes, and any notable patterns or information. Consider the following aspects:

    1. Common topics or themes across the emails
    2. Types of senders (e.g., personal contacts, businesses, newsletters)
    3. Any recurring events or important dates mentioned
    4. General tone or sentiment of the emails
    5. Any action items or important information that stands out

    Here are the emails:

    $emailSummaries

    Please provide a detailed analysis with specific observations and insights.
    """;
  }

  int min(int a, int b) => (a < b) ? a : b;
}