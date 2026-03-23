import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class UtilitiesPage extends StatelessWidget {
  const UtilitiesPage({super.key});

  // Hàm hỗ trợ mở URL
  Future<void> _launchURL(BuildContext context, String urlString) async {
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

  // Hàm map icon từ chuỗi trong DB sang IconData
  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'website': return Icons.language;
      case 'moodle': return Icons.edit_note;
      case 'portal': return Icons.dashboard_outlined;
      case 'drl': return Icons.fact_check_outlined;
      case 'fees': return Icons.account_balance_wallet_outlined;
      case 'handbook': return Icons.menu_book_outlined;
      default: return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiện ích sinh viên',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('utilities').orderBy('index', descending: false).snapshots(includeMetadataChanges: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Đã có lỗi xảy ra'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text('Hiện chưa có tiện ích nào được thiết lập.'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String title = data['title'] ?? 'N/A';
              final String url = data['url'] ?? '';
              final String iconName = data['iconName'] ?? '';

              return InkWell(
                onTap: () => _launchURL(context, url),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    // Màu nền: Xanh đậm trong Light mode, Xám đậm trong Dark mode
                    color: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFF6797E1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDarkMode ? Colors.white10 : const Color(0xFF6797E1).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconData(iconName),
                        size: 40,
                        color: const Color(0xFF6797E1),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}