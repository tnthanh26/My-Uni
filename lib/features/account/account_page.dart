import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';
import 'utilities_page.dart';
import 'setting_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Kiểm tra xem đang ở chế độ tối hay không
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Tự động đổi màu nền theo Theme (Trắng hoặc Đen xám)
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
            'Tài khoản',
            style: TextStyle(
              // Tự động đổi màu chữ tiêu đề theo Theme
                color: Theme.of(context).textTheme.titleLarge?.color,
                fontWeight: FontWeight.bold
            )
        ),
        backgroundColor: Colors.transparent, // Để lộ màu nền của Scaffold
        elevation: 0,
        centerTitle: true,
        // Đổi màu icon back (nếu có)
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
              name = data['displayName'] ?? "Thanh";
              faculty = data['faculty'] ?? "Công nghệ thông tin";
              photoBase64 = data['photoUrl'];
              isVerified = data['isVerified'] ?? true;
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
                          backgroundImage: photoBase64 != null
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
                              // Màu xám nhạt hơn trong Dark Mode để dễ đọc
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

                  // Các Item - Tự động thích ứng màu
                  _buildAccountItem(context, Icons.key_outlined, 'Đổi mật khẩu', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordPage()));
                  }),
                  Divider(indent: 70, color: Theme.of(context).dividerColor),
                  _buildAccountItem(context, Icons.grid_view_outlined, 'Tiện ích', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const UtilitiesPage()),);
                  }),
                  Divider(indent: 70, color: Theme.of(context).dividerColor),
                  _buildAccountItem(context, Icons.article_outlined, 'Bài đăng của tôi', () {}),
                  Divider(indent: 70, color: Theme.of(context).dividerColor),
                  _buildAccountItem(context, Icons.rate_review_outlined, 'Đánh giá của tôi', () {}),
                  Divider(indent: 70, color: Theme.of(context).dividerColor),
                  _buildAccountItem(context, Icons.bookmark_outline, 'Bài đã lưu', () {}),
                  Divider(indent: 70, color: Theme.of(context).dividerColor),
                  _buildAccountItem(context, Icons.settings_outlined, 'Cài đặt', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                  }),

                  const SizedBox(height: 50),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pushReplacementNamed(context, '/login');
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

  // Widget dùng chung đã được sửa màu để chạy tốt trong Dark Mode
  Widget _buildAccountItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          // Nền icon xám nhạt ở Light và xám trắng mờ ở Dark
            color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            shape: BoxShape.circle
        ),
        child: Icon(
            icon,
            // Icon tự động chuyển sang trắng mờ trong Dark Mode
            color: isDarkMode ? Colors.white70 : Colors.black87,
            size: 22
        ),
      ),
      title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
        // Mặc định Text sẽ tự lấy màu theo Theme nếu không set màu cứng
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