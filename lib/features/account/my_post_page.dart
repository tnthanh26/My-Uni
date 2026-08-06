/// UI Refactoring Changes for my_post_page.dart:
/// - Unified Design System: Primary Color #5893D8, Background #F8FAFC, Surface Light White, Surface Dark #15171A, Border #E4E7EC.
/// - Header & Typography: Nunito font for AppBar title, Encode Sans Expanded for content text.
/// - Card Hierarchy Optimization: Reduced card height by removing CircleAvatar and moving Edit/Delete actions into a top-right 3-dot menu (⋮).
/// - Conditional Status Badges: Badges are hidden for published/posted status, only appearing for pending/special statuses.
/// - Hashtags: Limited to maximum 3 hashtags with an overflow chip (+N).
/// - Metrics: Compact Like and Comment counters grouped cleanly at the bottom of the card.
/// - Aligned empty state with circular icon container and primary CTA button.
/// - Preserved all Firestore streams, edit timeframe checks (12 hours limit), search diacritics removal, poll widgets, and delete dialogs.

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
    final bool isRejected = status == 'rejected';
    final bool isNeedEdit = status == 'need_edit';

    String label = "Đang chờ duyệt";
    Color baseColor = Colors.orange;

    if (isRejected) {
      label = "Bị từ chối";
      baseColor = Colors.red;
    } else if (isNeedEdit) {
      label = "Cần chỉnh sửa";
      baseColor = Colors.amber;
    } else if (isPending) {
      label = "Đang chờ duyệt";
      baseColor = Colors.orange;
    } else {
      label = status;
      baseColor = const Color(0xFF5893D8);
    }

    final Color bgColor = baseColor.withValues(alpha: 0.12);
    final Color borderColor = baseColor.withValues(alpha: 0.35);
    final IconData icon = isPending
        ? Icons.schedule_rounded
        : (isRejected ? Icons.cancel_outlined : Icons.info_outline_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: baseColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: baseColor,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
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

  Widget _buildImagePreview(String base64Str) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.memory(
              base64Decode(base64Str),
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
              child: Icon(
                isForum ? Icons.forum_outlined : Icons.menu_book_outlined,
                size: 36,
                color: const Color(0xFF5893D8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isForum
                  ? "Chưa có bài đăng nào"
                  : "Chưa có tài liệu nào",
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isForum
                  ? "Bạn chưa có bài đăng diễn đàn nào. Đăng bài ngay để chia sẻ với mọi người."
                  : "Bạn chưa có tài liệu nào. Tải tài liệu môn học để lưu trữ và chia sẻ.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 13.5,
                color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 20),
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
                size: 18,
              ),
              label: Text(
                isForum ? "Tạo bài đăng ngay" : "Tải tài liệu lên",
                style: const TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5893D8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
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

    final bool showBadge = currentStatus != 'published' &&
        currentStatus != 'approved' &&
        currentStatus != 'posted' &&
        currentStatus != 'active';

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
                  builder: (context) =>
                      PostDetailPage(docId: docId, initialPostData: data),
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
                                fontWeight: FontWeight.bold,
                                fontSize: 15.5,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
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
                      if (showBadge) ...[
                        const SizedBox(width: 8),
                        _buildStatusBadge(currentStatus),
                      ],
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        color: isDarkMode ? const Color(0xFF1E2024) : Colors.white,
                        onSelected: (value) {
                          if (value == 'edit') {
                            _navigateToEdit(context, collectionPath, docId, data);
                          } else if (value == 'delete') {
                            _confirmDelete(context, ref);
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return [
                            if (canEdit)
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: Color(0xFF5893D8),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      "Chỉnh sửa",
                                      style: TextStyle(
                                        fontFamily: 'Encode Sans Expanded',
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF5893D8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFFF6C6C),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    collectionPath == 'study_materials'
                                        ? "Xóa tài liệu"
                                        : "Xóa bài viết",
                                    style: const TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFF6C6C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),

                  if (!isForum &&
                      (data['semester']?.toString().isNotEmpty == true)) ...[
                    const SizedBox(height: 6),
                    _buildInfoChip(
                      icon: Icons.calendar_month_rounded,
                      label: data['semester'],
                      isDarkMode: isDarkMode,
                    ),
                  ],

                  if (isForum && rawTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
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

                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 13.5,
                        color: isDarkMode
                            ? Colors.white70
                            : const Color(0xFF374151),
                        height: 1.45,
                      ),
                    ),
                  ],

                  if (data['imageUrl'] != null &&
                      data['imageUrl'].toString().isNotEmpty)
                    _buildImagePreview(data['imageUrl']),

                  if (collectionPath == 'study_materials' &&
                      data['isImage'] == true &&
                      data['fileData'] != null)
                    _buildImagePreview(data['fileData']),

                  if (isForum && data['poll'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: PollWidget(docId: docId, pollData: data['poll']),
                    ),

                  const SizedBox(height: 12),
                  Row(
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
                ],
              ),
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
                  fontSize: 13.5,
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
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 13,
                color: isDarkMode ? Colors.white : const Color(0xFF1D2939),
              ),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm bài đăng...',
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