import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_uni/models/event_model.dart';
import 'package:my_uni/features/event/create_personal_event_page.dart';
import 'package:my_uni/features/home/faculty_helper.dart';
import 'package:my_uni/utils/app_feedback.dart';

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
      AppFeedback.showInfo(
        context,
        "Đã bỏ quan tâm & hủy đồng bộ Lịch biểu ở trang góc nhỏ",
      );
    } else {
      // 2. Mở màn hình tạo / chỉnh sửa sự kiện cá nhân với nội dung điền sẵn từ bài viết
      final String eventName = (data['eventName'] ?? data['title'] ?? 'Sự kiện Khoa').toString();
      final String description = (data['description'] ?? '').toString();
      final String locationName = (data['locationName'] ?? '').toString();
      final String locationAddress = (data['locationAddress'] ?? '').toString();
      final String facultyName = (data['facultyName'] ?? data['department'] ?? 'Khoa HCMUS').toString();
      final String onlineUrl = (data['onlineUrl'] ?? data['onlineLink'] ?? '').toString().trim();
      final bool isOnline = data['isOnline'] == true || onlineUrl.isNotEmpty;
      final String sourceArticleUrl = (data['sourceArticleUrl'] ?? data['registrationUrl'] ?? data['link'] ?? onlineUrl).toString();

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
        locStr = isOnline ? 'Online' : (facultyName.isNotEmpty ? facultyName : 'Chưa cập nhật địa điểm');
      }

      final String contactStr = (data['contact'] ?? data['organizer'] ?? '').toString().trim();
      String fullDesc = description;
      if (contactStr.isNotEmpty && !fullDesc.contains(contactStr)) {
        if (fullDesc.isNotEmpty) fullDesc += '\n\n';
        fullDesc += '📞 Liên hệ: $contactStr';
      }

      final noteEvent = EventModel(
        id: docId,
        title: eventName,
        dateTime: parsedDateTime,
        location: locStr,
        reminder: '15 phút trước',
        description: '',
        sourceArticleUrl: sourceArticleUrl,
        onlineUrl: onlineUrl,
        isOnline: isOnline,
        facultyEventId: docId,
        isFromFacultyEvent: true,
        contact: contactStr.isNotEmpty ? contactStr : null,
      );

      if (!context.mounted) return;

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => CreatePersonalEventPage(event: noteEvent),
        ),
      );

      if (saved == true && context.mounted) {
        AppFeedback.showSuccess(
          context,
          "Đã lưu & tự động đồng bộ vào Lịch biểu ở trang góc nhỏ!",
        );
      }
    }
  }

  /// Dialog / BottomSheet cập nhật Khoa nhanh nếu người dùng chưa chọn Khoa
  void _showQuickFacultyPicker(BuildContext context, String? currentFaculty) {
    String? selected = (currentFaculty != null &&
            currentFaculty.isNotEmpty &&
            currentFaculty != 'Chưa cập nhật khoa')
        ? currentFaculty
        : FacultyHelper.allHcmusFaculties.first;

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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
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
                          color: const Color(0xFF5893D8).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Color(0xFF5893D8),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cập nhật Khoa của bạn',
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Chọn Khoa đang học để xem sự kiện dành riêng',
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white60
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: FacultyHelper.allHcmusFaculties.length,
                      itemBuilder: (context, index) {
                        final fac = FacultyHelper.allHcmusFaculties[index];
                        final isSelected = fac == selected;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF5893D8).withValues(alpha: 0.12)
                                : (isDarkMode
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF5893D8)
                                  : (isDarkMode
                                      ? Colors.white10
                                      : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: RadioListTile<String>(
                            value: fac,
                            groupValue: selected,
                            activeColor: const Color(0xFF5893D8),
                            title: Text(
                              fac,
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF5893D8)
                                    : (isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF334155)),
                              ),
                            ),
                            onChanged: (val) {
                              setModalState(() => selected = val);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null && selected != null) {
                          final newPrimary =
                              FacultyHelper.findFacultyByAccountString(selected);
                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .get();
                          List<String> followed =
                              (userDoc.data()?['followedFaculties'] as List?)
                                      ?.map((e) => e.toString())
                                      .toList() ??
                                  [];
                          if (newPrimary != null) {
                            followed.remove(newPrimary.id);
                          }
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .update({
                            'faculty': selected,
                            'followedFaculties': followed,
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã cập nhật Khoa: $selected'),
                                backgroundColor: const Color(0xFF5893D8),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5893D8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Xác nhận & Lưu Khoa',
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
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (ctx) {
        final bool isDarkMode = Theme.of(ctx).brightness == Brightness.dark;
        const Color primaryColor = Color(0xFF5893D8);

        final Color sheetColor =
            isDarkMode ? const Color(0xFF1C1E21) : Colors.white;

        final Color surfaceColor = isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC);

        final Color selectedSurfaceColor = isDarkMode
            ? primaryColor.withValues(alpha: 0.12)
            : primaryColor.withValues(alpha: 0.07);

        final Color borderColor = isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFE4E7EC);

        final Color selectedBorderColor = primaryColor.withValues(alpha: 0.38);

        final Color primaryTextColor =
            isDarkMode ? Colors.white : const Color(0xFF1D2939);

        final Color secondaryTextColor =
            isDarkMode ? Colors.white60 : const Color(0xFF667085);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(
                        top: 10,
                        bottom: 18,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white24
                            : const Color(0xFFD0D5DD),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(
                                alpha: isDarkMode ? 0.16 : 0.10,
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: primaryColor,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Theo dõi sự kiện các khoa',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Chọn tối đa 2 khoa để theo dõi thêm sự kiện.',
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: FacultyHelper.activeFaculties.map((fac) {
                            final bool isPrimary =
                                primaryFacultyInfo?.id == fac.id;
                            final bool isFollowed =
                                tempFollowed.contains(fac.id);
                            final bool isSelected = isPrimary || isFollowed;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: isPrimary
                                      ? null
                                      : () {
                                          if (isFollowed) {
                                            setModalState(() {
                                              tempFollowed.remove(fac.id);
                                            });
                                            return;
                                          }

                                          if (tempFollowed.length >= 2) {
                                            ScaffoldMessenger.of(context)
                                              ..hideCurrentSnackBar()
                                              ..showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Bạn chỉ có thể theo dõi tối đa 2 khoa khác.',
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            return;
                                          }

                                          setModalState(() {
                                            tempFollowed.add(fac.id);
                                          });
                                        },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    curve: Curves.easeOut,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? selectedSurfaceColor
                                          : surfaceColor,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? selectedBorderColor
                                            : borderColor,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? primaryColor.withValues(
                                                    alpha: isDarkMode ? 0.18 : 0.10,
                                                  )
                                                : (isDarkMode
                                                    ? Colors.white.withValues(
                                                        alpha: 0.05,
                                                      )
                                                    : Colors.white),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            fac.icon,
                                            size: 20,
                                            color: isSelected
                                                ? primaryColor
                                                : secondaryTextColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                fac.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily: 'Nunito',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: primaryTextColor,
                                                ),
                                              ),
                                              if (isPrimary) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Khoa chính của bạn',
                                                  style: TextStyle(
                                                    fontFamily:
                                                        'Encode Sans Expanded',
                                                    fontSize: 10.5,
                                                    color: secondaryTextColor,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 160),
                                          width: 22,
                                          height: 22,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? primaryColor
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? primaryColor
                                                  : borderColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  size: 15,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                      decoration: BoxDecoration(
                        color: sheetColor,
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: secondaryTextColor,
                                  side: BorderSide(color: borderColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Hủy',
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: FilledButton(
                                onPressed: () async {
                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user == null) return;
                                  if (primaryFacultyInfo != null) {
                                    tempFollowed.remove(primaryFacultyInfo.id);
                                  }
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .update({'followedFaculties': tempFollowed});
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Đã lưu danh sách khoa theo dõi',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Lưu thay đổi',
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                      stream: user != null
                          ? FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('interested_events')
                              .snapshots()
                          : null,
                      builder: (context, interestedSnapshot) {
                        final Set<String> interestedDocIds =
                            interestedSnapshot.data?.docs.map((d) => d.id).toSet() ?? {};

                        return StreamBuilder<QuerySnapshot>(
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

                            // Sắp xếp các sự kiện theo 4 thứ tự ưu tiên:
                            // 1. Event chưa quan tâm, sắp diễn ra gần nhất
                            // 2. Event chưa quan tâm khác
                            // 3. Event đã quan tâm
                            // 4. Event đã diễn ra
                            final now = DateTime.now();
                            filteredDocs.sort((a, b) {
                              final priorityA = _getEventPriority(a, interestedDocIds, now);
                              final priorityB = _getEventPriority(b, interestedDocIds, now);

                              if (priorityA != priorityB) {
                                return priorityA.compareTo(priorityB);
                              }

                              final dataA = a.data() as Map<String, dynamic>;
                              final dataB = b.data() as Map<String, dynamic>;

                              // Nhóm 1: Chưa quan tâm, sắp diễn ra -> Xếp tăng dần theo thời gian (sắp diễn ra gần nhất lên đầu)
                              if (priorityA == 1) {
                                final dtA = _extractEventDateTime(dataA);
                                final dtB = _extractEventDateTime(dataB);
                                if (dtA != null && dtB != null) {
                                  return dtA.compareTo(dtB);
                                }
                              }

                              // Nhóm 4: Đã diễn ra -> Xếp giảm dần theo thời gian (vừa kết thúc gần nhất lên đầu)
                              if (priorityA == 4) {
                                final dtA = _extractEventDateTime(dataA);
                                final dtB = _extractEventDateTime(dataB);
                                if (dtA != null && dtB != null) {
                                  return dtB.compareTo(dtA);
                                }
                              }

                              final int tsA = _extractMillis(dataA);
                              final int tsB = _extractMillis(dataB);
                              return tsB.compareTo(tsA);
                            });

                            if (activeSubTab == 'my_faculty' && primaryFacultyInfo == null) {
                              return _buildEmptyFacultySetupCard(context, isDark, userFacultyStr);
                            }

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

  DateTime? _extractEventDateTime(Map<String, dynamic> data) {
    if (data['startAt'] != null && data['startAt'] is Timestamp) {
      return (data['startAt'] as Timestamp).toDate();
    }
    if (data['startDateTime'] != null && data['startDateTime'] is String) {
      final parsed = DateTime.tryParse(data['startDateTime']);
      if (parsed != null) return parsed;
    }
    if (data['registrationDeadlineAt'] != null && data['registrationDeadlineAt'] is Timestamp) {
      return (data['registrationDeadlineAt'] as Timestamp).toDate();
    }
    return null;
  }

  int _getEventPriority(DocumentSnapshot doc, Set<String> interestedDocIds, DateTime now) {
    final data = doc.data() as Map<String, dynamic>;
    final bool isInterested = interestedDocIds.contains(doc.id);
    final DateTime? eventTime = _extractEventDateTime(data);

    final bool isPast = eventTime != null && eventTime.isBefore(now);

    if (isPast) {
      return 4; // 4. Event đã diễn ra
    }

    if (!isInterested) {
      if (eventTime != null && eventTime.isAfter(now)) {
        return 1; // 1. Event chưa quan tâm, sắp diễn ra gần nhất
      }
      return 2; // 2. Event chưa quan tâm khác
    }

    return 3; // 3. Event đã quan tâm
  }

  /// Empty State khi User chưa chọn Khoa trong account
  Widget _buildEmptyFacultySetupCard(
    BuildContext context,
    bool isDarkMode,
    String? currentFaculty,
  ) {
    final Color cardColor =
        isDarkMode ? const Color(0xFF1C1E21) : Colors.white;

    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE4E7EC);

    final Color primaryTextColor =
        isDarkMode ? Colors.white : const Color(0xFF1D2939);

    final Color secondaryTextColor =
        isDarkMode ? Colors.white60 : const Color(0xFF667085);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: isDarkMode
                ? const []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF5893D8).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_outlined,
                  size: 30,
                  color: Color(0xFF5893D8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa thiết lập khoa',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Chọn khoa của bạn để nhận sự kiện và thông báo chính thức phù hợp.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 12.5,
                  height: 1.5,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: () => _showQuickFacultyPicker(context, currentFaculty),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5893D8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  label: const Text(
                    'Thiết lập khoa',
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Thanh chuyển đổi Sub-Tab lọc Khoa cho trang Events
  Widget _buildSubTabBar({
    required BuildContext context,
    required bool isDarkMode,
    required FacultyInfo? primaryFacultyInfo,
    required List<String> followedFaculties,
    required String activeSubTab,
  }) {
    final Color backgroundColor = isDarkMode
        ? const Color(0xFF101214)
        : const Color(0xFFF8FAFC);

    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFEAECF0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // 1. Tab Khoa của bạn
            _buildSubTabChip(
              id: 'my_faculty',
              label: primaryFacultyInfo != null
                  ? 'Khoa của bạn · ${primaryFacultyInfo.shortName}'
                  : 'Khoa của bạn',
              icon: primaryFacultyInfo?.icon ?? Icons.school_rounded,
              isSelected: activeSubTab == 'my_faculty',
              isDarkMode: isDarkMode,
              badgeText: primaryFacultyInfo == null ? 'Chưa chọn' : null,
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
                  onTap: () => setState(() => _selectedSubTabId = facInfo.id),
                ),
              );
            }),

            const SizedBox(width: 8),

            // 3. Nút Quản lý theo dõi Khoa
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showManageFollowedFacultiesModal(
                  context,
                  primaryFacultyInfo,
                  followedFaculties,
                ),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: isDarkMode
                            ? Colors.white60
                            : const Color(0xFF667085),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Theo dõi khoa',
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white70
                              : const Color(0xFF475467),
                        ),
                      ),
                    ],
                  ),
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
    required VoidCallback onTap,
    String? badgeText,
  }) {
    const Color activeColor = Color(0xFF5893D8);

    final Color inactiveBackground = isDarkMode
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white;

    final Color inactiveBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE4E7EC);

    final Color inactiveTextColor = isDarkMode
        ? Colors.white70
        : const Color(0xFF475467);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : inactiveBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? activeColor : inactiveBorder,
            ),
            boxShadow: isSelected && !isDarkMode
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.16),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : inactiveTextColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 11.5,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : inactiveTextColor,
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.20)
                        : const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF667085),
                    ),
                  ),
                ),
              ],
            ],
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
    final String eventName =
    (data['eventName'] ??
        data['title'] ??
        'Sự kiện sinh viên')
        .toString();

    final String eventDateText =
    (data['eventDateText'] ??
        data['date'] ??
        'Xem chi tiết bài viết')
        .toString();

    final String locationName =
    (data['locationName'] ?? '').toString();

    final String locationAddress =
    (data['locationAddress'] ?? '').toString();

    final List<String> locDisplayParts = [];

    final String trimmedLocName =
    locationName.trim();

    final String trimmedLocAddr =
    locationAddress.trim();

    if (trimmedLocName.isNotEmpty) {
      locDisplayParts.add(trimmedLocName);
    }

    if (trimmedLocAddr.isNotEmpty &&
        trimmedLocAddr != trimmedLocName) {
      locDisplayParts.add(trimmedLocAddr);
    }

    final String locationDisplay =
    locDisplayParts.join(' - ');

    final String facultyDisplay =
    (data['facultyName'] ??
        data['department'] ??
        'Khoa HCMUS')
        .toString();

    final String? thumbnailUrl =
        data['thumbnailUrl'] ??
            (
                data['imageUrls'] != null &&
                    (data['imageUrls'] as List).isNotEmpty
                    ? data['imageUrls'][0]
                    : null
            );

    final String onlineUrl =
    (data['onlineUrl'] ??
        data['onlineLink'] ??
        '')
        .toString()
        .trim();

    final bool isOnline =
        data['isOnline'] == true ||
            onlineUrl.isNotEmpty;

    final String link =
    (data['sourceArticleUrl'] ??
        data['registrationUrl'] ??
        data['link'] ??
        onlineUrl)
        .toString();

    final String rawContact =
    (data['contact'] ??
        data['contactInfo'] ??
        '')
        .toString()
        .trim();

    final String rawOrganizer =
    (data['organizer'] ??
        data['organizerName'] ??
        '')
        .toString()
        .trim();

    String displayContact =
    rawContact.isNotEmpty
        ? rawContact
        : rawOrganizer;

    if (displayContact.isNotEmpty &&
        !displayContact
            .toLowerCase()
            .startsWith('liên hệ')) {
      displayContact =
      'Liên hệ: $displayContact';
    }

    final DateTime? eventDateTime = _extractEventDateTime(data);
    final bool isPast = eventDateTime != null && eventDateTime.isBefore(DateTime.now());

    final String effectiveLink =
    onlineUrl.isNotEmpty
        ? onlineUrl
        : link;

    final Color cardColor =
    _surfaceColor(isDark);

    final Color borderColor =
    _borderColor(isDark);

    final Color primaryTextColor =
    _primaryText(isDark);

    final Color secondaryTextColor =
    _secondaryText(isDark);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: isDark
            ? const []
            : [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
        BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: effectiveLink.isNotEmpty
                ? () {
              _launchURL(effectiveLink);
            }
                : null,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Opacity(
                      opacity: isPast ? 0.75 : 1.0,
                      child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                          ? Image.network(
                              thumbnailUrl,
                              height: 154,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Image.asset(
                                  'assets/images/news.png',
                                  height: 154,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.asset(
                              'assets/images/news.png',
                              height: 154,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),

                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin:
                            Alignment.topCenter,
                            end:
                            Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(
                                alpha: 0.34,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (isPast)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF344054).withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'ĐÃ DIỄN RA',
                                style: TextStyle(
                                  fontFamily: 'Encode Sans Expanded',
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (isOnline)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black
                                .withValues(
                              alpha: 0.48,
                            ),
                            borderRadius:
                            BorderRadius.circular(
                              10,
                            ),
                            border: Border.all(
                              color: Colors.white
                                  .withValues(
                                alpha: 0.22,
                              ),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize:
                            MainAxisSize.min,
                            children: [
                              Icon(
                                Icons
                                    .videocam_outlined,
                                size: 13,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Online',
                                style: TextStyle(
                                  fontFamily:
                                  'Encode Sans Expanded',
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                Padding(
                  padding:
                  const EdgeInsets.fromLTRB(
                    16,
                    15,
                    16,
                    15,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventName,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight:
                          FontWeight.w700,
                          fontSize: 17,
                          height: 1.3,
                          color: primaryTextColor,
                        ),
                      ),

                      const SizedBox(height: 13),

                      _buildEventInfoRow(
                        icon:
                        Icons.school_outlined,
                        text: facultyDisplay,
                        iconColor: primaryBlue,
                        textColor:
                        secondaryTextColor,
                      ),

                      const SizedBox(height: 9),

                      _buildEventInfoRow(
                        icon:
                        Icons.access_time_rounded,
                        text: eventDateText,
                        iconColor: primaryBlue,
                        textColor:
                        primaryTextColor,
                        fontWeight:
                        FontWeight.w600,
                      ),

                      if (locationDisplay.isNotEmpty ||
                          isOnline) ...[
                        const SizedBox(height: 9),
                        _buildEventInfoRow(
                          icon: isOnline
                              ? Icons
                              .videocam_outlined
                              : Icons
                              .location_on_outlined,
                          text: locationDisplay
                              .isNotEmpty
                              ? locationDisplay
                              : 'Trực tuyến',
                          iconColor:
                          primaryBlue,
                          textColor:
                          secondaryTextColor,
                        ),
                      ],

                      if (displayContact
                          .isNotEmpty) ...[
                        const SizedBox(height: 9),
                        _buildEventInfoRow(
                          icon: Icons
                              .contact_phone_outlined,
                          text: displayContact,
                          iconColor:
                          primaryBlue,
                          textColor:
                          secondaryTextColor,
                        ),
                      ],

                      const SizedBox(height: 15),

                      Row(
                        children: [
                          Expanded(
                            child: StreamBuilder<
                                DocumentSnapshot>(
                              stream: user != null
                                  ? FirebaseFirestore
                                  .instance
                                  .collection(
                                'users',
                              )
                                  .doc(user.uid)
                                  .collection(
                                'interested_events',
                              )
                                  .doc(docId)
                                  .snapshots()
                                  : null,
                              builder:
                                  (context, favSnapshot) {
                                final bool
                                isInterested =
                                    favSnapshot.hasData &&
                                        favSnapshot
                                            .data!
                                            .exists;

                                 if (isPast) {
                                   return FilledButton.icon(
                                     onPressed: () {
                                       _toggleInterest(
                                         context,
                                         docId,
                                         data,
                                       );
                                     },
                                     icon: Icon(
                                       isInterested
                                           ? Icons.check_circle_outline_rounded
                                           : Icons.event_busy_rounded,
                                       size: 16,
                                     ),
                                     label: Text(
                                       isInterested
                                           ? 'Đã quan tâm (Đã kết thúc)'
                                           : 'Sự kiện đã kết thúc',
                                       style: const TextStyle(
                                         fontFamily: 'Encode Sans Expanded',
                                         fontSize: 12,
                                         fontWeight: FontWeight.w600,
                                       ),
                                     ),
                                     style: FilledButton.styleFrom(
                                       backgroundColor: isDark
                                           ? const Color(0xFF2C2F33)
                                           : const Color(0xFFF2F4F7),
                                       foregroundColor: isDark
                                           ? Colors.white54
                                           : const Color(0xFF667085),
                                       elevation: 0,
                                       minimumSize: const Size(double.infinity, 42),
                                       shape: RoundedRectangleBorder(
                                         borderRadius: BorderRadius.circular(12),
                                       ),
                                     ),
                                   );
                                 }

                                return FilledButton.icon(
                                  onPressed: () {
                                    _toggleInterest(
                                      context,
                                      docId,
                                      data,
                                    );
                                  },
                                  icon: Icon(
                                    isInterested
                                        ? Icons
                                        .favorite_rounded
                                        : Icons
                                        .favorite_border_rounded,
                                    size: 17,
                                  ),
                                  label: Text(
                                    isInterested
                                        ? 'Đã quan tâm'
                                        : 'Quan tâm',
                                    style:
                                    const TextStyle(
                                      fontFamily:
                                      'Encode Sans Expanded',
                                      fontSize: 12.5,
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                  style:
                                  FilledButton.styleFrom(
                                    backgroundColor:
                                    isInterested
                                        ? primaryBlue
                                        .withValues(
                                      alpha:
                                      isDark
                                          ? 0.20
                                          : 0.12,
                                    )
                                        : primaryBlue,
                                    foregroundColor:
                                    isInterested
                                        ? primaryBlue
                                        : Colors.white,
                                    elevation: 0,
                                    minimumSize:
                                    const Size(
                                      double.infinity,
                                      42,
                                    ),
                                    shape:
                                    RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius
                                          .circular(
                                        12,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          if (onlineUrl.isNotEmpty ||
                              (
                                  link.isNotEmpty &&
                                      link != onlineUrl
                              )) ...[
                            const SizedBox(width: 9),

                            PopupMenuButton<String>(
                              tooltip:
                              'Thêm tùy chọn',
                              color:
                              _surfaceColor(isDark),
                              surfaceTintColor:
                              Colors.transparent,
                              shape:
                              RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(
                                  14,
                                ),
                              ),
                              onSelected: (value) {
                                if (value ==
                                    'join_online') {
                                  _launchURL(
                                    onlineUrl,
                                  );
                                } else if (value ==
                                    'open_source') {
                                  _launchURL(link);
                                }
                              },
                              itemBuilder:
                                  (context) => [
                                if (onlineUrl
                                    .isNotEmpty)
                                  PopupMenuItem<
                                      String>(
                                    value:
                                    'join_online',
                                    height: 42,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons
                                              .videocam_outlined,
                                          size: 18,
                                          color:
                                          secondaryTextColor,
                                        ),
                                        const SizedBox(
                                          width: 10,
                                        ),
                                        Text(
                                          'Tham gia trực tuyến',
                                          style:
                                          TextStyle(
                                            fontFamily:
                                            'Encode Sans Expanded',
                                            fontSize: 12,
                                            color:
                                            primaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                if (link.isNotEmpty &&
                                    link != onlineUrl)
                                  PopupMenuItem<
                                      String>(
                                    value:
                                    'open_source',
                                    height: 42,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons
                                              .open_in_new_rounded,
                                          size: 18,
                                          color:
                                          secondaryTextColor,
                                        ),
                                        const SizedBox(
                                          width: 10,
                                        ),
                                        Text(
                                          'Xem bài gốc',
                                          style:
                                          TextStyle(
                                            fontFamily:
                                            'Encode Sans Expanded',
                                            fontSize: 12,
                                            color:
                                            primaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              child: Container(
                                width: 42,
                                height: 42,
                                alignment:
                                Alignment.center,
                                decoration:
                                BoxDecoration(
                                  color: isDark
                                      ? Colors.white
                                      .withValues(
                                    alpha: 0.06,
                                  )
                                      : const Color(
                                    0xFFF5F7FA,
                                  ),
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    12,
                                  ),
                                  border: Border.all(
                                    color: borderColor,
                                  ),
                                ),
                                child: Icon(
                                  Icons
                                      .more_horiz_rounded,
                                  size: 21,
                                  color:
                                  secondaryTextColor,
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildEventInfoRow({
    required IconData icon,
    required String text,
    required Color iconColor,
    required Color textColor,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: 1,
          ),
          child: Icon(
            icon,
            size: 16,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily:
              'Encode Sans Expanded',
              fontSize: 12.5,
              height: 1.4,
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}