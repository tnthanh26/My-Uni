import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_uni/main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _showThemeDialog(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chế độ tối', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.light_mode_outlined),
              title: const Text('Sáng'),
              trailing: appProvider.themeMode == ThemeMode.light ? const Icon(Icons.check, color: Color(0xFF6797E1)) : null,
              onTap: () {
                appProvider.setTheme(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Tối'),
              trailing: appProvider.themeMode == ThemeMode.dark ? const Icon(Icons.check, color: Color(0xFF6797E1)) : null,
              onTap: () {
                appProvider.setTheme(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_brightness_outlined),
              title: const Text('Theo cài đặt hệ thống'),
              trailing: appProvider.themeMode == ThemeMode.system ? const Icon(Icons.check, color: Color(0xFF6797E1)) : null,
              onTap: () {
                appProvider.setTheme(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
          ],
        ),
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

    String langText = appProvider.locale.languageCode == 'vi' ? 'Tiếng Việt' : 'English';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              'Cài đặt',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 40),

            _buildSettingItem(
              label: 'Thông báo',
              trailing: Icon(Icons.notifications_none, color: isDarkMode ? Colors.white38 : Colors.black26),
              onTap: () {},
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),

            _buildSettingItem(
              label: 'Chế độ tối',
              status: themeText,
              onTap: () => _showThemeDialog(context),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),

            _buildSettingItem(
              label: 'Ngôn ngữ ứng dụng',
              status: langText,
              onTap: () {},
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),

            const SizedBox(height: 20),

            _buildSettingItem(
              label: 'Điều khoản dịch vụ',
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {},
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),

            _buildSettingItem(
              label: 'Trung tâm trợ giúp',
              trailing: const Icon(Icons.chevron_right, size: 20),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),

            _buildSettingItem(
              label: 'Gửi phản hồi',
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {},
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required String label,
    String? status,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                // Chữ label tự đổi đen/trắng theo nền
                color: isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black87,
              ),
            ),
            if (status != null)
              Text(
                status,
                style: TextStyle(
                  fontSize: 16,
                  // QUAN TRỌNG: Đổi màu xám tùy theo mode
                  color: isDarkMode ? Colors.white38 : Colors.black26,
                ),
              ),
            // Các icon chevron cũng tự đổi màu mờ đi một chút
            if (trailing != null)
              Opacity(opacity: 0.3, child: trailing),
          ],
        ),
      ),
    );
  }
}