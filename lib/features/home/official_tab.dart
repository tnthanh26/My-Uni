import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'post_action_row.dart';
import 'post_detail_page.dart';
import 'official_content_helper.dart';
import 'daily_digest_card.dart';

class OfficialTab extends StatelessWidget {
  final Function(String, Map<String, dynamic>) onSave;
  const OfficialTab({super.key, required this.onSave});

  Future<void> _launchURL(String urlString) async {
    if (urlString.trim().isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) return;
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
          .orderBy('publishedAt', descending: true)
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
              return DailyDigestCard(
                isDarkMode: isDarkMode,
              );
            }

            var doc = snapshot.data!.docs[index - 1];
            var data = doc.data() as Map<String, dynamic>;
            String docId = doc.id;
            bool isEvent = OfficialContentHelper.isOfficialEvent(
              data['title'],
              data['summary'],
            );
            final String summary = data['summary']?.toString().trim() ?? '';
            final String imagePath =
            OfficialContentHelper.getOfficialImageByContent(
              data['title'],
              data['summary'],
            );

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
                                      data['publishedDateText']?.toString() ?? '',
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