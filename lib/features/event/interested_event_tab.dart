import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InterestedEventTab extends StatelessWidget {
  const InterestedEventTab({super.key});

  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  }

  // LOGIC XÓA: Bỏ quan tâm sự kiện
  Future<void> _removeInterest(BuildContext context, String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('interested_events')
          .doc(docId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(" Đã bỏ quan tâm sự kiện")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lỗi khi xóa sự kiện")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Center(child: Text("Vui lòng đăng nhập"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(user.uid)
          .collection('interested_events')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Đã xảy ra lỗi"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF6797E1)));

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
              child: Text("Bạn chưa quan tâm sự kiện nào.",
                  style: TextStyle(color: Colors.grey))
          );
        }

        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  var doc = docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  return _buildEventCard(context, doc.id, data, isDarkMode);
                }, childCount: docs.length),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEventCard(BuildContext context, String docId, Map<String, dynamic> data, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Ảnh minh họa + Nút Xóa
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.asset(
                    'assets/images/news.png',
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover
                ),
              ),
              // Nút xóa (Bỏ quan tâm)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _removeInterest(context, docId),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),

          // 2. Nội dung text
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    data['title'] ?? 'Sự kiện sinh viên',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87
                    )
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Color(0xFF6797E1)),
                    const SizedBox(width: 4),
                    Text(data['date'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF6797E1)),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(
                            data['department'] ?? 'Cơ sở HCMUS',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis
                        )
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Nút Chi tiết
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                onPressed: () => _launchURL(data['link'] ?? ''),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isDark ? const Color(0xFF91B5EE) : const Color(0xFF6797E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Chi tiết bài viết',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF91B5EE) : const Color(0xFF6797E1)
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}