import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../database/db_helper.dart';
import '../models/nlp_result.dart';

class MoodTrackerScreen extends StatefulWidget {
  const MoodTrackerScreen({Key? key}) : super(key: key);

  @override
  State<MoodTrackerScreen> createState() => _MoodTrackerScreenState();
}

class _MoodTrackerScreenState extends State<MoodTrackerScreen> {
  List<NLPResult> _emotions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmotions();
  }

  Future<void> _loadEmotions() async {
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null) {
        final results = await DatabaseHelper.instance.getUserEmotions(user.userID!);
        if (results.isNotEmpty) {
          setState(() {
            _emotions = results;
            _isLoading = false;
          });
          return;
        }
      }
      // Fallback: mock data when database is empty or user is null
      setState(() {
        _emotions = [
          NLPResult(entryID: 1, emotion: 'Sadness', confidence: 0.81),
          NLPResult(entryID: 2, emotion: 'Anxiety', confidence: 0.87),
          NLPResult(entryID: 3, emotion: 'Neutral', confidence: 0.76),
          NLPResult(entryID: 4, emotion: 'Joy', confidence: 0.92),
          NLPResult(entryID: 5, emotion: 'Anxiety', confidence: 0.83),
          NLPResult(entryID: 6, emotion: 'Neutral', confidence: 0.79),
          NLPResult(entryID: 7, emotion: 'Joy', confidence: 0.95),
        ];
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  int _emotionToVal(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy': return 3;
      case 'neutral': return 2;
      case 'anxiety': return 1;
      case 'sadness': return 0;
      default: return 2;
    }
  }

  String _valToEmotion(double val) {
    if (val >= 3) return 'Joy';
    if (val >= 2) return 'Neutral';
    if (val >= 1) return 'Anxiety';
    return 'Sadness';
  }

  Color _emotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy': return Colors.green;
      case 'neutral': return Colors.blue;
      case 'anxiety': return Colors.orange;
      case 'sadness': return Colors.grey;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Tracker'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Your Emotional Trend',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  if (_emotions.isEmpty)
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('Not enough data to show a chart yet.\nWrite some journal entries!'),
                      ),
                    )
                  else
                    SizedBox(
                      height: 250,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    _valToEmotion(value),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                                reservedSize: 48,
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: (_emotions.length - 1).toDouble() > 0 ? (_emotions.length - 1).toDouble() : 1,
                          minY: 0,
                          maxY: 3,
                          lineBarsData: [
                            LineChartBarData(
                              spots: _emotions.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(), _emotionToVal(e.value.emotion).toDouble());
                              }).toList(),
                              isCurved: true,
                              color: Theme.of(context).primaryColor,
                              barWidth: 4,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  const Text(
                    'History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_emotions.isEmpty)
                    const Text('No mood data available.')
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _emotions.length,
                      itemBuilder: (context, index) {
                        final emo = _emotions.reversed.toList()[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _emotionColor(emo.emotion).withValues(alpha: 0.2),
                              child: Icon(Icons.mood, color: _emotionColor(emo.emotion)),
                            ),
                            title: Text(emo.emotion, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Confidence: ${(emo.confidence * 100).toStringAsFixed(1)}%'),
                          ),
                        );
                      }
                    ),
                ],
              ),
            ),
          ),
    );
  }
}
