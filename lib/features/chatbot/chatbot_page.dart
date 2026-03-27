import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color primaryColor = const Color(0xFF6797E1);

  bool _isTyping = false; // Track typing state

  // 1. Your data list lives here
  final List<ChatMessage> _messages = [
    ChatMessage(
        text: "Chào bạn, mình là ú em. Mình biết rất nhiều về trường đại học Khoa học Tự nhiên, hãy hỏi mình nếu có thắc mắc gì nhé!",
        isUser: false
    ),
  ];

  // 2. Put the logic function right here
  void _handleSendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: _messageController.text, isUser: true));
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Mock bot response
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: "Đợi Ú một xíu nhé, mình đang tìm hiểu...",
          isUser: false,
        ));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold( // Add this if it's missing
      resizeToAvoidBottomInset: true, // This pushes the UI up when keyboard appears
      body: Column(
        children: [
          _buildHeader(isDarkMode),
          Expanded(
            child: _buildChatArea(isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        color: primaryColor,
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.transparent,
            backgroundImage: AssetImage('assets/images/chatbot_avt.png'),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ú Em',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                    SizedBox(width: 5),
                    Text('Trực tuyến', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
            onPressed: () {},
          )
        ],
      ),
    );
  }

  Widget _buildChatArea(bool isDarkMode) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF121212) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildTypingIndicator(isDarkMode);
                }
                final msg = _messages[index];
                return msg.isUser
                    ? _buildUserMessage(isDarkMode, msg)
                    : _buildBotMessage(isDarkMode, msg);
              },
            ),
          ),
          _buildInputSection(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          _buildBotAvatarFrame(),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Ú Em đang nghĩ...",
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotAvatarFrame() {
    return CircleAvatar(
      radius: 18,
      backgroundColor: primaryColor,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Image.asset('assets/images/chatbot_avt.png'),
      ),
    );
  }

  Widget _buildBotMessage(bool isDarkMode, ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBotAvatarFrame(),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F3F6),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 14,
                    height: 1.4
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMessage(bool isDarkMode, ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                onSubmitted: (_) => _handleSendMessage(),
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                decoration: const InputDecoration(
                  hintText: "Nhập tin nhắn ở đây",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send_rounded, color: primaryColor),
              onPressed: _handleSendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
