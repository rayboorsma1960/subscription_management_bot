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
  List<AnalysisItem> _analysisItems = [];
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
      _analysisItems.clear();
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

      print("Emails fetched: ${emails.length}");

      final analysis = await _geminiService.analyzeEmails(emails);
      print("Raw analysis: $analysis");

      _analysisItems = _parseAnalysis(analysis);
      print("Parsed analysis items: ${_analysisItems.length}");

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error occurred: $e");
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<AnalysisItem> _parseAnalysis(String analysis) {
    List<AnalysisItem> items = [];
    List<String> lines = analysis.split('\n');
    String currentCategory = '';
    List<String> currentItems = [];

    for (String line in lines) {
      line = line.trim();
      if (line.startsWith('**') && line.endsWith('**')) {
        if (currentCategory.isNotEmpty) {
          print("Adding category: $currentCategory with ${currentItems.length} items");
          items.add(AnalysisItem(title: currentCategory, items: List.from(currentItems)));
          currentItems.clear();
        }
        currentCategory = line.replaceAll('*', '').trim();
      } else if (line.isNotEmpty && currentCategory.isNotEmpty) {
        // Remove bullet points if present
        if (line.startsWith('*')) {
          line = line.substring(1).trim();
        }
        currentItems.add(line);
      }
    }

    if (currentCategory.isNotEmpty) {
      print("Adding final category: $currentCategory with ${currentItems.length} items");
      items.add(AnalysisItem(title: currentCategory, items: currentItems));
    }

    return items;
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
    if (_analysisItems.isEmpty) {
      return Center(child: Text('No analysis data available.'));
    }
    return ListView.builder(
      itemCount: _analysisItems.length,
      itemBuilder: (context, index) {
        return ExpandableListTile(item: _analysisItems[index]);
      },
    );
  }
}

class AnalysisItem {
  final String title;
  final List<String> items;

  AnalysisItem({required this.title, required this.items});
}

class ExpandableListTile extends StatefulWidget {
  final AnalysisItem item;

  const ExpandableListTile({Key? key, required this.item}) : super(key: key);

  @override
  _ExpandableListTileState createState() => _ExpandableListTileState();
}

class _ExpandableListTileState extends State<ExpandableListTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text(widget.item.title, style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${widget.item.items.length} items'),
          trailing: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
        ),
        if (_isExpanded)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.item.items.map((String detail) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(detail)),
                  ],
                ),
              )).toList(),
            ),
          ),
        Divider(),
      ],
    );
  }
}