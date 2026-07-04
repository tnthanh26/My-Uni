import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Background: fade from solid to gradient
  late Animation<double> _bgOpacity;

  // Logo: fade + scale
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;

  // MyUni text: fade + slide up
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;



  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // --- Background Animation (Khớp với Native Splash) ---
    _bgOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // --- Logo ---
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.45, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.45, curve: Curves.easeOutBack),
      ),
    );

    // --- Title ---
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );



    _startAnimationsAndNavigate();
  }

  void _startAnimationsAndNavigate() {
    _controller.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 3200));

    if (!mounted || _navigated) return;

    final user = FirebaseAuth.instance.currentUser;
    String route = '/welcome';

    if (user != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final loginTimestamp = prefs.getInt('login_timestamp');

        if (loginTimestamp != null) {
          final loginTime = DateTime.fromMillisecondsSinceEpoch(loginTimestamp);
          final difference = DateTime.now().difference(loginTime).inDays;

          if (difference >= 15) {
            // Đã quá 15 ngày, tự động đăng xuất
            await FirebaseAuth.instance.signOut();
            await prefs.remove('login_timestamp');
            route = '/welcome';
          } else {
            route = '/home';
          }
        } else {
          // Chưa có mốc thời gian (ví dụ: người dùng cũ nâng cấp app), lưu mốc hiện tại
          await prefs.setInt('login_timestamp', DateTime.now().millisecondsSinceEpoch);
          route = '/home';
        }
      } catch (e) {
        debugPrint("Error checking login session age: $e");
        route = '/home'; // Nếu có lỗi bất ngờ, cho qua để không bị kẹt ở Splash
      }
    } else {
      route = '/welcome';
    }

    _navigate(route);
  }

  void _navigate(String route) {
    if (_navigated) return;
    _navigated = true;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Lớp nền 1: Màu trắng (Khớp hoàn toàn với Native Splash mới)
          Container(color: Colors.white),

          // Lớp nền 2: Gradient (Fade-in mượt mà từ trắng sang gradient)
          FadeTransition(
            opacity: _bgOpacity,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF09266),
                    Color(0xFFCD8569),
                    Color(0xFF023B7D),
                  ],
                  stops: [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),

          // Lớp nội dung
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Image.asset(
                        'assets/images/logoSplash.png',
                        width: 160,
                        height: 166,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _titleOpacity,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: Transform.translate(
                        offset: const Offset(0, -30),
                        child: Image.asset(
                          'assets/images/MyUni.png',
                          width: 220,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
