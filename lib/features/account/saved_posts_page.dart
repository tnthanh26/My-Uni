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

class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    timeago.setLocaleMessages('vi', CustomViMessages());
  }

  @override
  void dispose() {
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
        color: Colors.black.withOpacity(0.18),
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

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required bool isDarkMode,
    Color? customColor,
    Color? customIconColor,
  }) {
    final Color textColor = customColor ??
        (isDarkMode ? Colors.white70 : const Color(0xFF344054));
    final Color iconColor = customIconColor ?? textColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.06)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkButton(String docId, bool isDarkMode) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _removeSave(docId),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFFFCB45).withOpacity(isDarkMode ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFCB45).withOpacity(0.25),
          ),
        ),
        child: const Icon(
          Icons.bookmark_rounded,
          color: Color(0xFFFFCB45),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildImagePreviewFromMemory(Uint8List bytes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Image.memory(
            bytes,
            width: double.infinity,
            height: 190,
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
        ],
      ),
    );
  }

  Widget _buildOfficialCard(Map<String, dynamic> data, String docId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF5893D8).withOpacity(
                  isDarkMode ? 0.16 : 0.10,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.campaign_outlined,
                    size: 16,
                    color: Color(0xFF5893D8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Tin chính thức đã lưu",
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.white70
                          : const Color(0xFF356DA8),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
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
                        Text(
                          data['department'] ?? 'HCMUS News',
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data['date'] ?? '',
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
                  _buildBookmarkButton(docId, isDarkMode),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                data['title'] ?? '',
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  height: 1.4,
                  color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/news.png',
                  width: double.infinity,
                  height: 190,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => _launchURL(data['link'] ?? ''),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF5893D8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: isDarkMode
                        ? Colors.white.withOpacity(0.02)
                        : const Color(0xFFF8FBFF),
                  ),
                  label: const Text(
                    'Xem chi tiết bài viết',
                    style: TextStyle(
                      color: Color(0xFF5893D8),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Encode Sans Expanded',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForumCard(Map<String, dynamic> data, String docId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String? avatarData = data['authorAvatar'];

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(
                  isDarkMode ? 0.16 : 0.10,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.forum_outlined,
                    size: 16,
                    color: Color(0xFF8B5CF6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Bài diễn đàn đã lưu",
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.white70
                          : const Color(0xFF6D28D9),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                    isDarkMode ? Colors.white10 : const Color(0xFFF0F0F0),
                    backgroundImage:
                    (avatarData != null && avatarData.isNotEmpty)
                        ? MemoryImage(base64Decode(avatarData))
                        : null,
                    child: (avatarData == null || avatarData.isEmpty)
                        ? Icon(
                      Icons.person,
                      color: isDarkMode
                          ? Colors.white38
                          : Colors.grey,
                    )
                        : null,
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
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data['timestamp'] != null
                              ? timeago.format(
                            (data['timestamp'] as Timestamp).toDate(),
                            locale: 'vi',
                          )
                              : 'Vừa xong',
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
                  _buildBookmarkButton(docId, isDarkMode),
                ],
              ),
            ),
            if (data['hashtags'] != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (data['hashtags'] as List)
                      .map(
                        (tag) => _buildInfoChip(
                      icon: Icons.tag_rounded,
                      label: tag,
                      isDarkMode: isDarkMode,
                      customIconColor: const Color(0xFF306CFE),
                    ),
                  )
                      .toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                data['content'] ?? '',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 15,
                  color:
                  isDarkMode ? Colors.white70 : const Color(0xFF4B5563),
                  height: 1.6,
                ),
              ),
            ),
            if (data['imageUrl'] != null &&
                data['imageUrl'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildImagePreviewFromMemory(
                  base64Decode(data['imageUrl']),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> data, String docId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final int rating = (data['rating'] ?? 0) is int
        ? data['rating'] ?? 0
        : ((data['rating'] ?? 0) as num).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCB45).withOpacity(
                  isDarkMode ? 0.14 : 0.10,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.rate_review_rounded,
                    size: 16,
                    color: Color(0xFFC98A00),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Review đã lưu",
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.white70
                          : const Color(0xFF946200),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['courseName'] ?? '',
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Giảng viên: ${data['teacherName'] ?? ''}",
                          style: const TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Color(0xFF5893D8),
                          ),
                        ),
                        if ((data['semester'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            data['semester'],
                            style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontSize: 13,
                              color: isDarkMode
                                  ? Colors.white60
                                  : const Color(0xFF667085),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildBookmarkButton(docId, isDarkMode),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ...List.generate(
                    5,
                        (i) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        i < rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: i < rating
                            ? const Color(0xFFFFCB45)
                            : (isDarkMode
                            ? Colors.white12
                            : const Color(0xFFD9D9D9)),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "$rating/5",
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDarkMode
                          ? Colors.white
                          : const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Text(
                data['content'] ?? '',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 15,
                  color:
                  isDarkMode ? Colors.white70 : const Color(0xFF4B5563),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> data, String docId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String? fileData = data['fileData'];
    String? fileName = data['fileName'];
    bool isImage = data['isImage'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(
                  isDarkMode ? 0.16 : 0.10,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    size: 16,
                    color: Color(0xFF8B5CF6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Tài liệu đã lưu",
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.white70
                          : const Color(0xFF6D28D9),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['courseName'] ?? 'Tài liệu',
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Giảng viên: ${data['teacherName'] ?? ''}",
                          style: const TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Color(0xFF5893D8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildBookmarkButton(docId, isDarkMode),
                ],
              ),
            ),
            if ((data['content'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  data['content'] ?? '',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 15,
                    color:
                    isDarkMode ? Colors.white70 : const Color(0xFF4B5563),
                    height: 1.6,
                  ),
                ),
              ),
            if (fileData != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GestureDetector(
                  onTap: () => _handleOpenFile(
                    context,
                    fileData,
                    fileName ?? 'document',
                  ),
                  child: isImage
                      ? _buildImagePreviewFromMemory(base64Decode(fileData))
                      : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.04)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white10
                            : const Color(0xFFEAEFF5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5893D8)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.description_rounded,
                            color: Color(0xFF5893D8),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            fileName ?? 'Tài liệu',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.file_download_outlined,
                          color: isDarkMode
                              ? Colors.white38
                              : const Color(0xFF777777),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 72,
              color: isDarkMode ? Colors.white38 : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 18),
            Text(
              "Danh sách lưu trống!",
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white70 : const Color(0xFF545454),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Lưu lại những bài viết, review hay tài liệu quan trọng để xem lại sau.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                color: Colors.grey,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5893D8),
                minimumSize: const Size(200, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Về trang chủ",
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedList(String type) {
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

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String docId = docs[index].id;

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
            fontFamily: 'Encode Sans Expanded',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF545454),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: const Color(0xFF5893D8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor:
              isDarkMode ? Colors.white38 : const Color(0xFF777777),
              labelStyle: const TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(text: "Diễn đàn chung"),
                Tab(text: "Khóa học"),
              ],
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