import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:my_uni/features/credential/login_page.dart';
import 'package:my_uni/features/credential/signup_page.dart';
import 'package:my_uni/features/credential/otp_page.dart';
import 'package:my_uni/features/credential/forgot_password_page.dart';
import 'package:my_uni/features/home/home_page.dart';
import 'firebase_options.dart';
import 'features/services/notification_service.dart';
import 'app_provider.dart';
import 'theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:my_uni/web_mod/mod_dashboard.dart';
import 'package:my_uni/web_mod/collaborator_dashboard.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:my_uni/web_mod/mod_login_page.dart';
import 'package:my_uni/features/credential/user_status_gate.dart';
import 'package:my_uni/features/credential/blocked_account_page.dart';
import 'package:my_uni/splash_screen.dart';

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

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initializeDateFormatting('vi_VN', null);
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
  refreshListenable: GoRouterRefreshStream(
    FirebaseAuth.instance.authStateChanges(),
  ),
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    const allowedAdmins = [
      'nhatthanhtran2606@gmail.com',
      'huynhhuuhau01@gmail.com',
    ];

    const allowedCollaborators = ['trannhatthanha2@gmail.com'];

    final isAdmin = email != null && allowedAdmins.contains(email);
    final isCollaborator =
        email != null && allowedCollaborators.contains(email);

    final location = state.matchedLocation;

    final isLoginPage = location == '/mod-login';
    final isModPage = location == '/mod';
    final isCollaboratorPage = location == '/collaborator';

    if (user == null) {
      return isLoginPage ? null : '/mod-login';
    }

    if (!isAdmin && !isCollaborator) {
      FirebaseAuth.instance.signOut();
      return '/mod-login';
    }

    if (isLoginPage) {
      if (isAdmin) return '/mod';
      if (isCollaborator) return '/collaborator';
    }

    if (isModPage && !isAdmin) {
      return '/collaborator';
    }

    if (isCollaboratorPage && !isCollaborator) {
      return '/mod';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/mod-login',
      builder: (context, state) => const ModLoginPage(),
    ),
    GoRoute(path: '/mod', builder: (context, state) => const ModDashboard()),
    GoRoute(
      path: '/collaborator',
      builder: (context, state) => const CollaboratorDashboard(),
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
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: appProvider.themeMode,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
        builder: (context, child) {
          final mediaQueryData = MediaQuery.of(context);
          final constrainedTextScaler = mediaQueryData.textScaler.clamp(
            minScaleFactor: 0.8,
            maxScaleFactor: 1.15,
          );
          return MediaQuery(
            data: mediaQueryData.copyWith(textScaler: constrainedTextScaler),
            child: child ?? const SizedBox.shrink(),
          );
        },
        locale: const Locale('vi', 'VN'),
      );
    }

    return MaterialApp(
      title: 'MyUni',
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
        '/home': (context) => const UserStatusGate(child: HomePage()),
      },
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: appProvider.themeMode,
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        final constrainedTextScaler = mediaQueryData.textScaler.clamp(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.15,
        );
        return MediaQuery(
          data: mediaQueryData.copyWith(textScaler: constrainedTextScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
      locale: appProvider.locale ?? const Locale('vi', 'VN'),
    );
  }
}

// --- PHẦN 3: TRANG WELCOME (MOBILE) ---
class MyUniHomePage extends StatelessWidget {
  const MyUniHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy màu từ AppTheme hoặc AppColors để đồng bộ
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500.0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // Logo
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: Hero(
                        tag: 'app_logo', // Thêm Hero animation nếu cần sau này
                        child: Image.asset(
                          'assets/images/logoApp.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Tiêu đề
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

                    // Tagline nhỏ
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

                    // Nút Đăng nhập (Primary)
                    _buildButton(
                      context,
                      'Đăng nhập',
                      primaryColor,
                      () => Navigator.pushNamed(context, '/login'),
                      isOutlined: false,
                    ),

                    const SizedBox(height: 16),

                    // Nút Đăng ký (Secondary/Outlined)
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
