import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../database/db_helper.dart';
import '../models/assessment.dart';
import 'chat_screen.dart';
import 'assessment_history_screen.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({Key? key}) : super(key: key);

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  // ── Question banks ──────────────────────────────────────────────────
  final List<String> _phq9Questions = [
    "Little interest or pleasure in doing things",
    "Feeling down, depressed, or hopeless",
    "Trouble falling or staying asleep, or sleeping too much",
    "Feeling tired or having little energy",
    "Poor appetite or overeating",
    "Feeling bad about yourself — or that you are a failure or have let yourself or your family down",
    "Trouble concentrating on things, such as reading the newspaper or watching television",
    "Moving or speaking so slowly that other people could have noticed — or being so fidgety or restless that you have been moving around a lot more than usual",
    "Thoughts that you would be better off dead, or thoughts of hurting yourself in some way",
  ];

  final List<String> _gad7Questions = [
    "Feeling nervous, anxious, or on edge",
    "Not being able to stop or control worrying",
    "Worrying too much about different things",
    "Trouble relaxing",
    "Being so restless that it is hard to sit still",
    "Becoming easily annoyed or irritable",
    "Feeling afraid, as if something awful might happen",
  ];

  List<String> get _questions =>
      _selectedTest == 'PHQ-9' ? _phq9Questions : _gad7Questions;

  // ── Answer options ──────────────────────────────────────────────────
  final List<Map<String, dynamic>> _options = [
    {'label': 'Not at all', 'score': 0},
    {'label': 'Several days', 'score': 1},
    {'label': 'More than half the days', 'score': 2},
    {'label': 'Nearly every day', 'score': 3},
  ];

  // ── State variables ─────────────────────────────────────────────────
  bool _testSelected = false;
  String _selectedTest = '';

  int _currentPage = 0;
  late List<int> _answers;
  late PageController _pageController;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _answers = [];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────
  void _selectTest(String testName) {
    setState(() {
      _selectedTest = testName;
      _testSelected = true;
      _currentPage = 0;
      _showResults = false;
      _answers = List.filled(
        testName == 'PHQ-9' ? 9 : 7,
        -1,
      );
      _pageController = PageController();
    });
  }

  void _onOptionSelected(int questionIndex, int score) {
    setState(() {
      _answers[questionIndex] = score;
    });

    // Crisis check: PHQ-9 question 9 (index 8) — self-harm
    if (_selectedTest == 'PHQ-9' && questionIndex == 8 && score > 0) {
      // Show crisis dialog immediately, auto-advance happens after dialog closes
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        _showCrisisDialog();
      });
      return;
    }

    // Auto-advance after 400ms
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (questionIndex < _questions.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ── Crisis Dialog (Step 2) ──────────────────────────────────────────
  void _showCrisisDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          title: const Row(
            children: [
              Text('⚠️', style: TextStyle(fontSize: 28)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'We noticed something important',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your answer suggests you may be having thoughts of '
                'self-harm. Please know you are not alone. '
                'Reach out for help immediately.',
                style: TextStyle(fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 20),
              // Crisis numbers card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crisis Helplines',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPhoneRow(
                      '🇸🇦',
                      'KSA — Ministry of Health',
                      '920033360',
                    ),
                    const SizedBox(height: 10),
                    _buildPhoneRow(
                      '🌍',
                      'International — Suicide & Crisis Lifeline',
                      '988',
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // "Get Help Now" button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // In production: launch phone dialer with url_launcher
                },
                icon: const Icon(Icons.phone, size: 18),
                label: const Text('Get Help Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // "I'm Safe, Continue" button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Continue the test — no auto-advance since this is the last question,
                  // user can tap "See Results" manually.
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("I'm Safe, Continue"),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPhoneRow(String flag, String label, String number) {
    return Row(
      children: [
        Text(flag, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              Text(
                number,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _goToResults() async {
    setState(() {
      _showResults = true;
    });

    // Save result to database
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null) {
      final totalScore = _answers.reduce((a, b) => a + b);
      final now = DateTime.now().toIso8601String();
      final assessment = Assessment(
        userID: user.userID!,
        scaleType: _selectedTest,
        score: totalScore,
        date: now,
      );
      await DatabaseHelper.instance.createAssessment(assessment);
    }
  }

  void _resetTest() {
    setState(() {
      _testSelected = false;
      _selectedTest = '';
      _showResults = false;
      _answers = [];
      _currentPage = 0;
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _testSelected
              ? (_showResults ? '$_selectedTest Results' : '$_selectedTest Assessment')
              : 'Self Assessment',
        ),
        automaticallyImplyLeading: false,
        leading: _testSelected
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _resetTest,
              )
            : null,
      ),
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: SafeArea(
          child: _testSelected
              ? (_showResults ? _buildResultsPage() : _buildPageView())
              : _buildSelectionScreen(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  TEST SELECTION SCREEN (kept from original)
  // ══════════════════════════════════════════════════════════════════════

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
          const SizedBox(height: 32),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AssessmentHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text(
                'View Past Results',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(
    String testName,
    IconData icon,
    Color bgColor,
    Color iconColor,
    String subtitle,
  ) {
    return InkWell(
      onTap: () => _selectTest(testName),
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

  // ══════════════════════════════════════════════════════════════════════
  //  TYPEFORM-STYLE PAGE VIEW  (Step 1)
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildPageView() {
    final totalQuestions = _questions.length;

    return Column(
      children: [
        // ── Progress bar ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_currentPage + 1) / totalQuestions,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Question ${_currentPage + 1} of $totalQuestions',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // ── Question pages ──────────────────────────────────────────
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalQuestions,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              return _buildQuestionPage(index);
            },
          ),
        ),

        // ── Navigation buttons ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              // Previous button
              if (_currentPage > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                      );
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Previous'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

              if (_currentPage > 0) const SizedBox(width: 12),

              // Next / See Results button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _answers[_currentPage] == -1
                      ? null
                      : () {
                          if (_currentPage < totalQuestions - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _goToResults();
                          }
                        },
                  icon: Icon(
                    _currentPage == totalQuestions - 1
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _currentPage == totalQuestions - 1 ? 'See Results' : 'Next',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Single question page ──────────────────────────────────────────
  Widget _buildQuestionPage(int questionIndex) {
    final question = _questions[questionIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Intro prompt (only on first page)
          if (questionIndex == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Over the last 2 weeks, how often have you been bothered by:',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),

          // Question text
          Text(
            question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 24),

          // Answer option cards
          ...List.generate(_options.length, (optIdx) {
            final option = _options[optIdx];
            final isSelected = _answers[questionIndex] == option['score'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _onOptionSelected(questionIndex, option['score']),
                  child: Container(
                    width: double.infinity,
                    height: 56, // Fixed height per Step 1 constraints
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Score badge
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${option['score']}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected 
                                  ? Colors.white 
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Label
                        Expanded(
                          child: Text(
                            option['label'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        // Check icon
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  RESULTS PAGE (Step 3)
  // ══════════════════════════════════════════════════════════════════════

  /// Compute severity label + color for PHQ-9
  Map<String, dynamic> _phq9Severity(int score) {
    if (score <= 4) return {'label': 'Minimal', 'color': Colors.green};
    if (score <= 9) return {'label': 'Mild', 'color': Colors.lightGreen};
    if (score <= 14) return {'label': 'Moderate', 'color': Colors.orange};
    if (score <= 19) return {'label': 'Moderately Severe', 'color': Colors.deepOrange};
    return {'label': 'Severe', 'color': Colors.red};
  }

  /// Compute severity label + color for GAD-7
  Map<String, dynamic> _gad7Severity(int score) {
    if (score <= 4) return {'label': 'Minimal', 'color': Colors.green};
    if (score <= 9) return {'label': 'Mild', 'color': Colors.lightGreen};
    if (score <= 14) return {'label': 'Moderate', 'color': Colors.orange};
    return {'label': 'Severe', 'color': Colors.red};
  }

  String _recommendation(String severity) {
    switch (severity) {
      case 'Minimal':
        return "You're doing well. Keep maintaining healthy habits.";
      case 'Mild':
        return 'Consider talking to someone you trust about how you\'re feeling.';
      case 'Moderate':
        return 'We recommend speaking with a mental health professional.';
      default: // Moderately Severe / Severe
        return 'Please seek professional help as soon as possible.';
    }
  }

  Map<String, String> _encouragement(String severity) {
    switch (severity) {
      case 'Minimal':
        return {'emoji': '💪', 'text': 'Great job taking care of your mental health!'};
      case 'Mild':
        return {'emoji': '🌱', 'text': 'Small steps every day make a big difference.'};
      case 'Moderate':
        return {'emoji': '🤝', 'text': 'Asking for help is a sign of strength, not weakness.'};
      default:
        return {'emoji': '❤️', 'text': 'You matter. Please reach out to someone today.'};
    }
  }

  void _retakeTest() {
    setState(() {
      _currentPage = 0;
      _showResults = false;
      _answers = List.filled(_questions.length, -1);
      _pageController = PageController();
    });
  }

  Widget _buildResultsPage() {
    final int score = _answers.reduce((a, b) => a + b);
    final severity = _selectedTest == 'PHQ-9'
        ? _phq9Severity(score)
        : _gad7Severity(score);
    final String severityLabel = severity['label'];
    final Color severityColor = severity['color'];
    final String rec = _recommendation(severityLabel);
    final enc = _encouragement(severityLabel);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // ── 1. Score Circle ────────────────────────────────────────
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: severityColor, width: 6),
              color: severityColor.withValues(alpha: 0.08),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: severityColor,
                  ),
                ),
                Text(
                  _selectedTest,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: severityColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── 2. Severity Badge ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              severityLabel,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: severityColor,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── 3. Recommendation Text ─────────────────────────────────
          Text(
            rec,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey[800],
            ),
          ),

          const SizedBox(height: 24),

          // ── 4. Encouraging Message Card ────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: severityColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Text(
                  enc['emoji']!,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    enc['text']!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // ── 5. Action Buttons ──────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _retakeTest,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retake Test'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final maxScore = _selectedTest == 'PHQ-9' ? 27 : 21;
                final message =
                    'I just completed $_selectedTest and scored $score/$maxScore. '
                    'My result is $severityLabel. Can you help me understand '
                    'what this means and what I can do to feel better?';
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      initialMessage: message,
                      assessmentScore: score,
                      assessmentType: _selectedTest,
                      severityLevel: severityLabel,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('Talk to AI about your results'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Back to Home'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
