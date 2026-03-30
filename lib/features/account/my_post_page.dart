import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_uni/features/home/create_post_page.dart';
import 'package:timeago/timeago.dart' as timeago;

class MyPostsPage extends StatelessWidget {
  const MyPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Bài đăng của tôi", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Sắp xếp bài mới nhất lên đầu cho dễ quản lý
        stream: FirebaseFirestore.instance
            .collection('forum_posts')
            .where('authorId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6797E1)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context, "Bạn chưa có bài đăng nào!");
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: (data['authorAvatar'] != null && data['authorAvatar'].isNotEmpty)
                            ? MemoryImage(base64Decode(data['authorAvatar']))
                            : null,
                        child: (data['authorAvatar'] == null || data['authorAvatar'].isEmpty)
                            ? const Icon(Icons.person) : null,
                      ),
                      title: const Text("Bạn", style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        data['timestamp'] != null
                            ? timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'vi')
                            : 'Vừa xong',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),

                    // --- PHẦN HASHTAG ĐÃ ĐƯỢC THÊM Ở ĐÂY ---
                    if (data['hashtags'] != null && (data['hashtags'] as List).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: (data['hashtags'] as List).map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6797E1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(
                                  color: Color(0xFF6797E1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    // --------------------------------------

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        data['content'] ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.arrow_upward, size: 18, color: Color(0xFF6797E1)),
                        const SizedBox(width: 4),
                        Text("${data['likes'] ?? 0}"),
                        const SizedBox(width: 15),
                        const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text("${data['comments'] ?? 0}"),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.blueGrey),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreatePostPage(
                                  docId: doc.id,
                                  existingData: data,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _confirmDelete(context, doc.reference),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            child: Text(
                "Đừng ngại chia sẻ! Hãy đặt câu hỏi hoặc chia sẻ trải nghiệm thú vị của bạn ngay.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreatePostPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6797E1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: const Text(
                "Tạo bài đăng mới",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
          )
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, DocumentReference ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xóa bài viết?"),
        content: const Text("Hành động này không thể hoàn tác."),
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
              child: const Text("Xóa", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}