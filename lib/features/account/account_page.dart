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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
            'Tài khoản',
            style: TextStyle(
                color: Theme.of(context).textTheme.titleLarge?.color,
                fontWeight: FontWeight.bold
            )
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
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
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: isDarkMode ? Colors.white10 : Colors.grey[200],
                          backgroundImage: (photoBase64 != null && photoBase64.isNotEmpty)
                              ? MemoryImage(base64Decode(photoBase64))
                              : const AssetImage('assets/images/cat_avatar.jpg') as ImageProvider,
                        ),
                        const SizedBox(height: 15),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const EditProfilePage()),
                                );
                              },
                              child: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF6797E1)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Text(
                          faculty,
                          style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode ? Colors.white70 : Colors.black54
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (isVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6797E1).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Text(
                                'Đã xác thực ✅',
                                style: TextStyle(color: Color(0xFF6797E1), fontWeight: FontWeight.w500)
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  _buildAccountItem(context, Icons.key_outlined, 'Đổi mật khẩu', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordPage()));
                  }),
                  Divider(indent: 70, color: Theme.of(context).dividerColor),

                  _buildAccountItem(context, Icons.grid_view_outlined, 'Tiện ích', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const UtilitiesPage()),);
                  }),
                  Divider(indent: 70, color: Theme.of(context).dividerColor),

                  // CẬP NHẬT: BÀI ĐĂNG CỦA TÔI
                  _buildAccountItem(context, Icons.article_outlined, 'Bài đăng của tôi', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPostsPage()));
                  }),
                  Divider(indent: 70, color: Theme.of(context).dividerColor),

                  // CẬP NHẬT: ĐÁNH GIÁ CỦA TÔI
                  _buildAccountItem(context, Icons.rate_review_outlined, 'Đánh giá của tôi', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MyReviewsPage()));
                  }),
                  Divider(indent: 70, color: Theme.of(context).dividerColor),

                  _buildAccountItem(context, Icons.bookmark_outline, 'Bài đã lưu', () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SavedPostsPage())
                    );
                  }),
                  Divider(indent: 70, color: Theme.of(context).dividerColor),

                  _buildAccountItem(context, Icons.settings_outlined, 'Cài đặt', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                  }),

                  const SizedBox(height: 50),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton(
                      onPressed: () async {
                        _showLogoutDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE57373),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 0,
                      ),
                      child: const Text('Đăng xuất', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Hàm hiển thị Dialog xác nhận đăng xuất cho chuyên nghiệp
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Đăng xuất"),
        content: const Text("Bạn có chắc chắn muốn đăng xuất không?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: const Text("Đăng xuất", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            shape: BoxShape.circle
        ),
        child: Icon(
            icon,
            color: isDarkMode ? Colors.white70 : Colors.black87,
            size: 22
        ),
      ),
      title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
      ),
      trailing: Icon(
          Icons.chevron_right,
          color: isDarkMode ? Colors.white30 : Colors.grey,
          size: 20
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 2),
    );
  }
}