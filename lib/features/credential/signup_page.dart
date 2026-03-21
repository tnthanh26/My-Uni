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

  bool _isValidStudentEmail(String email) {
    return email.toLowerCase().endsWith('.edu.vn');
  }

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

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || _passwordController.text.isEmpty || _selectedUniversity == null) {
      _showSnackBar('Vui lòng điền đầy đủ thông tin', isError: true);
      return;
    }

    if (!_isValidStudentEmail(email)) {
      _showSnackBar('Chỉ chấp nhận email sinh viên (@...edu.vn)', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String otpCode = (Random().nextInt(900000) + 100000).toString();
      await _sendOTPEmail(email, otpCode);

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
      _showSnackBar('Không thể gửi OTP. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDarkMode ? Colors.white : Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Text(
              'Đăng ký tài khoản',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Tham gia cộng đồng sinh viên MyUni ngay hôm nay',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white60 : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Các trường nhập liệu sử dụng Widget dùng chung
            _buildInputContainer(
              isDarkMode: isDarkMode,
              child: TextFormField(
                controller: _firstNameController,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: _inputDecoration('Tên', Icons.person_outline, isDarkMode),
              ),
            ),
            const SizedBox(height: 16),

            _buildInputContainer(
              isDarkMode: isDarkMode,
              child: TextFormField(
                controller: _lastNameController,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: _inputDecoration('Họ', Icons.people_outline, isDarkMode),
              ),
            ),
            const SizedBox(height: 16),

            _buildInputContainer(
              isDarkMode: isDarkMode,
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: _inputDecoration('Email sinh viên (.edu.vn)', Icons.email_outlined, isDarkMode),
              ),
            ),
            const SizedBox(height: 16),

            _buildInputContainer(
              isDarkMode: isDarkMode,
              child: TextFormField(
                controller: _passwordController,
                obscureText: _isObscured,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: _inputDecoration(
                  'Mật khẩu',
                  Icons.lock_outline,
                  isDarkMode,
                  suffix: IconButton(
                    icon: Icon(
                      _isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: isDarkMode ? Colors.white60 : Colors.grey,
                    ),
                    onPressed: () => setState(() => _isObscured = !_isObscured),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildInputContainer(
              isDarkMode: isDarkMode,
              child: DropdownButtonFormField<String>(
                value: _selectedUniversity,
                dropdownColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                decoration: _inputDecoration('Trường đại học', Icons.school_outlined, isDarkMode),
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16),
                items: ['VNU - HCMUS (CS1)', 'VNU - HCMUS (CS2)'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedUniversity = val),
              ),
            ),

            const SizedBox(height: 50),

            ElevatedButton(
              onPressed: _isLoading ? null : _handleSignUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6797E1),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: isDarkMode ? 0 : 4,
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text('Gửi mã xác nhận', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Widget bọc ngoài để tạo shadow và bo góc đồng nhất
  Widget _buildInputContainer({required Widget child, required bool isDarkMode}) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: isDarkMode ? Border.all(color: Colors.white10) : null,
      ),
      child: child,
    );
  }

  // Tùy chỉnh InputDecoration để sạch sẽ và hiện đại
  InputDecoration _inputDecoration(String label, IconData icon, bool isDarkMode, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.grey[600], fontSize: 14),
      prefixIcon: Icon(icon, color: isDarkMode ? Colors.white60 : Colors.grey),
      suffixIcon: suffix,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    );
  }
}