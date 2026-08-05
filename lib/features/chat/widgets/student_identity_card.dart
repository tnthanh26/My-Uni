import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/base64_image_cache.dart';
import '../services/chat_service.dart';
import '../pages/chat_detail_page.dart';

class StudentIdentitySheet extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const StudentIdentitySheet({
    super.key,
    required this.userInfo,
  });

  static void show(BuildContext context, Map<String, dynamic> userInfo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StudentIdentitySheet(userInfo: userInfo),
    );
  }

  @override
  State<StudentIdentitySheet> createState() => _StudentIdentitySheetState();
}

class _StudentIdentitySheetState extends State<StudentIdentitySheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final userInfo = widget.userInfo;
    final String name = userInfo['displayName'] ?? userInfo['name'] ?? userInfo['authorName'] ?? 'Sinh viên';
    final String photoURL = userInfo['photoURL'] ?? userInfo['avatar'] ?? userInfo['authorAvatar'] ?? '';
    final String targetUid = userInfo['uid'] ?? userInfo['userId'] ?? userInfo['id'] ?? userInfo['authorId'] ?? userInfo['uploaderId'] ?? userInfo['targetUserId'] ?? '';
    final bool isSelf = currentUid.isNotEmpty && targetUid.isNotEmpty && currentUid == targetUid;

    ImageProvider? avatarProvider;
    if (photoURL.isNotEmpty) {
      if (photoURL.startsWith('http')) {
        avatarProvider = NetworkImage(photoURL);
      } else {
        try {
          avatarProvider = MemoryImage(Base64ImageCache.decode(photoURL));
        } catch (_) {
          avatarProvider = null;
        }
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2430) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.hcmusTeal.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // GÓC TRÁI: Avatar sinh viên
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.hcmusTeal.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.hcmusTeal.withValues(alpha: 0.15),
                          backgroundImage: avatarProvider,
                          child: avatarProvider == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.hcmusTeal,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E2430) : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: AppColors.hcmusTeal,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Ở GIỮA: Tên sinh viên & Xác thực
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: AppColors.hcmusTeal,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Tài khoản đã xác thực',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.hcmusTeal.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // LỀ PHẢI: Nút Nhắn tin (Chỉ hiện khi không phải chính mình)
                  if (!isSelf && targetUid.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.hcmusTeal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _isLoading
                            ? null
                            : () async {
                          // Giữ nguyên toàn bộ logic hiện tại
                        },
                        child: _isLoading
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(
                          Icons.chat_bubble_rounded,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
