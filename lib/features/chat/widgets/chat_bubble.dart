import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/base64_image_cache.dart';
import '../models/chat_models.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onRecall;
  final bool showStatus;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onRecall,
    this.showStatus = false,
  });

  Future<void> _handleOpenFile(
    BuildContext context,
    String base64Data,
    String fileName, {
    String extension = '',
  }) async {
    if (base64Data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tệp này không chứa dữ liệu hoặc được gửi từ phiên bản cũ."),
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Đang chuẩn bị tài liệu..."),
          duration: Duration(seconds: 1),
        ),
      );

      // Làm sạch dữ liệu Base64 nếu có tiền tố data URI
      String cleanBase64 = base64Data.trim();
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last.trim();
      }

      // Ghép extension vào fileName nếu tên file chưa có đuôi mở rộng
      String safeFileName = fileName.trim();
      final cleanExt = extension.toLowerCase().replaceAll('.', '').trim();
      if (cleanExt.isNotEmpty && !safeFileName.toLowerCase().endsWith('.$cleanExt')) {
        safeFileName = '$safeFileName.$cleanExt';
      }
      safeFileName = safeFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$safeFileName';
      final file = File(filePath);

      await file.writeAsBytes(base64Decode(cleanBase64));
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Không thể mở tệp (${result.message}). Vui lòng kiểm tra ứng dụng đọc tệp trên thiết bị.",
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi khi mở tệp: $e")),
        );
      }
    }
  }

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


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isOnlyContact = message.contactShare != null && message.text.isEmpty && !message.isRecalled;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
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

                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Hiển thị trạng thái gửi/đọc tin nhắn dưới bong bóng chat
          if (showStatus && isMe && !message.isRecalled)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(
                message.isRead ? 'Đã xem' : 'Đã gửi',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: message.isRead
                      ? AppColors.hcmusTeal
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageContent(String imageSource) {
    if (imageSource.startsWith('data:image') || imageSource.length > 500) {
      final provider = Base64ImageCache.getMemoryImage(imageSource);
      if (provider == null) return const Icon(Icons.broken_image, color: Colors.white70);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: provider,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white70),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageSource,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white70),
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
    
    String rawExt = fileData['extension'] ?? '';
    if (rawExt.contains('.')) {
      rawExt = rawExt.split('.').last;
    }
    if (rawExt.isEmpty && fileName.contains('.')) {
      rawExt = fileName.split('.').last;
    }
    final ext = rawExt.trim().toLowerCase();

    final base64Content =
        fileData['fileData'] ?? fileData['base64'] ?? '';

    IconData fileIcon = Icons.insert_drive_file_outlined;
    Color iconColor = AppColors.hcmusTeal;
    String fileTypeLabel = ext.isNotEmpty
        ? ext.toUpperCase()
        : 'TỆP';

    if (ext == 'pdf') {
      fileIcon = Icons.picture_as_pdf_outlined;
      iconColor = const Color(0xFFE5484D);
    } else if (['doc', 'docx'].contains(ext)) {
      fileIcon = Icons.description_outlined;
      iconColor = const Color(0xFF5893D8);
    } else if (['xls', 'xlsx'].contains(ext)) {
      fileIcon = Icons.table_chart_outlined;
      iconColor = const Color(0xFF2E9D65);
    } else if (['zip', 'rar', '7z'].contains(ext)) {
      fileIcon = Icons.folder_zip_outlined;
      iconColor = const Color(0xFFD99518);
    }

    final Color cardColor = isMe
        ? Colors.white.withValues(alpha: 0.12)
        : (isDark
        ? const Color(0xFF1C1E21)
        : Colors.white);

    final Color borderColor = isMe
        ? Colors.white.withValues(alpha: 0.18)
        : (isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE4E7EC));

    final Color primaryTextColor = isMe
        ? Colors.white
        : (isDark
        ? Colors.white
        : const Color(0xFF1D2939));

    final Color secondaryTextColor = isMe
        ? Colors.white70
        : (isDark
        ? Colors.white54
        : const Color(0xFF667085));

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          _handleOpenFile(
            context,
            base64Content,
            fileName,
            extension: ext,
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.12)
                      : iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  fileIcon,
                  size: 22,
                  color: isMe ? Colors.white : iconColor,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withValues(
                                alpha: 0.10,
                              )
                                  : iconColor.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius:
                              BorderRadius.circular(6),
                            ),
                            child: Text(
                              fileTypeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily:
                                'Encode Sans Expanded',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isMe
                                    ? Colors.white70
                                    : iconColor,
                              ),
                            ),
                          ),
                        ),
                        if (fileSize.isNotEmpty) ...[
                          const SizedBox(width: 7),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: secondaryTextColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              fileSize,
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily:
                                'Encode Sans Expanded',
                                fontSize: 10.5,
                                color:
                                secondaryTextColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.10)
                      : (isDark
                      ? Colors.white.withValues(
                    alpha: 0.06,
                  )
                      : const Color(0xFFF5F7FA)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: isMe
                      ? Colors.white70
                      : secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
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

    final Color cardBg =
        isDark ? const Color(0xFF1E293B) : Colors.white;

    final Color cardBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final Color textColorPrimary =
        isDark ? Colors.white : const Color(0xFF0F172A);

    final Color textColorSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final Color valueBoxBg =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    Future<void> copyValue() async {
      await Clipboard.setData(ClipboardData(text: value));

      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Đã sao chép $brandName'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }

    Future<void> openValue() async {
      if (!isUrl) {
        await copyValue();
        return;
      }

      try {
        String url = value;

        if (!url.startsWith('http')) {
          url = 'https://$url';
        }

        final uri = Uri.parse(url);

        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          return;
        }
      } catch (_) {}

      await copyValue();
    }

    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.18 : 0.05,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: brandColor.withValues(
                    alpha: isDark ? 0.18 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  brandIcon,
                  size: 21,
                  color: brandColor,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brandName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColorPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Liên hệ của $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: textColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: valueBoxBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cardBorder,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: isUrl ? openValue : null,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        12,
                        11,
                        8,
                        11,
                      ),
                      child: SelectableText(
                        value,
                        maxLines: 2,
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: isUrl
                              ? brandColor
                              : textColorPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: cardBorder,
                ),
                Tooltip(
                  message: 'Sao chép',
                  child: InkWell(
                    onTap: copyValue,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(12),
                    ),
                    child: SizedBox(
                      width: 43,
                      height: 43,
                      child: Icon(
                        Icons.content_copy_rounded,
                        size: 17,
                        color: brandColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUrl) ...[
            const SizedBox(height: 7),
            InkWell(
              onTap: openValue,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: brandColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 13,
                      color: brandColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
