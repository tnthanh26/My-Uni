import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';
import 'utilities_page.dart';
import 'setting_page.dart';
import 'my_post_page.dart';
import 'my_review_page.dart';
import 'saved_posts_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  void _showLogoutDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
        isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          "Đăng xuất",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          "Bạn có chắc chắn muốn đăng xuất không?",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Hủy",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: const Text(
              "Đăng xuất",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Encode Sans Expanded',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({
    required bool isDarkMode,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
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
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Divider(
        height: 1,
        color: isDarkMode ? Colors.white10 : const Color(0xFFEAEFF5),
      ),
    );
  }

  Widget _buildAccountItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
        Color iconColor = const Color(0xFF6797E1),
      }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.95)
                        : Colors.black87,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDarkMode ? Colors.white24 : Colors.black26,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required BuildContext context,
    required bool isDarkMode,
    required String name,
    required String faculty,
    required String? photoBase64,
    required bool isVerified,
  }) {
    ImageProvider avatarProvider;

    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        avatarProvider = MemoryImage(base64Decode(photoBase64));
      } catch (_) {
        avatarProvider = const AssetImage('assets/images/cat_avatar.jpg');
      }
    } else {
      avatarProvider = const AssetImage('assets/images/cat_avatar.jpg');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
        ),
        boxShadow: isDarkMode
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor:
                isDarkMode ? Colors.white10 : const Color(0xFFF3F4F6),
                backgroundImage: avatarProvider,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfilePage(),
                      ),
                    );
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6797E1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            faculty,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 14,
              color: isDarkMode ? Colors.white60 : const Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6797E1).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF6797E1).withOpacity(0.25),
                    ),
                  ),
                  child: const Text(
                    'Đã xác thực ✅',
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      color: Color(0xFF6797E1),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  'Tài khoản MyUni',
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    color: isDarkMode
                        ? Colors.white70
                        : const Color(0xFF344054),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDarkMode ? const Color(0xFF0F1113) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Tài khoản',
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            color: isDarkMode ? Colors.white : const Color(0xFF545454),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF111315) : Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            String name = "Người dùng MyUni";
            String faculty = "Chưa cập nhật khoa";
            String? photoBase64;
            bool isVerified = false;

            if (snapshot.hasData && snapshot.data!.exists) {
              var data = snapshot.data!.data() as Map<String, dynamic>;
              name = data['displayName'] ?? "Người dùng";
              faculty = data['faculty'] ?? "Chưa cập nhật khoa";
              photoBase64 = data['photoUrl'];
              isVerified = data['isVerified'] ?? false;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(
                    context: context,
                    isDarkMode: isDarkMode,
                    name: name,
                    faculty: faculty,
                    photoBase64: photoBase64,
                    isVerified: isVerified,
                  ),
                  const SizedBox(height: 22),

                  _buildSectionTitle('Tài khoản', isDarkMode),
                  _buildSettingsGroup(
                    isDarkMode: isDarkMode,
                    children: [
                      _buildAccountItem(
                        context,
                        icon: Icons.key_outlined,
                        title: 'Đổi mật khẩu',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const ChangePasswordPage(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(isDarkMode),
                      _buildAccountItem(
                        context,
                        icon: Icons.settings_outlined,
                        title: 'Cài đặt',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _buildSectionTitle('Nội dung của bạn', isDarkMode),
                  _buildSettingsGroup(
                    isDarkMode: isDarkMode,
                    children: [
                      _buildAccountItem(
                        context,
                        icon: Icons.article_outlined,
                        title: 'Bài đăng của tôi',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MyPostsPage(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(isDarkMode),
                      _buildAccountItem(
                        context,
                        icon: Icons.rate_review_outlined,
                        title: 'Đánh giá của tôi',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MyReviewsPage(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(isDarkMode),
                      _buildAccountItem(
                        context,
                        icon: Icons.bookmark_outline_rounded,
                        title: 'Bài đã lưu',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SavedPostsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _buildSectionTitle('Khác', isDarkMode),
                  _buildSettingsGroup(
                    isDarkMode: isDarkMode,
                    children: [
                      _buildAccountItem(
                        context,
                        icon: Icons.grid_view_outlined,
                        title: 'Tiện ích',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UtilitiesPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE57373),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text(
                        'Đăng xuất',
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}