import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:my_uni/features/credential/login_page.dart';
import 'package:my_uni/features/credential/signup_page.dart';
import 'package:my_uni/features/credential/otp_page.dart';
import 'package:my_uni/features/credential/forgot_password_page.dart';
import 'package:my_uni/features/home/home_page.dart';
import 'package:my_uni/features/myspace/myspace_screen.dart';
import 'firebase_options.dart';
import 'features/services/notification_service.dart';
import 'app_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:my_uni/web_mod/mod_dashboard.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:my_uni/web_mod/mod_login_page.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// --- PHẦN 1: HÀM MAIN ---
void main() async {
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const MyUniApp(),
    ),
  );
}

// --- PHẦN 2: CẤU HÌNH APP ---
final GoRouter _webRouter = GoRouter(
  initialLocation: '/mod-login',
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    // Email moderator của bạn
    final isLoggedIn = user != null && user.email == 'nhatthanhtran2606@gmail.com';
    final isGoingToLogin = state.matchedLocation == '/mod-login';

    if (!isLoggedIn && !isGoingToLogin) {
      return '/mod-login';
    }

    if (isLoggedIn && isGoingToLogin) {
      return '/mod';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/mod',
      builder: (context, state) => const ModDashboard(),
    ),
    GoRoute(
      path: '/mod-login',
      builder: (context, state) => const ModLoginPage(),
    ),
  ],
);

class MyUniApp extends StatelessWidget {
  const MyUniApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    if (kIsWeb) {
      return MaterialApp.router(
        routerConfig: _webRouter,
        title: 'MyUni Moderator',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: appProvider.themeMode,
      );
    }

    return MaterialApp(
      title: 'MyUni',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const MyUniHomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/otp': (context) => const OtpPage(),
        '/forgot_password': (context) => const ForgotPasswordPage(),
        '/home': (context) => const HomePage(),
      },
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: appProvider.themeMode,
      locale: appProvider.locale,
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5893D8),
        brightness: brightness,
      ),
      scaffoldBackgroundColor: brightness == Brightness.light ? Colors.white : null,
    );
  }
}

// --- PHẦN 3: TRANG WELCOME (MOBILE) ---
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
                Icon(Icons.school_rounded, size: 100, color: primaryColor),
                const SizedBox(height: 30),
                const Text(
                  'Chào mừng bạn đến với MyUni!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 50),

                _buildButton(
                    context,
                    'Đăng nhập',
                    primaryColor,
                        () => Navigator.pushNamed(context, '/login'),
                    isOutlined: false
                ),
                const SizedBox(height: 16),
                _buildButton(
                    context,
                    'Đăng ký tài khoản',
                    primaryColor,
                        () => Navigator.pushNamed(context, '/signup'),
                    isOutlined: true
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String text, Color color, VoidCallback onPressed, {required bool isOutlined}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: isOutlined
          ? OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      )
          : ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}