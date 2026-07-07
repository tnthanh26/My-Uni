import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_uni/features/home/post_detail_page.dart';

class DiscoverEventTab extends StatelessWidget {
  final bool useNestedScrollOverlap;

  const DiscoverEventTab({
    super.key,
    this.useNestedScrollOverlap = true,
  });

  static const Color primaryBlue = Color(0xFF6797E1);
  static const Color detailBlue = Color(0xFF5794F3);

  bool _checkIsEvent(dynamic title, dynamic summary) {
    final List<String> keywords = [
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
      'đăng ký tham gia',
    ];

    final String content =
    "${title.toString()} ${summary.toString()}".toLowerCase();

    return keywords.any((k) => content.contains(k));
  }

  List<Widget> _buildOverlapSliver(BuildContext context) {
    if (!useNestedScrollOverlap) {
      return const [
        SliverToBoxAdapter(child: SizedBox(height: 12)),
      ];
    }

    return [
      SliverOverlapInjector(
        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
      ),
    ];
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã bỏ quan tâm")),
      );
    } else {
      await docRef.set({
        'title': data['title'] ?? 'Sự kiện sinh viên',
        'date': data['date'] ?? 'Xem chi tiết bài viết',
        'department': data['department'] ?? 'Cơ sở HCMUS',
        'summary': data['summary'] ?? '',
        'link': data['link'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã thêm vào mục Đã quan tâm")),
      );
    }
  }

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

  List<BoxShadow> _shadow(bool isDark) => isDark
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600.0),
        child: Container(
          color: _backgroundColor(isDark),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('official_news')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Đã xảy ra lỗi dữ liệu',
                    style: TextStyle(color: _secondaryText(isDark)),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryBlue),
                );
              }

              final eventDocs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _checkIsEvent(
                  data['title'] ?? '',
                  data['summary'] ?? '',
                );
              }).toList();

              if (eventDocs.isEmpty) {
                return CustomScrollView(
                  slivers: [
                    ..._buildOverlapSliver(context),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'Hiện chưa có sự kiện nào',
                          style: TextStyle(color: _secondaryText(isDark)),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return CustomScrollView(
                slivers: [
                  ..._buildOverlapSliver(context),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final doc = eventDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final String docId = doc.id;

                          return _buildEventCard(
                            context,
                            docId,
                            data,
                            user,
                            isDark,
                          );
                        },
                        childCount: eventDocs.length,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(
      BuildContext context,
      String docId,
      Map<String, dynamic> data,
      User? user,
      bool isDark,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _surfaceColor(isDark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor(isDark)),
        boxShadow: _shadow(isDark),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(
                docId: docId,
                initialPostData: data,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              child: Stack(
                children: [
                  Image.asset(
                    'assets/images/news.png',
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.15),
                            Colors.black.withOpacity(0.4),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Text(
                        'MỚI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data['hashtags'] != null &&
                      (data['hashtags'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (data['hashtags'] as List)
                            .map((tag) => _buildTagChip(tag, isDark))
                            .toList(),
                      ),
                    ),
                  Text(
                    data['title']?.toString() ?? 'Sự kiện sinh viên',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _primaryText(isDark),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _secondarySurface(isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borderColor(isDark)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data['date']?.toString() ?? 'Xem chi tiết bài viết',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _secondaryText(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data['department']?.toString() ??
                                    'Cơ sở HCMUS',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _secondaryText(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip(dynamic tag, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
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
            tag.toString(),
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF344054),
            ),
          ),
        ],
      ),
    );
  }
}