import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_uni/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final Color primaryColor = AppColors.hcmusBlue;

  bool _isTyping = false;
  late AnimationController _typingController;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Chào bạn, mình là **Ú Em** 👋\nMình biết rất nhiều về trường Đại học Khoa học Tự nhiên, hãy hỏi mình nếu có thắc mắc gì nhé!",
      isUser: false,
    ),
  ];

  final List<String> _suggestedQuestions = [
    "Điểm rèn luyện",
    "Học bổng khuyến khích học tập",
    "Câu lạc bộ học thuật",
    "Cảnh báo học tập",
    "Địa chỉ các cơ sở",
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

  Future<void> _handleSendMessage([String? text]) async {
    final String userText = text ?? _messageController.text.trim();
    if (userText.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: userText, isUser: true));
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final url = Uri.parse('https://asia-southeast1-myuni-fe6d1.cloudfunctions.net/chatWithUEm');

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          if (idToken != null) "Authorization": "Bearer $idToken",
        },
        body: utf8.encode(jsonEncode({
          "data": {"query": userText}
        })),
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        final result = data['result'];
        String botAnswer = result != null ? result['answer'] : "Không nhận được câu trả lời từ Ú Em.";
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(text: botAnswer, isUser: false));
        });
      } else {
        String errorMessage = "Ú Em đang bận hoặc server đang khởi động. Bạn đợi xíu rồi thử lại nhé! 🙏";
        if (data is Map && data['error'] != null) {
          final error = data['error'];
          if (error['message'] != null) {
            errorMessage = error['message'];
          }
        }
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(text: errorMessage, isUser: false));
        });
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
      backgroundColor: isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600.0),
          child: Column(
            children: [
              _buildHeader(isDarkMode),
              Expanded(
                child: _buildChatArea(isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────
  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.only(top: 56, left: 20, right: 16, bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [
                  const Color(0xFF40539B).withOpacity(0.95),
                  const Color(0xFF74C98C).withOpacity(0.95),
                ]
              : [
                  const Color(0xFF042788).withOpacity(0.9),
                  const Color(0xFF60CA6F).withOpacity(1),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: Colors.white.withOpacity(0.1),
            backgroundImage: const AssetImage('assets/images/chatbot_avt.png'),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
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
                    const SizedBox(width: 6),
                    Text(
                      'Sẵn sàng trợ giúp',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFD85858),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFD85858),
                  width: 1,
                ),
              ),

              child: const Icon(
                Icons.report_gmailerrorred_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final TextEditingController detailController = TextEditingController();
    String selectedCategory = 'Sai kiến thức';
    final List<String> categories = [
      'Sai kiến thức',
      'Không phản hồi',
      'Nội dung không phù hợp',
      'Lỗi khác'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
            final Color textColor = isDarkMode ? Colors.white : Colors.black87;
            final Color labelColor = isDarkMode ? Colors.white70 : Colors.black54;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
              title: Row(
                children: [
                  const Icon(Icons.feedback_rounded, color: AppColors.hcmusBlue),
                  const SizedBox(width: 10),
                  Text(
                    'Báo cáo lỗi chatbot',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loại lỗi bạn gặp phải:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.black26),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          isExpanded: true,
                          dropdownColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                          style: TextStyle(color: textColor, fontSize: 14),
                          items: categories.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              setStateDialog(() {
                                selectedCategory = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Mô tả chi tiết:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: detailController,
                      maxLines: 4,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Vui lòng mô tả chi tiết nội dung lỗi hoặc câu hỏi bị lỗi...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDarkMode ? Colors.white24 : Colors.black26),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.hcmusBlue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.hcmusBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () async {
                    final String details = detailController.text.trim();
                    if (details.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập chi tiết lỗi!'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context);

                    final user = FirebaseAuth.instance.currentUser;
                    final String userEmail = user?.email ?? 'N/A';
                    final String userId = user?.uid ?? 'N/A';

                    try {
                      await FirebaseFirestore.instance.collection('chatbot_reports').add({
                        'category': selectedCategory,
                        'details': details,
                        'userEmail': userEmail,
                        'userId': userId,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                    } catch (e) {
                      debugPrint('Lỗi lưu report vào Firestore: $e');
                    }

                    // 2. Gửi thông báo đến Discord Webhook
                    await _sendToDiscordWebhook(
                      category: selectedCategory,
                      details: details,
                      userEmail: userEmail,
                      userId: userId,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cảm ơn đóng góp của bạn! Báo cáo đã được gửi tới hệ thống.'),
                          backgroundColor: AppColors.hcmusBlue,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Gửi báo cáo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendToDiscordWebhook({
    required String category,
    required String details,
    required String userEmail,
    required String userId,
  }) async {
    // WEBHOOK CONFIGURATION:
    // Bạn hãy tạo một webhook trên Discord (Server Settings -> Integrations -> Webhooks)
    // Và dán URL webhook thực tế của bạn vào đây thay thế chuỗi bên dưới.
    const String discordWebhookUrl = 'https://discord.com/api/webhooks/1521577476734849177/sBXm5Ve4FwXICLP6GGh4MApvwuloBoWT7fWioKhE-Z8xWepfGwQJUciYEZqt3NnzMCY7';

    if (discordWebhookUrl == 'YOUR_DISCORD_WEBHOOK_URL_HERE') {
      debugPrint('Discord Webhook chưa được cấu hình. Bỏ qua gửi tin nhắn.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(discordWebhookUrl),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          "username": "My-Uni Bot",
          "avatar_url": "https://i.imgur.com/gK2Jp5M.png",
          "embeds": [
            {
              "title": "🚨 BÁO CÁO LỖI CHATBOT MỚI",
              "color": 16730112, // Hex: #FF6868
              "fields": [
                {
                  "name": "📌 Loại lỗi",
                  "value": category,
                  "inline": true
                },
                {
                  "name": "👤 Người gửi",
                  "value": "$userEmail\n(UID: $userId)",
                  "inline": true
                },
                {
                  "name": "📝 Chi tiết lỗi",
                  "value": details,
                  "inline": false
                }
              ],
              "footer": {
                "text": "My-Uni Academic Companion App"
              },
              "timestamp": DateTime.now().toUtc().toIso8601String()
            }
          ]
        }),
      );
      if (response.statusCode == 204) {
        debugPrint('Gửi Discord Webhook thành công!');
      } else {
        debugPrint('Gửi Discord Webhook thất bại: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Lỗi kết nối tới Discord Webhook: $e');
    }
  }

  // ── Chat area ───────────────────────────────────────────────
  Widget _buildChatArea(bool isDarkMode) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
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
          _buildQuickReplies(isDarkMode),
          _buildInputSection(isDarkMode),
        ],
      ),
    );
  }

  // ── Quick Replies ──────────────────────────────────────────
  Widget _buildQuickReplies(bool isDarkMode) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _suggestedQuestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: ActionChip(
              label: Text(
                _suggestedQuestions[index],
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
              side: BorderSide(
                color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: () => _handleSendMessage(_suggestedQuestions[index]),
            ),
          );
        },
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
                    ? AppColors.surfaceDark
                    : primaryColor.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: isDarkMode ? Border.all(color: Colors.white10) : null,
              ),
              child: MarkdownBody(
                data: _cleanMessageFormat(msg.text),
                selectable: true,
                onTapLink: (text, href, title) async {
                  if (href != null) {
                    final uri = Uri.tryParse(href);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isDarkMode ? Colors.white.withOpacity(0.9) : const Color(0xFF1A1F35),
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
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                _cleanMessageFormat(msg.text),
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
              ? AppColors.surfaceDark
              : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.sentences,
                autocorrect: true,
                enableSuggestions: true,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : const Color(0xFF1A1F35),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: "Hỏi Ú Em điều gì đó...",
                  hintStyle: TextStyle(
                    color: isDarkMode
                        ? Colors.white24
                        : Colors.black.withOpacity(0.3),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  isDense: true,
                ),
                onSubmitted: (_) => _handleSendMessage(),
              ),
            ),

            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _handleSendMessage(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      )
    );
  }

  String _cleanMessageFormat(String text) {
    var cleaned = text;
    cleaned = cleaned.replaceAll(r'$\rightarrow$', '→');
    cleaned = cleaned.replaceAll(r'\rightarrow', '→');
    cleaned = cleaned.replaceAll(r'$\leftarrow$', '←');
    cleaned = cleaned.replaceAll(r'\leftarrow', '←');
    cleaned = cleaned.replaceAll(r'$\Rightarrow$', '⇒');
    cleaned = cleaned.replaceAll(r'\Rightarrow', '⇒');
    cleaned = cleaned.replaceAll(r'$\Leftarrow$', '⇐');
    cleaned = cleaned.replaceAll(r'\Leftarrow', '⇐');
    cleaned = cleaned.replaceAll(r'$\leftrightarrow$', '↔');
    cleaned = cleaned.replaceAll(r'\leftrightarrow', '↔');
    cleaned = cleaned.replaceAll(r'$\Leftrightarrow$', '⇔');
    cleaned = cleaned.replaceAll(r'\Leftrightarrow', '⇔');
    cleaned = cleaned.replaceAll(r'$\times$', '×');
    cleaned = cleaned.replaceAll(r'\times', '×');
    cleaned = cleaned.replaceAll(r'$\div$', '÷');
    cleaned = cleaned.replaceAll(r'\div', '÷');
    cleaned = cleaned.replaceAll(r'$\leq$', '≤');
    cleaned = cleaned.replaceAll(r'\leq', '≤');
    cleaned = cleaned.replaceAll(r'$\geq$', '≥');
    cleaned = cleaned.replaceAll(r'\geq', '≥');
    cleaned = cleaned.replaceAll(r'$\neq$', '≠');
    cleaned = cleaned.replaceAll(r'\neq', '≠');
    cleaned = cleaned.replaceAll(r'$\approx$', '≈');
    cleaned = cleaned.replaceAll(r'\approx', '≈');
    cleaned = cleaned.replaceAll(r'$\pm$', '±');
    cleaned = cleaned.replaceAll(r'\pm', '±');
    return cleaned;
  }
}

