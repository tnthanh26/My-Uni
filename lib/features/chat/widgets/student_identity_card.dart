import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class StudentIdentitySheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String name = userInfo['displayName'] ?? 'Sinh viên';
    final String email = userInfo['email'] ?? '';
    final String university = userInfo['university'] ?? 'HCMUS - ĐH Khoa học Tự nhiên';
    final String faculty = userInfo['faculty'] ?? 'Chưa cập nhật Khoa';
    final String studentId = userInfo['studentId'] ?? '';
    final String photoURL = userInfo['photoURL'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle indicator
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Avatar với Badge xác thực Google M3
          Stack(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.hcmusTeal.withValues(alpha: 0.15),
                backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                child: photoURL.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.hcmusTeal,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.hcmusTeal,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tên sinh viên
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),

          // Badge Sinh viên xác thực
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.hcmusTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.hcmusTeal.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, size: 14, color: AppColors.hcmusTeal),
                SizedBox(width: 6),
                Text(
                  'Sinh viên HCMUS đã xác thực',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.hcmusTeal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Thẻ thông tin xác thực chi tiết
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  context,
                  Icons.school_rounded,
                  'Trường',
                  university,
                  isDark,
                ),
                const Divider(height: 20),
                _buildInfoRow(
                  context,
                  Icons.account_tree_rounded,
                  'Khoa / Ngành',
                  faculty,
                  isDark,
                ),
                if (email.isNotEmpty) ...[
                  const Divider(height: 20),
                  _buildInfoRow(
                    context,
                    Icons.alternate_email_rounded,
                    'Email xác thực',
                    email,
                    isDark,
                  ),
                ],
                if (studentId.isNotEmpty) ...[
                  const Divider(height: 20),
                  _buildInfoRow(
                    context,
                    Icons.badge_rounded,
                    'Mã sinh viên (MSSV)',
                    studentId,
                    isDark,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Nút Đóng
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.hcmusTeal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Đóng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.hcmusTeal),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
