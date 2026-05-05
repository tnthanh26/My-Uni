import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

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
        child: Stack(
          children: [
            Positioned(
              top: 185,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/images/logoSplash.png',
                  width: 160,
                  height: 166,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Positioned(
              top: 320,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/images/MyUni.png',
                  width: 220,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const Positioned(
              top: 700,
              left: 0,
              right: 0,
              child: Text(
                'Slogan ở đây',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF6F6F6),
                  shadows: [
                    Shadow(
                      color: Color(0xFFEDF2F4),
                      blurRadius: 17,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 45,
              right: 45,
              bottom: 90,
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/welcome');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE9E8E8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(56),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Bắt đầu thôi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF545454),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}