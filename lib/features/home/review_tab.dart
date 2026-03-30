import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'create_review_page.dart';

class ReviewTab extends StatelessWidget {
  final Function(String, Map<String, dynamic>) onSave;
  const ReviewTab({super.key, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

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
                    _buildActionRow(user?.uid, docId, data),
                  ],
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

  Widget _buildActionRow(String? uid, String docId, Map<String, dynamic> data) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(uid ?? 'guest')
            .collection('saved_posts').doc(docId).snapshots(),
        builder: (context, saveSnapshot) {
          bool isSaved = saveSnapshot.hasData && saveSnapshot.data!.exists;
          return Row(
            children: [
              const Icon(Icons.favorite_border, color: Colors.grey, size: 20),
              const SizedBox(width: 4), const Text("96", style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 20),
              const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20),
              const SizedBox(width: 4), const Text("40", style: TextStyle(color: Colors.grey)),
              const Spacer(),
              GestureDetector(
                onTap: () => onSave(docId, data),
                child: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
                    color: isSaved ? Colors.amber : Colors.grey,
                    size: 20
                ),
              ),
            ],
          );
        }
    );
  }
}