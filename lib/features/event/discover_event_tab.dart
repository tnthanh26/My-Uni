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
                        borderRadius: BorderRadius.circular(8),
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
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            child: Stack(
                              children: [
                                Image.asset(
                                  'assets/images/news.png',
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 0, left: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: Color(0xFFFF8282),
                                        borderRadius: BorderRadius.circular(8)
                                    ),
                                    child: const Text(
                                        'MỚI CẬP NHẬT',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                    ),
                                  ),
                                ),
                                // Nút Quan tâm với StreamBuilder để check trạng thái real-time
                                Positioned(
                                  top: 0, right: 0,
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
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Thu hẹp vùng bấm thừa
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
                                Container(
                                  //width: 391,
                                  height: 24,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xEBEEFCF8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // mdi:clock icon
                                      const Icon(
                                        Icons.access_time_filled, // Sử dụng filled để giống vector hơn
                                        size: 12,
                                        color: Color(0xFF33D7A0), // Màu background #33D7A0 của Vector
                                      ),
                                      const SizedBox(width: 6), // Khoảng cách để text bắt đầu từ left: 22px (4px icon + 12px width + 6px gap)

                                      // 05/03/2026 - 07/03/2026
                                      Text(
                                        data['date']?.toString() ?? '05/03/2026 - 07/03/2026',
                                        style: const TextStyle(
                                          fontFamily: 'Encode Sans Expanded',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(
                                          Icons.location_on,
                                          size: 12,
                                          color: Color(0xFF33D7A0)
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        data['department']?.toString() ?? 'Cơ sở NVC',
                                        style: const TextStyle(
                                          fontFamily: 'Encode Sans Expanded',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 8), // Padding nhẹ bên phải
                                    ],
                                  ),
                                )
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