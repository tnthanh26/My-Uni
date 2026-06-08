import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_uni/app_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

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
    bool isDestructive = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor =
    isDestructive ? const Color(0xFFFF6C6C) : const Color(0xFF6797E1);

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
      backgroundColor:
      isDarkMode ? const Color(0xFF0F1113) : const Color(0xFFF8FAFC),
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
                  icon: Icons.notifications_none_rounded,
                  label: 'Thông báo',
                  onTap: () async {
                    bool isOpened = await openAppSettings();
                    if (!isOpened && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Không thể mở cài đặt lúc này"),
                        ),
                      );
                    }
                  },
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
                    'https://tinyurl.com/58dcj7cb',
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
          ],
        ),
      ),
    );
  }
}