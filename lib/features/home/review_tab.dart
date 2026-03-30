import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'create_review_page.dart';
import 'post_action_row.dart';
import 'post_detail_page.dart';

class ReviewTab extends StatelessWidget {
  final Function(String, Map<String, dynamic>) onSave;
  const ReviewTab({super.key, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('course_reviews')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF6797E1)));

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String docId = doc.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                // BỌC GESTUREDETECTOR LỚN ĐỂ VÀO DETAIL GIỐNG FACEBOOK
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailPage(docId: docId, initialPostData: data),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['courseName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(data['semester'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                Text("Giảng viên: ${data['teacherName'] ?? ''}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                            const Icon(Icons.more_horiz, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(5, (i) => Icon(
                            i < (data['rating'] ?? 0) ? Icons.star : Icons.star_border,
                            color: Colors.amber, size: 18,
                          )),
                        ),
                        const SizedBox(height: 12),
                        Text(data['content'] ?? '', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, height: 1.4)),
                        const SizedBox(height: 8),
                        const Divider(),

                        // CHẶN CHẠM Ở THANH ACTION
                        GestureDetector(
                          onTap: () {},
                          behavior: HitTestBehavior.opaque,
                          child: PostActionRow(
                            docId: docId,
                            data: data,
                            onSave: onSave,
                            collectionPath: 'course_reviews',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "fab_review_tab",
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateReviewPage())),
        backgroundColor: const Color(0xFF6797E1),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        child: const Icon(Icons.edit_outlined, color: Colors.white, size: 28),
      ),
    );
  }
}