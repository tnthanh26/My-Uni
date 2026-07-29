import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_colors.dart';
import '../models/chat_models.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onRecall;
  final Function(String newText)? onEdit;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onRecall,
    this.onEdit,
  });

  void _showOptionsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final iconColor = isDark ? Colors.white : const Color(0xFF2C2C2E);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Copy message text
              if (message.text.isNotEmpty && !message.isRecalled)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.copy_rounded, color: iconColor, size: 20),
                  title: const Text('Sao chép', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: message.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép vào bộ nhớ tạm'), duration: Duration(seconds: 1)),
                    );
                  },
                ),

              // Edit message text
              if (message.text.isNotEmpty && !message.isRecalled && onEdit != null)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.edit_outlined, color: iconColor, size: 20),
                  title: const Text('Chỉnh sửa', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(context);
                  },
                ),

              // Recall message
              if (!message.isRecalled && onRecall != null)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.undo_rounded, color: Colors.redAccent, size: 20),
                  title: const Text(
                    'Thu hồi',
                    style: TextStyle(fontSize: 15, color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmRecall(context);
                  },
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  void _confirmRecall(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Thu hồi tin nhắn?'),
        content: const Text('Tin nhắn này sẽ bị gỡ khỏi cuộc trò chuyện đối với cả 2 người.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              if (onRecall != null) onRecall!();
            },
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Chỉnh sửa tin nhắn'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Nhập nội dung mới...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.hcmusTeal),
            onPressed: () {
              final newText = controller.text.trim();
              Navigator.pop(context);
              if (newText.isNotEmpty && onEdit != null) {
                onEdit!(newText);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isOnlyContact = message.contactShare != null && message.text.isEmpty && !message.isRecalled;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: isMe && !message.isRecalled
                  ? () => _showOptionsDialog(context)
                  : null,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: isOnlyContact
                    ? const BoxDecoration(color: Colors.transparent)
                    : BoxDecoration(
                        color: message.isRecalled
                            ? (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))
                            : (isMe
                                ? AppColors.hcmusTeal
                                : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7))),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                        boxShadow: message.isRecalled
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                padding: isOnlyContact
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Nếu là tin nhắn đã thu hồi
                    if (message.isRecalled) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.block_rounded,
                            size: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Tin nhắn đã thu hồi',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Thẻ chia sẻ liên hệ nếu có
                      if (message.contactShare != null) ...[
                        _buildContactShareCard(context, message.contactShare!, isMe, isDark),
                        if (message.text.isNotEmpty) const SizedBox(height: 6),
                      ],

                      // Thẻ file đính kèm nếu có
                      if (message.fileShare != null) ...[
                        _buildFileShareCard(context, message.fileShare!, isMe, isDark),
                        if (message.text.isNotEmpty) const SizedBox(height: 6),
                      ],

                      // Hình ảnh nếu có
                      if (message.imageUrl != null && message.imageUrl!.isNotEmpty) ...[
                        _buildImageContent(message.imageUrl!),
                        if (message.text.isNotEmpty) const SizedBox(height: 6),
                      ],

                      // Nội dung chữ
                      if (message.text.isNotEmpty)
                        Text(
                          message.text,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            color: isMe
                                ? Colors.white
                                : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
                          ),
                        ),
                    ],

                    // Nhãn "Đã sửa" nếu có
                    if (message.isEdited && !message.isRecalled) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Đã sửa',
                        style: TextStyle(
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                          color: isMe
                              ? Colors.white70
                              : (isDark ? Colors.white38 : Colors.black45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(String imageSource) {
    if (imageSource.startsWith('data:image') || imageSource.length > 500) {
      try {
        final cleanBase64 = imageSource.contains(',') ? imageSource.split(',')[1] : imageSource;
        final bytes = base64Decode(cleanBase64.trim());
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white70),
          ),
        );
      } catch (e) {
        return const Icon(Icons.broken_image, color: Colors.white70);
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageSource,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white70),
      ),
    );
  }

  Widget _buildFileShareCard(
    BuildContext context,
    Map<String, String> fileData,
    bool isMe,
    bool isDark,
  ) {
    final fileName = fileData['fileName'] ?? 'Tài liệu đính kèm';
    final fileSize = fileData['fileSize'] ?? '';
    final ext = (fileData['extension'] ?? '').toLowerCase();

    IconData fileIcon = Icons.insert_drive_file_rounded;
    Color iconColor = AppColors.hcmusTeal;

    if (ext == 'pdf') {
      fileIcon = Icons.picture_as_pdf_rounded;
      iconColor = Colors.redAccent;
    } else if (['doc', 'docx'].contains(ext)) {
      fileIcon = Icons.description_rounded;
      iconColor = Colors.blueAccent;
    } else if (['xls', 'xlsx'].contains(ext)) {
      fileIcon = Icons.table_chart_rounded;
      iconColor = Colors.green;
    } else if (['zip', 'rar', '7z'].contains(ext)) {
      fileIcon = Icons.folder_zip_rounded;
      iconColor = Colors.amber;
    }

    return Container(
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.15)
            : (isDark ? const Color(0xFF3A3A3C) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? Colors.white24 : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(fileIcon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileSize.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    fileSize,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : (isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactShareCard(
    BuildContext context,
    Map<String, String> contact,
    bool isMe,
    bool isDark,
  ) {
    final type = (contact['type'] ?? 'zalo').toLowerCase();
    final value = contact['value'] ?? '';
    final name = contact['name'] ?? 'Sinh viên';

    IconData brandIcon;
    Color brandColor;
    String brandName;
    String actionLabel = 'Sao chép';
    bool isUrl = false;

    switch (type) {
      case 'facebook':
        brandIcon = Icons.facebook_rounded;
        brandColor = const Color(0xFF1877F2);
        brandName = 'Facebook';
        isUrl = value.contains('facebook.com') || value.startsWith('http');
        if (isUrl) actionLabel = 'Mở trang';
        break;
      case 'discord':
        brandIcon = Icons.headset_mic_rounded;
        brandColor = const Color(0xFF5865F2);
        brandName = 'Discord';
        break;
      case 'phone':
        brandIcon = Icons.phone_android_rounded;
        brandColor = const Color(0xFF10B981);
        brandName = 'Số điện thoại';
        actionLabel = 'Sao chép';
        break;
      case 'zalo':
      default:
        brandIcon = Icons.chat_bubble_rounded;
        brandColor = const Color(0xFF0068FF);
        brandName = 'Zalo';
        isUrl = value.contains('zalo.me') || value.startsWith('http');
        if (isUrl) actionLabel = 'Mở Zalo';
        break;
    }

    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final Color textColorPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color textColorSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color valueBoxBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Solid Brand Banner Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: isDark ? 0.2 : 0.1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: brandColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: brandColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(brandIcon, size: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brandName,
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textColorPrimary,
                          ),
                        ),
                        Text(
                          'Liên hệ của $name',
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 10,
                            color: textColorSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card Body: Contact Value & Action Button
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: valueBoxBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cardBorder),
                    ),
                    child: SelectableText(
                      value,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColorPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            if (isUrl) {
                              try {
                                String url = value;
                                if (!url.startsWith('http')) url = 'https://$url';
                                final uri = Uri.parse(url);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  return;
                                }
                              } catch (_) {}
                            }
                            await Clipboard.setData(ClipboardData(text: value));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã sao chép $brandName: $value'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 34,
                            decoration: BoxDecoration(
                              color: brandColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isUrl ? Icons.open_in_new_rounded : Icons.copy_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  actionLabel,
                                  style: const TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isUrl) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: value));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã sao chép liên kết $brandName'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 15,
                              color: brandColor,
                            ),
                          ),
                        ),
                      ],
                    ],
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
