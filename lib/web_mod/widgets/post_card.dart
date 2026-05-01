import 'dart:convert';
import 'package:flutter/material.dart';
import 'mod_action_button.dart';
import 'mod_chips.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.docId,
    required this.data,
    required this.collection,
    required this.onApprove,
    required this.onDelete,
    required this.onRestore,
    required this.onDismissReport,
    required this.onViewMaterial,
  });

  final String docId;
  final Map<String, dynamic> data;
  final String collection;

  final VoidCallback onApprove;
  final VoidCallback onDelete;
  final VoidCallback onRestore;
  final VoidCallback onDismissReport;
  final VoidCallback onViewMaterial;

  @override
  Widget build(BuildContext context) {
    double toxicity = (data['toxicityScore'] ?? 0).toDouble();
    bool isReported = data['isReported'] ?? false;
    int reportCount = data['reportCount'] ?? 0;

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
                const CircleAvatar(
                  backgroundColor: Color(0xFFF0F2F5),
                  child: Icon(Icons.person_outline, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['authorName'] ?? "Ẩn danh",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    Text(
                      data['timestamp']?.toDate().toString().substring(0, 16) ?? "",
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                if (isReported)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Báo cáo: $reportCount",
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ModToxicityBadge(toxicity: toxicity),
              ],
            ),

            const SizedBox(height: 20),

            /// CONTENT (tuỳ loại collection)
            if (collection == 'course_reviews') ...[
              Text(
                "Môn học: ${data['courseName']}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                  fontSize: 17,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (collection == 'study_materials') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, color: Colors.blueGrey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        data['fileName'] ?? "File",
                        style: const TextStyle(fontFamily: 'Nunito'),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: onViewMaterial,
                      child: const Text("XEM"),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (collection == 'forum_posts' && data['hashtags'] != null) ...[
              Wrap(
                spacing: 8,
                children: (data['hashtags'] as List)
                    .map((t) => Text(
                  "#$t",
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ))
                    .toList(),
              ),
              const SizedBox(height: 10),
            ],

            Text(
              data['content'] ?? "",
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),

            if (data['imageUrl'] != null && data['imageUrl'] != '') ...[
              const SizedBox(height: 16),
              Image.memory(base64Decode(data['imageUrl'])),
            ],

            const SizedBox(height: 20),
            const Divider(),

            /// ACTION
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (data['status'] != 'hidden') ...[
                  if (isReported)
                    ModActionButton(
                      icon: Icons.refresh,
                      label: "HỦY BÁO CÁO",
                      color: Colors.blueGrey,
                      onPressed: onDismissReport,
                    ),
                  const SizedBox(width: 10),
                  ModActionButton(
                    icon: Icons.delete,
                    label: "XÓA",
                    color: Colors.redAccent,
                    onPressed: onDelete,
                  ),
                  const SizedBox(width: 10),
                  if (data['status'] == 'pending')
                    ModActionButton(
                      icon: Icons.check,
                      label: "DUYỆT",
                      color: Colors.green,
                      onPressed: onApprove,
                    ),
                ] else
                  ModActionButton(
                    icon: Icons.restore,
                    label: "KHÔI PHỤC",
                    color: Colors.teal,
                    onPressed: onRestore,
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}