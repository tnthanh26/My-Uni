/// UI Refactoring Changes for saved_posts_page.dart:
/// - Unified Design System: Primary Color #5893D8, Background #F8FAFC, Surface Light White, Surface Dark #15171A, Border #E4E7EC.
/// - Header & Typography: Nunito font for AppBar title, Encode Sans Expanded for content text.
/// - Banner Removal: Eliminated full-width colored header banners across Official, Forum, Review, and Material cards.
/// - Type Chips & Bookmark: Replaced banners with sleek category chips (Tin chính thức, Diễn đàn, Đánh giá, Tài liệu) and standardized compact 36x36 bookmark buttons at top-right.
/// - Hashtags: Limited to maximum 3 hashtags with an overflow chip (+N) on Forum cards.
/// - Review Card Alignment: Standardized saved review cards to mirror the my_review_page.dart card layout.
/// - Material Card Alignment: Standardized saved material cards with file preview boxes and clear action hierarchy.
/// - Aligned empty state layout with circular icon container and primary CTA button.
/// - Preserved all Firestore queries, saved item deletion logic (_removeSave), search diacritics removal, navigation delegates, and file opening handlers.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:my_uni/utils/custom_timeago_messages.dart';
import 'package:my_uni/features/home/post_detail_page.dart';
import 'package:my_uni/utils/anonymous_utils.dart';
import 'package:my_uni/features/search/myuni_search_delegate.dart';
import 'package:my_uni/features/home/official_content_helper.dart';

String removeVietnameseDiacritics(String str) {
  const vietnameseMap = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'A': 'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ',
    'd': 'đ',
    'D': 'Đ',
    'e': 'èéẹẻẽêềếệểễ',
    'E': 'ÈÉẸẺẼÊỀẾỆỂỄ',
    'i': 'ìíịỉĩ',
    'I': 'ÌÍỊỈĨ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'O': 'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ',
    'u': 'ùúụủũưừứựửữ',
    'U': 'ÙÚỤỦŨƯỪỨỰỬỮ',
    'y': 'ỳýỵỷỹ',
    'Y': 'ỲÝỴỶỸ',
  };

  String result = str;
  vietnameseMap.forEach((nonDiacritics, diacritics) {
    for (int i = 0; i < diacritics.length; i++) {
      result = result.replaceAll(diacritics[i], nonDiacritics);
    }
  });
  return result.toLowerCase();
}

class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    timeago.setLocaleMessages('vi', CustomViMessages());
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _getCollectionPath(Map<String, dynamic> data) {
    if (data.containsKey('link')) return 'official_news';
    if (data.containsKey('rating')) return 'course_reviews';
    if (data.containsKey('fileData')) return 'study_materials';
    return 'forum_posts';
  }

  Future<void> _launchURL(String urlString) async {
    if (urlString.trim().isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  }

  Future<void> _handleOpenFile(
    BuildContext context,
    String base64Data,
    String fileName,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(base64Decode(base64Data));
      await OpenFilex.open(filePath);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $e")),
        );
      }
    }
  }

  Future<void> _removeSave(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_posts')
        .doc(docId)
        .delete();
  }

  void _navigateToDetail(Map<String, dynamic> data, String savedDocId) async {
    String originalId = data['originalDocId'] ?? savedDocId;
    String collectionPath = _getCollectionPath(data);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Container(
        color: Colors.black.withValues(alpha: 0.18),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF5893D8)),
        ),
      ),
    );

    try {
      DocumentSnapshot originalDoc = await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(originalId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;
      Navigator.pop(context);

      if (originalDoc.exists) {
        Map<String, dynamic> currentData =
            originalDoc.data() as Map<String, dynamic>;

        if (currentData['status'] == 'hidden') {
          _showUnavailableMessage(savedDocId);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(
                docId: originalId,
                initialPostData: currentData,
              ),
            ),
          );
        }
      } else {
        _showUnavailableMessage(savedDocId);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showUnavailableMessage(savedDocId);
    }
  }

  void _showUnavailableMessage(String savedDocId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          "Thông báo",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          "Bài viết này không còn tồn tại hoặc đã bị gỡ bỏ. Bạn có muốn xóa bản lưu này không?",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Đóng",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeSave(savedDocId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Đã gỡ bản lưu không còn khả dụng."),
                  ),
                );
              }
            },
            child: const Text(
              "Xóa bản lưu",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Encode Sans Expanded',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _formatTimestampText(Map<String, dynamic> data) {
    if (data['timestamp'] != null) {
      try {
        if (data['timestamp'] is Timestamp) {
          return timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'vi');
        } else if (data['timestamp'] is String &&
            data['timestamp'].toString().trim().isNotEmpty) {
          return data['timestamp'].toString().trim();
        }
      } catch (_) {}
    }
    if (data['savedAt'] != null) {
      try {
        if (data['savedAt'] is Timestamp) {
          return timeago.format((data['savedAt'] as Timestamp).toDate(), locale: 'vi');
        }
      } catch (_) {}
    }
    if (data['date'] != null && data['date'].toString().trim().isNotEmpty) {
      return data['date'].toString().trim();
    }
    if (data['createdAt'] != null) {
      try {
        if (data['createdAt'] is Timestamp) {
          return timeago.format((data['createdAt'] as Timestamp).toDate(), locale: 'vi');
        }
      } catch (_) {}
    }
    return 'Vừa xong';
  }

  Widget _buildRatingStars(int rating, bool isDarkMode) {
    return Row(
      children: [
        ...List.generate(
          5,
          (i) => Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i < rating
                  ? const Color(0xFFFFCB45)
                  : (isDarkMode ? Colors.white12 : const Color(0xFFD9D9D9)),
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "$rating/5",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreviewFromMemory(Uint8List bytes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Image.memory(
            bytes,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.02),
                    Colors.black.withValues(alpha: 0.22),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialCard(Map<String, dynamic> data, String docId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE4E7EC),
        ),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['department'] ?? 'HCMUS News',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTimestampText(data),
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.white54
                                : const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTypeChip("Tin chính thức", const Color(0xFF5893D8), isDarkMode),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                data['title'] ?? '',
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                  height: 1.4,
                  color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  OfficialContentHelper.getOfficialImageByContent(
                    data['title'],
                    data['summary'],
                  ),
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              if ((data['link'] ?? data['sourceUrl'] ?? data['sourceArticleUrl'])
                      ?.toString()
                      .trim()
                      .isNotEmpty ??
                  false) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () => _launchURL(
                        (data['link'] ?? data['sourceUrl'] ?? data['sourceArticleUrl'])
                            ?.toString() ??
                            ''),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF5893D8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: isDarkMode
                          ? Colors.white.withValues(alpha: 0.02)
                          : const Color(0xFFF8FBFF),
                    ),
                    label: const Text(
                      'Xem chi tiết bài viết',
                      style: TextStyle(
                        color: Color(0xFF5893D8),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForumCard(Map<String, dynamic> data, String docId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String? avatarData = data['authorAvatar'];
    final bool isAnonymous = (data['isAnonymous'] == true) ||
        (data['authorName']?.toString().toLowerCase().contains('vô danh') ?? false) ||
        (data['authorName']?.toString().toLowerCase().contains('ẩn danh') ?? false);

    List rawTags = (data['hashtags'] is List) ? data['hashtags'] : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE4E7EC),
        ),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                setState(() {});
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            isDarkMode ? Colors.white10 : const Color(0xFFF0F0F0),
                        backgroundImage: (!isAnonymous &&
                                avatarData != null &&
                                avatarData.isNotEmpty)
                            ? MemoryImage(base64Decode(avatarData))
                            : null,
                        child: (isAnonymous ||
                                avatarData == null ||
                                avatarData.isEmpty)
                            ? Icon(
                                Icons.person,
                                size: 20,
                                color: isDarkMode
                                    ? Colors.white38
                                    : Colors.grey,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAnonymous
                                  ? AnonymousUtils.anonymousPostAuthorName
                                  : (data['authorName'] ?? 'Sinh viên ẩn danh'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestampText(data),
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white54
                                    : const Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTypeChip("Diễn đàn", const Color(0xFF8B5CF6), isDarkMode),
                    ],
                  ),

                  if (rawTags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...rawTags.take(3).map((tag) {
                          return GestureDetector(
                            onTap: () {
                              final cleanTag =
                                  tag.toString().replaceAll('#', '').trim();
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDarkMode
                                      ? Colors.white10
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.tag_rounded,
                                    size: 13,
                                    color: Color(0xFF306CFE),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tag.toString(),
                                    style: TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : const Color(0xFF344054),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (rawTags.length > 3)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.white10
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              "+${rawTags.length - 3}",
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDarkMode
                                    ? Colors.white54
                                    : const Color(0xFF667085),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),
                  Text(
                    data['content'] ?? '',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 13.5,
                      color: isDarkMode ? Colors.white70 : const Color(0xFF374151),
                      height: 1.45,
                    ),
                  ),

                  if (data['imageUrl'] != null &&
                      data['imageUrl'].toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildImagePreviewFromMemory(
                      base64Decode(data['imageUrl']),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> data, String docId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final int rating = (data['rating'] ?? 0) is int
        ? data['rating'] ?? 0
        : ((data['rating'] ?? 0) as num).toInt();

    final String teacherName = data['teacherName'] ?? data['teacher'] ?? '';
    final String semester = (data['semester'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE4E7EC),
        ),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['courseName'] ?? 'Đánh giá môn học',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF1F2937),
                          ),
                        ),
                        if (teacherName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            "GV: $teacherName",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontSize: 12.5,
                              color: isDarkMode
                                  ? Colors.white54
                                  : const Color(0xFF667085),
                            ),
                          ),
                        ],
                        if (semester.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            semester,
                            style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.white54
                                  : const Color(0xFF667085),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTypeChip("Đánh giá", const Color(0xFFFF9800), isDarkMode),
                ],
              ),
              const SizedBox(height: 10),
              _buildRatingStars(rating, isDarkMode),
              const SizedBox(height: 10),
              Text(
                data['content'] ?? data['reviewContent'] ?? '',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 13.5,
                  color: isDarkMode ? Colors.white70 : const Color(0xFF374151),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> data, String docId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String? fileData = data['fileData'];
    String? fileName = data['fileName'];
    bool isImage = data['isImage'] ?? false;
    final String teacherName = data['teacherName'] ?? data['teacher'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE4E7EC),
        ),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['courseName'] ?? 'Tài liệu môn học',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF1F2937),
                          ),
                        ),
                        if (teacherName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            "GV: $teacherName",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontSize: 12.5,
                              color: isDarkMode
                                  ? Colors.white54
                                  : const Color(0xFF667085),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTypeChip("Tài liệu", const Color(0xFF00C853), isDarkMode),
                ],
              ),
              if ((data['content'] ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  data['content'] ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 13.5,
                    color: isDarkMode ? Colors.white70 : const Color(0xFF374151),
                    height: 1.45,
                  ),
                ),
              ],
              if (fileData != null) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _handleOpenFile(
                    context,
                    fileData,
                    fileName ?? 'document',
                  ),
                  child: isImage
                      ? _buildImagePreviewFromMemory(base64Decode(fileData))
                      : Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.white10
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5893D8)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.description_rounded,
                                  color: Color(0xFF5893D8),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  fileName ?? 'Tài liệu',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.file_download_outlined,
                                size: 20,
                                color: isDarkMode
                                    ? Colors.white38
                                    : const Color(0xFF777777),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                size: 36,
                color: Color(0xFF5893D8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Danh sách lưu trống",
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Lưu lại những bài viết, review hay tài liệu quan trọng để xem lại sau.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5893D8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Về trang chủ",
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedList(String type) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('saved_posts')
          .where('saveType', isEqualTo: type)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF5893D8)),
          );
        }

        final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
        if (docs.isEmpty) return _buildEmptyState();

        // Sort descending by saved timestamp (newest saved items first)
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          dynamic timeA = dataA['savedAt'] ?? dataA['timestamp'] ?? dataA['createdAt'];
          dynamic timeB = dataB['savedAt'] ?? dataB['timestamp'] ?? dataB['createdAt'];

          DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
          DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);

          if (timeA is Timestamp) dateA = timeA.toDate();
          if (timeB is Timestamp) dateB = timeB.toDate();

          return dateB.compareTo(dateA);
        });

        final cleanQuery = removeVietnameseDiacritics(_searchQuery);
        final filteredDocs = docs.where((doc) {
          if (cleanQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final title = removeVietnameseDiacritics(
              (data['title'] ?? data['subject'] ?? data['courseName'] ?? '').toString());
          final content = removeVietnameseDiacritics(
              (data['content'] ?? data['description'] ?? data['reviewContent'] ?? '').toString());
          final author = removeVietnameseDiacritics(
              (data['authorName'] ?? data['department'] ?? data['teacher'] ?? '').toString());
          return title.contains(cleanQuery) ||
              content.contains(cleanQuery) ||
              author.contains(cleanQuery);
        }).toList();

        if (_searchQuery.isNotEmpty && filteredDocs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 40,
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Không tìm thấy bài viết đã lưu phù hợp',
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var data = filteredDocs[index].data() as Map<String, dynamic>;
            String docId = filteredDocs[index].id;

            if (data.containsKey('department')) {
              return GestureDetector(
                onTap: () => _navigateToDetail(data, docId),
                child: _buildOfficialCard(data, docId),
              );
            }
            if (data.containsKey('authorName') &&
                !data.containsKey('rating') &&
                !data.containsKey('fileData')) {
              return GestureDetector(
                onTap: () => _navigateToDetail(data, docId),
                child: _buildForumCard(data, docId),
              );
            }
            if (data.containsKey('rating')) {
              return GestureDetector(
                onTap: () => _navigateToDetail(data, docId),
                child: _buildReviewCard(data, docId),
              );
            }
            if (data.containsKey('fileData')) {
              return GestureDetector(
                onTap: () => _navigateToDetail(data, docId),
                child: _buildMaterialCard(data, docId),
              );
            }

            return const SizedBox();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF0F1113) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF111315) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDarkMode ? Colors.white70 : const Color(0xFF545454),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Bài đã lưu",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F2F6),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: const Color(0xFF5893D8),
                ),
                labelColor: Colors.white,
                unselectedLabelColor:
                    isDarkMode ? Colors.white38 : const Color(0xFF777777),
                labelStyle: const TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(
                    child: Text(
                      "Tin tức & Diễn đàn",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Tab(
                    child: Text(
                      "Review & Tài liệu",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 13,
                color: isDarkMode ? Colors.white : const Color(0xFF1D2939),
              ),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm bài đã lưu...',
                hintStyle: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: isDarkMode ? Colors.white38 : const Color(0xFF98A2B3),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        splashRadius: 18,
                        onPressed: () {
                          _searchController.clear();
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF1C1E21) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE4E7EC),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: Color(0xFF6797E1),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSavedList("general"),
                _buildSavedList("course"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}