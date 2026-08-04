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

<<<<<<< Updated upstream
=======
  @override
  State<OfficialTab> createState() => _OfficialTabState();
}

class _OfficialTabState extends State<OfficialTab> {
  // Sub-tab id: 'all' (Toàn trường), 'my_faculty' (Khoa của bạn), hoặc 'fit'/'chemistry'/'physics'
  String _selectedSubTabId = 'all';

  // Bộ nhớ tạm Cache tin tức theo Sub-tab (chỉ hiện Skeleton 1 lần duy nhất khi mới tải tab)
  static final Map<String, List<QueryDocumentSnapshot>> _newsCache = {};

  String _getNewsImageUrl(Map<String, dynamic> data) {
    final imageUrl = data['imageUrl']?.toString().trim() ?? '';
    if (imageUrl.isNotEmpty) return imageUrl;

    final thumbnailUrl = data['thumbnailUrl']?.toString().trim() ?? '';
    if (thumbnailUrl.isNotEmpty) return thumbnailUrl;

    final imageUrls = data['imageUrls'];
    if (imageUrls is List && imageUrls.isNotEmpty) {
      final firstUrl = imageUrls.first?.toString().trim() ?? '';
      if (firstUrl.isNotEmpty) return firstUrl;
    }

    return '';
  }

>>>>>>> Stashed changes
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
    required String categoryTag,
  }) {
    final bool isHighlight = categoryTag == "Sự kiện" ||
        categoryTag == "Học bổng" ||
        categoryTag == "Tuyển dụng";

    final Color bgColor = isHighlight
        ? (isDarkMode
            ? const Color(0xFF1E3A8A).withOpacity(0.3)
            : const Color(0xFFE0F2FE))
        : (isDarkMode
            ? Colors.white.withOpacity(0.08)
            : const Color(0xFFF1F5F9));

    final Color textColor = isHighlight
        ? (isDarkMode ? const Color(0xFF93C5FD) : const Color(0xFF0369A1))
        : (isDarkMode ? Colors.white70 : const Color(0xFF475569));

    return GestureDetector(
      onTap: () {
        showSearch(
          context: context,
          delegate: MyUniSearchDelegate(
            currentScope: SearchScope.official,
            initialHashtag: categoryTag,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlight
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
              categoryTag,
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

<<<<<<< Updated upstream
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
=======
  /// Thanh chuyển đổi Sub-Tab (Toàn trường, Khoa của bạn, Các Khoa theo dõi + Nút Thêm)
  Widget _buildSubTabBar({
    required BuildContext context,
    required bool isDarkMode,
    required String? userFacultyStr,
    required FacultyInfo? primaryFacultyInfo,
    required List<String> followedFaculties,
  }) {
    final Color backgroundColor = isDarkMode
        ? const Color(0xFF101214)
        : const Color(0xFFF8FAFC);

    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFEAECF0);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: borderColor,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildSubTabChip(
              id: 'all',
              label: 'HCMUS',
              icon: Icons.school_rounded,
              isSelected: _selectedSubTabId == 'all',
              isDarkMode: isDarkMode,
              activeGradient: const [
                Color(0xFF5893D8),
                Color(0xFF5893D8),
              ],
              onTap: () {
                setState(() {
                  _selectedSubTabId = 'all';
                });
              },
            ),
            const SizedBox(width: 8),
            _buildSubTabChip(
              id: 'my_faculty',
              label: primaryFacultyInfo?.shortName ?? 'Chưa chọn',
              icon: primaryFacultyInfo?.icon ??
                  Icons.school_rounded,
              isSelected:
              _selectedSubTabId == 'my_faculty',
              isDarkMode: isDarkMode,
              activeGradient: const [
                Color(0xFF5893D8),
                Color(0xFF5893D8),
              ],
              badgeText:
              primaryFacultyInfo == null ? 'Chưa chọn' : null,
              onTap: () {
                setState(() {
                  _selectedSubTabId = 'my_faculty';
                });
              },
            ),
            ...followedFaculties.map((facId) {
              final facInfo =
              FacultyHelper.findById(facId);

              if (facInfo == null) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildSubTabChip(
                  id: facInfo.id,
                  label: facInfo.shortName,
                  icon: facInfo.icon,
                  isSelected:
                  _selectedSubTabId == facInfo.id,
                  isDarkMode: isDarkMode,
                  activeGradient: const [
                    Color(0xFF5893D8),
                    Color(0xFF5893D8),
                  ],
                  onTap: () {
                    setState(() {
                      _selectedSubTabId = facInfo.id;
                    });
                  },
                ),
              );
            }),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  _showManageFollowedFacultiesModal(
                    context,
                    primaryFacultyInfo,
                    followedFaculties,
                  );
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: borderColor,
                    ),
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
    required List<Color> activeGradient,
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
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor
                : inactiveBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : inactiveBorder,
            ),
            boxShadow: isSelected && !isDarkMode
                ? [
              BoxShadow(
                color: activeColor.withValues(
                  alpha: 0.16,
                ),
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
                color: isSelected
                    ? Colors.white
                    : inactiveTextColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 11.5,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : inactiveTextColor,
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

  /// Empty State khi User chưa chọn Khoa trong account
  Widget _buildEmptyFacultySetupCard(
      BuildContext context,
      bool isDarkMode,
      String? currentFaculty,
      ) {
    final Color cardColor = isDarkMode
        ? const Color(0xFF1C1E21)
        : Colors.white;

    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE4E7EC);

    final Color primaryTextColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1D2939);

    final Color secondaryTextColor = isDarkMode
        ? Colors.white60
        : const Color(0xFF667085);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 32,
        ),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            maxWidth: 420,
          ),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: isDarkMode
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF5893D8)
                      .withValues(alpha: 0.10),
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
                'Chọn khoa của bạn để nhận tin tức và thông báo chính thức phù hợp.',
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
                  onPressed: () {
                    _showQuickFacultyPicker(
                      context,
                      currentFaculty,
                    );
                  },
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                    const Color(0xFF5893D8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
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

  /// Thông báo khi Khoa của user chưa có kênh tin tự động (vd: Khoa Môi trường)
  Widget _buildFacultyNotActiveCard(
      BuildContext context,
      bool isDarkMode,
      String facultyName,
      ) {
    final Color cardColor = isDarkMode
        ? const Color(0xFF1C1E21)
        : Colors.white;

    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE4E7EC);

    final Color primaryTextColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1D2939);

    final Color secondaryTextColor = isDarkMode
        ? Colors.white60
        : const Color(0xFF667085);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 32,
        ),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            maxWidth: 420,
          ),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: isDarkMode
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF5893D8)
                      .withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 30,
                  color: Color(0xFF5893D8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                facultyName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Khoa này chưa có kênh tin tức riêng trên MyUni. Bạn vẫn có thể theo dõi tin từ các khoa khác.',
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
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showManageFollowedFacultiesModal(
                      context,
                      FacultyHelper
                          .findFacultyByAccountString(
                        facultyName,
                      ),
                      [],
                    );
                  },
                  icon: const Icon(
                    Icons.tune_rounded,
                    size: 18,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                    const Color(0xFF5893D8),
                    side: const BorderSide(
                      color: Color(0xFF5893D8),
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                  ),
                  label: const Text(
                    'Chọn khoa khác để theo dõi',
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 12.5,
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

  /// Single Card hiển thị 1 bài tin tức (dùng chung cho Toàn trường & Tin Khoa)
  Widget _buildNewsCard({
    required BuildContext context,
    required bool isDarkMode,
    required String docId,
    required Map<String, dynamic> data,
    required String collectionPath,
    required User? user,
  }) {
    final bool isEvent = OfficialContentHelper.isOfficialEvent(
      data['title'],
      data['summary'],
    );
    final String summary = data['summary']?.toString().trim() ?? '';
    final String uploadedImageUrl = _getNewsImageUrl(data);

    final String fallbackImagePath =
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

    final String departmentDisplay = data['department']?.toString() ??
        data['facultyName']?.toString() ??
        data['sourceName']?.toString() ??
        'HCMUS News';

    final String dateDisplay = data['publishedDateText']?.toString() ??
        data['date']?.toString() ??
        '';

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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white12
                                : const Color(0xFFF1F5F9),
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
>>>>>>> Stashed changes
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
                                categoryTag: OfficialContentHelper.getOfficialCategoryTag(
                                  data['title'],
                                  data['summary'],
                                  data['hashtags'],
                                ),
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
<<<<<<< Updated upstream
              ),
            );
          },
        )));
=======
                const SizedBox(height: 8),
                PostActionRow(
                  docId: docId,
                  data: data,
                  onSave: widget.onSave,
                  collectionPath: collectionPath,
                ),
                if ((data['link'] ?? data['sourceUrl'] ?? data['sourceArticleUrl'])?.toString().trim().isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () =>
                            _launchURL((data['link'] ?? data['sourceUrl'] ?? data['sourceArticleUrl'])?.toString() ?? ''),
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
  }

  /// Header Banner hiển thị cho 1 Khoa khi chọn xem tin Khoa
  Widget _buildFacultyHeaderBanner(
      FacultyInfo facultyInfo, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.3),
        ),
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
                Row(
                  children: [
                    Text(
                      facultyInfo.name,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDarkMode
                            ? Colors.white
                            : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Tin tức & thông báo mới nhất từ ${facultyInfo.shortName}',
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid ?? 'guest')
          .snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.hasData && userSnapshot.data!.exists
            ? userSnapshot.data!.data() as Map<String, dynamic>
            : <String, dynamic>{};

        final String? userFacultyStr = userData['faculty']?.toString();
        final List<String> rawFollowed =
            (userData['followedFaculties'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
                [];

        final FacultyInfo? primaryFacultyInfo =
        FacultyHelper.findFacultyByAccountString(userFacultyStr);

        // Loại bỏ Khoa chính khỏi danh sách Khoa theo dõi phụ để tránh trùng lặp tab
        final List<String> followedFaculties = rawFollowed
            .where((id) => id != primaryFacultyInfo?.id)
            .toList();

        // Nếu tab đang chọn trùng với ID Khoa chính vừa chuyển đổi, chuyển tab về 'my_faculty'
        if (primaryFacultyInfo != null && _selectedSubTabId == primaryFacultyInfo.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedSubTabId == primaryFacultyInfo.id) {
              setState(() {
                _selectedSubTabId = 'my_faculty';
              });
            }
          });
        }

        return Column(
          children: [
            // Thanh chuyển đổi sub-tab tin tức
            _buildSubTabBar(
              context: context,
              isDarkMode: isDarkMode,
              userFacultyStr: userFacultyStr,
              primaryFacultyInfo: primaryFacultyInfo,
              followedFaculties: followedFaculties,
            ),

            // Phần nội dung tin tức theo tab được chọn
            Expanded(
              child: _buildNewsBody(
                context: context,
                isDarkMode: isDarkMode,
                user: user,
                userFacultyStr: userFacultyStr,
                primaryFacultyInfo: primaryFacultyInfo,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNewsBody({
    required BuildContext context,
    required bool isDarkMode,
    required User? user,
    required String? userFacultyStr,
    required FacultyInfo? primaryFacultyInfo,
  }) {
    // CASE 1: Tab Toàn trường
    if (_selectedSubTabId == 'all') {
      return StreamBuilder<QuerySnapshot>(
        key: const ValueKey('subtab_stream_all'),
        stream: FirebaseFirestore.instance
            .collection('official_news')
            .orderBy('publishedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            _newsCache['all'] = snapshot.data!.docs.toList();
          }

          final cachedDocs = _newsCache['all'];

          if (!snapshot.hasData && cachedDocs == null) {
            return const PostCardSkeletonListView();
          }

          final docs = snapshot.hasData ? snapshot.data!.docs : (cachedDocs ?? []);

          if (docs.isEmpty) {
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
                key: const ValueKey('list_all_news'),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: docs.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return DailyDigestCard(
                      key: const ValueKey('daily_digest_card_all'),
                      isDarkMode: isDarkMode,
                    );
                  }

                  var doc = docs[index - 1];
                  var data = doc.data() as Map<String, dynamic>;
                  return KeyedSubtree(
                    key: ValueKey('official_news_${doc.id}'),
                    child: _buildNewsCard(
                      context: context,
                      isDarkMode: isDarkMode,
                      docId: doc.id,
                      data: data,
                      collectionPath: 'official_news',
                      user: user,
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    }

    // CASE 2: Tab Khoa của bạn
    if (_selectedSubTabId == 'my_faculty') {
      if (userFacultyStr == null ||
          userFacultyStr.trim().isEmpty ||
          userFacultyStr == 'Chưa cập nhật khoa') {
        return _buildEmptyFacultySetupCard(
            context, isDarkMode, userFacultyStr);
      }

      if (primaryFacultyInfo == null) {
        return _buildFacultyNotActiveCard(context, isDarkMode, userFacultyStr);
      }

      return _buildFacultyNewsStream(
        context: context,
        isDarkMode: isDarkMode,
        user: user,
        targetFacultyInfo: primaryFacultyInfo,
      );
    }

    // CASE 3: Tab Khoa được chọn từ danh sách theo dõi
    final FacultyInfo? targetFacultyInfo =
    FacultyHelper.findById(_selectedSubTabId);

    if (targetFacultyInfo != null) {
      return _buildFacultyNewsStream(
        context: context,
        isDarkMode: isDarkMode,
        user: user,
        targetFacultyInfo: targetFacultyInfo,
      );
    }

    return const Center(child: Text('Không tìm thấy dữ liệu'));
  }

  /// Stream dữ liệu từ `faculty_official_news` theo targetFacultyInfo
  Widget _buildFacultyNewsStream({
    required BuildContext context,
    required bool isDarkMode,
    required User? user,
    required FacultyInfo targetFacultyInfo,
  }) {
    final String subtabKey = targetFacultyInfo.id;

    return StreamBuilder<QuerySnapshot>(
      key: ValueKey('subtab_stream_faculty_$subtabKey'),
      stream: FirebaseFirestore.instance
          .collection('faculty_official_news')
          .where('facultyId', isEqualTo: targetFacultyInfo.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          _newsCache[subtabKey] = snapshot.data!.docs.toList();
        }

        final cachedDocs = _newsCache[subtabKey];

        if (!snapshot.hasData && cachedDocs == null) {
          return const PostCardSkeletonListView();
        }

        List<QueryDocumentSnapshot> docs = snapshot.hasData
            ? snapshot.data!.docs.toList()
            : (cachedDocs ?? []);

        // Sort theo publishedAt/timestamp/createdAt giảm dần trong bộ nhớ
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          DateTime getDocDate(Map<String, dynamic> d) {
            if (d['publishedAt'] is Timestamp) {
              return (d['publishedAt'] as Timestamp).toDate();
            }
            if (d['timestamp'] is Timestamp) {
              return (d['timestamp'] as Timestamp).toDate();
            }
            if (d['createdAt'] is Timestamp) {
              return (d['createdAt'] as Timestamp).toDate();
            }
            return DateTime.fromMillisecondsSinceEpoch(0);
          }

          return getDocDate(bData).compareTo(getDocDate(aData));
        });

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600.0),
            child: ListView.builder(
              key: ValueKey('list_faculty_$subtabKey'),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: docs.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return FacultyDailyDigestCard(
                    key: ValueKey('faculty_digest_$subtabKey'),
                    isDarkMode: isDarkMode,
                    facultyInfo: targetFacultyInfo,
                  );
                }

                var doc = docs[index - 1];
                var data = doc.data() as Map<String, dynamic>;

                return KeyedSubtree(
                  key: ValueKey('faculty_news_${doc.id}'),
                  child: _buildNewsCard(
                    context: context,
                    isDarkMode: isDarkMode,
                    docId: doc.id,
                    data: data,
                    collectionPath: 'faculty_official_news',
                    user: user,
                  ),
                );
              },
            ),
          ),
        );
>>>>>>> Stashed changes
      },
    );
  }
}