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
    if (imgData.startsWith('http')) {
      return Image.network(imgData, width: double.infinity, fit: BoxFit.cover);
    }
    try {
      return GestureDetector(
        onTap: () => _viewImage(context, imgData),
        child: Image.memory(base64Decode(imgData), width: double.infinity, fit: BoxFit.cover),
      );
    } catch (e) {
      return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('forum_posts').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF6797E1)));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String docId = doc.id;
              String? avatarData = data['authorAvatar'];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                // BỌC GESTUREDETECTOR LỚN ĐỂ VÀO DETAIL
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailPage(docId: docId, initialPostData: data),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orangeAccent.withOpacity(isDarkMode ? 0.3 : 0.2),
                          backgroundImage: (avatarData != null && avatarData.isNotEmpty) ? MemoryImage(base64Decode(avatarData)) : null,
                          child: (avatarData == null || avatarData.isEmpty) ? const Icon(Icons.person, color: Colors.orange) : null,
                        ),
                        title: Text(data['authorName'] ?? 'Sinh viên ẩn danh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87)),
                        subtitle: Text(data['timestamp'] != null ? timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'vi') : 'Vừa xong', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: Icon(Icons.more_horiz, color: isDarkMode ? Colors.white54 : Colors.grey),
                      ),
                      if (data['hashtags'] != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Wrap(
                            spacing: 8, runSpacing: 4,
                            children: (data['hashtags'] as List).map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFF6797E1).withOpacity(isDarkMode ? 0.15 : 0.1), borderRadius: BorderRadius.circular(12)),
                              child: Text('#$tag', style: TextStyle(color: isDarkMode ? const Color(0xFF91B5EE) : const Color(0xFF6797E1), fontSize: 12, fontWeight: FontWeight.w600)),
                            )).toList(),
                          ),
                        ),
                      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text(data['content'] ?? '', style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87, height: 1.5))),
                      const SizedBox(height: 12),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: _buildSafeImage(context, data['imageUrl']))),
                      Divider(height: 24, thickness: 0.5, indent: 16, endIndent: 16, color: isDarkMode ? Colors.white10 : Colors.black12),

                      // CHẶN CHẠM Ở THANH ACTION
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
        backgroundColor: const Color(0xFF6797E1), elevation: 6, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        child: const Icon(Icons.edit_outlined, color: Colors.white, size: 28),
      ),
    );
  }
}