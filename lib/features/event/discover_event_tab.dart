import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DiscoverEventTab extends StatelessWidget {
  const DiscoverEventTab({super.key});

  // Logic kiểm tra sự kiện an toàn với kiểu dữ liệu
  bool _checkIsEvent(dynamic title, dynamic summary) {
    List<String> keywords = [
      'seminar', 'talkshow', 'hội thảo', 'cuộc thi', 'chào tân sinh viên',
      'ngày hội', 'lễ tốt nghiệp', 'workshop', 'sự kiện', 'mời tham gia', 'đăng ký tham gia'
    ];
    String content = "${title.toString()} ${summary.toString()}".toLowerCase();
    return keywords.any((k) => content.contains(k));
  }

  // --- LOGIC QUAN TÂM ---
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
        .doc(docId); // Dùng chính ID của bài news để tránh trùng lặp

    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      // Nếu đã quan tâm rồi thì nhấn lại sẽ hủy (Xóa khỏi danh sách)
      await docRef.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã bỏ quan tâm")),
      );
    } else {
      // Nếu chưa thì thêm mới vào tab Đã quan tâm
      await docRef.set({
        'title': data['title'] ?? 'Sự kiện sinh viên',
        'date': data['date'] ?? 'Xem chi tiết',
        'department': data['department'] ?? 'Cơ sở HCMUS',
        'summary': data['summary'] ?? '',
        'link': data['link'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã thêm vào mục Đã quan tâm")),
      );
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
        if (snapshot.hasError) return const Center(child: Text("Đã xảy ra lỗi dữ liệu"));
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6797E1)));
        }

        final eventDocs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return _checkIsEvent(data['title'] ?? '', data['summary'] ?? '');
        }).toList();

        if (eventDocs.isEmpty) {
          return const Center(child: Text("Hiện chưa có sự kiện nào sắp tới"));
        }

        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    var doc = eventDocs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String docId = doc.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Stack(
                              children: [
                                Image.asset(
                                  'assets/images/news.png',
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 12, left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(4)
                                    ),
                                    child: const Text(
                                        'MỚI CẬP NHẬT',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                    ),
                                  ),
                                ),
                                // Nút Quan tâm với StreamBuilder để check trạng thái real-time
                                Positioned(
                                  top: 8, right: 8,
                                  child: StreamBuilder<DocumentSnapshot>(
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
                                            backgroundColor: isInterested
                                                ? Colors.grey // Đã quan tâm thì màu xám
                                                : const Color(0xFF6797E1), // Chưa thì màu xanh MyUni
                                            foregroundColor: Colors.white,
                                            elevation: 4,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            minimumSize: const Size(0, 32),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                          ),
                                          child: Text(
                                            isInterested ? 'Đã quan tâm' : 'Quan tâm',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        );
                                      }
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title']?.toString() ?? 'Sự kiện sinh viên',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDarkMode ? Colors.white : Colors.black87
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: Color(0xFF6797E1)),
                                    const SizedBox(width: 4),
                                    Text(
                                        data['date']?.toString() ?? 'Xem chi tiết',
                                        style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.grey)
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF6797E1)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                          data['department']?.toString() ?? 'Cơ sở HCMUS',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.grey)
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: eventDocs.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}