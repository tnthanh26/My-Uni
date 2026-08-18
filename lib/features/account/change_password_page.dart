import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isObscureCurrent = true;
  bool _isObscureNew = true;
  bool _isObscureConfirm = true;
  bool _isLoading = false;

  bool get _isNewPasswordSameAsCurrent =>
      _currentPasswordController.text.isNotEmpty &&
      _newPasswordController.text.isNotEmpty &&
      _currentPasswordController.text.trim() ==
          _newPasswordController.text.trim();

  bool get _isConfirmPasswordInvalid =>
      _newPasswordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty &&
      _confirmPasswordController.text.trim() !=
          _newPasswordController.text.trim();

  @override
  void initState() {
    super.initState();
    _currentPasswordController.addListener(_onPasswordChanged);
    _newPasswordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _currentPasswordController.removeListener(_onPasswordChanged);
    _newPasswordController.removeListener(_onPasswordChanged);
    _confirmPasswordController.removeListener(_onPasswordChanged);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      _showSnackBar(
        'Không tìm thấy thông tin đăng nhập. Vui lòng thử lại.',
        isError: true,
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text.trim(),
      );

      // Thêm timeout 10 giây để tránh việc xoay quá lâu nếu mạng chậm hoặc Firebase treo
      await user
          .reauthenticateWithCredential(credential)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw FirebaseAuthException(
              code: 'timeout',
              message: 'Hết thời gian yêu cầu. Vui lòng kiểm tra lại mạng.',
            ),
          );
      await user.updatePassword(_newPasswordController.text.trim());

      if (mounted) {
        _showSnackBar(
          'Cập nhật mật khẩu thành công! Vui lòng đăng nhập lại.',
          isError: false,
        );

        // Đăng xuất để đảm bảo an toàn
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          // Điều hướng về trang login và xóa toàn bộ stack cũ
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      String message = 'Đã xảy ra lỗi không xác định';
      debugPrint("Firebase Auth Error: ${e.code}");

      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Mật khẩu hiện tại không chính xác.';
        _currentPasswordController.clear();
      } else if (e.code == 'weak-password') {
        message = 'Mật khẩu mới quá yếu. Vui lòng chọn mật khẩu mạnh hơn.';
      } else if (e.code == 'too-many-requests') {
        message = 'Thao tác quá nhanh. Vui lòng thử lại sau ít phút.';
      } else if (e.code == 'requires-recent-login') {
        message = 'Vui lòng đăng nhập lại trước khi đổi mật khẩu.';
      } else {
        message = 'Lỗi: ${e.message}';
      }

      _showSnackBar(message, isError: true);
      return; // Dừng lại ở đây, không để chạy xuống finally nữa để chắc chắn
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showSnackBar('Lỗi hệ thống: $e', isError: true);
      return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kiểm tra chế độ tối
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Tự động đổi màu nền trắng/đen xám
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                'Đặt mật khẩu mới',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? Colors.white
                      : Colors.black, // Chữ trắng khi tối
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Tạo mật khẩu mới. Vui lòng đảm bảo mật khẩu này khác với mật khẩu trước để tăng cường bảo mật.',
                style: TextStyle(
                  fontSize: 15,
                  color: isDarkMode
                      ? Colors.white70
                      : Colors.black54, // Chữ mờ hơn khi tối
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              _buildPasswordField(
                context: context,
                controller: _currentPasswordController,
                hint: 'Nhập mật khẩu hiện tại',
                obscure: _isObscureCurrent,
                onToggle: () =>
                    setState(() => _isObscureCurrent = !_isObscureCurrent),
              ),
              const SizedBox(height: 20),

              _buildPasswordField(
                context: context,
                controller: _newPasswordController,
                hint: 'Nhập mật khẩu mới',
                obscure: _isObscureNew,
                onToggle: () => setState(() => _isObscureNew = !_isObscureNew),
                hasError: _isNewPasswordSameAsCurrent,
                errorText: _isNewPasswordSameAsCurrent
                    ? 'Mật khẩu mới không được trùng với mật khẩu hiện tại'
                    : null,
                validator: (val) {
                  if (val == null || val.isEmpty)
                    return 'Vui lòng không để trống';
                  if (val.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
                  if (val.trim() == _currentPasswordController.text.trim()) {
                    return 'Mật khẩu mới không được trùng với mật khẩu hiện tại';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildPasswordField(
                context: context,
                controller: _confirmPasswordController,
                hint: 'Nhập lại mật khẩu mới',
                obscure: _isObscureConfirm,
                onToggle: () =>
                    setState(() => _isObscureConfirm = !_isObscureConfirm),
                hasError: _isConfirmPasswordInvalid,
                errorText: _isConfirmPasswordInvalid
                    ? 'Mật khẩu nhập lại không khớp'
                    : null,
                validator: (val) {
                  if (val == null || val.isEmpty)
                    return 'Vui lòng xác nhận mật khẩu';
                  if (val.trim() != _newPasswordController.text.trim()) {
                    return 'Mật khẩu nhập lại không khớp';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 50),

              Center(
                child: ElevatedButton(
                  onPressed:
                      (_isLoading ||
                          _isNewPasswordSameAsCurrent ||
                          _isConfirmPasswordInvalid)
                      ? null
                      : _updatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6797E1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: isDarkMode
                        ? 0
                        : 4, // Tắt elevation khi tối để nhìn phẳng hơn
                    shadowColor: const Color(0xFF6797E1).withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Cập nhật mật khẩu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    bool hasError = false,
    String? errorText,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FormField<String>(
      initialValue: controller.text,
      validator:
          validator ??
          (val) {
            if (val == null || val.isEmpty) return 'Vui lòng không để trống';
            if (val.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
            return null;
          },
      builder: (FormFieldState<String> state) {
        final displayError = errorText ?? state.errorText;
        final fieldHasError = hasError || state.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                // Ô nhập liệu màu xám trắng mờ khi ở Dark Mode
                color: isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    // Bóng đổ nhẹ hơn ở Dark Mode để không bị thô
                    color: isDarkMode
                        ? Colors.black26
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                // Thêm viền khi có lỗi, hoặc viền mờ khi ở Dark Mode giúp ô nổi bật hơn
                border: Border.all(
                  color: fieldHasError
                      ? Colors.redAccent
                      : (isDarkMode ? Colors.white10 : Colors.transparent),
                  width: 1.2,
                ),
              ),
              child: TextField(
                controller: controller,
                obscureText: obscure,
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode
                      ? Colors.white
                      : Colors.black, // Chữ nhập vào
                ),
                onChanged: (val) {
                  state.didChange(val);
                },
                decoration: InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white38 : Colors.black26,
                    fontSize: 15,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 18,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFF6797E1),
                        size: 22,
                      ),
                      onPressed: onToggle,
                    ),
                  ),
                ),
              ),
            ),
            if (displayError != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  displayError,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
