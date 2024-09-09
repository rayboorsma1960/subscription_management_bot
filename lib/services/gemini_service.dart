import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class AnalysisResult {
  final String analysis;

  AnalysisResult(this.analysis);
}

class GeminiService {
  final String apiKey;
  final String apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';
  final int maxRetries = 3;
  final int retryDelay = 2; // seconds

  GeminiService(this.apiKey);

  Future<AnalysisResult> analyzeEmails(List<Map<String, dynamic>> emails) async {
    int retries = 0;
    while (retries < maxRetries) {
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
          final analysis = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
          return AnalysisResult(analysis);
        } else if (response.statusCode == 500) {
          retries++;
          if (retries < maxRetries) {
            await Future.delayed(Duration(seconds: retryDelay * retries));
            continue;
          }
        }
        throw Exception('Failed to analyze emails: ${response.body}');
      } catch (e) {
        retries++;
        if (retries >= maxRetries) {
          throw Exception('Error in analyzeEmails after $maxRetries attempts: $e');
        }
        await Future.delayed(Duration(seconds: retryDelay * retries));
      }
    }
    throw Exception('Unexpected error in analyzeEmails');
  }

  String _createPrompt(List<Map<String, dynamic>> emails) {
    final emailSummaries = emails.asMap().entries.map((entry) =>
    "Email ${entry.key + 1}:\n"
        "Subject: ${entry.value['subject']}\n"
        "From: ${entry.value['from']}\n"
        "Date: ${entry.value['date']}\n"
        "Snippet: ${entry.value['body'].substring(0, min(100, entry.value['body'].length))}..."
    ).join('\n\n---\n\n');

    return """
    Analyze the following emails and provide insights about their content, themes, and any notable patterns or information. Consider the following aspects:

    1. Common topics or themes across the emails
    2. Types of senders (e.g., personal contacts, businesses, newsletters)
    3. Any recurring events or important dates mentioned
    4. General tone or sentiment of the emails
    5. Any action items or important information that stands out
    6. Financial matters (e.g., bills, invoices, payments, subscriptions, financial advice)

    Here are the emails:

    $emailSummaries

    Please provide a detailed analysis with specific observations and insights. Format your response as follows:

    **Common Topics or Themes**
    * Topic 1
    * Topic 2
    ...

    **Types of Senders**
    * Sender type 1
    * Sender type 2
    ...

    **Recurring Events or Important Dates**
    * Event/Date 1
    * Event/Date 2
    ...

    **General Tone or Sentiment of the Emails**
    * Sentiment 1
    * Sentiment 2
    ...

    **Action Items or Important Information**
    * Action item 1
    * Action item 2
    ...

    **Financial Matters**
    * Financial insight 1
    * Financial insight 2
    ...
    """;
  }

  int min(int a, int b) => (a < b) ? a : b;
}