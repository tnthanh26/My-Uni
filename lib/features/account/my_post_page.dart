import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_uni/features/home/create_post_page.dart';
import 'package:my_uni/features/home/post_detail_page.dart';
import 'package:timeago/timeago.dart' as timeago;

class MyPostsPage extends StatelessWidget {
  const MyPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Bài đăng của tôi",
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
            .collection('forum_posts')
            .where('authorId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF5893D8)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context, "Bạn chưa có bài đăng nào!");
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String docId = doc.id;
              String? avatarData = data['authorAvatar'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  // Border gạch dưới giống CSS Vector 136
                  border: Border(bottom: BorderSide(color: Color(0xFFDFE6E9), width: 1)),
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailPage(
                          docId: docId,
                          initialPostData: data,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HEADER (Avatar & Name) ---
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22.5,
                              backgroundColor: const Color(0xFFF0F0F0),
                              backgroundImage: (avatarData != null && avatarData.isNotEmpty)
                                  ? MemoryImage(base64Decode(avatarData)) : null,
                              child: (avatarData == null || avatarData.isEmpty)
                                  ? const Icon(Icons.person, color: Colors.grey) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Bạn",
                                    style: TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF545454),
                                    ),
                                  ),
                                  Text(
                                    data['timestamp'] != null
                                        ? timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'vi')
                                        : 'Vừa xong',
                                    style: const TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontSize: 12,
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

                      // --- HASHTAGS (Style Frame 29018) ---
                      if (data['hashtags'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 8,
                            children: (data['hashtags'] as List).map((tag) {
                              bool isWarning = tag.toString().toLowerCase().contains('cảnh báo');
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isWarning
                                      ? const Color(0xFFFF6C6C).withOpacity(0.6)
                                      : const Color(0xFFEDEDED).withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.tag, size: 13, color: Color(0xFF344054)),
                                    const SizedBox(width: 2),
                                    Text(
                                      tag.toString(),
                                      style: const TextStyle(
                                        fontFamily: 'Encode Sans Expanded',
                                        fontSize: 10,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // --- CONTENT ---
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          data['content'] ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 15,
                            color: Color(0xFF545454),
                            height: 1.4,
                          ),
                        ),
                      ),

                      // --- IMAGE (Nếu có) ---
                      if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(data['imageUrl']),
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          const Icon(Icons.favorite_outline, size: 18, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text("${data['likeCount'] ?? 0}", style: const TextStyle(color: Color(0xFF545454))),
                          const SizedBox(width: 15),
                          const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF777777)),
                          const SizedBox(width: 4),
                          Text("${data['commentCount'] ?? 0}", style: const TextStyle(color: Color(0xFF545454))),
                          const Spacer(),

                          // Giữ nguyên logic Edit/Delete của bạn
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF5893D8), size: 26),
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
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6C6C), size: 24),
                            onPressed: () => _confirmDelete(context, doc.reference),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
              backgroundColor: const Color(0xFF5893D8),
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