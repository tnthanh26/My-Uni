import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'post_detail_page.dart';
import 'faculty_helper.dart';

class FacultyDailyDigestCard extends StatelessWidget {
  final bool isDarkMode;
  final FacultyInfo facultyInfo;

  const FacultyDailyDigestCard({
    super.key,
    required this.isDarkMode,
    required this.facultyInfo,
  });

  Future<void> _openDigestPostDetail(
    BuildContext context,
    String postId,
  ) async {
    if (postId.trim().isEmpty) return;

    try {
      // Thử tìm bài viết trong faculty_official_news trước
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('faculty_official_news')
          .doc(postId)
          .get();

      if (!doc.exists || doc.data() == null) {
        // Fallback sang official_news nếu không tìm thấy
        doc = await FirebaseFirestore.instance
            .collection('official_news')
            .doc(postId)
            .get();
      }

      if (!doc.exists || doc.data() == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy bài viết gốc')),
          );
        }
        return;
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailPage(
              docId: postId,
              initialPostData: {
                ...(doc.data() as Map<String, dynamic>),
                'collectionPath': 'faculty_official_news',
              },
              collectionPath: 'faculty_official_news',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Lỗi mở chi tiết digest: $e");
    }
  }

  Color _getImportanceColor(String importance) {
    switch (importance) {
      case 'high':
        return const Color(0xFFFFB020);
      default:
        return const Color(0xFF66ACFE);
    }
  }

  String _formatDateKey(String dateKey) {
    if (dateKey.length < 10) return dateKey;
    final cleanKey = dateKey.split('_').last;
    final parts = cleanKey.split('-');
    if (parts.length != 3) return dateKey;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final todayId = DateTime.now().toIso8601String().substring(0, 10);
    final targetDocId = '${facultyInfo.id}_$todayId';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_faculty_digest')
          .doc(targetDocId)
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic>? data;

        if (snapshot.hasData && snapshot.data!.exists) {
          data = snapshot.data!.data() as Map<String, dynamic>?;
        }

        // Nếu hôm nay chưa có doc chính xác ({facultyId}_{today}), thử fallback tìm digest gần nhất của Khoa này
        if (data == null) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('daily_faculty_digest')
                .where('facultyId', isEqualTo: facultyInfo.id)
                .snapshots(),
            builder: (context, querySnapshot) {
              if (!querySnapshot.hasData || querySnapshot.data!.docs.isEmpty) {
                // Nếu chưa có digest nào cả, hiển thị banner giới thiệu khoa mặc định
                return _buildDefaultFacultyBanner(context);
              }

              final docs = querySnapshot.data!.docs.toList();
              docs.sort((a, b) => b.id.compareTo(a.id));
              final latestData = docs.first.data() as Map<String, dynamic>;

              return _buildDigestUI(context, latestData, isFallback: true);
            },
          );
        }

        return _buildDigestUI(context, data, isFallback: false);
      },
    );
  }

  Widget _buildDefaultFacultyBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              facultyInfo.icon,
              color: const Color(0xFF3B82F6),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facultyInfo.name,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tin tức & thông báo chính thức từ ${facultyInfo.shortName}',
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 12,
                    color: isDarkMode
                        ? Colors.white60
                        : const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigestUI(
    BuildContext context,
    Map<String, dynamic> data, {
    required bool isFallback,
  }) {
    final items = List<Map<String, dynamic>>.from(
      (data['items'] ?? []).map((e) => Map<String, dynamic>.from(e)),
    );

    final bool isEmpty = data['isEmpty'] == true;
    final bool isLatestFallback =
        isFallback || (data['isLatestFallback'] == true);
    final String displayDateKey =
        data['displayDateKey']?.toString() ??
        (data['dateKey']?.toString() ?? '');

    final String subtitle = isLatestFallback
        ? 'Tóm tắt gần nhất (${_formatDateKey(displayDateKey)})'
        : isEmpty
        ? 'Hôm nay chưa có thông báo mới từ ${facultyInfo.shortName}'
        : '${items.length} tin mới từ ${facultyInfo.shortName} hôm nay';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [const Color(0xFF182235), const Color(0xFF101418)]
              : [const Color(0xFFEAF4FF), Colors.white],
        ),
        border: Border.all(
          color: const Color(0xFF66ACFE).withOpacity(isDarkMode ? 0.22 : 0.30),
        ),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF5893D8).withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              right: -26,
              top: -26,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF66ACFE).withOpacity(0.15),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF66ACFE).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          facultyInfo.icon,
                          color: const Color(0xFF5893D8),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title']?.toString() ??
                                  'Tóm tắt tin tức ${facultyInfo.shortName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white54
                                    : const Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((data['overallSummary']?.toString().trim() ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      data['overallSummary']?.toString() ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 13,
                        height: 1.45,
                        color: isDarkMode
                            ? Colors.white70
                            : const Color(0xFF475467),
                      ),
                    ),
                  ],
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ...items.take(3).map((item) {
                      final postId = item['postId']?.toString() ?? '';
                      final department =
                          item['department']?.toString() ?? facultyInfo.name;
                      final importance =
                          item['importance']?.toString() ?? 'normal';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () => _openDigestPostDetail(context, postId),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.045)
                                  : Colors.white.withOpacity(0.88),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.white10
                                    : const Color(0xFFE6EEF8),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: _getImportanceColor(
                                      importance,
                                    ).withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(
                                    Icons.article_rounded,
                                    size: 18,
                                    color: _getImportanceColor(importance),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Encode Sans Expanded',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF1F2937),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        department,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Encode Sans Expanded',
                                          fontSize: 11,
                                          color: isDarkMode
                                              ? Colors.white54
                                              : const Color(0xFF667085),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: isDarkMode
                                      ? Colors.white38
                                      : const Color(0xFF98A2B3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (items.isNotEmpty ||
                        (data['overallSummary']?.toString().trim().isNotEmpty ??
                            false))
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showDigestBottomSheet(
                          context: context,
                          items: items,
                          overallSummary:
                              data['overallSummary']?.toString() ?? '',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 2),
                          child: Text(
                            items.length > 1
                                ? 'Xem tất cả ${items.length} thông báo ${facultyInfo.shortName}'
                                : 'Xem tóm tắt đầy đủ',
                            style: const TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5893D8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDigestBottomSheet({
    required BuildContext context,
    required List<Map<String, dynamic>> items,
    required String overallSummary,
  }) {
    final parentContext = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF111315) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(facultyInfo.icon, color: const Color(0xFF5893D8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tất cả thông báo ${facultyInfo.shortName}',
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        if (overallSummary.trim().isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.045)
                                  : const Color(0xFFF8FBFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.white10
                                    : const Color(0xFFE6EEF8),
                              ),
                            ),
                            child: Text(
                              overallSummary,
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 12.5,
                                height: 1.5,
                                color: isDarkMode
                                    ? Colors.white70
                                    : const Color(0xFF475467),
                              ),
                            ),
                          ),
                        ...items.map((item) {
                          final postId = item['postId']?.toString() ?? '';
                          final department =
                              item['department']?.toString() ??
                              facultyInfo.name;
                          final importance =
                              item['importance']?.toString() ?? 'normal';
                          final importanceColor = _getImportanceColor(
                            importance,
                          );

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(sheetContext);

                              Future.delayed(
                                const Duration(milliseconds: 180),
                                () {
                                  _openDigestPostDetail(parentContext, postId);
                                },
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.045)
                                    : const Color(0xFFF8FBFF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: importanceColor.withOpacity(
                                    isDarkMode ? 0.35 : 0.28,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: importanceColor.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Icon(
                                      Icons.article_rounded,
                                      size: 18,
                                      color: importanceColor,
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title']?.toString() ?? '',
                                          style: TextStyle(
                                            fontFamily: 'Encode Sans Expanded',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isDarkMode
                                                ? Colors.white
                                                : const Color(0xFF1F2937),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          department,
                                          style: TextStyle(
                                            fontFamily: 'Encode Sans Expanded',
                                            fontSize: 11.5,
                                            color: isDarkMode
                                                ? Colors.white54
                                                : const Color(0xFF667085),
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          item['shortSummary']?.toString() ??
                                              '',
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'Encode Sans Expanded',
                                            fontSize: 12,
                                            height: 1.45,
                                            color: isDarkMode
                                                ? Colors.white60
                                                : const Color(0xFF667085),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: isDarkMode
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
