/// UI Refactoring Changes for my_review_page.dart (Reference Standard):
/// - Unified Design System: Primary Color #5893D8, Background #F8FAFC, Surface Light White, Surface Dark #15171A, Border #E4E7EC.
/// - Typography: Header font Nunito, Content font Encode Sans Expanded.
/// - Card Hierarchy: Compact card layout with radius 16, margin bottom 14, padding 14, subtle shadow (opacity 0.03, blur 10, offset (0, 3)).
/// - Aligned empty state layout with circular icon background and primary action CTA button.
/// - Preserved all Firestore queries, edit/delete callbacks, status badges, and search filtering logic.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_uni/features/home/create_review_page.dart';
import 'package:my_uni/features/home/post_detail_page.dart';
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

class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildRatingStars(int rating, bool isDarkMode) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          final bool filled = i < rating;
          return Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: filled
                  ? const Color(0xFFFFCB45)
                  : (isDarkMode ? Colors.white12 : const Color(0xFFD9D9D9)),
              size: 20,
            ),
          );
        }),
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

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDarkMode ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final bool isPending = status == 'pending';
    final Color bgColor = isPending
        ? Colors.orange.withValues(alpha: 0.12)
        : Colors.green.withValues(alpha: 0.12);
    final Color borderColor = isPending
        ? Colors.orange.withValues(alpha: 0.35)
        : Colors.green.withValues(alpha: 0.35);
    final Color textColor = isPending ? Colors.orange : Colors.green;
    final IconData icon = isPending
        ? Icons.schedule_rounded
        : Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            isPending ? "Đang chờ duyệt" : "Đã duyệt",
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

  Widget _buildReviewCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
    DocumentReference ref,
    bool isDarkMode,
  ) {
    final int rating = (data['rating'] is int)
        ? data['rating']
        : int.tryParse(data['rating']?.toString() ?? '5') ?? 5;

    final String courseName = data['courseName'] ?? 'Chưa có tên môn học';
    final String teacher = data['teacher'] ?? 'Chưa có thông tin giảng viên';
    final String content = data['content'] ?? 'Không có nội dung đánh giá';
    final String currentStatus = data['status'] ?? 'pending';

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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          courseName,
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(currentStatus),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 13.5,
                        color: isDarkMode
                            ? Colors.white54
                            : const Color(0xFF667085),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "GV: $teacher",
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildRatingStars(rating, isDarkMode),
                  const SizedBox(height: 10),
                  Text(
                    content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 13.5,
                      height: 1.45,
                      color: isDarkMode
                          ? Colors.white70
                          : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                      Row(
                        children: [
                          _buildActionButton(
                            icon: Icons.edit_outlined,
                            color: const Color(0xFF5893D8),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateReviewPage(
                                    docId: docId,
                                    existingData: data,
                                  ),
                                ),
                              );
                            },
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(width: 8),
                          _buildActionButton(
                            icon: Icons.delete_outline_rounded,
                            color: const Color(0xFFFF6C6C),
                            onTap: () => _confirmDelete(context, ref),
                            isDarkMode: isDarkMode,
                          ),
                        ],
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

  Widget _buildEmptyReviewState(BuildContext context) {
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
                Icons.rate_review_outlined,
                size: 36,
                color: Color(0xFF5893D8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Chưa có đánh giá nào",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Nunito',
                color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Các bài đánh giá môn học bạn đăng sẽ xuất hiện ở đây.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontFamily: 'Encode Sans Expanded',
                color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateReviewPage(),
                  ),
                );
              },
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
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text(
                "Tạo đánh giá mới",
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Encode Sans Expanded',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, DocumentReference ref) async {
    final confirm = await AppActionDialogs.showConfirmDialog(
      context: context,
      title: 'Xóa đánh giá?',
      message: 'Dữ liệu này sẽ bị xóa vĩnh viễn và không thể khôi phục.',
      confirmText: 'Xóa',
    );
    if (confirm == true) {
      await ref.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF0F1113)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Đánh giá của tôi",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF111315) : Colors.white,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white70 : const Color(0xFF545454),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
            height: 1,
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
                hintText: 'Tìm kiếm đánh giá...',
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
                          color: isDarkMode
                              ? Colors.white54
                              : const Color(0xFF667085),
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('course_reviews')
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
                  return _buildEmptyReviewState(context);
                }

                final cleanQuery = removeVietnameseDiacritics(_searchQuery);
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  if (cleanQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final courseName = removeVietnameseDiacritics(
                    (data['courseName'] ?? data['subject'] ?? '').toString(),
                  );
                  final teacher = removeVietnameseDiacritics(
                    (data['teacher'] ?? data['lecturer'] ?? '').toString(),
                  );
                  final content = removeVietnameseDiacritics(
                    (data['content'] ?? data['reviewContent'] ?? '').toString(),
                  );
                  return courseName.contains(cleanQuery) ||
                      teacher.contains(cleanQuery) ||
                      content.contains(cleanQuery);
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
                            'Không tìm thấy đánh giá phù hợp',
                            style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black87,
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

                    return _buildReviewCard(
                      context,
                      doc.id,
                      data,
                      doc.reference,
                      isDarkMode,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
