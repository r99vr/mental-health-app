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
  final List<String> _phq9Questions = [
    "Little interest or pleasure in doing things",
    "Feeling down, depressed, or hopeless",
    "Trouble falling or staying asleep, or sleeping too much",
    "Feeling tired or having little energy",
    "Poor appetite or overeating",
    "Feeling bad about yourself or that you are a failure",
    "Trouble concentrating on things, such as reading or watching TV",
    "Moving or speaking slowly, or being fidgety or restless",
    "Thoughts that you would be better off dead or of hurting yourself",
  ];

  final List<String> _gad7Questions = [
    "Feeling nervous, anxious, or on edge",
    "Not being able to stop or control worrying",
    "Worrying too much about different things",
    "Trouble relaxing",
    "Being so restless that it is hard to sit still",
    "Becoming easily annoyed or irritable",
    "Feeling afraid as if something awful might happen",
  ];

  List<String> get _questions => _selectedTest == 'PHQ-9' ? _phq9Questions : _gad7Questions;

  Map<int, int> _answers = {};
  bool _isSaving = false;
  bool _testSelected = false;
  String _selectedTest = '';

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
        scaleType: _selectedTest,
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

  Widget _buildSelectionScreen() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Assessment',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the test you want to take',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildTestCard(
                  'PHQ-9',
                  Icons.mood,
                  Colors.blue.shade100,
                  Colors.blue.shade800,
                  'Depression screening',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTestCard(
                  'GAD-7',
                  Icons.psychology,
                  Colors.green.shade100,
                  Colors.green.shade800,
                  'Anxiety screening',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(String testName, IconData icon, Color bgColor, Color iconColor, String subtitle) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTest = testName;
          _testSelected = true;
          _answers.clear();
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: iconColor),
            const SizedBox(height: 16),
            Text(
              testName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionsScreen() {
    return SingleChildScrollView(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_testSelected ? '$_selectedTest Assessment' : 'Self Assessment'),
        automaticallyImplyLeading: false,
        leading: _testSelected
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _testSelected = false;
                    _selectedTest = '';
                    _answers.clear();
                  });
                },
              )
            : null,
      ),
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: SafeArea(
          child: _testSelected ? _buildQuestionsScreen() : _buildSelectionScreen(),
        ),
      ),
    );
  }
}
