import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'post_action_row.dart';
import 'post_detail_page.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng đăng nhập để lưu sự kiện")));
      return;
    }
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('interested_events').doc(docId);
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
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('official_news')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF5893D8)));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            String docId = doc.id;
            bool isEvent = _checkIsEvent(data['title'] ?? '', data['summary'] ?? '');

            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFDFE6E9), width: 1)),
              ),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailPage(docId: docId, initialPostData: data))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- HEADER (CSS: Frame 1359) ---
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22.5,
                            backgroundColor: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      data['department'] ?? 'HCMUS News',
                                      style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF545454)),
                                    ),
                                    if (isEvent) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.check_circle, color: Color(0xFF66ACFE), size: 16),
                                    ]
                                  ],
                                ),
                                Text(
                                  data['date'] ?? '',
                                  style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 12, color: Color(0xFF545454)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.more_horiz, color: Color(0xFF777777)),
                        ],
                      ),
                    ),

                    // --- HASHTAG & QUAN TÂM (CSS: Frame 29018) ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (isEvent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFEDEDED).withOpacity(0.92), borderRadius: BorderRadius.circular(16)),
                            child: const Row(
                              children: [
                                Icon(Icons.tag, size: 13, color: Color(0xFF344054)),
                                Text("Sự Kiện", style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 10, color: Colors.black)),
                              ],
                            ),
                          )
                        else
                          const SizedBox(),

                        // Nút Quan tâm (CSS: Frame 29019)
                        if (isEvent)
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection('users').doc(user?.uid ?? 'guest').collection('interested_events').doc(docId).snapshots(),
                            builder: (context, favSnapshot) {
                              bool isInterested = favSnapshot.hasData && favSnapshot.data!.exists;
                              return GestureDetector(
                                onTap: () => _toggleInterest(context, docId, data),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isInterested ? Colors.grey[200] : const Color(0xFF9BC9FF).withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFDFDFDF)),
                                  ),
                                  child: Text(
                                    isInterested ? 'Đã quan tâm' : 'Quan tâm',
                                    style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 12, fontWeight: FontWeight.w500, color: isInterested ? Colors.grey : const Color(0xFF226792)),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        data['title'] ?? '',
                        style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w400, fontSize: 15, color: Color(0xFF545454), height: 1.3),
                      ),
                    ),

                    // --- IMAGE (CSS: Frame 1354) ---
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('assets/images/news.png', width: double.infinity, height: 260, fit: BoxFit.cover),
                    ),

                    // --- XEM THÊM (CSS: Xem thêm) ---
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text("Xem thêm", style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 13, color: Color(0xA9A9A9A9))),
                    ),

                    // --- ACTION ROW (CSS: Frame 1364) ---
                    // Lưu ý: PostActionRow của bạn sẽ chứa logic Like/Comment/Save
                    PostActionRow(
                      docId: docId,
                      data: data,
                      onSave: onSave,
                      collectionPath: 'official_news',
                    ),

                    // --- NÚT XEM CHI TIẾT ---
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16, top: 4),
                      child: SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () => _launchURL(data['link'] ?? ''),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF5893D8)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Xem chi tiết bài viết', style: TextStyle(color: Color(0xFF5893D8), fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}