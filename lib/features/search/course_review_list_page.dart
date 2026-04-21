import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/post_detail_page.dart';

class CourseReviewListPage extends StatefulWidget {
  final String fullCourseName;
  final String teacherName;

  const CourseReviewListPage({
    super.key,
    required this.fullCourseName,
    required this.teacherName,
  });

  @override
  State<CourseReviewListPage> createState() => _CourseReviewListPageState();
}

class _CourseReviewListPageState extends State<CourseReviewListPage> {
  bool isNewest = true;

  Color _backgroundColor(bool isDark) =>
      isDark ? const Color(0xFF121212) : const Color(0xFFF7F9FC);

  Color _surfaceColor(bool isDark) =>
      isDark ? const Color(0xFF1E1E1E) : Colors.white;

  Color _secondarySurface(bool isDark) =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F4F8);

  Color _primaryText(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF1E1E1E);

  Color _secondaryText(bool isDark) =>
      isDark ? Colors.white70 : const Color(0xFF6B7280);

  Color _borderColor(bool isDark) =>
      isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB);

  List<BoxShadow> _cardShadow(bool isDark) => isDark
      ? []
      : [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _backgroundColor(isDarkMode),
      appBar: AppBar(
        backgroundColor: _surfaceColor(isDarkMode),
        foregroundColor: _primaryText(isDarkMode),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleSpacing: 8,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.fullCourseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primaryText(isDarkMode),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Giảng viên: ${widget.teacherName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6797E1),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<bool>(
            color: _surfaceColor(isDarkMode),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: const Icon(Icons.sort_rounded, color: Color(0xFF6797E1)),
            onSelected: (bool value) {
              setState(() {
                isNewest = value;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<bool>>[
              PopupMenuItem<bool>(
                value: true,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.new_releases_outlined,
                    color: isNewest ? Colors.blue : Colors.grey,
                  ),
                  title: Text(
                    'Mới nhất',
                    style: TextStyle(
                      color:
                      isNewest ? Colors.blue : _primaryText(isDarkMode),
                      fontSize: 14,
                    ),
                  ),
                  trailing: isNewest
                      ? const Icon(Icons.check, color: Colors.blue, size: 20)
                      : null,
                ),
              ),
              PopupMenuItem<bool>(
                value: false,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.history_outlined,
                    color: !isNewest ? Colors.blue : Colors.grey,
                  ),
                  title: Text(
                    'Cũ nhất',
                    style: TextStyle(
                      color:
                      !isNewest ? Colors.blue : _primaryText(isDarkMode),
                      fontSize: 14,
                    ),
                  ),
                  trailing: !isNewest
                      ? const Icon(Icons.check, color: Colors.blue, size: 20)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('course_reviews')
            .where('courseName', isEqualTo: widget.fullCourseName)
            .where('teacherName', isEqualTo: widget.teacherName)
            .where('status', isEqualTo: 'approved')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6797E1)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: _surfaceColor(isDarkMode),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _borderColor(isDarkMode)),
                  boxShadow: _cardShadow(isDarkMode),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 36,
                      color: _secondaryText(isDarkMode),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có đánh giá chi tiết nào.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _primaryText(isDarkMode),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Khi có review mới, chúng sẽ hiện ở đây.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _secondaryText(isDarkMode),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final List<QueryDocumentSnapshot> reviewDocs =
          List<QueryDocumentSnapshot>.from(snapshot.data!.docs);

          reviewDocs.sort((a, b) {
            final t1 = a['timestamp'] as Timestamp;
            final t2 = b['timestamp'] as Timestamp;
            if (isNewest) {
              return t2.compareTo(t1);
            } else {
              return t1.compareTo(t2);
            }
          });

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: reviewDocs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = reviewDocs[index];
              final reviewData = doc.data() as Map<String, dynamic>;
              final String docId = doc.id;

              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailPage(
                        docId: docId,
                        initialPostData: reviewData,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _surfaceColor(isDarkMode),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _borderColor(isDarkMode)),
                    boxShadow: _cardShadow(isDarkMode),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _secondarySurface(isDarkMode),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _borderColor(isDarkMode)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.fullCourseName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: _primaryText(isDarkMode),
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      reviewData['semester'] ??
                                          'Học kỳ không xác định',
                                      style: TextStyle(
                                        color: _secondaryText(isDarkMode),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'GV: ${reviewData['teacherName'] ?? 'N/A'}',
                                      style: TextStyle(
                                        color: _secondaryText(isDarkMode),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: _secondaryText(isDarkMode),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: List.generate(
                            5,
                                (i) => Icon(
                              i < (reviewData['rating'] ?? 5)
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: const Color(0xFFFFCB45),
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          reviewData['content'] ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isDarkMode
                                ? Colors.white70
                                : const Color(0xFF545454),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _buildStat(
                              Icons.favorite_outline_rounded,
                              '${reviewData['likeCount'] ?? 0}',
                              isDarkMode,
                            ),
                            const SizedBox(width: 22),
                            _buildStat(
                              Icons.chat_bubble_outline_rounded,
                              '${reviewData['commentCount'] ?? 0}',
                              isDarkMode,
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.bookmark_border_rounded,
                              color: Colors.amber,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStat(IconData icon, String count, bool isDarkMode) {
    final Color color = _secondaryText(isDarkMode);

    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 5),
        Text(
          count,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}