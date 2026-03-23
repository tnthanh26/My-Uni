import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OfficialTab extends StatelessWidget {
  const OfficialTab({super.key});

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('official_news')
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

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                // Sử dụng cardColor của Theme để tự đổi màu Trắng <-> Xám đen
                color: Theme.of(context).cardColor,
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
                  // Header
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF6797E1),
                      child: Icon(Icons.school, color: Colors.white, size: 20),
                    ),
                    title: Text(
                      data['department'] ?? 'Thông báo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                        data['date'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)
                    ),
                    trailing: Icon(Icons.more_horiz, color: isDarkMode ? Colors.white54 : Colors.grey),
                  ),

                  // Nội dung bài đăng
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['summary'] ?? '',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: isDarkMode ? Colors.white70 : Colors.grey[800],
                              height: 1.4
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  // Ảnh minh họa
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/news.png',
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  // Thanh tương tác
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPostAction(Icons.favorite_border, 'Thích', isDarkMode),
                        _buildPostAction(Icons.chat_bubble_outline, 'Bình luận', isDarkMode),
                        _buildPostAction(Icons.bookmark_add_outlined, 'Lưu', isDarkMode),
                      ],
                    ),
                  ),

                  // Nút xem chi tiết
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _launchURL(data['link'] ?? ''),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(
                              color: isDarkMode ? const Color(0xFF91B5EE) : const Color(0xFF6797E1)
                          ),
                        ),
                        child: Text(
                            'Xem chi tiết bài viết',
                            style: TextStyle(
                                color: isDarkMode ? const Color(0xFF91B5EE) : const Color(0xFF6797E1),
                                fontWeight: FontWeight.bold
                            )
                        ),
                      ),
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
    return Row(
      children: [
        Icon(icon, size: 20, color: isDarkMode ? Colors.white60 : Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
            label,
            style: TextStyle(
                color: isDarkMode ? Colors.white60 : Colors.grey[600],
                fontSize: 12
            )
        ),
      ],
    );
  }
}