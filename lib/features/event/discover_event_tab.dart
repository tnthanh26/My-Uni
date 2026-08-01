import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_uni/features/home/faculty_helper.dart';

/// Utility to remove Vietnamese diacritics for simple text search
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

class DiscoverEventTab extends StatefulWidget {
  final bool useNestedScrollOverlap;

  const DiscoverEventTab({
    super.key,
    this.useNestedScrollOverlap = true,
  });

  @override
  State<DiscoverEventTab> createState() => _DiscoverEventTabState();
}

class _DiscoverEventTabState extends State<DiscoverEventTab> {
  static const Color primaryBlue = Color(0xFF6797E1);
  static const Color detailBlue = Color(0xFF5794F3);

  String? _selectedSubTabId; // 'my_faculty' hoặc ID khoa được chọn
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

  Future<void> _launchURL(String urlString) async {
    final cleanUrl = urlString.trim();
    if (cleanUrl.isEmpty) return;
    final Uri url = Uri.parse(cleanUrl);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  List<Widget> _buildOverlapSliver(BuildContext context) {
    if (!widget.useNestedScrollOverlap) {
      return const [
        SliverToBoxAdapter(child: SizedBox(height: 8)),
      ];
    }

    return [
      SliverOverlapInjector(
        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
      ),
    ];
  }

  /// Toggle quan tâm event: Lưu vào interested_events VÀ tạo personal_event
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

    final interestedRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('interested_events')
        .doc(docId);

    final personalRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('personal_events')
        .doc(docId);

    final docSnapshot = await interestedRef.get();

    if (docSnapshot.exists) {
      // 1. Xóa khỏi quan tâm và xóa luôn trong personal_events
      await interestedRef.delete();
      await personalRef.delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã bỏ quan tâm & xóa khỏi Lịch cá nhân")),
      );
    } else {
      // 2. Thêm vào interested_events
      final String eventName = (data['eventName'] ?? data['title'] ?? 'Sự kiện Khoa').toString();
      final String description = (data['description'] ?? '').toString();
      final String eventDateText = (data['eventDateText'] ?? data['date'] ?? '').toString();
      final String locationName = (data['locationName'] ?? '').toString();
      final String locationAddress = (data['locationAddress'] ?? '').toString();
      final String facultyName = (data['facultyName'] ?? data['department'] ?? 'Khoa HCMUS').toString();
      final String sourceArticleUrl = (data['sourceArticleUrl'] ?? data['registrationUrl'] ?? data['link'] ?? '').toString();
      final String registrationUrl = (data['registrationUrl'] ?? '').toString();
      final String? thumbnailUrl = data['thumbnailUrl'] ??
          (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty ? data['imageUrls'][0] : null);

      await interestedRef.set({
        'docId': docId,
        'facultyEventId': docId,
        'eventName': eventName,
        'title': eventName,
        'description': description,
        'eventDateText': eventDateText,
        'date': eventDateText,
        'locationName': locationName,
        'locationAddress': locationAddress,
        'facultyName': facultyName,
        'department': facultyName,
        'sourceArticleUrl': sourceArticleUrl,
        'registrationUrl': registrationUrl,
        'thumbnailUrl': thumbnailUrl,
        'startAt': data['startAt'],
        'startDateTime': data['startDateTime'],
        'endAt': data['endAt'],
        'endDateTime': data['endDateTime'],
        'timestamp': FieldValue.serverTimestamp(),
        'isFacultyEvent': true,
      });

      // 3. Tự động đọc ngày tháng, địa điểm & tạo 1 Personal Event ở Lịch cá nhân
      DateTime parsedDateTime = DateTime.now();
      if (data['startAt'] != null && data['startAt'] is Timestamp) {
        parsedDateTime = (data['startAt'] as Timestamp).toDate();
      } else if (data['startDateTime'] != null && data['startDateTime'] is String) {
        final parsed = DateTime.tryParse(data['startDateTime']);
        if (parsed != null) parsedDateTime = parsed;
      } else if (data['registrationDeadlineAt'] != null && data['registrationDeadlineAt'] is Timestamp) {
        parsedDateTime = (data['registrationDeadlineAt'] as Timestamp).toDate();
      }

      final List<String> locParts = [];
      final String trimmedLocName = locationName.trim();
      final String trimmedLocAddr = locationAddress.trim();
      if (trimmedLocName.isNotEmpty) locParts.add(trimmedLocName);
      if (trimmedLocAddr.isNotEmpty && trimmedLocAddr != trimmedLocName) locParts.add(trimmedLocAddr);
      String locStr = locParts.join(' - ');
      if (locStr.trim().isEmpty) {
        locStr = facultyName.isNotEmpty ? facultyName : 'Chưa cập nhật địa điểm';
      }

      String noteDesc = description.isNotEmpty ? description : 'Sự kiện được quan tâm từ thông báo Khoa.';
      noteDesc += '\n\n📌 LƯU Ý: Vui lòng kiểm tra kỹ bài đăng chính thức để xác nhận thông tin chi tiết.';

      await personalRef.set({
        'title': eventName,
        'location': locStr,
        'description': noteDesc,
        'dateTime': Timestamp.fromDate(parsedDateTime),
        'reminder': '15 phút trước',
        'facultyEventId': docId,
        'isFromFacultyEvent': true,
        'sourceArticleUrl': sourceArticleUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Đã thêm vào mục Quan tâm & Lịch cá nhân của bạn!"),
          backgroundColor: primaryBlue,
        ),
      );
    }
  }

  /// BottomSheet Quản lý theo dõi tối đa 2 Khoa khác
  void _showManageFollowedFacultiesModal(
    BuildContext context,
    FacultyInfo? primaryFacultyInfo,
    List<String> currentFollowed,
  ) {
    List<String> tempFollowed = List.from(currentFollowed);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDarkMode = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E222B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Color(0xFF8B5CF6),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theo dõi Sự kiện các Khoa',
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Theo dõi tối đa 2 Khoa khác ngoài Khoa của bạn',
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 12,
                                color: isDarkMode ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ...FacultyHelper.activeFaculties.map((fac) {
                    final bool isPrimary = primaryFacultyInfo?.id == fac.id;
                    final bool isFollowed = tempFollowed.contains(fac.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isPrimary
                            ? (isDarkMode
                                ? const Color(0xFF1E3A8A).withOpacity(0.2)
                                : const Color(0xFFEFF6FF))
                            : (isFollowed
                                ? (isDarkMode
                                    ? const Color(0xFF8B5CF6).withOpacity(0.15)
                                    : const Color(0xFFF3E8FF))
                                : (isDarkMode
                                    ? Colors.white.withOpacity(0.04)
                                    : const Color(0xFFF8FAFC))),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPrimary
                              ? const Color(0xFF3B82F6).withOpacity(0.4)
                              : (isFollowed
                                  ? const Color(0xFF8B5CF6)
                                  : (isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0))),
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isPrimary || isFollowed,
                        enabled: !isPrimary,
                        activeColor: isPrimary ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isPrimary
                                ? const Color(0xFF3B82F6).withOpacity(0.15)
                                : const Color(0xFF8B5CF6).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            fac.icon,
                            size: 20,
                            color: isPrimary ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                fac.name,
                                style: TextStyle(
                                  fontFamily: 'Encode Sans Expanded',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            if (isPrimary) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Khoa của bạn',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          'Mã khoa: ${fac.code}',
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 12,
                            color: isDarkMode ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                        onChanged: isPrimary
                            ? null
                            : (checked) {
                                if (checked == true) {
                                  if (tempFollowed.length >= 2) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Bạn chỉ có thể theo dõi tối đa 2 Khoa khác.'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }
                                  setModalState(() {
                                    tempFollowed.add(fac.id);
                                  });
                                } else {
                                  setModalState(() {
                                    tempFollowed.remove(fac.id);
                                  });
                                }
                              },
                      ),
                    );
                  }),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          if (primaryFacultyInfo != null) {
                            tempFollowed.remove(primaryFacultyInfo.id);
                          }
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .update({'followedFaculties': tempFollowed});
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã lưu danh sách Khoa theo dõi!'),
                                backgroundColor: Color(0xFF8B5CF6),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Lưu danh sách Khoa theo dõi',
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
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

    return StreamBuilder<DocumentSnapshot>(
      stream: user != null
          ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()
          : null,
      builder: (context, userSnapshot) {
        final Map<String, dynamic>? userData =
            userSnapshot.data?.data() as Map<String, dynamic>?;
        final String? userFacultyStr = userData?['faculty']?.toString();
        final FacultyInfo? primaryFacultyInfo =
            FacultyHelper.findFacultyByAccountString(userFacultyStr);

        final List<String> followedFaculties = (userData?['followedFaculties'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        final String activeSubTab = _selectedSubTabId ?? 'my_faculty';

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600.0),
            child: Container(
              color: _backgroundColor(isDark),
              child: Column(
                children: [
                  // Thanh Tìm kiếm sự kiện Khoa
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 13,
                        color: _primaryText(isDark),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm sự kiện Khoa...',
                        hintStyle: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: isDark ? Colors.white38 : const Color(0xFF98A2B3),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 21,
                          color: isDark ? Colors.white54 : const Color(0xFF667085),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                tooltip: 'Xóa tìm kiếm',
                                splashRadius: 18,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 19,
                                  color: isDark ? Colors.white54 : const Color(0xFF667085),
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1C1E21) : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : const Color(0xFFE4E7EC),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: primaryBlue,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Sub-tab bar lọc Khoa (Khoa của bạn, Các Khoa theo dõi, Nút Thêm)
                  _buildSubTabBar(
                    context: context,
                    isDarkMode: isDark,
                    primaryFacultyInfo: primaryFacultyInfo,
                    followedFaculties: followedFaculties,
                    activeSubTab: activeSubTab,
                  ),

                  // Danh sách Events từ collection `faculty_events`
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
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

                        if (!snapshot.hasData) {
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

                                    return _buildEventCard(
                                      context,
                                      docId,
                                      data,
                                      user,
                                      isDark,
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabChip({
    required String id,
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDarkMode,
    required List<Color> activeGradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: activeGradient) : null,
          color: isSelected
              ? null
              : (isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDarkMode ? Colors.white10 : const Color(0xFFCBD5E1)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeGradient.first.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDarkMode ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDarkMode ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
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
    final String eventName = (data['eventName'] ?? data['title'] ?? 'Sự kiện sinh viên').toString();
    final String eventDateText = (data['eventDateText'] ?? data['date'] ?? 'Xem chi tiết bài viết').toString();
    final String locationName = (data['locationName'] ?? '').toString();
    final String locationAddress = (data['locationAddress'] ?? '').toString();
    final List<String> locDisplayParts = [];
    final String trimmedLocName = locationName.trim();
    final String trimmedLocAddr = locationAddress.trim();
    if (trimmedLocName.isNotEmpty) locDisplayParts.add(trimmedLocName);
    if (trimmedLocAddr.isNotEmpty && trimmedLocAddr != trimmedLocName) locDisplayParts.add(trimmedLocAddr);
    final String locationDisplay = locDisplayParts.join(' - ');
    final String facultyDisplay = (data['facultyName'] ?? data['department'] ?? 'Khoa HCMUS').toString();

    final String? thumbnailUrl = data['thumbnailUrl'] ??
        (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty ? data['imageUrls'][0] : null);

    final String link = (data['sourceArticleUrl'] ?? data['registrationUrl'] ?? data['link'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: _surfaceColor(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor(isDark)),
        boxShadow: _shadow(isDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: link.isNotEmpty ? () => _launchURL(link) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Image Header
                Stack(
                  children: [
                    thumbnailUrl != null && thumbnailUrl.isNotEmpty
                        ? Image.network(
                            thumbnailUrl,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/images/news.png',
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.asset(
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
                              Colors.black.withOpacity(0.5),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryBlue,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.school_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              facultyDisplay,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Content details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          height: 1.3,
                          color: _primaryText(isDark),
                        ),
                      ),
                      const SizedBox(height: 12),

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
                                  Icons.access_time_filled_rounded,
                                  size: 16,
                                  color: primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    eventDateText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _primaryText(isDark),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (locationDisplay.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 16,
                                    color: primaryBlue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      locationDisplay,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _secondaryText(isDark),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Action Row: "Xem chi tiết" và "Quan tâm"
                      Row(
                        children: [
                          if (link.isNotEmpty)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _launchURL(link),
                                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                label: const Text(
                                  'Xem bài gốc',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryBlue,
                                  side: const BorderSide(color: primaryBlue),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          if (link.isNotEmpty) const SizedBox(width: 10),

                          // Nút Quan tâm
                          Expanded(
                            child: StreamBuilder<DocumentSnapshot>(
                              stream: user != null
                                  ? FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('interested_events')
                                      .doc(docId)
                                      .snapshots()
                                  : null,
                              builder: (context, favSnapshot) {
                                bool isInterested =
                                    favSnapshot.hasData && favSnapshot.data!.exists;

                                return ElevatedButton.icon(
                                  onPressed: () => _toggleInterest(context, docId, data),
                                  icon: Icon(
                                    isInterested ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    isInterested ? 'Đã quan tâm' : 'Quan tâm',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isInterested ? const Color(0xFFEF4444) : primaryBlue,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                );
                              },
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
        ),
      ),
    );
  }
}