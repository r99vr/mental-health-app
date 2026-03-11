import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String? initialMessage;
  final int? assessmentScore;
  final String? assessmentType;
  final String? severityLevel;

  const ChatScreen({
    Key? key,
    this.initialMessage,
    this.assessmentScore,
    this.assessmentType,
    this.severityLevel,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, this.isUser);
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final List<ChatMessage> _messages = [
    ChatMessage("Hello! I'm your AI mental health companion. How can I support you today?", false),
  ];

  @override
  void initState() {
    super.initState();
    // If launched from results screen, auto-send the initial message
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendInitialMessage(widget.initialMessage!);
      });
    }
  }

  void _sendInitialMessage(String text) {
    setState(() {
      _messages.insert(0, ChatMessage(text, true));
    });

    // Simulate AI response
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _messages.insert(0, ChatMessage(
          _generateContextualResponse(),
          false,
        ));
      });
    });
  }

  String _generateContextualResponse() {
    final type = widget.assessmentType ?? 'assessment';
    final severity = widget.severityLevel ?? '';

    if (severity == 'Minimal' || severity == 'Mild') {
      return "Thank you for sharing your $type results with me. "
          "It's great that you're being proactive about your mental health. "
          "How have you been feeling lately? Is there anything specific you'd like to talk about?";
    } else if (severity == 'Moderate') {
      return "Thank you for sharing your $type results with me. "
          "I can see you've been going through some challenges. "
          "Remember, seeking support is a sign of strength. "
          "Would you like to discuss some strategies that might help?";
    } else {
      return "Thank you for trusting me with your $type results. "
          "I want you to know that what you're feeling is valid, and help is available. "
          "I'd strongly recommend speaking with a mental health professional. "
          "In the meantime, would you like to talk about what's been on your mind?";
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.insert(0, ChatMessage(text, true));
      _messageController.clear();
    });

    // Simulate AI response
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _messages.insert(0, ChatMessage(
          "I hear you. Thank you for sharing that with me. This is a mock response, NLP processing will be added here in the future.", 
          false
        ));
      });
    });
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: message.isUser ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: message.isUser ? const Radius.circular(0) : const Radius.circular(20),
            bottomLeft: message.isUser ? const Radius.circular(20) : const Radius.circular(0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Support Chat'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Context banner when launched from assessment results
            if (widget.assessmentType != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.blue.shade50,
                child: Row(
                  children: [
                    const Text('📋', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Discussing your ${widget.assessmentType} results — '
                        'Score: ${widget.assessmentScore} (${widget.severityLevel})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                reverse: true, // Show newest messages at the bottom
                padding: const EdgeInsets.symmetric(vertical: 20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildChatBubble(_messages[index]);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
