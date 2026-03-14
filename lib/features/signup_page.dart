import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _isObscured = true;
  bool _isLoading = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedUniversity;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 1. Hàm kiểm tra email sinh viên
  bool _isValidStudentEmail(String email) {
    return email.toLowerCase().endsWith('.edu.vn');
  }

  // 2. Hàm gửi OTP qua EmailJS
  Future<void> _sendOTPEmail(String email, String otp) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'origin': 'http://localhost',
      },
      body: json.encode({
        'service_id': 'service_1oynodg',
        'template_id': 'template_3ftz8sr',
        'user_id': '0JWFYtrABC8w_Cfcp',
        'template_params': {
          'user_email': email,
          'otp_code': otp,
          'from_name': 'Đội ngũ phát triển MyUni',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Lỗi gửi email: ${response.body}');
    }
  }

  // 3. Hàm xử lý logic chính
  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();

    // Kiểm tra trống
    if (email.isEmpty || _passwordController.text.isEmpty || _selectedUniversity == null) {
      _showSnackBar('Vui lòng điền đầy đủ thông tin');
      return;
    }

    // Kiểm tra đuôi .edu.vn
    if (!_isValidStudentEmail(email)) {
      _showSnackBar('Chỉ chấp nhận email sinh viên (@...edu.vn)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Tạo mã OTP 6 số ngẫu nhiên
      String otpCode = (Random().nextInt(900000) + 100000).toString();

      // Gửi OTP
      await _sendOTPEmail(email, otpCode);

      // Chuyển sang trang OTP và truyền dữ liệu đi
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/otp',
          arguments: {
            'email': email,
            'otpCode': otpCode,
            'userData': {
              'firstName': _firstNameController.text.trim(),
              'lastName': _lastNameController.text.trim(),
              'password': _passwordController.text.trim(),
              'university': _selectedUniversity,
            }
          },
        );
      }
    } catch (e) {
      _showSnackBar('Không thể gửi OTP. Vui lòng thử lại.');
      print(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Đăng ký',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: 'Tên',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: 'Họ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email sinh viên (@...edu.vn)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _isObscured,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                suffixIcon: IconButton(
                  icon: Icon(_isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _isObscured = !_isObscured),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedUniversity,
              decoration: InputDecoration(
                labelText: 'Trường đại học',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: ['VNU - HCMUS (CS1)', 'VNU - HCMUS (CS2)'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (val) => setState(() => _selectedUniversity = val),
              hint: const Text('Chọn trường của bạn'),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSignUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6797E1),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Gửi mã xác nhận', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}