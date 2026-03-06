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
    }
    
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Journal Entry'),
        automaticallyImplyLeading: false, // For bottom nav structure
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How are you feeling right now?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Expanded(
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
            ],
          ),
        ),
      ),
    );
  }
}
