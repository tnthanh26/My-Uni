import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_uni/features/home/create_review_page.dart';
import 'package:my_uni/features/home/post_detail_page.dart';

class MyReviewsPage extends StatelessWidget {
  const MyReviewsPage({super.key});

  Widget _buildRatingStars(int rating, bool isDarkMode) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          final bool filled = i < rating;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: filled
                  ? const Color(0xFFFFCB45)
                  : (isDarkMode ? Colors.white12 : const Color(0xFFD9D9D9)),
              size: 22,
            ),
          );
        }),
        const SizedBox(width: 8),
        Text(
          "$rating/5",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontWeight: FontWeight.w700,
            fontSize: 14,
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
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Icon(icon, color: color, size: 20),
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
    bool canEdit = true;
    if (data['timestamp'] != null) {
      try {
        final Timestamp ts = data['timestamp'] as Timestamp;
        final DateTime postTime = ts.toDate();
        if (DateTime.now().difference(postTime).inHours >= 12) {
          canEdit = false;
        }
      } catch (e) {
        debugPrint("Error checking review edit timeframe: $e");
      }
    }

    final int rating = (data['rating'] ?? 0) is int
        ? data['rating'] ?? 0
        : ((data['rating'] ?? 0) as num).toInt();

    final String courseName =
    data['courseName']?.toString().isNotEmpty == true
        ? data['courseName']
        : 'Không rõ môn học';

    final String teacherName = data['teacherName']?.toString().isNotEmpty == true
        ? data['teacherName']
        : 'Chưa cập nhật';

    final String semester = data['semester']?.toString() ?? '';
    final String content = data['content']?.toString() ?? '';

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
                              courseName,
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                height: 1.35,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Giảng viên: $teacherName",
                              style: const TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: Color(0xFF5893D8),
                              ),
                            ),
                            if (semester.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                semester,
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
                      Row(
                        children: [
                          if (canEdit) ...[
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
                          ],
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
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (semester.isNotEmpty)
                        _buildInfoChip(
                          icon: Icons.calendar_month_rounded,
                          label: semester,
                          isDarkMode: isDarkMode,
                        ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.04)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white10
                            : const Color(0xFFEAEFF5),
                      ),
                    ),
                    child: _buildRatingStars(rating, isDarkMode),
                  ),
                ),

                if (content.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 15,
                        color: isDarkMode
                            ? Colors.white70
                            : const Color(0xFF4B5563),
                        height: 1.65,
                      ),
                    ),
                  ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyReviewState(BuildContext context) {
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
            const Icon(
              Icons.stars_outlined,
              size: 72,
              color: Color(0xFFFFCB45),
            ),
            const SizedBox(height: 18),
            Text(
              "Bạn chưa có đánh giá nào!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF545454),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Ý kiến của bạn rất quan trọng! Hãy review các môn đã học để giúp các bạn khóa sau chọn môn dễ dàng hơn nhé.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                color: Colors.grey,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateReviewPage(),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5893D8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
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
                  fontSize: 15,
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
          "Xóa đánh giá?",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          "Dữ liệu này sẽ bị xóa vĩnh viễn và không thể khôi phục.",
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
              "Xóa ngay",
              style: TextStyle(
                color: Color(0xFFFF6C6C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDarkMode ? const Color(0xFF0F1113) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Đánh giá của tôi",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF545454),
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
      body: StreamBuilder<QuerySnapshot>(
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

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
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
    );
  }
}