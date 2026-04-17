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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Màu nền động
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('course_reviews')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF5893D8)));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String docId = doc.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.transparent : Colors.white,
                  // Border dưới ngăn cách bài viết linh hoạt theo theme
                  border: Border(
                      bottom: BorderSide(
                          color: isDarkMode ? Colors.white10 : const Color(0xFFDFE6E9),
                          width: 2
                      )
                  ),
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailPage(docId: docId, initialPostData: data),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HEADER ---
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tên môn học
                                  Text(
                                    data['courseName'] ?? '',
                                    style: TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: isDarkMode ? Colors.white : const Color(0xFF545454),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Tên giảng viên
                                  Text(
                                    "Giảng viên: ${data['teacherName'] ?? ''}",
                                    style: TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontWeight: FontWeight.w300,
                                      fontSize: 14,
                                      color: isDarkMode ? Colors.white70 : const Color(0xFF545454),
                                    ),
                                  ),
                                  // Học kỳ
                                  Text(
                                    data['semester'] ?? '',
                                    style: TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontWeight: FontWeight.w300,
                                      fontSize: 14,
                                      color: isDarkMode ? Colors.white60 : const Color(0xFF545454),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.more_horiz, color: isDarkMode ? Colors.white38 : const Color(0xFF777777)),
                          ],
                        ),
                      ),

                      // --- STARS (Giữ màu vàng đặc trưng, chỉ chỉnh màu sao rỗng) ---
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: List.generate(5, (i) {
                            int rating = (data['rating'] ?? 0).toInt();
                            return Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: Icon(
                                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: i < rating ? const Color(0xFFFFCB45) : (isDarkMode ? Colors.white12 : const Color(0xFFD9D9D9)),
                                size: 22,
                              ),
                            );
                          }),
                        ),
                      ),

                      // --- CONTENT ---
                      Text(
                        data['content'] ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 15,
                          color: isDarkMode ? Colors.white : const Color(0xFF545454),
                          height: 1.33,
                        ),
                      ),

                      // --- XEM THÊM ---
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 12),
                        child: Text(
                          "Xem thêm",
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 15,
                            color: isDarkMode ? Colors.white38 : const Color(0xFFA9A9A9),
                          ),
                        ),
                      ),

                      // --- ACTION ROW ---
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
                      const SizedBox(height: 16),
                    ],
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
        backgroundColor: const Color(0xFF5893D8),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_outlined, color: Colors.white, size: 30),
      ),
    );
  }
}