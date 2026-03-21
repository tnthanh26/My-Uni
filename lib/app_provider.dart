import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('vi'); // Mặc định tiếng Việt

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  AppProvider() {
    _loadSettings();
  }

  // Lưu và load cài đặt từ máy điện thoại
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Theme
    String? theme = prefs.getString('theme');
    if (theme == 'dark') _themeMode = ThemeMode.dark;
    else if (theme == 'light') _themeMode = ThemeMode.light;
    else _themeMode = ThemeMode.system;

    // Load Ngôn ngữ
    String? lang = prefs.getString('lang');
    if (lang != null) _locale = Locale(lang);

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
}