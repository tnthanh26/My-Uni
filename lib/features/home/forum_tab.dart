import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'create_post_page.dart';
import 'post_action_row.dart';
import 'post_detail_page.dart';

class ForumTab extends StatefulWidget {
  final Function(String, Map<String, dynamic>) onSave;
  const ForumTab({super.key, required this.onSave});
  @override
  State<ForumTab> createState() => _ForumTabState();
}

class _ForumTabState extends State<ForumTab> {
  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('vi', timeago.ViMessages());
  }

  Future<void> _viewImage(BuildContext context, String base64Data) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(filePath);
      await file.writeAsBytes(base64Decode(base64Data));
      await OpenFilex.open(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không thể mở ảnh / file")));
      }
    }
  }

  Widget _buildSafeImage(BuildContext context, String? imgData) {
    if (imgData == null || imgData.isEmpty) return const SizedBox();
    try {
      return GestureDetector(
        onTap: () => _viewImage(context, imgData),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(base64Decode(imgData), width: double.infinity, height: 200, fit: BoxFit.cover),
        ),
      );
    } catch (e) {
      return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // CSS: #FFFFFF
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('forum_posts').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF5893D8)));

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
                  border: Border(bottom: BorderSide(color: Color(0xFFDFE6E9), width: 1)), // CSS: Vector 136
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailPage(docId: docId, initialPostData: data)));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HEADER (CSS: Frame 1359) ---
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            // Avatar (CSS: Frame 1497)
                            CircleAvatar(
                              radius: 22.5,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 22.5,
                                backgroundColor: const Color(0xFFF0F0F0),
                                backgroundImage: (avatarData != null && avatarData.isNotEmpty)
                                    ? MemoryImage(base64Decode(avatarData)) : null,
                                child: (avatarData == null || avatarData.isEmpty)
                                    ? const Icon(Icons.person, color: Colors.grey) : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Name & Time (CSS: Frame 1350)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['authorName'] ?? 'Sinh viên ẩn danh',
                                    style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF545454)),
                                  ),
                                  Text(
                                    data['timestamp'] != null
                                        ? timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'vi')
                                        : 'Vừa xong',
                                    style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 12, color: Color(0xFF545454)),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.more_horiz, color: Color(0xFF777777)), // CSS: mage:dots
                          ],
                        ),
                      ),

                      // --- HASHTAGS (CSS: Frame 29018 / Frame 1365) ---
                      if (data['hashtags'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 8,
                            children: (data['hashtags'] as List).map((tag) {
                              // Màu sắc hashtag tùy chỉnh theo text (Cảnh báo: Đỏ, còn lại: Xám xanh)
                              bool isWarning = tag.toString().toLowerCase().contains('cảnh báo');
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isWarning ? const Color(0xFFFF6C6C).withOpacity(0.6) : const Color(0xFFEDEDED).withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.tag, size: 13, color: Color(0xFF344054)),
                                    const SizedBox(width: 2),
                                    Text(
                                      tag.toString(),
                                      style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 10, color: Colors.black),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // --- CONTENT (CSS: Encode Sans Expanded 15px) ---
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          data['content'] ?? '',
                          style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: Color(0xFF545454), height: 1.4),
                        ),
                      ),

                      // --- IMAGE (Nếu có) ---
                      _buildSafeImage(context, data['imageUrl']),

                      const SizedBox(height: 12),

                      // --- ACTION ROW (Like, Comment, Save) ---
                      GestureDetector(
                        onTap: () {},
                        behavior: HitTestBehavior.opaque,
                        child: PostActionRow(
                          docId: docId,
                          data: data,
                          onSave: widget.onSave,
                          collectionPath: 'forum_posts',
                        ),
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
      floatingActionButton: FloatingActionButton(
        heroTag: "fab_forum_tab",
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostPage())),
        backgroundColor: const Color(0xFF5893D8), // Đồng bộ màu Primary mới
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_outlined, color: Colors.white, size: 30),
      ),
    );
  }
}