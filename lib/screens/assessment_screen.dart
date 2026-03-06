import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../database/db_helper.dart';
import '../models/assessment.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({Key? key}) : super(key: key);

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  // A mock list of questions commonly found in tools like PHQ-9
  final List<String> _questions = [
    "Little interest or pleasure in doing things",
    "Feeling down, depressed, or hopeless",
    "Trouble falling or staying asleep, or sleeping too much",
    "Feeling tired or having little energy",
  ];

  Map<int, int> _answers = {};
  bool _isSaving = false;

  void _submitAssessment() async {
    if (_answers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    
    if (user != null) {
      int totalScore = _answers.values.fold(0, (sum, val) => sum + val);
      final now = DateTime.now().toIso8601String();
      
      final assessment = Assessment(
        userID: user.userID!,
        scaleType: 'PHQ-9 (Short Mock)',
        score: totalScore,
        date: now,
      );

      await DatabaseHelper.instance.createAssessment(assessment);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Assessment Complete'),
          content: Text('Your total score is $totalScore.\n\n0-4: Minimal\n5-9: Mild\n10-14: Moderate\n15-27: Severe\n\nRemember, this app is for tracking and not medical diagnosis. Please consult a professional if needed.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _answers.clear());
              },
              child: const Text('OK'),
            )
          ],
        ),
      );
    }
    
    setState(() => _isSaving = false);
  }

  Widget _buildQuestionCard(int index, String question) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. $question',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...List.generate(4, (optionIndex) {
              final labels = ['Not at all', 'Several days', 'More than half the days', 'Nearly every day'];
              return RadioListTile<int>(
                title: Text(labels[optionIndex]),
                value: optionIndex,
                groupValue: _answers[index],
                onChanged: (val) {
                  setState(() {
                    _answers[index] = val!;
                  });
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Self Assessment'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Over the last 2 weeks, how often have you been bothered by any of the following problems?',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              ...List.generate(_questions.length, (index) {
                return _buildQuestionCard(index, _questions[index]);
              }),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submitAssessment,
                  child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Assessment'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
