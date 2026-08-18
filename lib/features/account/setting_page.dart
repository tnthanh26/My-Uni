import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_uni/app_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _showThemeDialog(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Text(
                'Chế độ tối',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Encode Sans Expanded',
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              _buildThemeOption(
                context: context,
                icon: Icons.light_mode_outlined,
                title: 'Sáng',
                selected: appProvider.themeMode == ThemeMode.light,
                onTap: () {
                  appProvider.setTheme(ThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
              _buildThemeOption(
                context: context,
                icon: Icons.dark_mode_outlined,
                title: 'Tối',
                selected: appProvider.themeMode == ThemeMode.dark,
                onTap: () {
                  appProvider.setTheme(ThemeMode.dark);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
              _buildThemeOption(
                context: context,
                icon: Icons.settings_brightness_outlined,
                title: 'Theo cài đặt hệ thống',
                selected: appProvider.themeMode == ThemeMode.system,
                onTap: () {
                  appProvider.setTheme(ThemeMode.system);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Xác nhận xóa tài khoản',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Tài khoản của bạn sẽ không bị xóa ngay lập tức mà sẽ ẩn khỏi hệ thống. '
          'Sau 3 ngày, tài khoản cùng toàn bộ dữ liệu liên quan sẽ bị xóa vĩnh viễn và không thể khôi phục.\n\n'
          'Bạn có chắc chắn muốn tiếp tục yêu cầu xóa tài khoản?',
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black54,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Xác nhận xóa',
              style: TextStyle(
                color: Color(0xFFFF6C6C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      _requestAccountDeletion(context);
    }
  }

  Future<void> _requestAccountDeletion(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final scheduledDate = DateTime.now().add(const Duration(days: 3));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'status': 'deleting',
            'scheduledDeleteAt': Timestamp.fromDate(scheduledDate),
          });

      if (!mounted) return;
      Navigator.pop(context); // Tắt loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Đã gửi yêu cầu xóa tài khoản! Tài khoản sẽ được xóa hoàn toàn sau 3 ngày.",
          ),
        ),
      );

      Navigator.pop(context); // Quay về trang trước
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Tắt loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi yêu cầu xóa: ${e.toString()}")),
      );
    }
  }

  Future<void> _openExternalLink(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Không thể mở liên kết lúc này")),
      );
    }
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF6797E1).withOpacity(isDarkMode ? 0.18 : 0.12)
                : (isDarkMode
                      ? Colors.white.withOpacity(0.04)
                      : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFF6797E1).withOpacity(0.35)
                  : (isDarkMode ? Colors.white10 : const Color(0xFFE6ECF3)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF6797E1).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF6797E1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF6797E1),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Encode Sans Expanded',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({
    required bool isDarkMode,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
        ),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String label,
    String? status,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = isDestructive
        ? const Color(0xFFFF6C6C)
        : const Color(0xFF6797E1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.95)
                        : Colors.black87,
                  ),
                ),
              ),
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: isDarkMode ? Colors.white24 : Colors.black26,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Divider(
        height: 1,
        color: isDarkMode ? Colors.white10 : const Color(0xFFEAEFF5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    String themeText = 'Theo hệ thống';
    if (appProvider.themeMode == ThemeMode.light) themeText = 'Sáng';
    if (appProvider.themeMode == ThemeMode.dark) themeText = 'Tối';

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF0F1113)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF111315) : Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cài đặt',
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 22),

            _buildSectionTitle('Tùy chỉnh', isDarkMode),
            _buildSettingsGroup(
              isDarkMode: isDarkMode,
              children: [
                _buildSettingItem(
                  icon: appProvider.notificationsEnabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  label: 'Thông báo',
                  onTap: () => appProvider.setNotificationsEnabled(
                    !appProvider.notificationsEnabled,
                  ),
                  trailing: Switch(
                    value: appProvider.notificationsEnabled,
                    onChanged: (val) =>
                        appProvider.setNotificationsEnabled(val),
                    activeColor: const Color(0xFF6797E1),
                  ),
                ),
                _buildDivider(isDarkMode),
                _buildSettingItem(
                  icon: Icons.dark_mode_outlined,
                  label: 'Chế độ tối',
                  status: themeText,
                  onTap: () => _showThemeDialog(context),
                ),
              ],
            ),

            const SizedBox(height: 22),

            _buildSectionTitle('Hỗ trợ', isDarkMode),
            _buildSettingsGroup(
              isDarkMode: isDarkMode,
              children: [
                _buildSettingItem(
                  icon: Icons.article_outlined,
                  label: 'Điều khoản dịch vụ',
                  onTap: () => _openExternalLink(
                    context,
                    'https://myuni-legal.web.app/',
                  ),
                ),
                _buildDivider(isDarkMode),
                _buildSettingItem(
                  icon: Icons.feedback_outlined,
                  label: 'Gửi phản hồi',
                  onTap: () => _openExternalLink(
                    context,
                    'https://forms.gle/zyU75ecHFuapfPGz8',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            _buildSectionTitle('Tài khoản', isDarkMode),
            _buildSettingsGroup(
              isDarkMode: isDarkMode,
              children: [
                _buildSettingItem(
                  icon: Icons.delete_forever_rounded,
                  label: 'Xóa tài khoản',
                  isDestructive: true,
                  onTap: () => _showDeleteAccountDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
