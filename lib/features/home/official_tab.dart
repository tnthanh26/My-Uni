import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OfficialTab extends StatelessWidget {
  final Function(String, Map<String, dynamic>) onSave;
  const OfficialTab({super.key, required this.onSave});

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  }

  bool _checkIsEvent(String title, String summary) {
    List<String> keywords = [
      'seminar', 'talkshow', 'hội thảo', 'cuộc thi', 'chào tân sinh viên',
      'ngày hội', 'lễ tốt nghiệp', 'workshop', 'sự kiện', 'mời tham gia', 'đăng ký tham gia'
    ];
    String content = "${title.toString()} ${summary.toString()}".toLowerCase();
    return keywords.any((k) => content.contains(k));
  }

  Future<void> _toggleInterest(BuildContext context, String docId, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng đăng nhập để lưu sự kiện")),
      );
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('interested_events')
        .doc(docId);

    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      await docRef.delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã bỏ quan tâm")));
    } else {
      await docRef.set({
        'title': data['title'] ?? '',
        'date': data['date'] ?? '',
        'department': data['department'] ?? '',
        'summary': data['summary'] ?? '',
        'link': data['link'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã thêm vào mục Đã quan tâm")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

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
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            String docId = doc.id;
            String title = data['title']?.toString() ?? '';
            String summary = data['summary']?.toString() ?? '';
            bool isEvent = _checkIsEvent(title, summary);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
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
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF6797E1),
                      child: Icon(Icons.school, color: Colors.white, size: 20),
                    ),
                    title: Row(
                      children: [
                        Text(
                          data['department'] ?? 'Thông báo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (isEvent) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle, color: Colors.blue, size: 14),
                        ]
                      ],
                    ),
                    subtitle: Text(
                        data['date'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)
                    ),
                    trailing: Icon(Icons.more_horiz, color: isDarkMode ? Colors.white54 : Colors.grey),
                  ),

                  if (isEvent)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6797E1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Text(
                              "# Sự kiện",
                              style: TextStyle(color: Color(0xFF6797E1), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user?.uid ?? 'guest')
                                  .collection('interested_events')
                                  .doc(docId)
                                  .snapshots(),
                              builder: (context, favSnapshot) {
                                bool isInterested = favSnapshot.hasData && favSnapshot.data!.exists;

                                return ElevatedButton(
                                  onPressed: () => _toggleInterest(context, docId, data),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isInterested ? Colors.grey : const Color(0xFF6797E1),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: const Size(90, 30),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  child: Text(
                                      isInterested ? 'Đã quan tâm' : 'Quan tâm',
                                      style: const TextStyle(fontSize: 12)
                                  ),
                                );
                              }
                          ),
                        ],
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          summary,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: isDarkMode ? Colors.white70 : Colors.grey[800],
                              height: 1.4
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPostAction(Icons.favorite_border, 'Thích', isDarkMode),
                        _buildPostAction(Icons.chat_bubble_outline, 'Bình luận', isDarkMode),
                        // Nút Lưu cập nhật logic StreamBuilder để đổi màu
                        StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(user?.uid ?? 'guest')
                                .collection('saved_posts')
                                .doc(docId)
                                .snapshots(),
                            builder: (context, saveSnapshot) {
                              bool isSaved = saveSnapshot.hasData && saveSnapshot.data!.exists;
                              return GestureDetector(
                                onTap: () => onSave(docId, data),
                                child: _buildPostAction(
                                  isSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
                                  color: isSaved ? Colors.amber : Colors.grey,
                                  'Lưu',
                                  isDarkMode,
                                ),
                              );
                            }
                        ),
                      ],
                    ),
                  ),

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

  Widget _buildPostAction(IconData icon, String label, bool isDarkMode, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? (isDarkMode ? Colors.white60 : Colors.grey[600])),
        const SizedBox(width: 4),
        Text(
            label,
            style: TextStyle(
                color: color ?? (isDarkMode ? Colors.white60 : Colors.grey[600]),
                fontSize: 12
            )
        ),
      ],
    );
  }
}