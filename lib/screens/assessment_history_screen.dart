import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../database/db_helper.dart';
import '../models/assessment.dart';

class AssessmentHistoryScreen extends StatefulWidget {
  const AssessmentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AssessmentHistoryScreen> createState() =>
      _AssessmentHistoryScreenState();
}

class _AssessmentHistoryScreenState extends State<AssessmentHistoryScreen> {
  List<Assessment> _assessments = [];
  bool _isLoading = true;

  // Mock data used when the database is empty
  final List<Assessment> _mockAssessments = [
    Assessment(
      userID: 0,
      scaleType: 'PHQ-9',
      score: 7,
      date: '2026-03-08',
    ),
    Assessment(
      userID: 0,
      scaleType: 'GAD-7',
      score: 14,
      date: '2026-03-09',
    ),
    Assessment(
      userID: 0,
      scaleType: 'PHQ-9',
      score: 12,
      date: '2026-03-10',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAssessments();
  }

  Future<void> _loadAssessments() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null) {
      final results =
          await DatabaseHelper.instance.getUserAssessments(user.userID!);
      setState(() {
        _assessments = results.isEmpty ? _mockAssessments : results;
        _isLoading = false;
      });
    } else {
      setState(() {
        _assessments = _mockAssessments;
        _isLoading = false;
      });
    }
  }

  // ── Severity helpers ──────────────────────────────────────────────────
  String _getSeverity(String scaleType, int score) {
    if (scaleType == 'PHQ-9') {
      if (score <= 4) return 'Minimal';
      if (score <= 9) return 'Mild';
      if (score <= 14) return 'Moderate';
      if (score <= 19) return 'Moderately Severe';
      return 'Severe';
    } else {
      if (score <= 4) return 'Minimal';
      if (score <= 9) return 'Mild';
      if (score <= 14) return 'Moderate';
      return 'Severe';
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'Minimal':
      case 'Mild':
        return Colors.green;
      case 'Moderate':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  // ── Date formatting ───────────────────────────────────────────────────
  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment History'),
      ),
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _assessments.isEmpty
                  ? _buildEmptyState()
                  : _buildList(),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No assessments yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a PHQ-9 or GAD-7 test to see results here.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ── Main list with summary ────────────────────────────────────────────
  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 20),
        Text(
          'All Results',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_assessments.length, (i) {
          return _buildHistoryCard(_assessments[i]);
        }),
      ],
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────
  Widget _buildSummaryCard() {
    final latest = _assessments.first;
    final latestSeverity = _getSeverity(latest.scaleType, latest.score);
    final color = _severityColor(latestSeverity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Total tests
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Tests',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_assessments.length}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Latest result
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Latest Result',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        latestSeverity,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Individual history card ───────────────────────────────────────────
  Widget _buildHistoryCard(Assessment assessment) {
    final severity = _getSeverity(assessment.scaleType, assessment.score);
    final color = _severityColor(severity);
    final isPHQ = assessment.scaleType == 'PHQ-9';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isPHQ ? Colors.blue : Colors.green).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                isPHQ ? Icons.mood : Icons.psychology,
                color: isPHQ ? Colors.blue.shade700 : Colors.green.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Test info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assessment.scaleType,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(assessment.date),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            // Severity label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                severity,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Score badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2.5),
              ),
              alignment: Alignment.center,
              child: Text(
                '${assessment.score}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
