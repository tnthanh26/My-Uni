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

  Future<void> _verifyAndSignUp(Map<String, dynamic> args) async {
    final String userEnteredOtp = _otpInputController.text.trim();
    final String correctOtp = args['otpCode'];
    final String email = args['email'];
    final Map<String, dynamic> userData = args['userData'];

    // 1. Kiểm tra mã OTP
    if (userEnteredOtp != correctOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã OTP không chính xác. Vui lòng thử lại.')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // 2. Mã đúng -> Thực sự tạo tài khoản trên Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: userData['password'],
      );

      // 3. Lưu thông tin bổ sung vào Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'firstName': userData['firstName'],
        'lastName': userData['lastName'],
        'email': email,
        'university': userData['university'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Thành công -> Chuyển vào Home
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Lỗi đăng ký')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã có lỗi xảy ra: $e')),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lấy dữ liệu truyền từ trang SignUp sang
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String email = args['email'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Image.asset(
                'assets/images/otp_icon.png',
                height: 150,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.mark_email_read, size: 100, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Xác thực OTP',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Mã OTP đã được gửi đến:\n$email',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 40),

            // Ô nhập mã OTP
            const Text('Nhập mã 6 chữ số', style: TextStyle(color: Colors.grey)),
            TextField(
              controller: _otpInputController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '000000',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _isVerifying ? null : () => _verifyAndSignUp(args),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6797E1),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isVerifying
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Xác nhận & Đăng ký', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Quay lại sửa email', style: TextStyle(color: Colors.grey)),
            )
          ],
        ),
      ),
    );
  }
}