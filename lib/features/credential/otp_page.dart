import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _otpInputController = TextEditingController();
  bool _isVerifying = false;
  int _secondsRemaining = 60;
  bool _canResend = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpInputController.dispose();
    super.dispose();
  }

  Future<void> _resendOtp(String email) async {
    if (!_canResend || _isVerifying) return;

    setState(() {
      _isVerifying = true;
    });

    try {
      final sendOtpUrl = Uri.parse('https://asia-southeast1-myuni-fe6d1.cloudfunctions.net/sendRegistrationOTP');
      final response = await http.post(
        sendOtpUrl,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
        },
        body: utf8.encode(json.encode({
          "data": {"email": email}
        })),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showSnackBar('Mã OTP mới đã được gửi lại vào email.');
        _startTimer();
      } else {
        _showSnackBar('Không thể gửi lại mã. Vui lòng thử lại sau.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Lỗi kết nối khi gửi lại mã: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _verifyAndSignUp(Map<String, dynamic> args) async {
    if (_isVerifying) return;

    final String userEnteredOtp = _otpInputController.text.trim();
    final String email = args['email'];
    final Map<String, dynamic> userData = args['userData'];

    if (userEnteredOtp.isEmpty) {
      _showSnackBar('Vui lòng nhập mã OTP.', isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // Gọi Cloud Function để xác thực OTP và tạo tài khoản
      final verifyUrl = Uri.parse('https://asia-southeast1-myuni-fe6d1.cloudfunctions.net/verifyOTPAndCreateUser');
      final response = await http.post(
        verifyUrl,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
        },
        body: json.encode({
          "data": {
            "email": email,
            "otp": userEnteredOtp,
            "userData": userData,
          }
        }),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        final result = responseData['result'];
        if (result != null && result['success'] == true) {
          final String customToken = result['customToken'];
          
          // Đăng nhập bằng Custom Token nhận được từ server
          UserCredential userCredential = await FirebaseAuth.instance.signInWithCustomToken(customToken);

          // Cập nhật trạng thái chờ duyệt xác thực bởi Mod cho sinh viên mới
          try {
            final uid = userCredential.user!.uid;
            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'isVerified': false,
              'verificationStatus': 'pending',
              'verificationSubmittedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('show_onboarding_$uid', true);
            await prefs.setInt('login_timestamp', DateTime.now().millisecondsSinceEpoch);
          } catch (e) {
            debugPrint("Error saving onboarding or verification data: $e");
          }

          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          }
        } else {
          _showSnackBar('Không thể tạo tài khoản. Vui lòng thử lại.', isError: true);
        }
      } else {
        String errorMessage = "Mã OTP không chính xác hoặc đã hết hạn.";
        if (responseData is Map && responseData['error'] != null) {
          final error = responseData['error'];
          if (error['message'] != null) {
            errorMessage = error['message'];
          }
        }
        _showSnackBar(errorMessage, isError: true);
      }
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

    return PopScope(
      canPop: !_isVerifying,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _isVerifying
              ? const SizedBox()
              : BackButton(color: isDarkMode ? Colors.white : Colors.black),
        ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500.0),
          child: SingleChildScrollView(
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

            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Chưa nhận được mã? ",
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
                TextButton(
                  onPressed: _canResend && !_isVerifying ? () => _resendOtp(email) : null,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _canResend ? "Gửi lại mã" : "Gửi lại mã (${_secondsRemaining}s)",
                    style: TextStyle(
                      color: _canResend && !_isVerifying
                          ? const Color(0xFF6797E1)
                          : (isDarkMode ? Colors.white30 : Colors.grey),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _isVerifying ? null : () => Navigator.pop(context),
              child: Text(
                  'Quay lại sửa email',
                  style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.grey[600])
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ))));
  }
}