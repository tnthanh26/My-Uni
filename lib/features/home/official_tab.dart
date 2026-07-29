import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'post_action_row.dart';
import 'post_detail_page.dart';
import 'official_content_helper.dart';
import 'daily_digest_card.dart';
import 'package:my_uni/features/search/myuni_search_delegate.dart';

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
    required BuildContext context,
    required bool isDarkMode,
    required bool isEvent,
  }) {
    final String label = isEvent ? "Sự kiện" : "Tin chính thức";

    final Color bgColor = isEvent
        ? (isDarkMode ? const Color(0xFF1E3A8A).withOpacity(0.3) : const Color(0xFFE0F2FE))
        : (isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9));

    final Color textColor = isEvent
        ? (isDarkMode ? const Color(0xFF93C5FD) : const Color(0xFF0369A1))
        : (isDarkMode ? Colors.white70 : const Color(0xFF475569));

    return GestureDetector(
      onTap: () {
        showSearch(
          context: context,
          delegate: MyUniSearchDelegate(
            currentScope: SearchScope.official,
            initialHashtag: isEvent ? "Sự kiện" : "Thông báo",
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEvent
                ? const Color(0xFF66ACFE).withOpacity(0.35)
                : (isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0)),
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
              label,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestButton({
    required BuildContext context,
    required bool isDarkMode,
    required bool isInterested,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isInterested
                ? (isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFF1F5F9))
                : const Color(0xFF5893D8),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isInterested || isDarkMode
                ? []
                : [
              BoxShadow(
                color: const Color(0xFF5893D8).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isInterested ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                size: 16,
                color: isInterested
                    ? (isDarkMode ? Colors.white70 : const Color(0xFF64748B))
                    : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                isInterested ? 'Đã quan tâm' : 'Quan tâm',
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isInterested
                      ? (isDarkMode ? Colors.white70 : const Color(0xFF64748B))
                      : Colors.white,
                ),
              ),
            ],
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

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600.0),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1C1F26) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isDarkMode
                    ? []
                    : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
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
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDarkMode
                                    ? [const Color(0xFF1E3A8A).withOpacity(0.3), const Color(0xFF1E40AF).withOpacity(0.1)]
                                    : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE).withOpacity(0.5)],
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.tips_and_updates_rounded,
                                  size: 16,
                                  color: Color(0xFF3B82F6),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sự kiện nổi bật dành cho bạn',
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                    color: isDarkMode
                                        ? const Color(0xFF93C5FD)
                                        : const Color(0xFF1E40AF),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDarkMode ? Colors.white12 : const Color(0xFFF1F5F9),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(3.0),
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.contain,
                                    ),
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
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              letterSpacing: -0.2,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.verified_rounded,
                                          color: Color(0xFF3B82F6),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      data['publishedDateText']?.toString() ?? '',
                                      style: TextStyle(
                                        fontFamily: 'Encode Sans Expanded',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isDarkMode
                                            ? Colors.white54
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildCategoryChip(
                                context: context,
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
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            data['title']?.toString() ?? '',
                            style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              height: 1.3,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),

                        if (summary.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              summary,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 13,
                                height: 1.6,
                                color: isDarkMode
                                    ? Colors.white70
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              children: [
                                Image.asset(
                                  imagePath,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/news.png',
                                      width: double.infinity,
                                      height: 200,
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
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.4),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        PostActionRow(
                          docId: docId,
                          data: data,
                          onSave: onSave,
                          collectionPath: 'official_news',
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _launchURL(data['link']?.toString() ?? ''),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: isDarkMode
                                    ? Colors.white.withOpacity(0.05)
                                    : const Color(0xFFF1F5F9),
                                foregroundColor: const Color(0xFF5893D8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Xem chi tiết bài viết',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Encode Sans Expanded',
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.open_in_new_rounded, size: 16),
                                ],
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
        )));
      },
    );
  }
}