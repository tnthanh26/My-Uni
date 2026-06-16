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
    required this.onViewComments,
  });

  final String docId;
  final Map<String, dynamic> data;
  final String collection;

  final VoidCallback onApprove;
  final VoidCallback onDelete;
  final VoidCallback onRestore;
  final VoidCallback onDismissReport;
  final VoidCallback onViewMaterial;
  final VoidCallback onViewComments;

  Widget _buildPollPreview(Map<String, dynamic> pollData) {
    final List<dynamic> options = pollData['options'] ?? [];
    final Map<String, dynamic> votes = Map<String, dynamic>.from(pollData['votes'] ?? {});
    final int totalParticipants = votes.length;

    Map<int, int> optionCounts = {};
    for (var v in votes.values) {
      if (v is List) {
        for (var idx in v) {
          if (idx is int) optionCounts[idx] = (optionCounts[idx] ?? 0) + 1;
        }
      } else if (v is int) {
        optionCounts[v] = (optionCounts[v] ?? 0) + 1;
      }
    }

    int totalVotes = 0;
    optionCounts.forEach((key, value) => totalVotes += value);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.poll_outlined, size: 16, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text(
                "Khảo sát ý kiến",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Nunito',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...options.asMap().entries.map((entry) {
            int idx = entry.key;
            String text = entry.value.toString();
            int count = optionCounts[idx] ?? 0;
            double percentage = totalVotes > 0 ? (count / totalVotes) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: const TextStyle(fontSize: 12, fontFamily: 'Nunito'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "${(percentage * 100).toInt()}% ($count)",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double toxicity = (data['toxicityScore'] ?? 0).toDouble();
    bool isReported = data['isReported'] ?? false;
    int reportCount = data['reportCount'] ?? 0;

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
          )
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
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFF0F2F5),
                  child: Icon(
                    Icons.person_outline,
                    color: Colors.grey,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['authorName'] ?? "Ẩn danh",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    Text(
                      data['timestamp']?.toDate().toString().substring(0, 16) ?? "",
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                if (isReported)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      "Báo cáo: $reportCount",
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ModToxicityBadge(toxicity: toxicity),
              ],
            ),

            const SizedBox(height: 12),

            if (collection == 'course_reviews') ...[
              Text(
                "Môn học: ${data['courseName']}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                  fontSize: 15,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 6),
            ],

            if (collection == 'study_materials') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_file, color: Colors.blueGrey, size: 18),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: Text(
                            data['fileName'] ?? "File",
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 76,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: onViewMaterial,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        child: const Text("XEM"),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
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
                    fontSize: 12,
                  ),
                ))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],

            Text(
              data['content'] ?? "",
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontFamily: 'Nunito',
              ),
            ),

            if (data['poll'] != null) ...[
              const SizedBox(height: 16),
              _buildPollPreview(data['poll']),
            ],

            if (data['imageUrl'] != null && data['imageUrl'] != '') ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 360,
                    minHeight: 100,
                    maxWidth: double.infinity,
                  ),
                  child: Image.memory(
                    base64Decode(data['imageUrl']),
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey[200],
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            "Không thể hiển thị hình ảnh",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

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
                  if (data['status'] != 'hidden') ...[
                    if (isReported)
                      SizedBox(
                        width: 150,
                        height: 34,
                        child: ModActionButton(
                          icon: Icons.refresh,
                          label: "HỦY BÁO CÁO",
                          color: Colors.blueGrey,
                          onPressed: onDismissReport,
                        ),
                      ),
                    SizedBox(
                      width: 82,
                      height: 34,
                      child: ModActionButton(
                        icon: Icons.delete,
                        label: "XÓA",
                        color: Colors.redAccent,
                        onPressed: onDelete,
                      ),
                    ),
                    if (data['status'] == 'pending')
                      SizedBox(
                        width: 90,
                        height: 34,
                        child: ModActionButton(
                          icon: Icons.check,
                          label: "DUYỆT",
                          color: Colors.green,
                          onPressed: onApprove,
                        ),
                      ),
                    SizedBox(
                      width: 120,
                      height: 34,
                      child: ModActionButton(
                        icon: Icons.comment_outlined,
                        label: "BÌNH LUẬN",
                        color: Colors.blueAccent,
                        onPressed: onViewComments,
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: 140,
                      height: 34,
                      child: ModActionButton(
                        icon: Icons.restore,
                        label: "KHÔI PHỤC",
                        color: Colors.teal,
                        onPressed: onRestore,
                      ),
                    ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}