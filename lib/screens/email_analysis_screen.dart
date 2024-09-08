import 'package:flutter/material.dart';
import '../services/email_scanner_service.dart';
import '../services/gemini_service.dart';

class EmailAnalysisScreen extends StatefulWidget {
  const EmailAnalysisScreen({Key? key}) : super(key: key);

  @override
  _EmailAnalysisScreenState createState() => _EmailAnalysisScreenState();
}

class _EmailAnalysisScreenState extends State<EmailAnalysisScreen> {
  final EmailScannerService _emailScannerService = EmailScannerService();
  final GeminiService _geminiService = GeminiService('AIzaSyAOApzWL2G8uTtaY9z4rMHeIx6Jk7ZYx8Y');
  String _analysis = '';
  bool _isLoading = false;
  String _errorMessage = '';
  int _processedEmails = 0;
  int _totalEmails = 0;

  @override
  void initState() {
    super.initState();
    _fetchAndAnalyzeEmails();
  }

  Future<void> _fetchAndAnalyzeEmails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _processedEmails = 0;
      _totalEmails = 0;
    });

    try {
      final emails = await _emailScannerService.fetchEmailsFromLastSixMonths(
        onProgress: (processed, total) {
          setState(() {
            _processedEmails = processed;
            _totalEmails = total;
          });
        },
      );

      if (emails.isEmpty) {
        throw Exception('No emails found in the last 6 months');
      }

      final analysis = await _geminiService.analyzeEmails(emails);

      setState(() {
        _analysis = analysis;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Analysis Results'),
      ),
      body: _isLoading
          ? _buildLoadingWidget()
          : _errorMessage.isNotEmpty
          ? _buildErrorWidget()
          : _buildAnalysisWidget(),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchAndAnalyzeEmails,
        child: const Icon(Icons.refresh),
        tooltip: 'Refresh Analysis',
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Processing emails: $_processedEmails / $_totalEmails'),
          SizedBox(height: 10),
          LinearProgressIndicator(
            value: _totalEmails > 0 ? _processedEmails / _totalEmails : 0,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red[300]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchAndAnalyzeEmails,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisWidget() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Text(_analysis),
    );
  }
}