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
  });

  final String uid;
  final Map<String, dynamic> data;

  final VoidCallback onSuspend;
  final VoidCallback onRestore;
  final VoidCallback onViewActivity;

  @override
  Widget build(BuildContext context) {
    final displayName = data['displayName'] ?? 'Chưa có tên';
    final email = data['email'] ?? '';
    final university = data['university'] ?? 'Chưa có trường';
    final faculty = data['faculty'] ?? 'Chưa có khoa';
    final phone = data['phone'] ?? '';
    final photoUrl = data['photoUrl'] ?? '';
    final status = data['status'] ?? 'active';
    final violationCount = data['violationCount'] ?? 0;
    final suspensionCount = data['suspensionCount'] ?? 0;
    final lastBanReason = data['lastBanReason'] ?? '';

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

    ImageProvider? avatarProvider;

    if (photoUrl.toString().trim().isNotEmpty) {
      try {
        avatarProvider = MemoryImage(base64Decode(photoUrl));
      } catch (_) {
        avatarProvider = null;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFEAF2FF),
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null
                      ? const Icon(Icons.person_outline, color: Colors.blueAccent)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1F37),
                          fontFamily: 'Nunito',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // --- INFO ---
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ModUserInfoChip(icon: Icons.school_outlined, label: university),
                ModUserInfoChip(icon: Icons.apartment_outlined, label: faculty),
                if (phone.toString().trim().isNotEmpty)
                  ModUserInfoChip(icon: Icons.phone_outlined, label: phone),
                ModUserInfoChip(icon: Icons.warning_amber_rounded, label: "Vi phạm: $violationCount"),
                ModUserInfoChip(icon: Icons.lock_clock_outlined, label: "Đã khóa: $suspensionCount"),
                if (lastBanReason.toString().trim().isNotEmpty)
                  ModUserInfoChip(icon: Icons.info_outline, label: "Lý do: $lastBanReason"),
              ],
            ),

            const SizedBox(height: 22),
            const Divider(),
            const SizedBox(height: 12),

            // --- ACTION ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ModActionButton(
                  icon: Icons.history_outlined,
                  label: "XEM HOẠT ĐỘNG",
                  color: Colors.blueGrey,
                  onPressed: onViewActivity,
                ),
                const SizedBox(width: 12),

                if (status == 'active')
                  ModActionButton(
                    icon: Icons.lock_outline,
                    label: "KHÓA TÀI KHOẢN",
                    color: Colors.orange,
                    onPressed: onSuspend,
                  )
                else
                  ModActionButton(
                    icon: Icons.lock_open_outlined,
                    label: "MỞ KHÓA",
                    color: Colors.green,
                    onPressed: onRestore,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}