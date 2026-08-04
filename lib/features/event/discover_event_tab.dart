import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_uni/features/home/post_detail_page.dart';
import 'package:my_uni/features/search/myuni_search_delegate.dart';

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

<<<<<<< Updated upstream
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
=======
                  // Danh sách Events từ collection `faculty_events`
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      key: ValueKey('event_stream_$activeSubTab'),
                      stream: FirebaseFirestore.instance
                          .collection('faculty_events')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Đã xảy ra lỗi dữ liệu sự kiện Khoa',
                              style: TextStyle(color: _secondaryText(isDark)),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: primaryBlue),
                          );
                        }

                        final allEventDocs = snapshot.data!.docs;

                        // Lọc tài liệu theo Khoa đang chọn & từ khóa tìm kiếm
                        final cleanQuery = removeVietnameseDiacritics(_searchQuery);
                        final filteredDocs = allEventDocs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          if (data['shouldPublish'] == false) return false;

                          // 1. Kiểm tra Khoa
                          bool matchesFac = false;
                          if (activeSubTab == 'my_faculty') {
                            if (primaryFacultyInfo == null) {
                              matchesFac = true;
                            } else {
                              matchesFac = _matchesFaculty(data, primaryFacultyInfo);
                            }
                          } else {
                            final targetFacInfo = FacultyHelper.findById(activeSubTab);
                            if (targetFacInfo != null) {
                              matchesFac = _matchesFaculty(data, targetFacInfo);
                            } else {
                              matchesFac = true;
                            }
                          }

                          if (!matchesFac) return false;

                          // 2. Kiểm tra từ khóa tìm kiếm
                          if (cleanQuery.isNotEmpty) {
                            final eventName = removeVietnameseDiacritics((data['eventName'] ?? data['title'] ?? '').toString());
                            final desc = removeVietnameseDiacritics((data['description'] ?? '').toString());
                            final locName = removeVietnameseDiacritics((data['locationName'] ?? '').toString());
                            final locAddr = removeVietnameseDiacritics((data['locationAddress'] ?? '').toString());
                            final facName = removeVietnameseDiacritics((data['facultyName'] ?? '').toString());
                            final facCode = removeVietnameseDiacritics((data['facultyCode'] ?? '').toString());

                            final matchesSearch = eventName.contains(cleanQuery) ||
                                desc.contains(cleanQuery) ||
                                locName.contains(cleanQuery) ||
                                locAddr.contains(cleanQuery) ||
                                facName.contains(cleanQuery) ||
                                facCode.contains(cleanQuery);

                            if (!matchesSearch) return false;
                          }

                          return true;
                        }).toList();

                        // Sắp xếp các sự kiện mới nhất lên trước
                        filteredDocs.sort((a, b) {
                          final dataA = a.data() as Map<String, dynamic>;
                          final dataB = b.data() as Map<String, dynamic>;
                          final int tsA = _extractMillis(dataA);
                          final int tsB = _extractMillis(dataB);
                          return tsB.compareTo(tsA);
                        });

                        if (filteredDocs.isEmpty) {
                          return CustomScrollView(
                            slivers: [
                              ..._buildOverlapSliver(context),
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.event_busy_rounded,
                                          size: 48,
                                          color: _secondaryText(isDark),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Hiện chưa có sự kiện nào từ Khoa này',
                                          style: TextStyle(
                                            color: _primaryText(isDark),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Các thông báo sự kiện, hội thảo mới nhất sẽ tự động cập nhật ở đây.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _secondaryText(isDark),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return CustomScrollView(
                          key: ValueKey('event_list_$activeSubTab'),
                          slivers: [
                            ..._buildOverlapSliver(context),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final doc = filteredDocs[index];
                                    final data = doc.data() as Map<String, dynamic>;
                                    final String docId = doc.id;

                                    return KeyedSubtree(
                                      key: ValueKey('event_card_${doc.id}'),
                                      child: _buildEventCard(
                                        context,
                                        docId,
                                        data,
                                        user,
                                        isDark,
                                      ),
                                    );
                                  },
                                  childCount: filteredDocs.length,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _matchesFaculty(Map<String, dynamic> data, FacultyInfo facInfo) {
    final String facId = (data['facultyId'] ?? '').toString().toLowerCase();
    final String facCode = (data['facultyCode'] ?? '').toString().toLowerCase();
    final String facName = (data['facultyName'] ?? '').toString().toLowerCase();

    if (facId == facInfo.id.toLowerCase()) return true;
    if (facCode == facInfo.code.toLowerCase()) return true;
    return facInfo.matchKeywords.any((kw) => facName.contains(kw) || facId.contains(kw));
  }

  int _extractMillis(Map<String, dynamic> data) {
    if (data['startAt'] != null && data['startAt'] is Timestamp) {
      return (data['startAt'] as Timestamp).millisecondsSinceEpoch;
    }
    if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
      return (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
    }
    if (data['updatedAt'] != null && data['updatedAt'] is Timestamp) {
      return (data['updatedAt'] as Timestamp).millisecondsSinceEpoch;
    }
    return 0;
  }

  /// Thanh chuyển đổi Sub-Tab lọc Khoa cho trang Events
  Widget _buildSubTabBar({
    required BuildContext context,
    required bool isDarkMode,
    required FacultyInfo? primaryFacultyInfo,
    required List<String> followedFaculties,
    required String activeSubTab,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF14171D) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 1. Tab Khoa của bạn
            _buildSubTabChip(
              id: 'my_faculty',
              label: primaryFacultyInfo != null
                  ? 'Khoa của bạn (${primaryFacultyInfo.shortName})'
                  : 'Khoa của bạn',
              icon: primaryFacultyInfo?.icon ?? Icons.school_rounded,
              isSelected: activeSubTab == 'my_faculty',
              isDarkMode: isDarkMode,
              activeGradient: const [Color(0xFF059669), Color(0xFF047857)],
              onTap: () => setState(() => _selectedSubTabId = 'my_faculty'),
            ),

            // 2. Các Khoa đang theo dõi thêm
            ...followedFaculties.map((facId) {
              final facInfo = FacultyHelper.findById(facId);
              if (facInfo == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildSubTabChip(
                  id: facInfo.id,
                  label: facInfo.shortName,
                  icon: facInfo.icon,
                  isSelected: activeSubTab == facInfo.id,
                  isDarkMode: isDarkMode,
                  activeGradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                  onTap: () => setState(() => _selectedSubTabId = facInfo.id),
                ),
              );
            }),

            const SizedBox(width: 8),

            // 3. Nút Quản lý theo dõi Khoa
            GestureDetector(
              onTap: () => _showManageFollowedFacultiesModal(
                context,
                primaryFacultyInfo,
                followedFaculties,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.5),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 16,
                      color: Color(0xFF8B5CF6),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Theo dõi Khoa',
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
>>>>>>> Stashed changes
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
                            .map((tag) => _buildTagChip(context, tag, isDark))
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

  Widget _buildTagChip(BuildContext context, dynamic tag, bool isDark) {
    final String tagText = tag.toString();
    return GestureDetector(
      onTap: () {
        final cleanTag = tagText.replaceAll('#', '').trim();
        if (cleanTag.isNotEmpty) {
          showSearch(
            context: context,
            delegate: MyUniSearchDelegate(
              currentScope: SearchScope.official,
              initialHashtag: cleanTag,
            ),
          );
        }
      },
      child: Container(
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
              tagText,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF344054),
              ),
            ),
          ],
        ),
      ),
    );
  }
}