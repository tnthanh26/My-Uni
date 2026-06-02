import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetPassword() async {
    // 1. Validate form trước khi chạy logic
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() => _isLoading = true);

    try {
      // 2. Gửi yêu cầu reset pass trực tiếp qua Firebase Auth
      // Firebase sẽ xử lý việc gửi mail nếu email tồn tại
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        // 3. Thông báo khéo léo để người dùng tự kiểm tra lại email nếu nhập sai
        _showSnackBar(
          'Yêu cầu đã gửi đến: $email. Nếu không nhận được, hãy kiểm tra kỹ hộp thư hoặc thư rác.',
        );

        // Chờ người dùng kịp đọc email đã nhập trên SnackBar rồi mới quay về
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Đã xảy ra lỗi. Vui lòng thử lại.';

      if (e.code == 'too-many-requests') {
        errorMessage = 'Quá nhiều yêu cầu. Vui lòng thử lại sau ít phút.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Lỗi kết nối mạng. Vui lòng kiểm tra internet.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Địa chỉ email không hợp lệ.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Tài khoản này đã bị khóa.';
      }

      if (mounted) _showSnackBar(errorMessage, isError: true);
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi không xác định: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kiểm tra chế độ tối
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDarkMode ? Colors.white : Colors.black,
              size: 20
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Icon minh họa với nền màu nhẹ thích ứng
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6797E1).withOpacity(isDarkMode ? 0.15 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                      Icons.lock_reset_rounded,
                      size: 80,
                      color: Color(0xFF6797E1)
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Quên mật khẩu?',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  'Nhập email sinh viên để xác thực tài khoản. Chúng tôi sẽ gửi mã khôi phục qua email này.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      height: 1.5
                  ),
                ),
                const SizedBox(height: 40),

                // Trường nhập Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Email sinh viên',
                    labelStyle: TextStyle(
                        color: isDarkMode ? Colors.white60 : Colors.grey[600]
                    ),
                    hintText: 'user@student.edu.vn',
                    hintStyle: TextStyle(
                        color: isDarkMode ? Colors.white24 : Colors.black26
                    ),
                    prefixIcon: Icon(
                      Icons.mail_outline_rounded,
                      color: isDarkMode ? Colors.white60 : Colors.grey,
                    ),
                    filled: true,
                    // Màu nền ô nhập liệu đổi theo Mode
                    fillColor: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: isDarkMode
                          ? BorderSide(color: Colors.white.withOpacity(0.1))
                          : BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: isDarkMode
                          ? BorderSide(color: Colors.white.withOpacity(0.1))
                          : BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFF6797E1), width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập email';
                    }
                    final trimmedValue = value.trim().toLowerCase();
                    final allowedEmails = [
                      'nhatthanhtran2606@gmail.com',
                      'trannhatthanha2@gmail.com',
                    ];

                    if (allowedEmails.contains(trimmedValue)) {
                      return null;
                    }

                    final RegExp emailRegex = RegExp(
                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.edu\.vn$',
                    );

                    if (!emailRegex.hasMatch(trimmedValue)) {
                      return 'Vui lòng sử dụng email sinh viên (.edu.vn)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // Nút Gửi
                ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6797E1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: isDarkMode ? 0 : 2, // Phẳng hơn khi tối
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2
                    ),
                  )
                      : const Text(
                    'Gửi yêu cầu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}