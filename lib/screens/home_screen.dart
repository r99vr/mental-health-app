import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // To build the body based on the selected index
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return const JournalScreen();
      case 2:
        return const MoodTrackerScreen();
      case 3:
        return const AssessmentScreen();
      case 4:
        return const ChatScreen();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    final user = Provider.of<AuthProvider>(context).currentUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, ${user?.name ?? 'Guest'} 👋',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How are you feeling today?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildFeatureCard(
                context,
                'Journal\nEntry',
                Icons.book_outlined,
                Colors.blue.shade100,
                Colors.blue.shade800,
                () => _onItemTapped(1),
              ),
              _buildFeatureCard(
                context,
                'Mood\nTracker',
                Icons.bar_chart,
                Colors.purple.shade100,
                Colors.purple.shade800,
                () => _onItemTapped(2),
              ),
              _buildFeatureCard(
                context,
                'Mental\nAssessments',
                Icons.assignment_outlined,
                Colors.green.shade100,
                Colors.green.shade800,
                () => _onItemTapped(3),
              ),
              _buildFeatureCard(
                context,
                'AI\nChat',
                Icons.chat_bubble_outline,
                Colors.orange.shade100,
                Colors.orange.shade800,
                () => _onItemTapped(4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 32, color: iconColor),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mental Health App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Journal'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Mood'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Tests'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        ],
      ),
    );
  }
}

// ==========================================
// Placeholder Screens for internal navigation
// (Will replace these in later task segments)
// ==========================================

class JournalScreen extends StatelessWidget {
  const JournalScreen({Key? key}) : super(key: key);
  @override Widget build(BuildContext context) => const Center(child: Text('Journal Screen Placeholder'));
}

class MoodTrackerScreen extends StatelessWidget {
  const MoodTrackerScreen({Key? key}) : super(key: key);
  @override Widget build(BuildContext context) => const Center(child: Text('Mood Tracker Placeholder'));
}

class AssessmentScreen extends StatelessWidget {
  const AssessmentScreen({Key? key}) : super(key: key);
  @override Widget build(BuildContext context) => const Center(child: Text('Assessment Placeholder'));
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({Key? key}) : super(key: key);
  @override Widget build(BuildContext context) => const Center(child: Text('AI Chat Placeholder'));
}
