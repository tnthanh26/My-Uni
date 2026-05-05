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
      final filePath =
          '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(filePath);
      await file.writeAsBytes(base64Decode(base64Data));
      await OpenFilex.open(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Không thể mở ảnh / file")),
        );
      }
    }
  }

  Widget _buildSafeImage(BuildContext context, String? imgData) {
    if (imgData == null || imgData.isEmpty) return const SizedBox();

    try {
      return GestureDetector(
        onTap: () => _viewImage(context, imgData),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Image.memory(
                base64Decode(imgData),
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.02),
                        Colors.black.withOpacity(0.22),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_full_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Mở ảnh',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Encode Sans Expanded',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return const SizedBox();
    }
  }

  Widget _buildTagChip(dynamic tag, bool isDarkMode) {
    final String tagText = tag.toString();
    final String lowerTag = tagText.toLowerCase();

    final bool isWarning = lowerTag.contains('cảnh báo');
    final bool isHot =
        lowerTag.contains('hot') ||
            lowerTag.contains('gấp') ||
            lowerTag.contains('urgent');

    Color bgColor;
    Color borderColor;
    Color textColor;
    Color iconColor;
    IconData icon;

    if (isWarning) {
      bgColor = const Color(0xFFFF6C6C).withOpacity(isDarkMode ? 0.22 : 0.14);
      borderColor = const Color(0xFFFF6C6C).withOpacity(0.35);
      textColor = isDarkMode ? Colors.white : const Color(0xFF9F1239);
      iconColor = textColor;
      icon = Icons.warning_amber_rounded;
    } else if (isHot) {
      bgColor = const Color(0xFFFFB020).withOpacity(isDarkMode ? 0.20 : 0.14);
      borderColor = const Color(0xFFFFB020).withOpacity(0.35);
      textColor = isDarkMode ? Colors.white : const Color(0xFF92400E);
      iconColor = textColor;
      icon = Icons.local_fire_department_rounded;
    } else {
      bgColor = isDarkMode
          ? Colors.white.withOpacity(0.06)
          : const Color(0xFFF1F5F9);
      borderColor = isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0);
      textColor = isDarkMode ? Colors.white70 : const Color(0xFF344054);

      iconColor = const Color(0xFF306CFE);

      icon = Icons.tag_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: iconColor,
          ),
          const SizedBox(width: 4),
          Text(
            tagText,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorAvatar(String? avatarData, bool isDarkMode) {
    if (avatarData != null && avatarData.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: 23,
          backgroundColor: isDarkMode ? Colors.white10 : Colors.white,
          child: CircleAvatar(
            radius: 21,
            backgroundImage: MemoryImage(base64Decode(avatarData)),
          ),
        );
      } catch (e) {
        return CircleAvatar(
          radius: 23,
          backgroundColor: isDarkMode ? Colors.white10 : const Color(0xFFF0F0F0),
          child: Icon(
            Icons.person,
            color: isDarkMode ? Colors.white38 : Colors.grey,
          ),
        );
      }
    }

    return CircleAvatar(
      radius: 23,
      backgroundColor: isDarkMode ? Colors.white10 : const Color(0xFFF0F0F0),
      child: Icon(
        Icons.person,
        color: isDarkMode ? Colors.white38 : Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('forum_posts')
            .where('status', isEqualTo: 'approved')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5893D8)),
            );
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white10
                        : const Color(0xFFE9EEF3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 42,
                      color: isDarkMode ? Colors.white38 : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Chưa có bài viết nào.",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String docId = doc.id;
              String? avatarData = data['authorAvatar'];
              final String content = data['content']?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white10
                        : const Color(0xFFE9EEF3),
                  ),
                  boxShadow: isDarkMode
                      ? []
                      : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailPage(
                              docId: docId,
                              initialPostData: data,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                            child: Row(
                              children: [
                                _buildAuthorAvatar(avatarData, isDarkMode),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['authorName'] ?? 'Sinh viên ẩn danh',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily:
                                          'Encode Sans Expanded',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF2C2C2C),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        data['timestamp'] != null
                                            ? timeago.format(
                                          (data['timestamp'] as Timestamp)
                                              .toDate(),
                                          locale: 'vi',
                                        )
                                            : 'Vừa xong',
                                        style: TextStyle(
                                          fontFamily:
                                          'Encode Sans Expanded',
                                          fontSize: 12,
                                          color: isDarkMode
                                              ? Colors.white60
                                              : const Color(0xFF667085),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (data['hashtags'] != null &&
                              (data['hashtags'] as List).isNotEmpty)
                            Padding(
                              padding:
                              const EdgeInsets.fromLTRB(14, 0, 14, 10),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (data['hashtags'] as List)
                                    .map((tag) => _buildTagChip(tag, isDarkMode))
                                    .toList(),
                              ),
                            ),

                          if (content.trim().isNotEmpty)
                            Padding(
                              padding:
                              const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: Text(
                                content,
                                style: TextStyle(
                                  fontFamily: 'Encode Sans Expanded',
                                  fontSize: 15,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : const Color(0xFF4B5563),
                                  height: 1.6,
                                ),
                              ),
                            ),

                          if (data['imageUrl'] != null &&
                              data['imageUrl'].toString().isNotEmpty)
                            Padding(
                              padding:
                              const EdgeInsets.fromLTRB(14, 0, 14, 12),
                              child: _buildSafeImage(context, data['imageUrl']),
                            ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.03)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: GestureDetector(
                                onTap: () {},
                                behavior: HitTestBehavior.opaque,
                                child: PostActionRow(
                                  docId: docId,
                                  data: data,
                                  onSave: widget.onSave,
                                  collectionPath: 'forum_posts',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "fab_forum_tab",
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreatePostPage()),
        ),
        backgroundColor: const Color(0xFF5893D8),
        elevation: 5,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.edit_outlined,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}