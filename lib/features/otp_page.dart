import 'package:flutter/material.dart';

class OtpPage extends StatelessWidget {
  const OtpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Image.asset(
                'assets/images/otp_icon.png',
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 40),

            // 2. Title
            const Text(
              'Xác thực OTP',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // 3. Subtitle
            const Text(
              'Mã OTP sẽ được gửi đến email sinh viên của bạn',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 40),

            // 4. Email Input with underline style from design
            const Text(
              'Nhập email',
              style: TextStyle(color: Colors.grey),
            ),
            const TextField(
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'abc@student.edu.vn',
                hintStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  decoration: TextDecoration.underline,
                ),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 60),

            // 5. Blue "Nhận mã OTP" Button
            ElevatedButton(
              onPressed: () {
                // TODO: Logic to trigger OTP email
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6797E1),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Nhận mã OTP',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}