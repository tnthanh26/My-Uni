import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'create_review_page.dart';

class ReviewTab extends StatelessWidget {
  const ReviewTab({super.key});

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
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
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
                    const Text("Xem thêm", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const Divider(),
                    _buildActionRow(),
                  ],
                ),
              );
            },
          );
        },
      ),
      // THÊM CÂY BÚT CHO REVIEW
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateReviewPage())),
        backgroundColor: const Color(0xFF6797E1),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        child: const Icon(Icons.edit_outlined, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildActionRow() {
    return const Row(
      children: [
        Icon(Icons.favorite_border, color: Colors.grey, size: 20),
        SizedBox(width: 4), Text("96", style: TextStyle(color: Colors.grey)),
        SizedBox(width: 20),
        Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20),
        SizedBox(width: 4), Text("40", style: TextStyle(color: Colors.grey)),
        Spacer(),
        Icon(Icons.bookmark_outline, color: Colors.grey, size: 20),
      ],
    );
  }
}