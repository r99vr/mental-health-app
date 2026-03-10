import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../database/db_helper.dart';
import '../models/journal_entry.dart';
import '../models/nlp_result.dart';
import 'dart:math';

class JournalScreen extends StatefulWidget {
  const JournalScreen({Key? key}) : super(key: key);

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _textController = TextEditingController();
  bool _isSaving = false;
  List<JournalEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null) {
      final results = await DatabaseHelper.instance.getUserJournalEntries(user.userID!);
      if (results.isNotEmpty) {
        setState(() {
          _entries = results;
        });
        return;
      }
    }
    // Fallback: mock data when database is empty or user is null
    setState(() {
      _entries = [
        JournalEntry(userID: 1, text: "I had a really good day today, feeling happy and productive", date: "2026-03-08T10:00:00"),
        JournalEntry(userID: 1, text: "Feeling a bit anxious about my exams, hard to focus", date: "2026-03-09T14:00:00"),
        JournalEntry(userID: 1, text: "Tired and stressed, everything feels overwhelming", date: "2026-03-10T09:00:00"),
      ];
    });
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return isoDate;
    }
  }

  void _saveEntry() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    
    if (user != null) {
      final now = DateTime.now().toIso8601String();
      final entry = JournalEntry(
        userID: user.userID!,
        text: text,
        date: now,
      );
      
      final savedEntry = await DatabaseHelper.instance.createJournalEntry(entry);

      // MOCK NLP Result for demonstration until TFLite model is integrated
      final mockEmotions = ['Joy', 'Sadness', 'Anxiety', 'Neutral'];
      final mockEmotion = mockEmotions[Random().nextInt(mockEmotions.length)];
      
      await DatabaseHelper.instance.createNLPResult(NLPResult(
        entryID: savedEntry.entryID!,
        emotion: mockEmotion,
        confidence: 0.75 + (Random().nextDouble() * 0.2), // 75% - 95%
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry saved successfully!')),
      );
      _textController.clear();
      _loadEntries(); // Reload entries after saving
    }
    
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Journal Entry'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'How are you feeling right now?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 150,
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText: 'Write your thoughts here...',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveEntry,
                    icon: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(_isSaving ? 'Saving...' : 'Save Entry'),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Past Entries',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (_entries.isEmpty)
                  const Text('No entries yet.')
                else
                  ...List.generate(_entries.length, (index) {
                    final entry = _entries[index];
                    final preview = entry.text.length > 60
                        ? '${entry.text.substring(0, 60)}...'
                        : entry.text;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: Icon(Icons.book, color: Colors.blue.shade700),
                        ),
                        title: Text(
                          preview,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          _formatDate(entry.date),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
