import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_uni/features/home/create_review_page.dart';
import 'package:my_uni/features/home/post_detail_page.dart';

class MyReviewsPage extends StatelessWidget {
  const MyReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // Đồng bộ màu nền trắng chuẩn các Tab
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Đánh giá của tôi",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontWeight: FontWeight.bold,
            color: Color(0xFF545454),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF545454)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('course_reviews')
            .where('authorId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF5893D8)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyReviewState(context);
          }

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
                  // Border dưới ngăn cách theo style Vector 136 - 2px của ReviewTab
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
                      // --- HEADER (Tên môn & Giảng viên) ---
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
                                  Text(
                                    data['courseName'] ?? 'Không rõ môn học',
                                    style: const TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Color(0xFF545454),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Giảng viên: ${data['teacherName'] ?? 'Chưa cập nhật'}",
                                    style: const TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontWeight: FontWeight.w300,
                                      fontSize: 14,
                                      color: Color(0xFF545454),
                                    ),
                                  ),
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
                            // Giữ nguyên logic Edit/Delete nhưng đổi Icon cho thanh thoát
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 22, color: Color(0xFF5893D8)),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CreateReviewPage(docId: doc.id, existingData: data),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 22, color: Color(0xFFFF6C6C)),
                                  onPressed: () => _confirmDelete(context, doc.reference),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // --- STARS (Style #FFCB45) ---
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

                      // --- CONTENT (15px, height 1.33) ---
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
                        padding: EdgeInsets.only(top: 4, bottom: 16),
                        child: Text(
                          "Xem thêm",
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 14,
                            color: Color(0xFFA9A9A9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- CÁC HÀM HELPER GIỮ NGUYÊN LOGIC, CẬP NHẬT UI ĐỒNG BỘ ---
  Widget _buildEmptyReviewState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars_outlined, size: 100, color: Color(0xFFFFCB45)),
            const SizedBox(height: 24),
            const Text(
                "Bạn chưa có đánh giá nào!",
                style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF545454))
            ),
            const SizedBox(height: 12),
            const Text(
                "Ý kiến của bạn rất quan trọng! Hãy review các môn đã học để giúp các bạn khóa sau chọn môn dễ dàng hơn nhé.",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Encode Sans Expanded', color: Colors.grey, fontSize: 14, height: 1.5)
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateReviewPage())),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5893D8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("Tạo đánh giá mới", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, DocumentReference ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xóa đánh giá?"),
        content: const Text("Dữ liệu này sẽ bị xóa vĩnh viễn và không thể khôi phục."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Hủy", style: TextStyle(color: Colors.grey))
          ),
          TextButton(
              onPressed: () async {
                await ref.delete();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Xóa ngay", style: TextStyle(color: Color(0xFFFF6C6C), fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}