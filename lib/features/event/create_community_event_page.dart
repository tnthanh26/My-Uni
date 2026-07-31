import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CommunityEventPage extends StatelessWidget {
  const CommunityEventPage({super.key});

  // Hàm lọc CHỈ lấy những tin là Event
  bool _isRealEvent(dynamic title, dynamic summary) {
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sự kiện cộng đồng mới", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6797E1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Lấy danh sách ID đã quan tâm
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('interested_events').snapshots(),
        builder: (context, favSnapshot) {
          List<String> interestedIds = favSnapshot.hasData ? favSnapshot.data!.docs.map((d) => d.id).toList() : [];

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('official_news').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, newsSnapshot) {
              if (!newsSnapshot.hasData) return const Center(child: CircularProgressIndicator());

              // BỘ LỌC QUAN TRỌNG: 1. Phải là Event + 2. Chưa có trong list quan tâm
              final displayDocs = newsSnapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return _isRealEvent(data['title'], data['summary']) && !interestedIds.contains(doc.id);
              }).toList();

              if (displayDocs.isEmpty) {
                return const Center(child: Text("Không có sự kiện cộng đồng mới nào.", style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: displayDocs.length,
                itemBuilder: (context, index) {
                  var doc = displayDocs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  return _buildEventCard(context, doc.id, data, isDark);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, String docId, Map<String, dynamic> data, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                Image.asset('assets/images/news.png', height: 140, width: double.infinity, fit: BoxFit.cover),
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Text(
                      'MỚI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(data['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(data['date']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            trailing: ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users').doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('interested_events').doc(docId).set({
                  ...data,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã thêm vào mục Quan tâm")));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6797E1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text("Quan tâm", style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}