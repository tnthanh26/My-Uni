import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedUniversity;
  final _studentIdController = TextEditingController();
  final _cohortStartController = TextEditingController();
  final _cohortEndController = TextEditingController();

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _studentIdController.dispose();
    _cohortStartController.dispose();
    _cohortEndController.dispose();
    super.dispose();
  }

  bool _isValidStudentEmail(String email) {
    final trimmedEmail = email.trim().toLowerCase();
    final allowedEmails = [
      'nhatthanhtest2002@gmail.com',
      'testusermyuni@gmail.com',
    ];

    if (allowedEmails.contains(trimmedEmail)) {
      return true;
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.edu\.vn$',
    );

    return emailRegex.hasMatch(trimmedEmail);
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
    final password = _passwordController.text;
    final startYear = _cohortStartController.text.trim();
    final endYear = _cohortEndController.text.trim();

    if (
    _displayNameController.text.trim().isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        _selectedUniversity == null ||
        _studentIdController.text.trim().isEmpty ||
        startYear.isEmpty ||
        endYear.isEmpty
    ) {
      _showSnackBar('Vui lòng điền đầy đủ thông tin', isError: true);
      return;
    }

    if (startYear.length != 4 || endYear.length != 4) {
      _showSnackBar('Niên khóa không hợp lệ (mỗi năm phải đủ 4 chữ số)', isError: true);
      return;
    }

    final cohortString = '$startYear - $endYear';

    if (!_isValidStudentEmail(email)) {
      _showSnackBar('Chỉ chấp nhận email sinh viên (@...edu.vn)', isError: true);
      return;
    }

    if (password.length > 30) {
      _showSnackBar('Mật khẩu không được vượt quá 30 ký tự', isError: true);
      return;
    }

    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);

    if (!hasNumber && !hasSpecialChar) {
      _showSnackBar('Mật khẩu phải chứa ít nhất một số hoặc ký tự đặc biệt', isError: true);
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
              'displayName': _displayNameController.text.trim(),
              'password': password.trim(),
              'university': _selectedUniversity,
              'studentId': _studentIdController.text.trim(),
              'cohort': cohortString,
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

            _buildInputContainer(
              isDarkMode: isDarkMode,
              child: TextFormField(
                controller: _displayNameController,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: _inputDecoration(
                  'Họ và tên',
                  Icons.person_outline,
                  isDarkMode,
                ),
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
            const SizedBox(height: 16),

            _buildInputContainer(
              isDarkMode: isDarkMode,
              child: TextFormField(
                controller: _studentIdController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: _inputDecoration(
                  'Mã số sinh viên',
                  Icons.badge_outlined,
                  isDarkMode,
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildInputContainer(
              isDarkMode: isDarkMode,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.school_outlined, color: isDarkMode ? Colors.white60 : Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Niên khóa',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white60 : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 75,
                                child: TextFormField(
                                  controller: _cohortStartController,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  onChanged: (value) {
                                    if (value.length == 4) {
                                      FocusScope.of(context).nextFocus();
                                    }
                                  },
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: _cohortPartDecoration(context, 'yyyy'),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  '-',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white60 : Colors.grey[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 75,
                                child: TextFormField(
                                  controller: _cohortEndController,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: _cohortPartDecoration(context, 'yyyy'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

  InputDecoration _cohortPartDecoration(BuildContext context, String hint) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDarkMode ? Colors.white24 : Colors.black26,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: isDarkMode
          ? Colors.white.withOpacity(0.04)
          : Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 10,
      ),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF6797E1),
          width: 1.4,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      String label,
      IconData icon,
      bool isDarkMode, {
        Widget? suffix,
        String? hintText,
      }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDarkMode ? Colors.white38 : Colors.grey[500],
        fontSize: 14,
      ),
      labelStyle: TextStyle(
        color: isDarkMode ? Colors.white60 : Colors.grey[600],
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: isDarkMode ? Colors.white60 : Colors.grey),
      suffixIcon: suffix,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    );
  }
}