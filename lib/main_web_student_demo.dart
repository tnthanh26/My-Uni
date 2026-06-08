import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';
import 'app_provider.dart';
import 'theme/app_theme.dart';

import 'features/services/notification_service.dart';
import 'features/credential/login_page.dart';
import 'features/credential/signup_page.dart';
import 'features/credential/otp_page.dart';
import 'features/credential/forgot_password_page.dart';
import 'features/credential/user_status_gate.dart';
import 'features/credential/blocked_account_page.dart';
import 'features/home/home_page.dart';
import 'splash_screen.dart';
import 'utils/mobile_web_frame.dart';

void main() async {
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Web demo chủ yếu để test flow student.
  // Nếu NotificationService không support web thì không nên để nó làm crash demo.
  try {
    await NotificationService.init();
  } catch (_) {
    debugPrint('NotificationService skipped on web student demo.');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const MyUniStudentWebDemoApp(),
    ),
  );
}

class MyUniStudentWebDemoApp extends StatelessWidget {
  const MyUniStudentWebDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return MaterialApp(
      title: 'MyUni Student Demo',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashPage(),
        '/welcome': (context) => const MyUniHomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/otp': (context) => const OtpPage(),
        '/forgot_password': (context) => const ForgotPasswordPage(),
        '/blocked': (context) => const BlockedAccountPage(),
        '/home': (context) => const UserStatusGate(
          child: HomePage(),
        ),
      },
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: appProvider.themeMode,
      locale: appProvider.locale,

      // Quan trọng: bọc toàn bộ app student trong frame điện thoại.
      builder: (context, child) {
        return MobileWebFrame(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

// --- TRANG WELCOME STUDENT ---
class MyUniHomePage extends StatelessWidget {
  const MyUniHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                SizedBox(
                  width: 140,
                  height: 140,
                  child: Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/images/logoApp.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Text(
                  'Chào mừng bạn đến với',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'MyUni',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Your Campus. Your Way.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),

                const SizedBox(height: 60),

                _buildButton(
                  context,
                  'Đăng nhập',
                  primaryColor,
                      () => Navigator.pushNamed(context, '/login'),
                  isOutlined: false,
                ),

                const SizedBox(height: 16),

                _buildButton(
                  context,
                  'Đăng ký tài khoản',
                  primaryColor,
                      () => Navigator.pushNamed(context, '/signup'),
                  isOutlined: true,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
      BuildContext context,
      String text,
      Color color,
      VoidCallback onPressed, {
        required bool isOutlined,
        IconData? icon,
      }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: isOutlined
          ? OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          foregroundColor: color,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22),
              const SizedBox(width: 10),
            ],
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      )
          : ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22),
              const SizedBox(width: 10),
            ],
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}