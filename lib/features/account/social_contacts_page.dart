import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';
import '../chat/services/chat_service.dart';

class SocialContactsPage extends StatefulWidget {
  const SocialContactsPage({super.key});

  @override
  State<SocialContactsPage> createState() => _SocialContactsPageState();
}

class _SocialContactsPageState extends State<SocialContactsPage> {
  final ChatService _chatService = ChatService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _zaloController = TextEditingController();
  final TextEditingController _discordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingContacts();
  }

  Future<void> _loadExistingContacts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final contacts = await _chatService.getUserSocialContacts(uid);
      if (mounted) {
        setState(() {
          _facebookController.text = contacts['facebook'] ?? '';
          _zaloController.text = contacts['zalo'] ?? '';
          _discordController.text = contacts['discord'] ?? '';
          _phoneController.text = contacts['phone'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _facebookController.dispose();
    _zaloController.dispose();
    _discordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveContacts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final updatedContacts = {
        'facebook': _facebookController.text.trim(),
        'zalo': _zaloController.text.trim(),
        'discord': _discordController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      await _chatService.saveUserSocialContacts(uid, updatedContacts);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật thông tin liên hệ thành công!'),
            backgroundColor: AppColors.hcmusTeal,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu thông tin: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thông tin liên hệ',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card giải thích
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.hcmusTeal.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.hcmusTeal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.contact_phone_rounded,
                            color: AppColors.hcmusTeal,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Chuẩn bị sẵn thông tin liên hệ để có thể nhanh chóng chia sẻ với bạn học khác nhe.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 1. Facebook
                    _buildContactInput(
                      context,
                      label: 'Facebook',
                      hint: 'Ví dụ: facebook.com/tenban hoặc Username',
                      icon: Icons.facebook,
                      iconColor: const Color(0xFF1877F2),
                      controller: _facebookController,
                    ),
                    const SizedBox(height: 18),

                    // 2. Zalo
                    _buildContactInput(
                      context,
                      label: 'Zalo',
                      hint: 'Số điện thoại Zalo hoặc Zalo ID',
                      icon: Icons.chat_rounded,
                      iconColor: const Color(0xFF0068FF),
                      controller: _zaloController,
                    ),
                    const SizedBox(height: 18),

                    // 3. Discord
                    _buildContactInput(
                      context,
                      label: 'Discord',
                      hint: 'Ví dụ: username#1234 hoặc discord.gg/...',
                      icon: Icons.headset_mic_rounded,
                      iconColor: const Color(0xFF5865F2),
                      controller: _discordController,
                    ),
                    const SizedBox(height: 18),

                    // 4. SĐT
                    _buildContactInput(
                      context,
                      label: 'Số điện thoại',
                      hint: 'Ví dụ: 0901234567',
                      icon: Icons.phone_rounded,
                      iconColor: const Color(0xFF34A853),
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 32),

                    // Nút Lưu
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.hcmusTeal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(
                          _isSaving ? 'Đang lưu...' : 'Lưu thông tin',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveContacts,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildContactInput(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.grey.shade500,
              fontSize: 13.5,
            ),
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.hcmusTeal,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
