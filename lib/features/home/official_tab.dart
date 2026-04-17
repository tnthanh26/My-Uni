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

  Widget _getDynamicIcons(dynamic titleData, dynamic summaryData) {
    String title = titleData?.toString().toLowerCase() ?? "";
    String summary = summaryData?.toString().toLowerCase() ?? "";
    String text = "$title $summary";

    List<String> icons = [];

    if (text.contains('thông báo') || text.contains('quy định')) icons.add("📢");
    if (text.contains('học bổng') || text.contains('scholarship')) icons.add("🎓");
    if (text.contains('cuộc thi') || text.contains('contest') || text.contains('giải thưởng')) icons.add("🏆");
    if (text.contains('tuyển dụng') || text.contains('việc làm') || text.contains('intern')) icons.add("💼");
    if (text.contains('công nghệ') || text.contains('tech') || text.contains('it')) icons.add("💻");
    if (text.contains('thể thao') || text.contains('bóng đá')) icons.add("⚽");
    if (text.contains('nghệ thuật') || text.contains('văn nghệ') || text.contains('âm nhạc')) icons.add("🎨♫");
    if (text.contains('lễ tốt nghiệp') || text.contains('graduation')) icons.add("📜");
    if (text.contains('hội thảo') || text.contains('seminar') || text.contains('workshop') || text.contains('talkshow')) icons.add("🎤");
    if (text.contains('y tế') || text.contains('khám chữa bệnh')) icons.add("🏥");

    if (icons.isEmpty) icons.add("📌");

    return Text(
      "${icons.join(" ")} ",
      style: const TextStyle(fontSize: 18),
    );
  }

  bool _checkIsEvent(dynamic titleData, dynamic summaryData) {
    String title = titleData?.toString().toLowerCase() ?? "";
    String summary = summaryData?.toString().toLowerCase() ?? "";
    List<String> keywords = [
      'seminar', 'talkshow', 'hội thảo', 'cuộc thi', 'chào tân sinh viên',
      'ngày hội', 'lễ tốt nghiệp', 'workshop', 'sự kiện', 'mời tham gia', 'đăng ký tham gia'
    ];
    String content = "$title $summary";
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
        'title': data['title']?.toString() ?? '',
        'date': data['date']?.toString() ?? '',
        'department': data['department']?.toString() ?? '',
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
            bool isEvent = _checkIsEvent(data['title'], data['summary']);

            void goToDetail() => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailPage(docId: docId, initialPostData: data)));

            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.transparent : Colors.white,
                border: Border(
                    bottom: BorderSide(
                        color: isDarkMode ? Colors.white10 : const Color(0xFFDFE6E9),
                        width: 1
                    )
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22.5,
                          backgroundColor: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
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
                                    data['department']?.toString() ?? 'HCMUS News',
                                    style: TextStyle(
                                        fontFamily: 'Encode Sans Expanded',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isDarkMode ? Colors.white : const Color(0xFF545454)
                                    ),
                                  ),
                                  if (isEvent) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.check_circle, color: Color(0xFF66ACFE), size: 16),
                                  ]
                                ],
                              ),
                              Text(
                                data['date']?.toString() ?? '',
                                style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.white60 : const Color(0xFF545454)
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.more_horiz, color: isDarkMode ? Colors.white38 : const Color(0xFF777777)),
                      ],
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isEvent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white10 : const Color(0xFFEDEDED).withOpacity(0.92),
                              borderRadius: BorderRadius.circular(16)
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.tag, size: 13, color: isDarkMode ? Colors.white70 : const Color(0xFF344054)),
                              Text(
                                  "Sự Kiện",
                                  style: TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontSize: 10,
                                      color: isDarkMode ? Colors.white70 : Colors.black
                                  )
                              ),
                            ],
                          ),
                        )
                      else
                        const SizedBox(),

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
                                  color: isInterested
                                      ? (isDarkMode ? Colors.white12 : Colors.grey[200])
                                      : const Color(0xFF9BC9FF).withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDarkMode ? Colors.white10 : const Color(0xFFDFDFDF)),
                                ),
                                child: Text(
                                  isInterested ? 'Đã quan tâm' : 'Quan tâm',
                                  style: TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isInterested
                                          ? (isDarkMode ? Colors.white38 : Colors.grey)
                                          : (isDarkMode ? Colors.white : const Color(0xFF226792))
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),

                  GestureDetector(
                    onTap: goToDetail,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: _getDynamicIcons(data['title'], data['summary']),
                            ),
                            TextSpan(
                              text: data['title']?.toString() ?? '',
                              style: TextStyle(
                                  fontFamily: 'Encode Sans Expanded',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 15,
                                  color: isDarkMode ? Colors.white : const Color(0xFF545454),
                                  height: 1.3
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/images/news.png', width: double.infinity, height: 260, fit: BoxFit.cover),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: InkWell(
                      onTap: goToDetail,
                      child: const Text(
                        "Xem thêm...",
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 13,
                          color: Color(0xFF5893D8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  PostActionRow(
                    docId: docId,
                    data: data,
                    onSave: onSave,
                    collectionPath: 'official_news',
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 16, top: 4),
                    child: SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => _launchURL(data['link']?.toString() ?? ''),
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
            );
          },
        );
      },
    );
  }
}