import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:my_uni/features/credential/login_page.dart';
import 'package:my_uni/features/credential/signup_page.dart';
import 'package:my_uni/features/credential/otp_page.dart';
import 'package:my_uni/features/credential/forgot_password_page.dart';
import 'package:my_uni/features/home/home_page.dart';
import 'package:my_uni/features/myspace/myspace_screen.dart'; // Import MySpaceScreen
import 'firebase_options.dart';
import 'notification_service.dart';

// --- PHẦN 1: QUẢN LÝ TRẠNG THÁI (APP PROVIDER) ---
class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('vi'); // Mặc định Tiếng Việt

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  AppProvider() {
    _loadSettings();
  }

  // Load cài đặt đã lưu từ bộ nhớ máy
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

  // Hàm thay đổi Theme
  void setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme', mode.toString().split('.').last);
  }

  // Hàm thay đổi Ngôn ngữ
  void setLocale(String langCode) async {
    _locale = Locale(langCode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('lang', langCode);
  }
}

// --- PHẦN 2: HÀM MAIN ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
  await NotificationService.init();

  runApp(
    // Bao bọc App bằng Provider để quản lý Dark Mode & Ngôn ngữ
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const MyUniApp(),
    ),
  );
}

// --- PHẦN 3: CẤU HÌNH APP ---
class MyUniApp extends StatelessWidget {
  const MyUniApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe sự thay đổi từ AppProvider
    final appProvider = Provider.of<AppProvider>(context);

    return MaterialApp(
      title: 'MyUni',
      debugShowCheckedModeBanner: false,

      // Cấu hình Ngôn ngữ
      locale: appProvider.locale,

      // Cấu hình Dark Mode / Light Mode
      themeMode: appProvider.themeMode,

      // Theme Sáng
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5893D8),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),

      // Theme Tối
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5893D8),
          brightness: Brightness.dark,
        ),
        // Bạn có thể tùy chỉnh màu nền Dark Mode ở đây
      ),

      home: const MyUniHomePage(),

      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/otp': (context) => const OtpPage(),
        '/forgot_password': (context) => const ForgotPasswordPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

// --- PHẦN 4: TRANG WELCOME ---
class MyUniHomePage extends StatelessWidget {
  const MyUniHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF5893D8);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 100,
                  color: primaryColor,
                ),
                const SizedBox(height: 30),

                Text(
                  'Chào mừng bạn đến với MyUni!',
                  textAlign: TextAlign.center,
                  textScaler: const TextScaler.linear(1.0),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Kết nối với các bạn cùng trường',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),

                const SizedBox(height: 50),

                // Button Đăng nhập
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('Đăng nhập', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 16),

                // Button Đăng ký
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/signup'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text(
                      'Đăng ký tài khoản',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}