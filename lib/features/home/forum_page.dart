import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ForumTab extends StatelessWidget {
  const ForumTab({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('forum_posts')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6797E1)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;

            // Kiểm tra xem bài đăng có ảnh hay không
            bool hasImage = data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor, // Đổi màu theo Theme
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header: Người đăng
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orangeAccent.withOpacity(isDarkMode ? 0.3 : 0.2),
                      child: const Icon(Icons.person, color: Colors.orange),
                    ),
                    title: Text(
                      data['authorName'] ?? 'Sinh viên ẩn danh',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                        data['timeAgo'] ?? 'Vừa xong',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)
                    ),
                    trailing: Icon(Icons.more_horiz, color: isDarkMode ? Colors.white54 : Colors.grey),
                  ),

                  // 2. PHẦN HASHTAG DẠNG Ô KHOANH
                  if (data['hashtags'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Wrap(
                        spacing: 8,
                        children: (data['hashtags'] as List).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              // Màu nền chip nhạt hơn trong Dark Mode
                              color: const Color(0xFF6797E1).withOpacity(isDarkMode ? 0.15 : 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                // Màu chữ hashtag sáng hơn trong Dark Mode
                                color: isDarkMode ? const Color(0xFF91B5EE) : const Color(0xFF6797E1),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // 3. Nội dung chữ
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      data['content'] ?? '',
                      style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          height: 1.5
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Ảnh bài đăng
                  if (hasImage)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          data['imageUrl'],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
                        ),
                      ),
                    ),

                  Divider(
                    height: 24,
                    thickness: 0.5,
                    indent: 16,
                    endIndent: 16,
                    color: isDarkMode ? Colors.white10 : Colors.black12,
                  ),

                  // 5. Các nút hành động
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPostAction(Icons.favorite_border, 'Thích', isDarkMode),
                        _buildPostAction(Icons.chat_bubble_outline, 'Bình luận', isDarkMode),
                        _buildPostAction(Icons.bookmark_add_outlined, 'Lưu', isDarkMode),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostAction(IconData icon, String label, bool isDarkMode) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            Icon(
                icon,
                size: 20,
                color: isDarkMode ? Colors.white60 : Colors.grey[600]
            ),
            const SizedBox(width: 6),
            Text(
                label,
                style: TextStyle(
                    color: isDarkMode ? Colors.white60 : Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500
                )
            ),
          ],
        ),
      ),
    );
  }
}