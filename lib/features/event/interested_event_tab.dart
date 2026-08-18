import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/base64_image_cache.dart';

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

class InterestedEventTab extends StatefulWidget {
  const InterestedEventTab({super.key});

  @override
  State<InterestedEventTab> createState() => _InterestedEventTabState();
}

class _InterestedEventTabState extends State<InterestedEventTab> {
  static const Color primaryBlue = Color(0xFF6797E1);
  static const Color detailBlue = Color(0xFF5794F3);

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

  Future<void> _removeInterest(BuildContext context, String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('interested_events')
          .doc(docId)
          .delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('personal_events')
          .doc(docId)
          .delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã bỏ quan tâm sự kiện & xóa khỏi lịch cá nhân'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lỗi khi xóa sự kiện')));
    }
  }

  DateTime? _extractEventDateTime(Map<String, dynamic> data) {
    if (data['dateTime'] != null && data['dateTime'] is Timestamp) {
      return (data['dateTime'] as Timestamp).toDate();
    }
    if (data['endAt'] != null && data['endAt'] is Timestamp) {
      return (data['endAt'] as Timestamp).toDate();
    }
    if (data['endDateTime'] != null && data['endDateTime'] is String) {
      final parsed = DateTime.tryParse(data['endDateTime']);
      if (parsed != null) return parsed;
    }
    if (data['startAt'] != null && data['startAt'] is Timestamp) {
      return (data['startAt'] as Timestamp).toDate();
    }
    if (data['startDateTime'] != null && data['startDateTime'] is String) {
      final parsed = DateTime.tryParse(data['startDateTime']);
      if (parsed != null) return parsed;
    }
    if (data['registrationDeadlineAt'] != null &&
        data['registrationDeadlineAt'] is Timestamp) {
      return (data['registrationDeadlineAt'] as Timestamp).toDate();
    }
    return null;
  }

  Color _backgroundColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F9FC);

  Color _surfaceColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

  Color _secondarySurfaceColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF1F4F8);

  Color _primaryTextColor(bool isDarkMode) =>
      isDarkMode ? Colors.white : const Color(0xFF1E1E1E);

  Color _secondaryTextColor(bool isDarkMode) =>
      isDarkMode ? Colors.white70 : const Color(0xFF6B7280);

  Color _borderColor(bool isDarkMode) => isDarkMode
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFE5E7EB);

  List<BoxShadow> _cardShadow(bool isDarkMode) => isDarkMode
      ? []
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ];

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
        child: Text(
          'Vui lòng đăng nhập',
          style: TextStyle(
            color: _secondaryTextColor(isDarkMode),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600.0),
        child: Container(
          color: _backgroundColor(isDarkMode),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 13,
                    color: _primaryTextColor(isDarkMode),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm sự kiện đã lưu',
                    hintStyle: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: isDarkMode
                          ? Colors.white38
                          : const Color(0xFF98A2B3),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 21,
                      color: isDarkMode
                          ? Colors.white54
                          : const Color(0xFF667085),
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
                              color: isDarkMode
                                  ? Colors.white54
                                  : const Color(0xFF667085),
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: isDarkMode
                        ? const Color(0xFF1C1E21)
                        : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
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
              const SizedBox(height: 12),

              // Content Stream List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('interested_events')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Đã xảy ra lỗi',
                          style: TextStyle(
                            color: _secondaryTextColor(isDarkMode),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: primaryBlue),
                      );
                    }

                    final allDocs = snapshot.data!.docs;

                    final urlsToPreload = allDocs
                        .map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['thumbnailUrl'] ??
                              (data['imageUrls'] != null &&
                                      (data['imageUrls'] as List).isNotEmpty
                                  ? data['imageUrls'][0]
                                  : null);
                        })
                        .map((e) => e?.toString())
                        .whereType<String>()
                        .toList();
                    Base64ImageCache.preloadImages(urlsToPreload);

                    if (allDocs.isEmpty) {
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
                                Icons.favorite_border_rounded,
                                size: 34,
                                color: _secondaryTextColor(isDarkMode),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Bạn chưa quan tâm sự kiện nào.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _primaryTextColor(isDarkMode),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Những sự kiện bạn lưu sẽ xuất hiện ở đây.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _secondaryTextColor(isDarkMode),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Filter search query & expiration (> 3 days past)
                    final cleanQuery = removeVietnameseDiacritics(_searchQuery);
                    final threeDaysAgo = DateTime.now().subtract(
                      const Duration(days: 3),
                    );

                    final filteredDocs = allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      // 0. Lọc sự kiện đã diễn ra quá 3 ngày
                      final DateTime? eventDateTime = _extractEventDateTime(
                        data,
                      );
                      if (eventDateTime != null &&
                          eventDateTime.isBefore(threeDaysAgo)) {
                        return false;
                      }

                      if (cleanQuery.isEmpty) return true;

                      final title = removeVietnameseDiacritics(
                        (data['eventName'] ??
                                data['title'] ??
                                data['eventTitle'] ??
                                data['name'] ??
                                '')
                            .toString(),
                      );
                      final desc = removeVietnameseDiacritics(
                        (data['description'] ?? data['content'] ?? '')
                            .toString(),
                      );
                      final locName = removeVietnameseDiacritics(
                        (data['locationName'] ?? '').toString(),
                      );
                      final locAddr = removeVietnameseDiacritics(
                        (data['locationAddress'] ?? '').toString(),
                      );
                      final department = removeVietnameseDiacritics(
                        (data['facultyName'] ??
                                data['department'] ??
                                data['organizer'] ??
                                '')
                            .toString(),
                      );

                      return title.contains(cleanQuery) ||
                          desc.contains(cleanQuery) ||
                          locName.contains(cleanQuery) ||
                          locAddr.contains(cleanQuery) ||
                          department.contains(cleanQuery);
                    }).toList();

                    if (_searchQuery.isNotEmpty && filteredDocs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 42,
                                color: _secondaryTextColor(isDarkMode),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Không tìm thấy sự kiện phù hợp',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _primaryTextColor(isDarkMode),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Thử tìm với từ khóa khác.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _secondaryTextColor(isDarkMode),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildEventCard(
                          context,
                          doc.id,
                          data,
                          isDarkMode,
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
  }

  Future<String> _fetchContactFallback(
    Map<String, dynamic> data,
    String docId,
  ) async {
    final String rawContact = (data['contact'] ?? data['contactInfo'] ?? '')
        .toString()
        .trim();
    final String rawOrganizer =
        (data['organizer'] ?? data['organizerName'] ?? '').toString().trim();
    if (rawContact.isNotEmpty) {
      return rawContact.toLowerCase().startsWith('liên hệ')
          ? rawContact
          : 'Liên hệ: $rawContact';
    }
    if (rawOrganizer.isNotEmpty) {
      return 'Liên hệ: $rawOrganizer';
    }

    final String targetDocId =
        (data['facultyEventId'] ?? data['docId'] ?? docId).toString();
    if (targetDocId.isNotEmpty) {
      try {
        final facDoc = await FirebaseFirestore.instance
            .collection('faculty_events')
            .doc(targetDocId)
            .get();
        if (facDoc.exists && facDoc.data() != null) {
          final fData = facDoc.data()!;
          final String fContact =
              (fData['contact'] ?? fData['contactInfo'] ?? '')
                  .toString()
                  .trim();
          final String fOrganizer =
              (fData['organizer'] ?? fData['organizerName'] ?? '')
                  .toString()
                  .trim();
          if (fContact.isNotEmpty) {
            return fContact.toLowerCase().startsWith('liên hệ')
                ? fContact
                : 'Liên hệ: $fContact';
          }
          if (fOrganizer.isNotEmpty) {
            return 'Liên hệ: $fOrganizer';
          }
        }
      } catch (_) {}
    }
    return '';
  }

  Future<bool> _checkEventExists(
    Map<String, dynamic> data,
    String docId,
  ) async {
    final String targetDocId =
        (data['facultyEventId'] ?? data['docId'] ?? docId).toString();
    final String collectionPath = (data['collectionPath'] ?? 'faculty_events')
        .toString();
    if (targetDocId.isEmpty) return true;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(targetDocId)
          .get();
      return doc.exists;
    } catch (_) {
      return true;
    }
  }

  Widget _buildEventCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
    bool isDarkMode,
  ) {
    final String title =
        (data['eventName'] ?? data['title'] ?? 'Sự kiện sinh viên').toString();

    final String date = (data['eventDateText'] ?? data['date'] ?? '')
        .toString();

    final String department =
        (data['locationName'] ??
                data['facultyName'] ??
                data['department'] ??
                'Cơ sở HCMUS')
            .toString();

    final String onlineUrl = (data['onlineUrl'] ?? data['onlineLink'] ?? '')
        .toString()
        .trim();

    final bool isOnline = data['isOnline'] == true || onlineUrl.isNotEmpty;

    final String link =
        (data['sourceArticleUrl'] ??
                data['registrationUrl'] ??
                data['link'] ??
                onlineUrl)
            .toString();

    final String rawContact = (data['contact'] ?? data['contactInfo'] ?? '')
        .toString()
        .trim();

    final String rawOrganizer =
        (data['organizer'] ?? data['organizerName'] ?? '').toString().trim();

    String displayContact = rawContact.isNotEmpty ? rawContact : rawOrganizer;

    if (displayContact.isNotEmpty &&
        !displayContact.toLowerCase().startsWith('liên hệ')) {
      displayContact = 'Liên hệ: $displayContact';
    }

    final String effectiveLink = onlineUrl.isNotEmpty ? onlineUrl : link;

    final String? thumbnailUrl =
        data['thumbnailUrl'] ??
        (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty
            ? data['imageUrls'][0]
            : null);

    final Color cardColor = _surfaceColor(isDarkMode);

    final Color borderColor = _borderColor(isDarkMode);

    final Color primaryTextColor = _primaryTextColor(isDarkMode);

    final Color secondaryTextColor = _secondaryTextColor(isDarkMode);

    return FutureBuilder<bool>(
      future: _checkEventExists(data, docId),
      builder: (context, eventSnapshot) {
        final bool isDeleted =
            eventSnapshot.hasData && eventSnapshot.data == false;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDeleted
                  ? Colors.redAccent.withValues(alpha: 0.32)
                  : borderColor,
            ),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: !isDeleted && effectiveLink.isNotEmpty
                    ? () {
                        _launchURL(effectiveLink);
                      }
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Base64ImageCache.buildSmartImage(
                          imageUrl: thumbnailUrl,
                          height: 150,
                          width: double.infinity,
                          fallbackAsset: 'assets/images/news.png',
                        ),

                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.34),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (isOnline)
                          Positioned(
                            top: 11,
                            left: 11,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.48),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.20),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.videocam_outlined,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Online',
                                    style: TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        Positioned(
                          top: 10,
                          right: 10,
                          child: Tooltip(
                            message: 'Bỏ khỏi danh sách quan tâm',
                            child: Material(
                              color: Colors.transparent,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _removeInterest(context, docId),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.42),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              fontSize: 16.5,
                              height: 1.3,
                              color: primaryTextColor,
                            ),
                          ),

                          if (isDeleted) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(
                                  alpha: isDarkMode ? 0.14 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.30,
                                  ),
                                ),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(top: 1),
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      size: 17,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      'Sự kiện này đã bị hủy hoặc không còn tồn tại trên hệ thống.',
                                      style: TextStyle(
                                        fontFamily: 'Encode Sans Expanded',
                                        fontSize: 11.5,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 13),

                          _buildInterestedEventInfoRow(
                            icon: Icons.access_time_rounded,
                            text: date.isEmpty
                                ? 'Chưa cập nhật thời gian'
                                : date,
                            iconColor: primaryBlue,
                            textColor: primaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),

                          const SizedBox(height: 9),

                          _buildInterestedEventInfoRow(
                            icon: isOnline
                                ? Icons.videocam_outlined
                                : Icons.location_on_outlined,
                            text: department.isNotEmpty
                                ? department
                                : (isOnline
                                      ? 'Trực tuyến'
                                      : 'Chưa cập nhật địa điểm'),
                            iconColor: primaryBlue,
                            textColor: secondaryTextColor,
                          ),

                          FutureBuilder<String>(
                            future: _fetchContactFallback(data, docId),
                            builder: (context, snapshot) {
                              final String contactInfo =
                                  snapshot.data ?? displayContact;

                              if (contactInfo.trim().isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(top: 9),
                                child: _buildInterestedEventInfoRow(
                                  icon: Icons.contact_phone_outlined,
                                  text: contactInfo,
                                  iconColor: primaryBlue,
                                  textColor: secondaryTextColor,
                                ),
                              );
                            },
                          ),

                          if (!isDeleted &&
                              (onlineUrl.isNotEmpty || link.isNotEmpty)) ...[
                            const SizedBox(height: 15),

                            _buildInterestedEventActions(
                              isDarkMode: isDarkMode,
                              onlineUrl: onlineUrl,
                              link: link,
                            ),
                          ],
                        ],
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
  }

  Widget _buildInterestedEventInfoRow({
    required IconData icon,
    required String text,
    required Color iconColor,
    required Color textColor,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
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

  Widget _buildInterestedEventActions({
    required bool isDarkMode,
    required String onlineUrl,
    required String link,
  }) {
    final bool hasOnlineLink = onlineUrl.isNotEmpty;

    final bool hasSourceLink = link.isNotEmpty && link != onlineUrl;

    final Color secondaryTextColor = _secondaryTextColor(isDarkMode);

    final Color borderColor = _borderColor(isDarkMode);

    if (hasOnlineLink) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                _launchURL(onlineUrl);
              },
              icon: const Icon(Icons.videocam_outlined, size: 17),
              label: const Text(
                'Tham gia trực tuyến',
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          if (hasSourceLink) ...[
            const SizedBox(width: 9),

            PopupMenuButton<String>(
              tooltip: 'Thêm tùy chọn',
              color: _surfaceColor(isDarkMode),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) {
                if (value == 'open_source') {
                  _launchURL(link);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  value: 'open_source',
                  height: 42,
                  child: Row(
                    children: [
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Xem bài gốc',
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 12,
                          color: _primaryTextColor(isDarkMode),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 21,
                  color: secondaryTextColor,
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (hasSourceLink) {
      return SizedBox(
        width: double.infinity,
        height: 42,
        child: OutlinedButton.icon(
          onPressed: () {
            _launchURL(link);
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 17),
          label: const Text(
            'Xem chi tiết sự kiện',
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryBlue,
            side: const BorderSide(color: primaryBlue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
