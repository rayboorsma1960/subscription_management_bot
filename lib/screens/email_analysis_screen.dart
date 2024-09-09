import 'package:flutter/material.dart';
import '../services/email_scanner_service.dart';
import '../services/gemini_service.dart';
import 'raw_email_screen.dart';

class EmailAnalysisScreen extends StatefulWidget {
  const EmailAnalysisScreen({Key? key}) : super(key: key);

  @override
  EmailAnalysisScreenState createState() => EmailAnalysisScreenState();
}

class EmailAnalysisScreenState extends State<EmailAnalysisScreen> {
  final EmailScannerService _emailScannerService = EmailScannerService();
  final GeminiService _geminiService = GeminiService('AIzaSyAOApzWL2G8uTtaY9z4rMHeIx6Jk7ZYx8Y');
  List<AnalysisItem> _analysisItems = [];
  List<Map<String, dynamic>> _emails = [];
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
      _emails.clear();
    });

    try {
      _emails = await _emailScannerService.fetchEmailsFromLastSixMonths(
        onProgress: (processed, total) {
          setState(() {
            _processedEmails = processed;
            _totalEmails = total;
          });
        },
      );

      if (_emails.isEmpty) {
        throw Exception('No emails found in the last 6 months');
      }

      final analysisResult = await _geminiService.analyzeEmails(_emails);

      _analysisItems = _parseAnalysis(analysisResult.analysis);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
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
          items.add(AnalysisItem(title: currentCategory, items: List.from(currentItems)));
          currentItems.clear();
        }
        currentCategory = line.replaceAll('*', '').trim();
      } else if (line.startsWith('*') && currentCategory.isNotEmpty) {
        currentItems.add(line.substring(1).trim());
      }
    }

    if (currentCategory.isNotEmpty) {
      items.add(AnalysisItem(title: currentCategory, items: currentItems));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Email Analysis'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Analysis'),
              Tab(text: 'All Emails'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAnalysisTab(),
            _buildAllEmailsWidget(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _fetchAndAnalyzeEmails,
          tooltip: 'Refresh Analysis',
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }

  Widget _buildAnalysisTab() {
    if (_isLoading) {
      return _buildLoadingWidget();
    } else if (_errorMessage.isNotEmpty) {
      return _buildErrorWidget();
    } else {
      return SingleChildScrollView(
        child: Column(
          children: [
            EmailOrganizationScore(score: _calculateOrganizationScore()),
            ..._analysisItems.map(_buildAnalysisItemWidget).toList(),
          ],
        ),
      );
    }
  }

  Widget _buildAnalysisItemWidget(AnalysisItem item) {
    return ExpandableListTile(item: item);
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text('Processing emails: $_processedEmails / $_totalEmails'),
          const SizedBox(height: 10),
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

  Widget _buildAllEmailsWidget() {
    return ListView.builder(
      itemCount: _emails.length,
      itemBuilder: (context, index) {
        final email = _emails[index];
        return ListTile(
          title: Text(email['subject'] ?? 'No Subject'),
          subtitle: Text(email['from'] ?? 'Unknown Sender'),
          onTap: () => _navigateToRawEmail(email['id']),
        );
      },
    );
  }

  void _navigateToRawEmail(String emailId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RawEmailScreen(
          emailId: emailId,
          emailScannerService: _emailScannerService,
        ),
      ),
    );
  }

  double _calculateOrganizationScore() {
    // Placeholder implementation - replace with actual scoring logic
    int readEmails = _emails.where((email) => email['read'] == true).length;
    double readPercentage = readEmails / _emails.length;

    // This is a very basic scoring method. You should expand this based on more factors.
    return readPercentage * 100;
  }
}

class AnalysisItem {
  final String title;
  final List<String> items;

  AnalysisItem({required this.title, required this.items});
}

class ExpandableListTile extends StatefulWidget {
  final AnalysisItem item;

  const ExpandableListTile({
    Key? key,
    required this.item,
  }) : super(key: key);

  @override
  ExpandableListTileState createState() => ExpandableListTileState();
}

class ExpandableListTileState extends State<ExpandableListTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text(widget.item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.item.items.map((String detail) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $detail'),
              )).toList(),
            ),
          ),
        const Divider(),
      ],
    );
  }
}

class EmailOrganizationScore extends StatelessWidget {
  final double score;

  const EmailOrganizationScore({Key? key, required this.score}) : super(key: key);

  String _getScoreDescription(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Fair';
    return 'Needs Improvement';
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.lightGreen;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Email Organization Score',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score)),
            ),
            const SizedBox(height: 16),
            Text(
              score.toStringAsFixed(0),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: _getScoreColor(score),
              ),
            ),
            Text(
              _getScoreDescription(score),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}