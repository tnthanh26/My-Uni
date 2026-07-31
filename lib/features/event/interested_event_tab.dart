import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_uni/features/home/post_detail_page.dart';

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
        const SnackBar(content: Text('Đã bỏ quan tâm sự kiện & xóa khỏi lịch cá nhân')),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi khi xóa sự kiện')),
      );
    }
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

  Color _borderColor(bool isDarkMode) =>
      isDarkMode ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB);

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

                    // Filter search query
                    final cleanQuery = removeVietnameseDiacritics(_searchQuery);
                    final filteredDocs = allDocs.where((doc) {
                      if (cleanQuery.isEmpty) return true;
                      final data = doc.data() as Map<String, dynamic>;
                      final title = removeVietnameseDiacritics(
                          (data['eventName'] ?? data['title'] ?? data['eventTitle'] ?? data['name'] ?? '').toString());
                      final desc = removeVietnameseDiacritics(
                          (data['description'] ?? data['content'] ?? '').toString());
                      final locName = removeVietnameseDiacritics(
                          (data['locationName'] ?? '').toString());
                      final locAddr = removeVietnameseDiacritics(
                          (data['locationAddress'] ?? '').toString());
                      final department = removeVietnameseDiacritics(
                          (data['facultyName'] ?? data['department'] ?? data['organizer'] ?? '').toString());

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

  Widget _buildEventCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
    bool isDarkMode,
  ) {
    final String title = (data['eventName'] ?? data['title'] ?? 'Sự kiện sinh viên').toString();
    final String date = (data['eventDateText'] ?? data['date'] ?? '').toString();
    final String department = (data['locationName'] ?? data['facultyName'] ?? data['department'] ?? 'Cơ sở HCMUS').toString();
    final String link = (data['sourceArticleUrl'] ?? data['registrationUrl'] ?? data['link'] ?? '').toString();
    final String? thumbnailUrl = data['thumbnailUrl'] ??
        (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty ? data['imageUrls'][0] : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor(isDarkMode)),
        boxShadow: _cardShadow(isDarkMode),
      ),
      child: InkWell(
        onTap: () {
          if (link.isNotEmpty) {
            _launchURL(link);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bài viết không có đường dẫn bài gốc')),
            );
          }
        },
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                      ? Image.network(
                          thumbnailUrl,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/news.png',
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/news.png',
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.12),
                          Colors.black.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => _removeInterest(context, docId),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Text(
                      'Đã quan tâm',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _primaryTextColor(isDarkMode),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _secondarySurfaceColor(isDarkMode),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borderColor(isDarkMode)),
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
                                date.isEmpty ? 'Xem chi tiết bài viết' : date,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _secondaryTextColor(isDarkMode),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
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
                                department,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _secondaryTextColor(isDarkMode),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (link.isNotEmpty) {
                      _launchURL(link);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bài viết không có đường dẫn bài gốc')),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text(
                    'Xem bài gốc',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: detailBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}