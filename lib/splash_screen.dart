import 'dart:async';
import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Logo: fade + scale
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;

  // MyUni text: fade + slide up
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;

  // Tagline: fade + slide up (delayed)
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;

  // Button: fade + slide up (most delayed)
  late Animation<double> _buttonOpacity;
  late Animation<Offset> _buttonSlide;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // --- Logo ---
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    // --- Title ---
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
      ),
    );

    // --- Tagline ---
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.65, curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.65, curve: Curves.easeOut),
      ),
    );

    // --- Button ---
    _buttonOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.85, curve: Curves.easeOut),
      ),
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.85, curve: Curves.easeOut),
      ),
    );

    _startAnimationsAndNavigate();
  }

  void _startAnimationsAndNavigate() {
    _controller.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 4500));
    if (!mounted || _navigated) return;
    const route = '/welcome';
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF09266),
              Color(0xFFCD8569),
              Color(0xFF023B7D),
            ],
            stops: [0.0, 0.15, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 5), // Tăng flex ở trên để đẩy logo xuống gần giữa hơn

              // ── Logo + Title + Tagline ──
              Column(
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

                  /*
                  FadeTransition(
                    opacity: _taglineOpacity,
                    child: SlideTransition(
                      position: _taglineSlide,
                      child: Transform.translate(
                        offset: const Offset(0, -24),
                        child: const Text(
                          'Người bạn đồng hành thời đại học',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Color(0x66000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  */
                ],
              ),

              const Spacer(flex: 6), // Spacer giữa logo và nút

              // ── CTA Button ──
              FadeTransition(
                opacity: _buttonOpacity,
                child: SlideTransition(
                  position: _buttonSlide,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 45),
                    child: SizedBox(
                      height: 52, // Tăng nhẹ chiều cao nút
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _navigate('/welcome'),
                        style: ElevatedButton.styleFrom(
                          // Đổi sang màu trắng bán trong suốt (Glassmorphism)
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          side: const BorderSide(color: Colors.white, width: 1.5), // Viền trắng mảnh
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(56),
                          ),
                        ),
                        child: const Text(
                          'Bắt đầu thôi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white, // Chữ trắng cho hợp tông Glassmorphism
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
