import 'package:flutter/material.dart';
import 'package:my_uni/features/login_page.dart';
import 'package:my_uni/features/signup_page.dart';

void main() {
  runApp(const MyUniApp());
}

class MyUniApp extends StatelessWidget {
  const MyUniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyUni',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Matching the blue shade from your provided design
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6797E1)),
        useMaterial3: true,
      ),
      // The initial screen that loads
      home: const MyUniHomePage(),

      // The "Map" that tells Flutter where to go when you call pushNamed
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
      },
    );
  }
}

class MyUniHomePage extends StatelessWidget {
  const MyUniHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Branding Icon
            const Icon(
              Icons.school_rounded,
              size: 100,
              color: Color(0xFF6797E1),
            ),
            const SizedBox(height: 30),

            // Welcome Text
            const Text(
              'Welcome to MyUni!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Connecting students within your campus.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 50),

            // Navigation Button: Login
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // This matches the key in the 'routes' map above
                  Navigator.pushNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6797E1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Navigation Button: Sign Up
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  // This matches the key in the 'routes' map above
                  Navigator.pushNamed(context, '/signup');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF6797E1), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6797E1),
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