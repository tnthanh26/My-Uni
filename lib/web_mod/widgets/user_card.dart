import 'dart:convert';
import 'package:flutter/material.dart';
import 'mod_action_button.dart';
import 'mod_chips.dart';

class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.uid,
    required this.data,
    required this.onSuspend,
    required this.onRestore,
    required this.onViewActivity,
    this.onApproveVerification,
    this.onRejectVerification,
    this.onDeleteUser,
  });

  final String uid;
  final Map<String, dynamic> data;

  final VoidCallback onSuspend;
  final VoidCallback onRestore;
  final VoidCallback onViewActivity;
  final VoidCallback? onApproveVerification;
  final VoidCallback? onRejectVerification;
  final VoidCallback? onDeleteUser;

  @override
  Widget build(BuildContext context) {
    final displayName = data['displayName'] ?? 'Chưa có tên';
    final email = data['email'] ?? '';
    final university = data['university'] ?? 'Chưa có trường';
    final faculty = data['faculty'] ?? 'Chưa có khoa';
    final studentId = data['studentId'] ?? '';
    final photoUrl = data['photoUrl'] ?? '';
    final status = data['status'] ?? 'active';
    final violationCount = data['violationCount'] ?? 0;
    final suspensionCount = data['suspensionCount'] ?? 0;
    final lastBanReason = data['lastBanReason'] ?? '';

    final bool isVerified = data['isVerified'] ?? false;
    final String verificationStatus =
        data['verificationStatus'] ?? (isVerified ? 'approved' : 'pending');

    Color statusColor;
    String statusText;

    switch (status) {
      case 'suspended':
        statusColor = Colors.orange;
        statusText = 'Đang bị khóa';
        break;
      default:
        statusColor = Colors.green;
        statusText = 'Đang hoạt động';
    }

    Color verifyColor;
    String verifyText;
    if (isVerified || verificationStatus == 'approved') {
      verifyColor = const Color(0xFF6797E1);
      verifyText = 'Đã xác thực';
    } else if (verificationStatus == 'rejected') {
      verifyColor = Colors.redAccent;
      verifyText = 'Từ chối xác thực';
    } else {
      verifyColor = Colors.amber.shade800;
      verifyText = 'Chờ duyệt xác thực';
    }

    ImageProvider? avatarProvider;

    if (photoUrl.toString().trim().isNotEmpty) {
      try {
        avatarProvider = MemoryImage(base64Decode(photoUrl));
      } catch (_) {
        avatarProvider = null;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: const Color(0xFFEAF2FF),
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null
                      ? const Icon(
                          Icons.person_outline,
                          color: Colors.blueAccent,
                          size: 19,
                        )
                      : null,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1F37),
                                fontFamily: 'Nunito',
                              ),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: Color(0xFF6797E1),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        email.isNotEmpty ? email : (studentId.isNotEmpty ? 'MSSV: $studentId' : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Verification Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: verifyColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    verifyText,
                    style: TextStyle(
                      color: verifyColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Account Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // INFO CHIPS
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (studentId.isNotEmpty)
                  ModUserInfoChip(
                    icon: Icons.badge_outlined,
                    label: "MSSV: $studentId",
                  ),
                ModUserInfoChip(
                  icon: Icons.school_outlined,
                  label: university,
                ),
                ModUserInfoChip(
                  icon: Icons.apartment_outlined,
                  label: faculty,
                ),
                ModUserInfoChip(
                  icon: Icons.warning_amber_rounded,
                  label: "$violationCount VP",
                ),
                ModUserInfoChip(
                  icon: Icons.lock_clock_outlined,
                  label: "$suspensionCount khóa",
                ),
              ],
            ),

            if (lastBanReason.toString().trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Lý do khóa gần nhất: $lastBanReason",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Nunito',
                ),
              ),
            ],

            const SizedBox(height: 10),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 10),

            // ACTIONS
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (onApproveVerification != null &&
                      (verificationStatus == 'pending' || verificationStatus == 'rejected' || !isVerified))
                    SizedBox(
                      width: 140,
                      height: 38,
                      child: ModActionButton(
                        icon: Icons.verified_user_outlined,
                        label: verificationStatus == 'rejected' ? "Duyệt lại" : "Duyệt xác thực",
                        color: Colors.green,
                        onPressed: onApproveVerification!,
                      ),
                    ),
                  if (onRejectVerification != null &&
                      (verificationStatus == 'pending' || (!isVerified && verificationStatus != 'rejected')))
                    SizedBox(
                      width: 110,
                      height: 38,
                      child: ModActionButton(
                        icon: Icons.cancel_outlined,
                        label: "Từ chối",
                        color: Colors.redAccent,
                        onPressed: onRejectVerification!,
                      ),
                    ),
                  if (onDeleteUser != null && verificationStatus == 'rejected')
                    SizedBox(
                      width: 135,
                      height: 38,
                      child: ModActionButton(
                        icon: Icons.delete_forever_outlined,
                        label: "Xóa tài khoản",
                        color: Colors.red.shade900,
                        onPressed: onDeleteUser!,
                      ),
                    ),
                  SizedBox(
                    width: 130,
                    height: 38,
                    child: ModActionButton(
                      icon: Icons.history_outlined,
                      label: "Hoạt động",
                      color: Colors.blueGrey,
                      onPressed: onViewActivity,
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    height: 38,
                    child: status == 'active'
                        ? ModActionButton(
                            icon: Icons.lock_outline,
                            label: "Khóa",
                            color: Colors.orange,
                            onPressed: onSuspend,
                          )
                        : ModActionButton(
                            icon: Icons.lock_open_outlined,
                            label: "Mở khóa",
                            color: Colors.green,
                            onPressed: onRestore,
                          ),
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