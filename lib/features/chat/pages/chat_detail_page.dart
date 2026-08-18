import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/student_identity_card.dart';
import '../../../utils/base64_image_cache.dart';
import 'package:my_uni/widgets/app_action_dialogs.dart';

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
    _chatService.cleanupExpiredMessages(widget.roomId);
  }

  Future<void> _loadTargetUserInfo() async {
    final info = await _chatService.getStudentVerificationInfo(
      widget.targetUserId,
    );
    if (mounted && info != null) {
      setState(() {
        _targetUserInfo = info;
      });
    }
  }

  void _confirmDeleteChatRoom() async {
    final confirm = await AppActionDialogs.showConfirmDialog(
      context: context,
      title: 'Xóa cuộc trò chuyện?',
      message:
          'Toàn bộ tin nhắn trong cuộc trò chuyện này sẽ bị xóa. Bạn có chắc chắn không?',
      confirmText: 'Xóa',
    );
    if (confirm == true) {
      try {
        await _chatService.deleteChatRoom(widget.roomId);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi xóa cuộc trò chuyện: $e')),
          );
        }
      }
    }
  }

  void _showChatOptionsMenu() {
    AppActionDialogs.showActionBottomSheet(
      context: context,
      title: 'Tùy chọn cuộc trò chuyện',
      actions: [
        AppActionItem(
          title: 'Báo cáo cuộc trò chuyện',
          icon: Icons.report_gmailerrorred_outlined,
          onTap: _showReportUserOptions,
        ),
        AppActionItem(
          title: 'Xóa cuộc trò chuyện',
          icon: Icons.delete_outline_rounded,
          isDanger: true,
          onTap: _confirmDeleteChatRoom,
        ),
      ],
    );
  }

  Future<void> _showReportUserOptions() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _ReportUserBottomSheet(onSubmitReport: _submitUserReport);
      },
    );
  }

  Future<void> _submitUserReport(String reason) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': currentUid,
        'reportedUserId': widget.targetUserId,
        'reportedUserName': widget.targetUserName,
        'roomId': widget.roomId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'type': 'chat_user',
      });

      if (mounted) {
        _showSuccessReportDialog(
          "Cảm ơn bạn đã đóng góp ý kiến. Ban quản trị sẽ tiến hành kiểm tra lịch sử trò chuyện và thông tin người dùng này để xử lý vi phạm trong thời gian sớm nhất.",
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi báo cáo: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSuccessReportDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDarkMode =
            Theme.of(dialogContext).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Gửi báo cáo thành công",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 13,
                    height: 1.45,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5893D8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Đồng ý",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
          SnackBar(
            content: Text(
              'Lỗi khi gửi tin nhắn: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
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

      // Hiển thị thông báo đang tải lên
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang tải hình ảnh lên...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Tải hình ảnh lên Firebase Storage
      final fileName = 'chat_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(
        'chat_images/$fileName',
      );

      final uploadTask = storageRef.putData(
        compressedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await _chatService.sendMessage(widget.roomId, '', imageUrl: downloadUrl);
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error picking/sending image: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể gửi hình ảnh: $e')));
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'zip',
          'rar',
          'txt',
        ],
      );
      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.first;
      // Firestore document max limit is 1MB (~750KB binary -> ~1MB Base64)
      if (platformFile.size > 750 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng chọn tệp nhỏ hơn 750KB để gửi đính kèm'),
            ),
          );
        }
        return;
      }

      Uint8List? bytes = platformFile.bytes;
      if (bytes == null && platformFile.path != null) {
        final file = File(platformFile.path!);
        bytes = await file.readAsBytes();
      }

      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể đọc dữ liệu tệp đính kèm')),
          );
        }
        return;
      }

      final fileName = platformFile.name;
      String extension = platformFile.extension ?? '';
      if (extension.contains('.')) {
        extension = extension.split('.').last;
      }
      if (extension.isEmpty && fileName.contains('.')) {
        extension = fileName.split('.').last;
      }
      extension = extension.trim().toLowerCase();
      final sizeKb = (platformFile.size / 1024).toStringAsFixed(1);
      final fileSize = platformFile.size > 1024 * 1024
          ? '${(platformFile.size / (1024 * 1024)).toStringAsFixed(1)} MB'
          : '$sizeKb KB';

      final base64Data = base64Encode(bytes);

      await _chatService.sendMessage(
        widget.roomId,
        '',
        fileShare: {
          'fileName': fileName,
          'fileSize': fileSize,
          'extension': extension,
          'fileData': base64Data,
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
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? brandColor
                : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? brandColor
                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : brandColor)
                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
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
    String myFirestoreName = '';
    if (myUid.isNotEmpty) {
      savedContacts = await _chatService.getUserSocialContacts(myUid);
      try {
        final myProfile = await _chatService.getStudentVerificationInfo(myUid);
        if (myProfile != null) {
          myFirestoreName = myProfile['displayName'] ?? '';
        }
      } catch (e) {
        debugPrint("Error fetching current user profile name: $e");
      }
    }

    if (!mounted) return;

    final zaloController = TextEditingController(
      text: savedContacts['zalo'] ?? '',
    );
    final fbController = TextEditingController(
      text: savedContacts['facebook'] ?? '',
    );
    final phoneController = TextEditingController(
      text: savedContacts['phone'] ?? '',
    );
    final discordController = TextEditingController(
      text: savedContacts['discord'] ?? '',
    );

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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
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
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1F2937),
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
                          _buildBrandChip(
                            'facebook',
                            'Facebook',
                            Icons.facebook_rounded,
                            const Color(0xFF1877F2),
                            selectedType,
                            (type) => setDialogState(() => selectedType = type),
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildBrandChip(
                            'zalo',
                            'Zalo',
                            Icons.chat_bubble_rounded,
                            const Color(0xFF0068FF),
                            selectedType,
                            (type) => setDialogState(() => selectedType = type),
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildBrandChip(
                            'discord',
                            'Discord',
                            Icons.headset_mic_rounded,
                            const Color(0xFF5865F2),
                            selectedType,
                            (type) => setDialogState(() => selectedType = type),
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildBrandChip(
                            'phone',
                            'SĐT',
                            Icons.phone_android_rounded,
                            const Color(0xFF10B981),
                            selectedType,
                            (type) => setDialogState(() => selectedType = type),
                            isDark,
                          ),
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
                        fillColor: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFE2E8F0),
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
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey[600],
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final String val = currentController.text.trim();
                              if (val.isEmpty) return;

                              Navigator.pop(context);

                              final myName = myFirestoreName.isNotEmpty
                                  ? myFirestoreName
                                  : (myUser?.displayName ?? 'Sinh viên');

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
                  leading: const Icon(
                    Icons.add_photo_alternate_rounded,
                    color: AppColors.hcmusTeal,
                  ),
                  title: const Text(
                    'Gửi hình ảnh',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.attach_file_rounded,
                    color: AppColors.hcmusTeal,
                  ),
                  title: const Text(
                    'Gửi tệp đính kèm',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendFile();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.badge_rounded,
                    color: AppColors.hcmusTeal,
                  ),
                  title: const Text(
                    'Chia sẻ thông tin liên hệ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
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
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
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
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.targetUserId)
                .snapshots(),
            builder: (context, userSnap) {
              String resolvedName = widget.targetUserName;
              String resolvedPhoto =
                  Base64ImageCache.getCachedUserAvatar(widget.targetUserId) ??
                  widget.targetUserPhoto;

              if (userSnap.hasData && userSnap.data?.data() != null) {
                final uData = userSnap.data!.data() as Map<String, dynamic>;
                resolvedName =
                    uData['displayName'] ??
                    uData['name'] ??
                    uData['fullName'] ??
                    widget.targetUserName;
                resolvedPhoto =
                    uData['photoURL'] ??
                    uData['photoUrl'] ??
                    uData['avatar'] ??
                    uData['authorAvatar'] ??
                    uData['avatarUrl'] ??
                    uData['userAvatar'] ??
                    resolvedPhoto;
                Base64ImageCache.updateUserAvatar(
                  widget.targetUserId,
                  resolvedPhoto,
                );
              }

              final avatarProvider = Base64ImageCache.getAvatarProvider(
                resolvedPhoto,
              );

              return Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.hcmusTeal.withValues(
                      alpha: 0.15,
                    ),
                    backgroundImage: avatarProvider,
                    child: avatarProvider == null
                        ? Text(
                            resolvedName.trim().isNotEmpty
                                ? resolvedName.trim()[0].toUpperCase()
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
                                resolvedName,
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
              );
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Tùy chọn cuộc trò chuyện',
            onPressed: _showChatOptionsMenu,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            /*
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
            ),*/

            // Realtime Message Stream List (Isolated Widget to prevent rebuild lag during typing)
            Expanded(
              child: _ChatMessageList(
                roomId: widget.roomId,
                currentUid: currentUid,
                targetUserName: widget.targetUserName,
                targetUserPhoto: widget.targetUserPhoto,
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
        12,
        6,
        12,
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
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: AppColors.hcmusTeal,
                              size: 22,
                            ),
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
                                    icon: const Icon(
                                      Icons.add_photo_alternate_rounded,
                                      color: AppColors.hcmusTeal,
                                      size: 20,
                                    ),
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
                                    icon: const Icon(
                                      Icons.attach_file_rounded,
                                      color: AppColors.hcmusTeal,
                                      size: 20,
                                    ),
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
                                    icon: const Icon(
                                      Icons.badge_rounded,
                                      color: AppColors.hcmusTeal,
                                      size: 20,
                                    ),
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
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
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

class _ChatMessageList extends StatefulWidget {
  final String roomId;
  final String currentUid;
  final String targetUserName;
  final String targetUserPhoto;
  final ScrollController scrollController;
  final ChatService chatService;

  const _ChatMessageList({
    required this.roomId,
    required this.currentUid,
    required this.targetUserName,
    required this.targetUserPhoto,
    required this.scrollController,
    required this.chatService,
  });

  @override
  State<_ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<_ChatMessageList> {
  late Stream<List<ChatMessage>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = widget.chatService.getMessagesStream(widget.roomId);
  }

  @override
  void didUpdateWidget(covariant _ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _messagesStream = widget.chatService.getMessagesStream(widget.roomId);
    }
  }

  Widget _buildTimeDivider(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(dt);
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(dt);
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
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
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawMessages = snapshot.data ?? [];

        // Tự động đánh dấu đã đọc khi nhận tin nhắn mới và đang ở trong màn hình này
        final hasUnread = rawMessages.any(
          (m) => m.senderId != widget.currentUid && !m.isRead,
        );
        if (hasUnread) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.chatService.markRoomAsRead(widget.roomId);
          });
        }

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

        return LayoutBuilder(
          builder: (context, constraints) {
            final List<Widget> messageWidgets = [];

            int lastSentMsgIndex = -1;
            for (int i = rawMessages.length - 1; i >= 0; i--) {
              if (rawMessages[i].senderId == widget.currentUid) {
                lastSentMsgIndex = i;
                break;
              }
            }

            for (int i = 0; i < rawMessages.length; i++) {
              final msg = rawMessages[i];
              bool showTimeHeader = false;

              if (i == 0) {
                showTimeHeader = true;
              } else {
                final olderMsg = rawMessages[i - 1];
                final diffInMinutes = msg.timestamp
                    .difference(olderMsg.timestamp)
                    .inMinutes
                    .abs();
                if (diffInMinutes >= 10) {
                  showTimeHeader = true;
                }
              }

              if (showTimeHeader) {
                messageWidgets.add(_buildTimeDivider(context, msg.timestamp));
              }

              messageWidgets.add(
                RepaintBoundary(
                  child: ChatBubble(
                    key: ValueKey(msg.id),
                    message: msg,
                    isMe: msg.senderId == widget.currentUid,
                    showStatus: i == lastSentMsgIndex,
                    onRecall: () async {
                      try {
                        await widget.chatService.recallMessage(
                          widget.roomId,
                          msg.id,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Không thể thu hồi tin nhắn: $e'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              controller: widget.scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 24).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: messageWidgets,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportUserBottomSheet extends StatefulWidget {
  final Function(String) onSubmitReport;

  const _ReportUserBottomSheet({required this.onSubmitReport});

  @override
  State<_ReportUserBottomSheet> createState() => _ReportUserBottomSheetState();
}

class _ReportUserBottomSheetState extends State<_ReportUserBottomSheet> {
  final List<String> reportReasons = [
    'Quấy rối / Đe dọa',
    'Ngôn từ thô tục / Xúc phạm',
    'Spam / Quảng cáo không mong muốn',
    'Mạo danh người khác',
    'Hành vi quấy rối học tập',
    'Khác',
  ];

  bool isOtherSelected = false;
  late final TextEditingController customReasonController;

  @override
  void initState() {
    super.initState();
    customReasonController = TextEditingController();
  }

  @override
  void dispose() {
    customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color sheetColor = isDarkMode
        ? const Color(0xFF1C1C1E)
        : Colors.white;
    final Color primaryTextColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1F1F1F);
    final Color secondaryTextColor = isDarkMode
        ? const Color(0xFFB0B3B8)
        : const Color(0xFF65676B);
    final Color surfaceColor = isDarkMode
        ? const Color(0xFF292A2D)
        : const Color(0xFFF5F6F7);
    final Color borderColor = isDarkMode
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFE4E6EB);
    final Color accentColor = isDarkMode
        ? const Color(0xFF8AB4F8)
        : const Color(0xFF1A73E8);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Báo cáo người dùng",
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "Chọn lý do phù hợp nhất",
                            style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: surfaceColor,
                        minimumSize: const Size(38, 38),
                      ),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: borderColor),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...reportReasons.map((reason) {
                        final bool isSelected =
                            reason == "Khác" && isOtherSelected;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Material(
                            color: isSelected
                                ? accentColor.withOpacity(
                                    isDarkMode ? 0.14 : 0.08,
                                  )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () {
                                if (reason == "Khác") {
                                  FocusScope.of(context).unfocus();
                                  setState(() {
                                    isOtherSelected = true;
                                  });
                                } else {
                                  Navigator.pop(context);
                                  widget.onSubmitReport(reason);
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? accentColor.withOpacity(
                                                isDarkMode ? 0.18 : 0.10,
                                              )
                                            : surfaceColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        reason == "Khác"
                                            ? Icons.edit_outlined
                                            : Icons.report_problem_outlined,
                                        size: 19,
                                        color: isSelected
                                            ? accentColor
                                            : secondaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        reason,
                                        style: TextStyle(
                                          fontFamily: 'Encode Sans Expanded',
                                          fontSize: 13,
                                          height: 1.35,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      isSelected
                                          ? Icons.expand_less_rounded
                                          : Icons.chevron_right_rounded,
                                      size: 21,
                                      color: isSelected
                                          ? accentColor
                                          : secondaryTextColor.withOpacity(0.6),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (isOtherSelected)
                        Padding(
                          key: const ValueKey('custom-report-section'),
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Mô tả lý do",
                                        style: TextStyle(
                                          fontFamily: 'Encode Sans Expanded',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        FocusScope.of(context).unfocus();
                                        setState(() {
                                          isOtherSelected = false;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: customReasonController,
                                  minLines: 3,
                                  maxLines: 5,
                                  maxLength: 300,
                                  textInputAction: TextInputAction.newline,
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 13,
                                    height: 1.4,
                                    color: primaryTextColor,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        "Nhập lý do báo cáo người dùng này...",
                                    hintStyle: TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontSize: 12,
                                      color: secondaryTextColor,
                                    ),
                                    counterStyle: TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontSize: 10,
                                      color: secondaryTextColor,
                                    ),
                                    filled: true,
                                    fillColor: sheetColor,
                                    contentPadding: const EdgeInsets.all(14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: borderColor,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: borderColor,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: accentColor,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: FilledButton(
                                    onPressed: () {
                                      String customReason =
                                          customReasonController.text.trim();
                                      if (customReason.isNotEmpty) {
                                        Navigator.pop(context);
                                        widget.onSubmitReport(
                                          "Khác: $customReason",
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context)
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Vui lòng nhập lý do báo cáo",
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                      }
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: accentColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      "Gửi báo cáo",
                                      style: TextStyle(
                                        fontFamily: 'Encode Sans Expanded',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
