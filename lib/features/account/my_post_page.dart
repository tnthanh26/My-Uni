import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_uni/features/home/create_post_page.dart';
import 'package:my_uni/features/home/create_material_page.dart';
import 'package:my_uni/features/home/post_detail_page.dart';
import 'package:timeago/timeago.dart' as timeago;

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('vi', timeago.ViMessages());
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
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

  void _confirmDelete(BuildContext context, DocumentReference ref) {
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
          "Xóa bài viết?",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          "Hành động này sẽ xóa vĩnh viễn dữ liệu.",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Hủy",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              await ref.delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              "Xóa",
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
          ],
        ),
      ),
    );
  }

  Widget _buildPostList(String collectionPath) {
    final user = FirebaseAuth.instance.currentUser;

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

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PostDetailPage(docId: docId, initialPostData: data),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isForum
                        ? const Color(0xFF5893D8).withOpacity(
                      isDarkMode ? 0.16 : 0.10,
                    )
                        : const Color(0xFF8B5CF6).withOpacity(
                      isDarkMode ? 0.16 : 0.10,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isForum ? Icons.forum_outlined : Icons.menu_book_rounded,
                        size: 16,
                        color: isForum
                            ? const Color(0xFF5893D8)
                            : const Color(0xFF8B5CF6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isForum ? "Bài viết diễn đàn" : "Tài liệu của bạn",
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? Colors.white70
                              : (isForum
                              ? const Color(0xFF356DA8)
                              : const Color(0xFF6D28D9)),
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
                      _buildInfoChip(
                        icon: isForum
                            ? Icons.chat_bubble_outline_rounded
                            : Icons.folder_open_rounded,
                        label: isForum ? "Diễn đàn" : "Tài liệu",
                        isDarkMode: isDarkMode,
                      ),
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
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.06)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.white10
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            "#$tag",
                            style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white70
                                  : const Color(0xFF344054),
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
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
              ),
              boxShadow: isDarkMode
                  ? []
                  : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5893D8).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF5893D8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Quản lý bài viết và tài liệu bạn đã tạo",
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.white70
                          : const Color(0xFF344054),
                    ),
                  ),
                ),
              ],
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