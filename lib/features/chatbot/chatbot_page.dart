import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

class _ChatbotPageState extends State<ChatbotPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ── Palette ────────────────────────────────────────────────
  // Soft Indigo — swap this one line to change the whole theme:
  //   Violet Mint : const Color(0xFF7C6FF7)
  //   Rose Slate  : const Color(0xFFE0607E)
  final Color primaryColor = const Color(0xFF5B8DEF);

  bool _isTyping = false;
  bool _inputFocused = false;
  late AnimationController _typingController;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Chào bạn, mình là **Ú Em** 👋\nMình biết rất nhiều về trường Đại học Khoa học Tự nhiên, hãy hỏi mình nếu có thắc mắc gì nhé!",
      isUser: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _typingController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final String userText = _messageController.text;

    setState(() {
      _messages.add(ChatMessage(text: userText, isUser: true));
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final url = Uri.parse('http://34.142.157.91:8000/chat');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"query": userText}),
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String botAnswer = data['answer'];
        List<dynamic> sources = data['sources'] ?? [];

        if (sources.isNotEmpty) {
          botAnswer += "\n\n*(Nguồn: Trang ${sources.join(', ')})*";
        }

        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(text: botAnswer, isUser: false));
        });
      } else {
        throw Exception("Lỗi server: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: "Ú Em đang bận hoặc server đang khởi động. Bạn đợi xíu rồi thử lại nhé! 🙏",
          isUser: false,
        ));
      });
    }
    _scrollToBottom();
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

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDarkMode ? const Color(0xFF0F1117) : const Color(0xFFF7F9FF),
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

  // ── Header ─────────────────────────────────────────────────
  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.only(top: 56, left: 20, right: 16, bottom: 16),
      decoration: BoxDecoration(color: primaryColor),
      child: Row(
        children: [
          // Avatar with ring
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.transparent,
              backgroundImage: const AssetImage('assets/images/chatbot_avt.png'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ú Em',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4ADE80).withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Trực tuyến',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Report button
          GestureDetector(
            onTap: () => _showReportDialog(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.report_problem_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.feedback_rounded, color: Color(0xFF5893D8)),
              const SizedBox(width: 10),
              Text(
                'Báo cáo lỗi chatbot',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bạn gặp vấn đề gì với câu trả lời của Ú Em?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              _buildReportOption(context, 'Chatbot trả lời sai kiến thức', isDarkMode),
              _buildReportOption(context, 'Không nhận được câu trả lời', isDarkMode),
              _buildReportOption(context, 'Nội dung không phù hợp', isDarkMode),
              _buildReportOption(context, 'Lỗi khác...', isDarkMode),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey, fontFamily: 'Poppins')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportOption(BuildContext context, String title, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cảm ơn bạn! Báo cáo "$title" đã được gửi.'),
              backgroundColor: const Color(0xFF5893D8),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ── Chat area ───────────────────────────────────────────────
  Widget _buildChatArea(bool isDarkMode) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F1117) : const Color(0xFFF7F9FF),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white12 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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

  // ── Typing indicator ────────────────────────────────────────
  Widget _buildTypingIndicator(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBotAvatarFrame(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? primaryColor.withOpacity(0.12)
                  : primaryColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: AnimatedBuilder(
              animation: _typingController,
              builder: (context, child) {
                return Row(
                  children: List.generate(3, (i) {
                    final double offset =
                    ((_typingController.value * 3 - i) % 1.0).clamp(0.0, 1.0);
                    final double bounce =
                    offset < 0.5 ? offset * 2 : (1 - offset) * 2;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Transform.translate(
                        offset: Offset(0, -5 * bounce),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Bot avatar ──────────────────────────────────────────────
  Widget _buildBotAvatarFrame() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primaryColor,
        border: Border.all(
          color: primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Image.asset(
          'assets/images/chatbot_avt.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ── Bot message ─────────────────────────────────────────────
  Widget _buildBotMessage(bool isDarkMode, ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBotAvatarFrame(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? primaryColor.withOpacity(0.12)
                    : primaryColor.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: MarkdownBody(
                data: msg.text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isDarkMode ? const Color(0xFFE2E8F8) : const Color(0xFF1A1F35),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  strong: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F1117),
                  ),
                  em: TextStyle(
                    color: isDarkMode
                        ? Colors.white54
                        : const Color(0xFF1A1F35).withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ── User message ────────────────────────────────────────────
  Widget _buildUserMessage(bool isDarkMode, ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(width: 40),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input section ───────────────────────────────────────────
  Widget _buildInputSection(bool isDarkMode) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 8, 16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _inputFocused
                ? primaryColor.withOpacity(0.5)
                : isDarkMode
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.07),
            width: 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Focus(
                onFocusChange: (v) => setState(() => _inputFocused = v),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                  autocorrect: true,
                  enableSuggestions: true,
                  style: TextStyle(
                    color: isDarkMode ? const Color(0xFFE2E8F8) : const Color(0xFF1A1F35),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: "Hỏi Ú Em điều gì đó...",
                    hintStyle: TextStyle(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.25)
                          : Colors.black.withOpacity(0.3),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _handleSendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _handleSendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}