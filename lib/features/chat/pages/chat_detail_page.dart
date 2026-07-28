import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/student_identity_card.dart';

class ChatDetailPage extends StatefulWidget {
  final String roomId;
  final String targetUserId;
  final String targetUserName;
  final String targetUserPhoto;

  const ChatDetailPage({
    super.key,
    required this.roomId,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserPhoto = '',
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _targetUserInfo;

  @override
  void initState() {
    super.initState();
    _chatService.markRoomAsRead(widget.roomId);
    _loadTargetUserInfo();
  }

  Future<void> _loadTargetUserInfo() async {
    final info = await _chatService.getStudentVerificationInfo(widget.targetUserId);
    if (mounted && info != null) {
      setState(() {
        _targetUserInfo = info;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildTimeDivider(DateTime dt) {
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(dt);
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(dt);
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final displayStr = isToday ? timeStr : dateStr;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            displayStr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white54
                  : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    _messageController.clear();
    try {
      await _chatService.sendMessage(widget.roomId, text);
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi gửi tin nhắn: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 35,
        minWidth: 800,
        minHeight: 800,
      );
      final base64Image = 'data:image/jpeg;base64,${base64Encode(compressedBytes)}';

      await _chatService.sendMessage(
        widget.roomId,
        '',
        imageUrl: base64Image,
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error picking/sending image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gửi hình ảnh: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'zip', 'rar', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.first;
      if (platformFile.size > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng chọn tệp nhỏ hơn 10MB')),
          );
        }
        return;
      }

      final fileName = platformFile.name;
      final extension = platformFile.extension ?? '';
      final sizeKb = (platformFile.size / 1024).toStringAsFixed(1);
      final fileSize = platformFile.size > 1024 * 1024
          ? '${(platformFile.size / (1024 * 1024)).toStringAsFixed(1)} MB'
          : '$sizeKb KB';

      await _chatService.sendMessage(
        widget.roomId,
        '',
        fileShare: {
          'fileName': fileName,
          'fileSize': fileSize,
          'extension': extension,
        },
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error picking/sending file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gửi tệp đính kèm: $e')),
        );
      }
    }
  }

  void _showShareContactDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myUser = FirebaseAuth.instance.currentUser;
    final myUid = myUser?.uid ?? '';

    // Lấy thông tin liên hệ đã lưu từ Firestore
    Map<String, String> savedContacts = {};
    if (myUid.isNotEmpty) {
      savedContacts = await _chatService.getUserSocialContacts(myUid);
    }

    if (!mounted) return;

    final zaloController = TextEditingController(text: savedContacts['zalo'] ?? '');
    final fbController = TextEditingController(text: savedContacts['facebook'] ?? '');
    final phoneController = TextEditingController(text: savedContacts['phone'] ?? '');
    final discordController = TextEditingController(text: savedContacts['discord'] ?? '');

    String selectedType = 'zalo';
    bool saveAsDefault = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            TextEditingController currentController;
            String labelText;
            String hintText;

            if (selectedType == 'zalo') {
              currentController = zaloController;
              labelText = 'Số điện thoại Zalo';
              hintText = '0901234567';
            } else if (selectedType == 'facebook') {
              currentController = fbController;
              labelText = 'Link / Tên Facebook';
              hintText = 'fb.com/username';
            } else if (selectedType == 'phone') {
              currentController = phoneController;
              labelText = 'Số điện thoại gọi';
              hintText = '0901234567';
            } else {
              currentController = discordController;
              labelText = 'Tên / Tag Discord';
              hintText = 'username#1234';
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.contact_mail_rounded, color: AppColors.hcmusTeal),
                  SizedBox(width: 10),
                  Text(
                    'Chia sẻ thông tin liên hệ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chọn loại liên hệ bạn muốn gửi cho đối phương:',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Zalo'),
                          selected: selectedType == 'zalo',
                          onSelected: (val) => setDialogState(() => selectedType = 'zalo'),
                          selectedColor: AppColors.hcmusTeal.withValues(alpha: 0.2),
                        ),
                        ChoiceChip(
                          label: const Text('Facebook'),
                          selected: selectedType == 'facebook',
                          onSelected: (val) => setDialogState(() => selectedType = 'facebook'),
                          selectedColor: AppColors.hcmusTeal.withValues(alpha: 0.2),
                        ),
                        ChoiceChip(
                          label: const Text('SĐT'),
                          selected: selectedType == 'phone',
                          onSelected: (val) => setDialogState(() => selectedType = 'phone'),
                          selectedColor: AppColors.hcmusTeal.withValues(alpha: 0.2),
                        ),
                        ChoiceChip(
                          label: const Text('Discord'),
                          selected: selectedType == 'discord',
                          onSelected: (val) => setDialogState(() => selectedType = 'discord'),
                          selectedColor: const Color(0xFF5865F2).withValues(alpha: 0.2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: currentController,
                      decoration: InputDecoration(
                        labelText: labelText,
                        hintText: hintText,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: saveAsDefault,
                          activeColor: AppColors.hcmusTeal,
                          onChanged: (val) => setDialogState(() => saveAsDefault = val ?? true),
                        ),
                        const Expanded(
                          child: Text(
                            'Lưu lại làm thông tin mặc định',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.hcmusTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final String val = currentController.text.trim();
                    if (val.isEmpty) return;

                    Navigator.pop(context);

                    // Lưu vào hồ sơ nếu được tick chọn
                    if (saveAsDefault && myUid.isNotEmpty) {
                      savedContacts[selectedType] = val;
                      await _chatService.saveUserSocialContacts(myUid, savedContacts);
                    }

                    final myName = myUser?.displayName ?? 'Sinh viên';

                    await _chatService.sendMessage(
                      widget.roomId,
                      'Tôi gửi bạn thông tin liên hệ:',
                      contactShare: {
                        'type': selectedType,
                        'value': val,
                        'name': myName,
                      },
                    );
                    _scrollToBottom();
                  },
                  child: const Text('Chia sẻ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: () {
            if (_targetUserInfo != null) {
              StudentIdentitySheet.show(context, _targetUserInfo!);
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.hcmusTeal.withValues(alpha: 0.15),
                backgroundImage: widget.targetUserPhoto.isNotEmpty
                    ? NetworkImage(widget.targetUserPhoto)
                    : null,
                child: widget.targetUserPhoto.isEmpty
                    ? Text(
                        widget.targetUserName.isNotEmpty
                            ? widget.targetUserName[0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.hcmusTeal,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.targetUserName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppColors.hcmusTeal,
                        ),
                      ],
                    ),
                    const Text(
                      'Sinh viên HCMUS đã xác thực',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.hcmusTeal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: AppColors.hcmusTeal),
            onPressed: () {
              if (_targetUserInfo != null) {
                StudentIdentitySheet.show(context, _targetUserInfo!);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner nhắc nhở an toàn
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.hcmusTeal.withValues(alpha: 0.08),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: AppColors.hcmusTeal),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tài khoản đã xác thực qua Email sinh viên. Hãy lịch sự và cẩn trọng khi chia sẻ thông tin cá nhân.',
                      style: TextStyle(fontSize: 11, color: AppColors.hcmusTeal, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            // Realtime Message Stream List
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _chatService.getMessagesStream(widget.roomId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data ?? [];

                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mark_chat_read_outlined,
                              size: 48,
                              color: AppColors.hcmusTeal.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Đã kết nối với ${widget.targetUserName}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Hãy gửi lời chào hoặc chia sẻ thông tin liên hệ Zalo/FB để trao đổi thêm.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      bool showTimeHeader = false;

                      if (index == 0) {
                        showTimeHeader = true;
                      } else {
                        final prevMsg = messages[index - 1];
                        final diffInMinutes = msg.timestamp.difference(prevMsg.timestamp).inMinutes.abs();
                        if (diffInMinutes >= 10) {
                          showTimeHeader = true;
                        }
                      }

                      final bubble = ChatBubble(
                        message: msg,
                        isMe: msg.senderId == currentUid,
                        onRecall: () async {
                          try {
                            await _chatService.recallMessage(widget.roomId, msg.id);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Không thể thu hồi tin nhắn: $e')),
                              );
                            }
                          }
                        },
                        onEdit: (newText) async {
                          try {
                            await _chatService.editMessage(widget.roomId, msg.id, newText);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Không thể sửa tin nhắn: $e')),
                              );
                            }
                          }
                        },
                      );

                      if (showTimeHeader) {
                        return Column(
                          key: ValueKey(msg.id),
                          children: [
                            _buildTimeDivider(msg.timestamp),
                            bubble,
                          ],
                        );
                      }

                      return bubble;
                    },
                  );
                },
              ),
            ),

            // Bottom Input Bar (Chatbot / Messenger Floating Style)
            Padding(
              padding: EdgeInsets.fromLTRB(
                12, 6, 12,
                MediaQuery.of(context).padding.bottom + 8,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Nút Gửi Ảnh
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.hcmusTeal, size: 22),
                      tooltip: 'Gửi hình ảnh',
                      onPressed: _pickAndSendImage,
                    ),

                    // Nút Gửi File Tài liệu
                    IconButton(
                      icon: const Icon(Icons.attach_file_rounded, color: AppColors.hcmusTeal, size: 22),
                      tooltip: 'Gửi tệp đính kèm',
                      onPressed: _pickAndSendFile,
                    ),

                    // Nút Chia sẻ liên hệ
                    IconButton(
                      icon: const Icon(Icons.badge_outlined, color: AppColors.hcmusTeal, size: 22),
                      tooltip: 'Chia sẻ thông tin liên hệ Zalo/FB',
                      onPressed: _showShareContactDialog,
                    ),

                    // Khung nhập tin nhắn
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1A1F35),
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Nút Gửi (Circular Teal Button)
                    Material(
                      color: AppColors.hcmusTeal,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _sendMessage,
                        child: const Padding(
                          padding: EdgeInsets.all(9),
                          child: Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
