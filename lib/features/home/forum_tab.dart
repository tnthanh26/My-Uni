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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Cập nhật màu nền động
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
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.transparent : Colors.white,
                  border: Border(
                      bottom: BorderSide(
                          color: isDarkMode ? Colors.white10 : const Color(0xFFDFE6E9),
                          width: 1
                      )
                  ),
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailPage(docId: docId, initialPostData: data)));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HEADER ---
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22.5,
                              backgroundColor: isDarkMode ? Colors.white10 : Colors.white,
                              child: CircleAvatar(
                                radius: 22.5,
                                backgroundColor: isDarkMode ? Colors.white12 : const Color(0xFFF0F0F0),
                                backgroundImage: (avatarData != null && avatarData.isNotEmpty)
                                    ? MemoryImage(base64Decode(avatarData)) : null,
                                child: (avatarData == null || avatarData.isEmpty)
                                    ? const Icon(Icons.person, color: Colors.grey) : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['authorName'] ?? 'Sinh viên ẩn danh',
                                    style: TextStyle(
                                        fontFamily: 'Encode Sans Expanded',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isDarkMode ? Colors.white : const Color(0xFF545454)
                                    ),
                                  ),
                                  Text(
                                    data['timestamp'] != null
                                        ? timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'vi')
                                        : 'Vừa xong',
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

                      // --- HASHTAGS ---
                      if (data['hashtags'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: (data['hashtags'] as List).map((tag) {
                              bool isWarning = tag.toString().toLowerCase().contains('cảnh báo');
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isWarning
                                      ? const Color(0xFFFF6C6C).withOpacity(isDarkMode ? 0.3 : 0.6)
                                      : (isDarkMode ? Colors.white10 : const Color(0xFFEDEDED).withOpacity(0.92)),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.tag, size: 13, color: Color(0xFF5893D8)),
                                    const SizedBox(width: 2),
                                    Text(
                                      tag.toString(),
                                      style: TextStyle(
                                          fontFamily: 'Encode Sans Expanded',
                                          fontSize: 10,
                                          color: isDarkMode ? Colors.white70 : Colors.black
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // --- CONTENT ---
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          data['content'] ?? '',
                          style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontSize: 15,
                              color: isDarkMode ? Colors.white : const Color(0xFF545454),
                              height: 1.4
                          ),
                        ),
                      ),

                      // --- IMAGE ---
                      _buildSafeImage(context, data['imageUrl']),

                      const SizedBox(height: 4),

                      // --- ACTION ROW ---
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
                      const SizedBox(height: 4),
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
        backgroundColor: const Color(0xFF5893D8),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_outlined, color: Colors.white, size: 30),
      ),
    );
  }
}