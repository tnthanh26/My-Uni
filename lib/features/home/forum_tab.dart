import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:my_uni/utils/custom_timeago_messages.dart';
import 'package:my_uni/utils/base64_image_cache.dart';
import 'create_post_page.dart';
import 'post_action_row.dart';
import 'post_detail_page.dart';
import 'poll_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_uni/features/chat/services/chat_service.dart';
import 'package:my_uni/features/chat/widgets/student_identity_card.dart';
import 'package:my_uni/utils/anonymous_utils.dart';
import 'package:my_uni/features/search/myuni_search_delegate.dart';
import 'widgets/home_skeleton.dart';

class ForumTab extends StatefulWidget {
  final Function(String, Map<String, dynamic>) onSave;
  const ForumTab({super.key, required this.onSave});

  @override
  State<ForumTab> createState() => _ForumTabState();
}

class _ForumTabState extends State<ForumTab> {
  List<String>? _sortedPostIds;
  final Map<String, QueryDocumentSnapshot> _cachedPostsMap = {};

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('vi', CustomViMessages());
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
                Base64ImageCache.decode(imgData),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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

    return GestureDetector(
      onTap: () {
        final cleanTag = tagText.replaceAll('#', '').trim();
        if (cleanTag.isNotEmpty) {
          showSearch(
            context: context,
            delegate: MyUniSearchDelegate(
              currentScope: SearchScope.forum,
              initialHashtag: cleanTag,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white10 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tag_rounded, size: 14, color: Color(0xFF306CFE)),
            const SizedBox(width: 5),
            Text(
              tagText,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white70 : const Color(0xFF344054),
              ),
            ),
          ],
        ),
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
            backgroundImage: MemoryImage(Base64ImageCache.decode(avatarData)),
          ),
        );
      } catch (e) {
        return CircleAvatar(
          radius: 23,
          backgroundColor: isDarkMode
              ? Colors.white10
              : const Color(0xFFF0F0F0),
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
            return const PostCardSkeletonListView();
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

          List<QueryDocumentSnapshot> posts = snapshot.data!.docs;

          // Hàm tính điểm xu hướng (Trending Score) cho cộng đồng ~30 người dùng
          // Đã tinh chỉnh K (denominator): 1 ngày trôi qua = +10 điểm tương tác (thay vì +100 điểm)
          // Giúp bài viết nhiều like/comment ngày hôm qua vẫn đứng trên bài mới 0 tương tác hôm nay
          double calculateTrendingScore(Map<String, dynamic> data) {
            final double likes = (data['likeCount'] ?? 0).toDouble();
            final double comments = (data['commentCount'] ?? 0).toDouble();
            final Timestamp? time = data['timestamp'] as Timestamp?;
            double score = likes * 1.5 + comments * 3.0;
            if (time != null) {
              score += time.toDate().millisecondsSinceEpoch / (1000 * 8640.0);
            }
            return score;
          }

          if (_sortedPostIds == null) {
            // Khi tải lần đầu hoặc khi refresh: Tính toán điểm xu hướng và sắp xếp
            final List<QueryDocumentSnapshot> sorted = List.from(posts);
            sorted.sort((a, b) {
              final aScore = calculateTrendingScore(
                a.data() as Map<String, dynamic>,
              );
              final bScore = calculateTrendingScore(
                b.data() as Map<String, dynamic>,
              );
              return bScore.compareTo(aScore);
            });
            _sortedPostIds = sorted.map((doc) => doc.id).toList();
            _cachedPostsMap.clear();
            for (var doc in posts) {
              _cachedPostsMap[doc.id] = doc;
            }
          } else {
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;

            // 1. Tự động xóa bài viết khỏi UI nếu bài viết đó bị xóa khỏi Firestore (không cần trượt tay)
            final currentPostIds = posts.map((d) => d.id).toSet();
            _sortedPostIds!.removeWhere((id) => !currentPostIds.contains(id));
            _cachedPostsMap.removeWhere(
              (id, _) => !currentPostIds.contains(id),
            );

            // 2. Tự động nạp bài viết mới vào feed (khi vừa vào app hoặc khi có bài mới)
            bool hasNewPosts = false;
            for (var doc in posts) {
              if (!_cachedPostsMap.containsKey(doc.id)) {
                hasNewPosts = true;
                break;
              }
            }

            if (hasNewPosts) {
              final List<QueryDocumentSnapshot> sorted = List.from(posts);
              sorted.sort((a, b) {
                final aScore = calculateTrendingScore(
                  a.data() as Map<String, dynamic>,
                );
                final bScore = calculateTrendingScore(
                  b.data() as Map<String, dynamic>,
                );
                return bScore.compareTo(aScore);
              });
              _sortedPostIds = sorted.map((doc) => doc.id).toList();
              _cachedPostsMap.clear();
              for (var doc in posts) {
                _cachedPostsMap[doc.id] = doc;
              }
            } else {
              // Cập nhật tương tác mới (like/comment) cho các bài viết đã có
              for (var doc in posts) {
                if (_cachedPostsMap.containsKey(doc.id)) {
                  _cachedPostsMap[doc.id] = doc;
                }
              }
            }
          }

          // Ánh xạ lại các bài viết theo thứ tự đã được khóa
          final List<QueryDocumentSnapshot> orderedPosts = [];
          for (var id in _sortedPostIds!) {
            if (_cachedPostsMap.containsKey(id)) {
              orderedPosts.add(_cachedPostsMap[id]!);
            }
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600.0),
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _sortedPostIds = null;
                    _cachedPostsMap.clear();
                  });
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  itemCount: orderedPosts.length,
                  itemBuilder: (context, index) {
                    var doc = orderedPosts[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String docId = doc.id;
                    String? avatarData = data['authorAvatar'];
                    final String content = data['content']?.toString() ?? '';

                    final currentUser = FirebaseAuth.instance.currentUser;
                    final bool isOwner = currentUser?.uid == data['authorId'];
                    final bool isAnonymous =
                        (data['isAnonymous'] == true) ||
                        (data['authorName']?.toString().toLowerCase().contains(
                              'vô danh',
                            ) ??
                            false) ||
                        (data['authorName']?.toString().toLowerCase().contains(
                              'ẩn danh',
                            ) ??
                            false);
                    final bool showOwnAnonymousBadge = isOwner && isAnonymous;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF15171A)
                            : Colors.white,
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
                            onTap: () async {
                              final bool? result = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostDetailPage(
                                    docId: docId,
                                    initialPostData: data,
                                  ),
                                ),
                              );
                              if (result == true && mounted) {
                                setState(() {
                                  _sortedPostIds = null;
                                  _cachedPostsMap.clear();
                                });
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    14,
                                    14,
                                    10,
                                  ),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          if (isAnonymous) return;
                                          final authorId =
                                              (data['authorId'] ??
                                                      data['uploaderId'] ??
                                                      data['userId'] ??
                                                      data['uid'])
                                                  ?.toString() ??
                                              '';
                                          if (authorId.isEmpty) return;
                                          final info = await ChatService()
                                              .getStudentVerificationInfo(
                                                authorId,
                                              );
                                          if (context.mounted) {
                                            StudentIdentitySheet.show(
                                              context,
                                              info ??
                                                  {
                                                    'uid': authorId,
                                                    'displayName':
                                                        data['authorName'] ??
                                                        'Sinh viên',
                                                    'photoURL':
                                                        avatarData ?? '',
                                                  },
                                            );
                                          }
                                        },
                                        child: _buildAuthorAvatar(
                                          isAnonymous ? null : avatarData,
                                          isDarkMode,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () async {
                                                      if (isAnonymous) return;
                                                      final authorId =
                                                          (data['authorId'] ??
                                                                  data['uploaderId'] ??
                                                                  data['userId'] ??
                                                                  data['uid'])
                                                              ?.toString() ??
                                                          '';
                                                      if (authorId.isEmpty)
                                                        return;
                                                      final info =
                                                          await ChatService()
                                                              .getStudentVerificationInfo(
                                                                authorId,
                                                              );
                                                      if (context.mounted) {
                                                        StudentIdentitySheet.show(
                                                          context,
                                                          info ??
                                                              {
                                                                'uid': authorId,
                                                                'displayName':
                                                                    data['authorName'] ??
                                                                    'Sinh viên',
                                                                'photoURL':
                                                                    avatarData ??
                                                                    '',
                                                              },
                                                        );
                                                      }
                                                    },
                                                    child: Text(
                                                      isAnonymous
                                                          ? AnonymousUtils
                                                                .anonymousPostAuthorName
                                                          : (data['authorName'] ??
                                                                'Người dùng'),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontFamily:
                                                            'Encode Sans Expanded',
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                        color: isDarkMode
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF2C2C2C,
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (showOwnAnonymousBadge) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF5893D8,
                                                      ).withOpacity(0.12),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      "Của bạn",
                                                      style: TextStyle(
                                                        fontFamily:
                                                            'Encode Sans Expanded',
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Color(
                                                          0xFF5893D8,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              data['timestamp'] != null
                                                  ? timeago.format(
                                                      (data['timestamp']
                                                              as Timestamp)
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
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      0,
                                      14,
                                      10,
                                    ),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: (data['hashtags'] as List)
                                          .map(
                                            (tag) =>
                                                _buildTagChip(tag, isDarkMode),
                                          )
                                          .toList(),
                                    ),
                                  ),

                                if (content.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      0,
                                      14,
                                      14,
                                    ),
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
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      0,
                                      14,
                                      12,
                                    ),
                                    child: _buildSafeImage(
                                      context,
                                      data['imageUrl'],
                                    ),
                                  ),

                                if (data['poll'] != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: PollWidget(
                                      docId: docId,
                                      pollData: data['poll'],
                                    ),
                                  ),

                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    0,
                                    10,
                                    10,
                                  ),
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
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "fab_forum_tab",
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostPage()),
          );
          if (result == true || result != null) {
            setState(() {
              _sortedPostIds = null;
              _cachedPostsMap.clear();
            });
          }
        },
        backgroundColor: const Color(0xFF5893D8),
        elevation: 5,
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_outlined, color: Colors.white, size: 28),
      ),
    );
  }
}
