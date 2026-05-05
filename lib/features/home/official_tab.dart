import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'post_action_row.dart';
import 'post_detail_page.dart';

class OfficialTab extends StatelessWidget {
  final Function(String, Map<String, dynamic>) onSave;
  const OfficialTab({super.key, required this.onSave});

  Future<void> _launchURL(String urlString) async {
    if (urlString.trim().isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  }

  bool _checkIsEvent(dynamic titleData, dynamic summaryData) {
    String title = titleData?.toString().toLowerCase() ?? "";
    String summary = summaryData?.toString().toLowerCase() ?? "";
    List<String> keywords = [
      'seminar',
      'talkshow',
      'hội thảo',
      'cuộc thi',
      'chào tân sinh viên',
      'ngày hội',
      'lễ tốt nghiệp',
      'workshop',
      'sự kiện',
      'mời tham gia',
      'đăng ký tham gia'
    ];
    String content = "$title $summary";
    return keywords.any((k) => content.contains(k));
  }

  String _getImageByContent(dynamic titleData, dynamic summaryData) {
    String title = titleData?.toString().toLowerCase() ?? "";
    String summary = summaryData?.toString().toLowerCase() ?? "";
    String text = "$title $summary";

    if (text.contains('học bổng') || text.contains('scholarship')) {
      return 'assets/images/scholarship.jpg';
    }
    if (text.contains('tuyển dụng') ||
        text.contains('việc làm') ||
        text.contains('intern') ||
        text.contains('thực tập')) {
      return 'assets/images/job.jpg';
    }
    if (text.contains('hội thảo') ||
        text.contains('seminar') ||
        text.contains('workshop') ||
        text.contains('talkshow')) {
      return 'assets/images/seminar.jpg';
    }
    if (text.contains('thể thao') ||
        text.contains('bóng đá') ||
        text.contains('giải đấu')) {
      return 'assets/images/sport.jpg';
    }
    if (text.contains('công nghệ') ||
        text.contains('tech') ||
        text.contains('lập trình')) {
      return 'assets/images/tech.jpg';
    }
    if (text.contains('nghệ thuật') ||
        text.contains('văn nghệ') ||
        text.contains('âm nhạc')) {
      return 'assets/images/art.jpg';
    }
    if (text.contains('lễ tốt nghiệp') || text.contains('graduation')) {
      return 'assets/images/graduation.jpg';
    }
    if (text.contains('cuộc thi') ||
        text.contains('contest') ||
        text.contains('giải thưởng')) {
      return 'assets/images/contest.jpg';
    }
    if (text.contains('thông báo') || text.contains('quy định')) {
      return 'assets/images/announcement.jpg';
    }
    if (text.contains('y tế') || text.contains('khám chữa bệnh')) {
      return 'assets/images/health.jpg';
    }

    return 'assets/images/news.png';
  }

  Future<void> _toggleInterest(
      BuildContext context,
      String docId,
      Map<String, dynamic> data,
      ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng đăng nhập để lưu sự kiện")),
      );
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('interested_events')
        .doc(docId);

    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      await docRef.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã bỏ quan tâm")),
      );
    } else {
      await docRef.set({
        'title': data['title']?.toString() ?? '',
        'date': data['date']?.toString() ?? '',
        'department': data['department']?.toString() ?? '',
        'summary': data['summary'] ?? '',
        'link': data['link'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã thêm vào mục Đã quan tâm")),
      );
    }
  }

  Future<void> _openDigestPostDetail(
      BuildContext context,
      String postId,
      ) async {
    if (postId.trim().isEmpty) return;

    final doc = await FirebaseFirestore.instance
        .collection('official_news')
        .doc(postId)
        .get();

    if (!doc.exists || doc.data() == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy bài viết gốc')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          docId: postId,
          initialPostData: doc.data()!,
        ),
      ),
    );
  }

  Widget _buildDailyDigestCard({
    required BuildContext context,
    required bool isDarkMode,
  }) {
    final todayId = DateTime.now().toIso8601String().substring(0, 10);

    Color getImportanceColor(String importance) {
      switch (importance) {
        case 'high':
          return const Color(0xFFFFB020);
        default:
          return const Color(0xFF66ACFE);
      }
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_official_digest')
          .doc(todayId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(
          (data['items'] ?? []).map((e) => Map<String, dynamic>.from(e)),
        );

        if (items.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [
                const Color(0xFF182235),
                const Color(0xFF101418),
              ]
                  : [
                const Color(0xFFEAF4FF),
                Colors.white,
              ],
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
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFF5893D8),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title']?.toString() ?? 'Hôm nay có gì mới?',
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
                                  '${items.length} thông báo mới hôm nay',
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

                      const SizedBox(height: 12),

                      Text(
                        data['overallSummary']?.toString() ?? '',
                        maxLines: 2,
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

                      const SizedBox(height: 14),

                      ...items.take(3).map((item) {
                        final postId = item['postId']?.toString() ?? '';
                        final department = item['department']?.toString() ?? '';
                        final importance = item['importance']?.toString() ?? 'normal';

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
                                      color: getImportanceColor(importance)
                                          .withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Icon(
                                      Icons.article_rounded,
                                      size: 18,
                                      color: getImportanceColor(importance),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                                ? Colors.white
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

                      if (items.length > 3)
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _showDigestBottomSheet(
                            context: context,
                            isDarkMode: isDarkMode,
                            items: items,
                            overallSummary: data['overallSummary']?.toString() ?? '',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 2),
                            child: Text(
                              'Xem tất cả ${items.length} thông báo',
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF5893D8),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDigestBottomSheet({
    required BuildContext context,
    required bool isDarkMode,
    required List<Map<String, dynamic>> items,
    required String overallSummary,
  }) {
    final parentContext = context;
    Color getImportanceColor(String importance) {
      switch (importance) {
        case 'high':
          return const Color(0xFFFFB020);
        default:
          return const Color(0xFF66ACFE);
      }
    }

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
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF5893D8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tất cả thông báo hôm nay',
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
                              item['department']?.toString() ?? '';
                          final importance =
                              item['importance']?.toString() ?? 'normal';
                          final importanceColor =
                          getImportanceColor(importance);

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(sheetContext);

                              Future.delayed(const Duration(milliseconds: 180), () {
                                _openDigestPostDetail(parentContext, postId);
                              });
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
                                      color:
                                      importanceColor.withOpacity(0.14),
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
                                            fontFamily:
                                            'Encode Sans Expanded',
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
                                            fontFamily:
                                            'Encode Sans Expanded',
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
                                            fontFamily:
                                            'Encode Sans Expanded',
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

  Widget _buildCategoryChip({
    required bool isDarkMode,
    required bool isEvent,
  }) {
    final String label = isEvent ? "Sự kiện" : "Tin chính thức";

    final Color bgColor = isEvent
        ? const Color(0xFF66ACFE).withOpacity(isDarkMode ? 0.20 : 0.14)
        : (isDarkMode ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9));

    final Color borderColor = isEvent
        ? const Color(0xFF66ACFE).withOpacity(0.35)
        : (isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0));

    final Color textColor = isEvent
        ? (isDarkMode ? Colors.white : const Color(0xFF1D4F91))
        : (isDarkMode ? Colors.white70 : const Color(0xFF344054));

    final Color iconColor = isEvent
        ? const Color(0xFF5893D8)
        : const Color(0xFF306CFE);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tag_rounded,
            size: 13,
            color: iconColor,
          ),
          const SizedBox(width: 4),
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

  Widget _buildInterestButton({
    required BuildContext context,
    required bool isDarkMode,
    required bool isInterested,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isInterested
              ? (isDarkMode ? Colors.white12 : const Color(0xFFF3F4F6))
              : const Color(0xFF9BC9FF).withOpacity(isDarkMode ? 0.35 : 0.80),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isInterested
                ? (isDarkMode ? Colors.white10 : const Color(0xFFE5E7EB))
                : const Color(0xFF66ACFE).withOpacity(0.45),
          ),
        ),
        child: Text(
          isInterested ? 'Đã quan tâm' : 'Quan tâm',
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isInterested
                ? (isDarkMode ? Colors.white54 : Colors.grey[700])
                : (isDarkMode ? Colors.white : const Color(0xFF1D4F91)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('official_news')
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
            child: Text(
              'Chưa có bài viết chính thức nào',
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 14,
                color: isDarkMode ? Colors.white60 : Colors.black54,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: snapshot.data!.docs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildDailyDigestCard(
                context: context,
                isDarkMode: isDarkMode,
              );
            }

            var doc = snapshot.data!.docs[index - 1];
            var data = doc.data() as Map<String, dynamic>;
            String docId = doc.id;
            bool isEvent = _checkIsEvent(data['title'], data['summary']);
            final String summary = data['summary']?.toString().trim() ?? '';
            final String imagePath =
            _getImageByContent(data['title'], data['summary']);

            void goToDetail() => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(
                  docId: docId,
                  initialPostData: data,
                ),
              ),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isEvent
                      ? const Color(0xFF66ACFE).withOpacity(isDarkMode ? 0.20 : 0.22)
                      : (isDarkMode
                      ? Colors.white10
                      : const Color(0xFFE9EEF3)),
                ),
                boxShadow: isDarkMode
                    ? []
                    : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.045),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: goToDetail,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isEvent)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            color: const Color(0xFF66ACFE).withOpacity(
                              isDarkMode ? 0.18 : 0.10,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  size: 16,
                                  color: Color(0xFF5893D8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Sự kiện có thể bạn quan tâm',
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : const Color(0xFF356DA8),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
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
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            data['department']?.toString() ?? 'HCMUS News',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'Encode Sans Expanded',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : const Color(0xFF2C2C2C),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.verified_rounded,
                                          color: Color(0xFF66ACFE),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      data['date']?.toString() ?? '',
                                      style: TextStyle(
                                        fontFamily: 'Encode Sans Expanded',
                                        fontSize: 12,
                                        color: isDarkMode
                                            ? Colors.white60
                                            : const Color(0xFF667085),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildCategoryChip(
                                isDarkMode: isDarkMode,
                                isEvent: isEvent,
                              ),
                              if (isEvent)
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user?.uid ?? 'guest')
                                      .collection('interested_events')
                                      .doc(docId)
                                      .snapshots(),
                                  builder: (context, favSnapshot) {
                                    bool isInterested = favSnapshot.hasData &&
                                        favSnapshot.data!.exists;
                                    return _buildInterestButton(
                                      context: context,
                                      isDarkMode: isDarkMode,
                                      isInterested: isInterested,
                                      onTap: () => _toggleInterest(
                                        context,
                                        docId,
                                        data,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                          child: Text(
                            data['title']?.toString() ?? '',
                            style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                              height: 1.35,
                            ),
                          ),
                        ),

                        if (summary.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                            child: Text(
                              summary,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 13,
                                height: 1.5,
                                color: isDarkMode
                                    ? Colors.white70
                                    : const Color(0xFF667085),
                              ),
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              children: [
                                Image.asset(
                                  imagePath,
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/news.png',
                                      width: double.infinity,
                                      height: 220,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.05),
                                          Colors.black.withOpacity(0.30),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.45),
                                          borderRadius:
                                          BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isEvent
                                              ? 'Xem thông tin sự kiện'
                                              : 'Xem nội dung chính thức',
                                          style: const TextStyle(
                                            fontFamily: 'Encode Sans Expanded',
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        PostActionRow(
                          docId: docId,
                          data: data,
                          onSave: onSave,
                          collectionPath: 'official_news',
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton(
                              onPressed: () =>
                                  _launchURL(data['link']?.toString() ?? ''),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF5893D8),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: isDarkMode
                                    ? Colors.white.withOpacity(0.02)
                                    : const Color(0xFFF8FBFF),
                              ),
                              child: const Text(
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
                ),
              ),
            );
          },
        );
      },
    );
  }
}