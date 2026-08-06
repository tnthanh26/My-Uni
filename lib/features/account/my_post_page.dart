import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_uni/features/home/create_post_page.dart';
import 'package:my_uni/features/home/create_material_page.dart';
import 'package:my_uni/features/home/post_detail_page.dart';
import 'package:my_uni/features/home/poll_widget.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:my_uni/utils/custom_timeago_messages.dart';
import 'package:my_uni/features/search/myuni_search_delegate.dart';
import 'package:my_uni/widgets/app_action_dialogs.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('vi', CustomViMessages());
    _tabController = TabController(length: 2, vsync: this);
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

  Widget _buildStatusBadge(String status) {
    final bool isPending = status == 'pending';
    final Color bgColor = isPending
        ? Colors.orange.withOpacity(0.12)
        : Colors.green.withOpacity(0.12);
    final Color borderColor = isPending
        ? Colors.orange.withOpacity(0.35)
        : Colors.green.withOpacity(0.35);
    final Color textColor = isPending ? Colors.orange : Colors.green;
    final IconData icon =
    isPending ? Icons.schedule_rounded : Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 5),
          Text(
            isPending ? "Đang chờ duyệt" : "Đã đăng",
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
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
  }) {
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
          Icon(
            icon,
            size: 13,
            color: isDarkMode ? Colors.white70 : const Color(0xFF344054),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : const Color(0xFF344054),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(isDarkMode ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.20),
          ),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildImagePreview(String base64Str) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.memory(
              base64Decode(base64Str),
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
      ),
    );
  }

  void _navigateToEdit(
      BuildContext context,
      String collection,
      String docId,
      Map<String, dynamic> data,
      ) {
    Widget targetPage;
    if (collection == 'study_materials') {
      targetPage = CreateMaterialPage(docId: docId, existingData: data);
    } else {
      targetPage = CreatePostPage(docId: docId, existingData: data);
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetPage),
    );
  }

  void _confirmDelete(BuildContext context, DocumentReference ref) async {
    final confirm = await AppActionDialogs.showConfirmDialog(
      context: context,
      title: 'Xóa bài viết?',
      message: 'Hành động này sẽ xóa vĩnh viễn dữ liệu.',
      confirmText: 'Xóa',
    );
    if (confirm == true) {
      await ref.delete();
    }
  }

  Widget _buildEmptyState(BuildContext context, String collectionPath) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isForum = collectionPath == 'forum_posts';

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
              isForum ? Icons.forum_outlined : Icons.menu_book_outlined,
              size: 42,
              color: isDarkMode ? Colors.white38 : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              isForum
                  ? "Bạn chưa có bài đăng diễn đàn nào."
                  : "Bạn chưa có tài liệu nào.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => isForum
                        ? const CreatePostPage()
                        : const CreateMaterialPage(),
                  ),
                );
              },
              icon: Icon(
                isForum ? Icons.add_comment_rounded : Icons.upload_file_rounded,
                size: 20,
              ),
              label: Text(
                isForum ? "Tạo bài đăng ngay" : "Tải tài liệu lên",
                style: const TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5893D8),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildPostList(String collectionPath) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionPath)
          .where('authorId', isEqualTo: user?.uid)
          .where('status', isNotEqualTo: 'hidden')
          .orderBy('status')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF5893D8)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(context, collectionPath);
        }

        final cleanQuery = removeVietnameseDiacritics(_searchQuery);
        final filteredDocs = snapshot.data!.docs.where((doc) {
          if (cleanQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final content = removeVietnameseDiacritics(
              (data['content'] ?? data['fileName'] ?? data['description'] ?? '').toString());
          final subject = removeVietnameseDiacritics(
              (data['subject'] ?? data['courseName'] ?? '').toString());
          final hashtags = removeVietnameseDiacritics(
              (data['hashtags'] ?? []).join(' '));
          return content.contains(cleanQuery) ||
              subject.contains(cleanQuery) ||
              hashtags.contains(cleanQuery);
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
                    'Không tìm thấy bài đăng phù hợp',
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var doc = filteredDocs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildDetailedItem(
              context,
              doc.id,
              data,
              collectionPath,
              doc.reference,
            );
          },
        );
      },
    );
  }

  Widget _buildDetailedItem(
      BuildContext context,
      String docId,
      Map<String, dynamic> data,
      String collectionPath,
      DocumentReference ref,
      ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String? avatarData = data['authorAvatar'];
    String currentStatus = data['status'] ?? 'pending';
    final bool isForum = collectionPath == 'forum_posts';

    bool canEdit = true;
    if (data['timestamp'] != null) {
      try {
        final Timestamp ts = data['timestamp'] as Timestamp;
        final DateTime postTime = ts.toDate();
        if (DateTime.now().difference(postTime).inHours >= 12) {
          canEdit = false;
        }
      } catch (e) {
        debugPrint("Error checking post edit timeframe: $e");
      }
    }

    final String title = isForum
        ? "Bạn"
        : (data['courseName']?.toString().isNotEmpty == true
        ? data['courseName']
        : "Tài liệu");

    final String subtitle = data['timestamp'] != null
        ? timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'vi')
        : 'Vừa xong';

    final String content = data['content'] ??
        (collectionPath == 'study_materials'
            ? (data['fileName'] ?? 'Tài liệu không tên')
            : '');

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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final bool? result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PostDetailPage(docId: docId, initialPostData: data),
                ),
              );
              if (result == true && mounted) {
                setState(() {});
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 23,
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
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
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
                      _buildStatusBadge(currentStatus),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!isForum &&
                          (data['semester']?.toString().isNotEmpty == true))
                        _buildInfoChip(
                          icon: Icons.calendar_month_rounded,
                          label: data['semester'],
                          isDarkMode: isDarkMode,
                        ),
                    ],
                  ),
                ),

                if (isForum && data['hashtags'] != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (data['hashtags'] as List).map((tag) {
                        return GestureDetector(
                          onTap: () {
                            final cleanTag = tag.toString().replaceAll('#', '').trim();
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
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white10
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
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
                                  size: 14,
                                  color: Color(0xFF306CFE),
                                ),
                                const SizedBox(width: 5),
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
                      }).toList(),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text(
                    content,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildImagePreview(data['imageUrl']),
                  ),

                if (collectionPath == 'study_materials' &&
                    data['isImage'] == true &&
                    data['fileData'] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildImagePreview(data['fileData']),
                  ),

                if (isForum && data['poll'] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: PollWidget(docId: docId, pollData: data['poll']),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      _buildInfoChip(
                        icon: Icons.favorite_outline_rounded,
                        label: "${data['likeCount'] ?? 0}",
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: "${data['commentCount'] ?? 0}",
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Row(
                    children: [
                      if (canEdit) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _navigateToEdit(
                              context,
                              collectionPath,
                              docId,
                              data,
                            ),
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Color(0xFF5893D8),
                              size: 18,
                            ),
                            label: const Text(
                              "Chỉnh sửa",
                              style: TextStyle(
                                color: Color(0xFF5893D8),
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Encode Sans Expanded',
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF5893D8)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: isDarkMode
                                  ? Colors.white.withOpacity(0.02)
                                  : const Color(0xFFF8FBFF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (!canEdit)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _confirmDelete(context, ref),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFFF6C6C),
                              size: 18,
                            ),
                            label: Text(
                              collectionPath == 'study_materials'
                                  ? "Xóa tài liệu"
                                  : "Xóa bài viết",
                              style: const TextStyle(
                                color: Color(0xFFFF6C6C),
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Encode Sans Expanded',
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFF6C6C)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: isDarkMode
                                  ? Colors.white.withOpacity(0.02)
                                  : const Color(0xFFFFF5F5),
                            ),
                          ),
                        )
                      else
                        _buildActionButton(
                          icon: Icons.delete_outline_rounded,
                          color: const Color(0xFFFF6C6C),
                          onTap: () => _confirmDelete(context, ref),
                          isDarkMode: isDarkMode,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          "Bài đăng của tôi",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF545454),
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(76),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.05)
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
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: "Diễn đàn"),
                  Tab(text: "Tài liệu"),
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
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F2F6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF5893D8),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm bài đăng...',
                        hintStyle: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 13.5,
                          color: isDarkMode
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.cancel_rounded,
                        size: 18,
                        color: isDarkMode
                            ? Colors.white38
                            : const Color(0xFF94A3B8),
                      ),
                      onPressed: () {
                        _searchController.clear();
                      },
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostList('forum_posts'),
                _buildPostList('study_materials'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}