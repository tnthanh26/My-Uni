import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _otpInputController = TextEditingController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _otpInputController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndSignUp(Map<String, dynamic> args) async {
    final String userEnteredOtp = _otpInputController.text.trim();
    final String correctOtp = args['otpCode'];
    final String email = args['email'];
    final Map<String, dynamic> userData = args['userData'];

    if (userEnteredOtp != correctOtp) {
      _showSnackBar('Mã OTP không chính xác. Vui lòng thử lại.', isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // Tạo tài khoản Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: userData['password'],
      );

      // Lưu thông tin vào Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'displayName': "${userData['firstName']} ${userData['lastName']}",
        'firstName': userData['firstName'],
        'lastName': userData['lastName'],
        'email': email,
        'university': userData['university'],

        // field chưa có thì để rỗng/null để EditProfilePage cập nhật sau
        'faculty': null,
        'phone': '',
        'dob': '',
        'photoUrl': '',

        // field hệ thống
        'status': 'active',
        'isBanned': false,
        'role': 'student',
        'isVerified': true,
        'verificationMethod': 'edu_email_otp',
        'verifiedAt': FieldValue.serverTimestamp(),
        'verificationLevel': 'student',
        'violationCount': 0,
        'suspensionCount': 0,
        'lastBanReason': '',
        'lastViolationAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Lỗi đăng ký', isError: true);
    } catch (e) {
      _showSnackBar('Đã có lỗi xảy ra: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kiểm tra chế độ tối
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Lấy dữ liệu an toàn
    final dynamic rawArgs = ModalRoute.of(context)?.settings.arguments;
    if (rawArgs == null || rawArgs is! Map<String, dynamic>) {
      return const Scaffold(body: Center(child: Text("Lỗi dữ liệu đầu vào")));
    }
    final Map<String, dynamic> args = rawArgs;
    final String email = args['email'] ?? "Email không xác định";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: isDarkMode ? Colors.white : Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Icon minh họa với nền nhẹ
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF6797E1).withOpacity(isDarkMode ? 0.15 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  size: 100,
                  color: Color(0xFF6797E1),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Xác thực OTP',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'Mã OTP đã được gửi đến:\n'),
                  TextSpan(
                    text: email,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6797E1)
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),

            Text(
                'NHẬP MÃ 6 CHỮ SỐ',
                style: TextStyle(
                  color: isDarkMode ? Colors.white38 : Colors.grey,
                  letterSpacing: 2,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                )
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _otpInputController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 15,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(color: isDarkMode ? Colors.white10 : Colors.grey[200]),
                counterText: "", // Ẩn bộ đếm chữ số
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey[300]!),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF6797E1), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 50),

            ElevatedButton(
              onPressed: _isVerifying ? null : () => _verifyAndSignUp(args),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6797E1),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: isDarkMode ? 0 : 4,
              ),
              child: _isVerifying
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text(
                  'Xác nhận & Đăng ký',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ),

            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                  'Quay lại sửa email',
                  style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.grey[600])
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}