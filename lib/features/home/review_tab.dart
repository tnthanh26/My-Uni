import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'create_review_page.dart';
import 'post_action_row.dart';
import 'post_detail_page.dart';

class ReviewTab extends StatelessWidget {
  final Function(String, Map<String, dynamic>) onSave;
  const ReviewTab({super.key, required this.onSave});

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
    Color? iconColor,
  }) {
    final Color textColor =
    isDarkMode ? Colors.white70 : const Color(0xFF344054);

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
            color: iconColor ?? textColor,
          ),
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

  Widget _buildReviewCard(
      BuildContext context,
      Map<String, dynamic> data,
      String docId,
      bool isDarkMode,
      ) {
    final int rating = (data['rating'] ?? 0) is int
        ? data['rating'] ?? 0
        : ((data['rating'] ?? 0) as num).toInt();

    final String courseName = data['courseName']?.toString() ?? '';
    final String teacherName = data['teacherName']?.toString() ?? '';
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
                              "Giảng viên: ${teacherName.isEmpty ? 'Chưa cập nhật' : teacherName}",
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
                        icon: Icons.tag_rounded,
                        label: "Review",
                        isDarkMode: isDarkMode,
                        iconColor: const Color(0xFF306CFE),
                      ),
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

                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
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
                        onSave: onSave,
                        collectionPath: 'course_reviews',
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
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('course_reviews')
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
                      Icons.reviews_outlined,
                      size: 42,
                      color: isDarkMode ? Colors.white38 : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Chưa có đánh giá nào.",
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

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600.0),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String docId = doc.id;

              return _buildReviewCard(
                context,
                data,
                docId,
                isDarkMode,
              );
            },
          )));
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "fab_review_tab",
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateReviewPage()),
          );
        },
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