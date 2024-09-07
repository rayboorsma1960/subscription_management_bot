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
        "Body: ${email['body'].substring(0, min(100, email['body'].length))}..."
    ).join('\n\n');

    return """
    Analyze the following 6 months of emails and provide insights about the user's subscriptions, spending habits, and any other notable patterns or information. Focus on:

    1. Identifying recurring subscriptions and their costs
    2. Total monthly spending on subscriptions
    3. Trends in subscription usage or changes
    4. Potential areas for cost-saving
    5. Any unusual or notable spending patterns

    Here are the emails:

    $emailSummaries

    Please provide a detailed analysis with specific numbers and insights.
    """;
  }

  int min(int a, int b) => (a < b) ? a : b;
}