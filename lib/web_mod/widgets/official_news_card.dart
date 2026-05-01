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
    final date = data['date'] ?? '';
    final link = data['link'] ?? '';
    final likeCount = data['likeCount'] ?? 0;
    final commentCount = data['commentCount'] ?? 0;

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
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER
            Row(
              children: [
                authorAvatar.toString().trim().isNotEmpty
                    ? CircleAvatar(
                  backgroundImage: NetworkImage(authorAvatar),
                  radius: 22,
                )
                    : const CircleAvatar(
                  backgroundColor: Color(0xFFEAF2FF),
                  radius: 22,
                  child: Icon(Icons.campaign_outlined, color: Colors.blueAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      Text(
                        authorId.isNotEmpty ? authorId : department,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "OFFICIAL NEWS",
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// TITLE
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1F37),
                fontSize: 20,
                fontFamily: 'Nunito',
              ),
            ),

            const SizedBox(height: 10),

            /// DEPARTMENT
            if (department.toString().trim().isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.apartment, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      department,
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontFamily: 'Nunito',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            /// DATE
            if (date.toString().trim().isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            /// SUMMARY
            Text(
              summary,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Color(0xFF4A4A4A),
                fontFamily: 'Nunito',
              ),
            ),

            /// LINK
            if (link.toString().trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, color: Colors.blueAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        link,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 13,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            /// STATS
            Row(
              children: [
                ModStatChip(icon: Icons.favorite_border, label: "$likeCount lượt thích"),
                const SizedBox(width: 10),
                ModStatChip(icon: Icons.chat_bubble_outline, label: "$commentCount bình luận"),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            /// ACTION
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ModActionButton(
                  icon: Icons.edit_outlined,
                  label: "SỬA BÀI",
                  color: Colors.orange,
                  onPressed: onEdit,
                ),
                const SizedBox(width: 12),
                ModActionButton(
                  icon: Icons.delete_sweep,
                  label: "XÓA BÀI",
                  color: Colors.redAccent,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}