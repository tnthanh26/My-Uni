import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('vi'); // Mặc định tiếng Việt
  bool _notificationsEnabled = true;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get notificationsEnabled => _notificationsEnabled;

  AppProvider() {
    _loadSettings();
  }

  // Lưu và load cài đặt từ máy điện thoại
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Theme
    String? theme = prefs.getString('theme');
    if (theme == 'dark')
      _themeMode = ThemeMode.dark;
    else if (theme == 'light')
      _themeMode = ThemeMode.light;
    else
      _themeMode = ThemeMode.system;

    // Load Ngôn ngữ
    String? lang = prefs.getString('lang');
    if (lang != null) _locale = Locale(lang);

    // Load Thông báo
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;

    notifyListeners();
  }

  void setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme', mode.toString().split('.').last);
  }

  void setLocale(String langCode) async {
    _locale = Locale(langCode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('lang', langCode);
  }

  void setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', enabled);
  }
}
