import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import '../services/email_scanner_service.dart';

class SelectEmailScreen extends StatefulWidget {
  const SelectEmailScreen({Key? key}) : super(key: key);

  @override
  _SelectEmailScreenState createState() => _SelectEmailScreenState();
}

class _SelectEmailScreenState extends State<SelectEmailScreen> {
  final EmailScannerService _emailScannerService = EmailScannerService();
  List<gmail.Message> _emails = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchEmails();
  }

  Future<void> _fetchEmails() async {
    try {
      final emails = await _emailScannerService.fetchRecentEmails();
      setState(() {
        _emails = emails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching emails: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchEmails(String query) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final emails = await _emailScannerService.searchEmails(query);
      setState(() {
        _emails = emails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching emails: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Subscription Email'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search emails...',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      _searchEmails(_searchController.text);
                    }
                  },
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _searchEmails(value);
                }
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: _emails.length,
              itemBuilder: (context, index) {
                final email = _emails[index];
                final subject = email.payload?.headers
                    ?.firstWhere((header) => header.name == 'Subject',
                    orElse: () => gmail.MessagePartHeader())
                    .value ?? 'No Subject';
                final from = email.payload?.headers
                    ?.firstWhere((header) => header.name == 'From',
                    orElse: () => gmail.MessagePartHeader())
                    .value ?? 'Unknown Sender';
                return ListTile(
                  title: Text(subject),
                  subtitle: Text(from),
                  onTap: () {
                    Navigator.pop(context, email);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}