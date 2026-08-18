import 'dart:convert';
import 'package:flutter/material.dart';
import 'mod_action_button.dart';
import 'mod_chips.dart';

class OfficialNewsCard extends StatelessWidget {
  const OfficialNewsCard({
    super.key,
    required this.docId,
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  final String docId;
  final Map<String, dynamic> data;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'Không có tiêu đề';
    final summary = data['summary'] ?? '';
    final department = data['department'] ?? '';
    final authorName = data['authorName'] ?? 'Official';
    final authorId = data['authorId'] ?? '';
    final authorAvatar = data['authorAvatar'] ?? '';
    final avatarImage = _getAvatarImage(authorAvatar);
    final date = data['publishedDateText'] ?? '';
    final link = data['link'] ?? '';
    final likeCount = data['likeCount'] ?? 0;
    final commentCount = data['commentCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER
            Row(
              children: [
                avatarImage != null
                    ? CircleAvatar(backgroundImage: avatarImage, radius: 16)
                    : const CircleAvatar(
                        backgroundColor: Color(0xFFEAF2FF),
                        radius: 16,
                        child: Icon(
                          Icons.campaign_outlined,
                          color: Colors.blueAccent,
                          size: 18,
                        ),
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      Text(
                        authorId.isNotEmpty ? authorId : department,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    "OFFICIAL NEWS",
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// TITLE
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1F37),
                fontSize: 16,
                height: 1.35,
                fontFamily: 'Nunito',
              ),
            ),

            const SizedBox(height: 8),

            /// DEPARTMENT
            if (department.toString().trim().isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.apartment, size: 14, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      department,
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontFamily: 'Nunito',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            /// DATE
            if (date.toString().trim().isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            /// SUMMARY
            Text(
              summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF4A4A4A),
                fontFamily: 'Nunito',
              ),
            ),

            /// LINK
            if (link.toString().trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, color: Colors.blueAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        link,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 12,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            /// STATS
            Row(
              children: [
                ModStatChip(
                  icon: Icons.favorite_border,
                  label: "$likeCount lượt thích",
                ),
                const SizedBox(width: 8),
                ModStatChip(
                  icon: Icons.chat_bubble_outline,
                  label: "$commentCount bình luận",
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            /// ACTION
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 104,
                    height: 34,
                    child: ModActionButton(
                      icon: Icons.edit_outlined,
                      label: "SỬA BÀI",
                      color: Colors.orange,
                      onPressed: onEdit,
                    ),
                  ),
                  SizedBox(
                    width: 104,
                    height: 34,
                    child: ModActionButton(
                      icon: Icons.delete_sweep,
                      label: "XÓA BÀI",
                      color: Colors.redAccent,
                      onPressed: onDelete,
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

ImageProvider? _getAvatarImage(String? avatar) {
  if (avatar == null || avatar.trim().isEmpty) return null;
  if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
    return NetworkImage(avatar);
  }
  try {
    return MemoryImage(base64Decode(avatar));
  } catch (e) {
    return null;
  }
}
