import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class UtilitiesPage extends StatelessWidget {
  const UtilitiesPage({super.key});

  Future<void> _launchURL(BuildContext context, String urlString) async {
    if (urlString.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liên kết không hợp lệ')),
      );
      return;
    }

    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mở liên kết: $e')),
      );
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'website':
        return Icons.language_rounded;
      case 'moodle':
        return Icons.edit_note_rounded;
      case 'portal':
        return Icons.dashboard_outlined;
      case 'drl':
        return Icons.fact_check_outlined;
      case 'fees':
        return Icons.account_balance_wallet_outlined;
      case 'handbook':
        return Icons.menu_book_outlined;
      default:
        return Icons.link_rounded;
    }
  }

  String _getSubtitle(String iconName, String title) {
    switch (iconName.toLowerCase()) {
      case 'website':
        return 'Trang chính thức';
      case 'moodle':
        return 'Học tập trực tuyến';
      case 'portal':
        return 'Cổng thông tin';
      case 'drl':
        return 'Điểm rèn luyện';
      case 'fees':
        return 'Học phí & thanh toán';
      case 'handbook':
        return 'Sổ tay sinh viên';
      default:
        return title;
    }
  }

  Widget _buildTopIntro(bool isDarkMode) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
        ),
        boxShadow: isDarkMode
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF6797E1).withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              color: Color(0xFF6797E1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Truy cập nhanh các hệ thống cần thiết cho sinh viên chỉ với một chạm.',
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: isDarkMode ? Colors.white70 : const Color(0xFF344054),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityCard({
    required BuildContext context,
    required bool isDarkMode,
    required String title,
    required String url,
    required String iconName,
  }) {
    final IconData iconData = _getIconData(iconName);
    final String subtitle = _getSubtitle(iconName, title);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchURL(context, url),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white10
                  : const Color(0xFFE9EEF3),
            ),
            boxShadow: isDarkMode
                ? []
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6797E1).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    iconData,
                    size: 28,
                    color: const Color(0xFF6797E1),
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 12,
                    height: 1.4,
                    color: isDarkMode
                        ? Colors.white54
                        : const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Mở ngay',
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6797E1),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Color(0xFF6797E1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.extension_off_outlined,
              size: 70,
              color: isDarkMode ? Colors.white38 : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 18),
            Text(
              'Hiện chưa có tiện ích nào được thiết lập.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : const Color(0xFF475467),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Center(
      child: Text(
        'Đã có lỗi xảy ra',
        style: TextStyle(
          fontFamily: 'Encode Sans Expanded',
          color: isDarkMode ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDarkMode ? const Color(0xFF0F1113) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Tiện ích sinh viên',
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDarkMode ? Colors.white : const Color(0xFF545454),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF111315) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : const Color(0xFF545454),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('utilities')
                  .orderBy('index', descending: false)
                  .snapshots(includeMetadataChanges: true),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(isDarkMode);
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6797E1),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _buildEmptyState(isDarkMode);
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String title = data['title'] ?? 'N/A';
                    final String url = data['url'] ?? '';
                    final String iconName = data['iconName'] ?? '';

                    return _buildUtilityCard(
                      context: context,
                      isDarkMode: isDarkMode,
                      title: title,
                      url: url,
                      iconName: iconName,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}