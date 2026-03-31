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
    return Scaffold(
      backgroundColor: Colors.white,
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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  // Border dưới ngăn cách bài viết (CSS: Vector 136 - 2px)
                  border: Border(bottom: BorderSide(color: Color(0xFFDFE6E9), width: 2)),
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
                      // --- HEADER (CSS: Frame 1359) ---
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
                                  // Tên môn học (CSS: font-weight: 700, size: 16)
                                  Text(
                                    data['courseName'] ?? '',
                                    style: const TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Color(0xFF545454),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Tên giảng viên (CSS: top 35px, font-weight: 300)
                                  Text(
                                    "Giảng viên: ${data['teacherName'] ?? ''}",
                                    style: const TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontWeight: FontWeight.w300,
                                      fontSize: 14,
                                      color: Color(0xFF545454),
                                    ),
                                  ),
                                  // Học kỳ (CSS: top 65px, font-weight: 300)
                                  Text(
                                    data['semester'] ?? '',
                                    style: const TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontWeight: FontWeight.w300,
                                      fontSize: 14,
                                      color: Color(0xFF545454),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.more_horiz, color: Color(0xFF777777)),
                          ],
                        ),
                      ),

                      // --- STARS (CSS: Stars - gap 3px, color #FFCB45) ---
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: List.generate(5, (i) {
                            int rating = (data['rating'] ?? 0).toInt();
                            return Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: Icon(
                                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: i < rating ? const Color(0xFFFFCB45) : const Color(0xFFD9D9D9),
                                size: 22,
                              ),
                            );
                          }),
                        ),
                      ),

                      // --- CONTENT (CSS: font-size: 15, height: 1.33) ---
                      Text(
                        data['content'] ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 15,
                          color: Color(0xFF545454),
                          height: 1.33,
                        ),
                      ),

                      // --- XEM THÊM ---
                      const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 12),
                        child: Text(
                          "Xem thêm",
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 15,
                            color: Color(0xFFA9A9A9),
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