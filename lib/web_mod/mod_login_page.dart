import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ModLoginPage extends StatelessWidget {
  const ModLoginPage({super.key});

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.setCustomParameters({'prompt': 'select_account'});

      // 1. Thực hiện đăng nhập
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithPopup(googleProvider);

      final User? user = userCredential.user;

      if (user != null) {
        final String? email = user.email;

        const allowedAdmins = [
          'nhatthanhtran2606@gmail.com',
          'huynhhuuhau01@gmail.com',
        ];

        const allowedCollaborators = ['trannhatthanha2@gmail.com'];

        if (allowedAdmins.contains(email)) {
          if (context.mounted) {
            context.go('/mod');
          }
        } else if (allowedCollaborators.contains(email)) {
          if (context.mounted) {
            context.go('/collaborator');
          }
        } else {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Tài khoản không có quyền truy cập!"),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Lỗi đăng nhập: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F37),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          width: 400, // Cố định chiều rộng để giống hình bạn gửi
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sử dụng đúng Icon từ hình ảnh
              const Icon(
                Icons.shield_outlined,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                "MYUNI MANAGEMENT PORTAL",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Vui lòng đăng nhập để tiếp tục",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              OutlinedButton.icon(
                onPressed: () => _handleGoogleSignIn(context),
                icon: Image.network(
                  'https://cdn-teams-slug.flaticon.com/google.jpg',
                  width: 18,
                ),
                label: const Text("Đăng nhập bằng Google"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
