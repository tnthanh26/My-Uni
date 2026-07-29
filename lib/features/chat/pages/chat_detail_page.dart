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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
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

  Widget _buildBrandChip(
    String type,
    String label,
    IconData icon,
    Color brandColor,
    String selectedType,
    Function(String) onSelect,
    bool isDark,
  ) {
    final isSelected = selectedType == type;
    return InkWell(
      onTap: () => onSelect(type),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? brandColor.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? brandColor : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? brandColor : (isDark ? Colors.white60 : const Color(0xFF64748B))),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? (isDark ? Colors.white : brandColor) : (isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
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

    String selectedType = 'facebook';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            TextEditingController currentController;
            String hintText;
            IconData typeIcon;
            Color typeColor;

            if (selectedType == 'facebook') {
              currentController = fbController;
              hintText = 'facebook.com/username';
              typeIcon = Icons.facebook_rounded;
              typeColor = const Color(0xFF1877F2);
            } else if (selectedType == 'zalo') {
              currentController = zaloController;
              hintText = '0901234567 hoặc zalo.me/090...';
              typeIcon = Icons.chat_bubble_rounded;
              typeColor = const Color(0xFF0068FF);
            } else if (selectedType == 'discord') {
              currentController = discordController;
              hintText = 'username#1234';
              typeIcon = Icons.headset_mic_rounded;
              typeColor = const Color(0xFF5865F2);
            } else {
              currentController = phoneController;
              hintText = '0901234567';
              typeIcon = Icons.phone_android_rounded;
              typeColor = const Color(0xFF10B981);
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Chia sẻ thông tin liên hệ',
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Brand Selector Segment Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildBrandChip('facebook', 'Facebook', Icons.facebook_rounded, const Color(0xFF1877F2), selectedType, (type) => setDialogState(() => selectedType = type), isDark),
                          const SizedBox(width: 8),
                          _buildBrandChip('zalo', 'Zalo', Icons.chat_bubble_rounded, const Color(0xFF0068FF), selectedType, (type) => setDialogState(() => selectedType = type), isDark),
                          const SizedBox(width: 8),
                          _buildBrandChip('discord', 'Discord', Icons.headset_mic_rounded, const Color(0xFF5865F2), selectedType, (type) => setDialogState(() => selectedType = type), isDark),
                          const SizedBox(width: 8),
                          _buildBrandChip('phone', 'SĐT', Icons.phone_android_rounded, const Color(0xFF10B981), selectedType, (type) => setDialogState(() => selectedType = type), isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: currentController,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Icon(typeIcon, color: typeColor, size: 20),
                        hintText: hintText,
                        hintStyle: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          color: isDark ? Colors.white38 : Colors.grey[400],
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: typeColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Hủy',
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                color: isDark ? Colors.white60 : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: typeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final String val = currentController.text.trim();
                              if (val.isEmpty) return;

                              Navigator.pop(context);

                              final myName = myUser?.displayName ?? 'Sinh viên';

                              await _chatService.sendMessage(
                                widget.roomId,
                                '',
                                contactShare: {
                                  'type': selectedType,
                                  'value': val,
                                  'name': myName,
                                },
                              );
                              _scrollToBottom();
                            },
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text(
                              'Gửi ngay',
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAttachmentMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.hcmusTeal),
                  title: const Text('Gửi hình ảnh', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.attach_file_rounded, color: AppColors.hcmusTeal),
                  title: const Text('Gửi tệp đính kèm', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendFile();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.badge_rounded, color: AppColors.hcmusTeal),
                  title: const Text('Chia sẻ thông tin liên hệ', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _showShareContactDialog();
                  },
                ),
              ],
            ),
          ),
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

            // Realtime Message Stream List (Isolated Widget to prevent rebuild lag during typing)
            Expanded(
              child: _ChatMessageList(
                roomId: widget.roomId,
                currentUid: currentUid,
                targetUserName: widget.targetUserName,
                scrollController: _scrollController,
                chatService: _chatService,
              ),
            ),

            // Bottom Input Bar (Dynamic Morphing, Isolated State, Lag-Free)
            _ChatInputBar(
              controller: _messageController,
              onSend: _sendMessage,
              onPickImage: _pickAndSendImage,
              onPickFile: _pickAndSendFile,
              onShareContact: _showShareContactDialog,
              onShowAttachmentMenu: _showAttachmentMenu,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;
  final VoidCallback onShareContact;
  final VoidCallback onShowAttachmentMenu;

  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.onPickFile,
    required this.onShareContact,
    required this.onShowAttachmentMenu,
  });

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _isTyping = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    final isNotEmpty = widget.controller.text.trim().isNotEmpty;
    if (isNotEmpty != _isTyping) {
      setState(() {
        _isTyping = isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12, 6, 12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Container(
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
            // Thanh công cụ đính kèm biến thiên mượt mà (Morphing từ 3 nút -> 1 nút +)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.fastOutSlowIn,
              width: _isTyping ? 36.0 : 96.0,
              height: 36.0,
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  child: _isTyping
                      ? SizedBox(
                          key: const ValueKey('plus_btn'),
                          width: 36,
                          height: 36,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.hcmusTeal, size: 22),
                            tooltip: 'Mở rộng tiện ích',
                            onPressed: widget.onShowAttachmentMenu,
                          ),
                        )
                      : SizedBox(
                          key: const ValueKey('icons_row'),
                          width: 96,
                          height: 36,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.hcmusTeal, size: 20),
                                    tooltip: 'Gửi hình ảnh',
                                    onPressed: widget.onPickImage,
                                  ),
                                ),
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.attach_file_rounded, color: AppColors.hcmusTeal, size: 20),
                                    tooltip: 'Gửi tệp đính kèm',
                                    onPressed: widget.onPickFile,
                                  ),
                                ),
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.badge_rounded, color: AppColors.hcmusTeal, size: 20),
                                    tooltip: 'Chia sẻ thông tin liên hệ',
                                    onPressed: widget.onShareContact,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(width: 4),
            // Khung nhập tin nhắn
            Expanded(
              child: TextField(
                controller: widget.controller,
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
                onTap: widget.onSend,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(12, 9, 9, 9),
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
    );
  }
}

class _ChatMessageList extends StatelessWidget {
  final String roomId;
  final String currentUid;
  final String targetUserName;
  final ScrollController scrollController;
  final ChatService chatService;

  const _ChatMessageList({
    required this.roomId,
    required this.currentUid,
    required this.targetUserName,
    required this.scrollController,
    required this.chatService,
  });

  Widget _buildTimeDivider(BuildContext context, DateTime dt) {
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatMessage>>(
      stream: chatService.getMessagesStream(roomId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawMessages = snapshot.data ?? [];
        if (rawMessages.isEmpty) {
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
                    'Đã kết nối với $targetUserName',
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

        final reversedMessages = rawMessages.reversed.toList();

        return ListView.builder(
          controller: scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: reversedMessages.length,
          itemBuilder: (context, index) {
            final msg = reversedMessages[index];
            bool showTimeHeader = false;

            if (index == reversedMessages.length - 1) {
              showTimeHeader = true;
            } else {
              final olderMsg = reversedMessages[index + 1];
              final diffInMinutes = msg.timestamp.difference(olderMsg.timestamp).inMinutes.abs();
              if (diffInMinutes >= 10) {
                showTimeHeader = true;
              }
            }

            final bubble = RepaintBoundary(
              child: ChatBubble(
                key: ValueKey(msg.id),
                message: msg,
                isMe: msg.senderId == currentUid,
                onRecall: () async {
                  try {
                    await chatService.recallMessage(roomId, msg.id);
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
                    await chatService.editMessage(roomId, msg.id, newText);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Không thể sửa tin nhắn: $e')),
                      );
                    }
                  }
                },
              ),
            );

            if (showTimeHeader) {
              return Column(
                key: ValueKey('header_${msg.id}'),
                children: [
                  _buildTimeDivider(context, msg.timestamp),
                  bubble,
                ],
              );
            }

            return bubble;
          },
        );
      },
    );
  }
}
