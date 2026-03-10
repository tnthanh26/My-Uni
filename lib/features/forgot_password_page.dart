import 'package:flutter/material.dart';

class ForgotPasswordFlow extends StatefulWidget {
  const ForgotPasswordFlow({super.key});

  @override
  State<ForgotPasswordFlow> createState() => _ForgotPasswordFlowState();
}

class _ForgotPasswordFlowState extends State<ForgotPasswordFlow> {
  int _step = 1; // Tracks which of the 5 screens to show

  void _nextStep() => setState(() => _step++);
  void _reset() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: _step == 1 ? _reset : () => setState(() => _step--))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1: return _stepOne(); // "Quên mật khẩu?"
      case 2: return _stepTwo(); // "Kiểm tra email"
      case 3: return _stepThree(); // "Đã đặt lại mật khẩu!"
      case 4: return _stepFour(); // "Đặt mật khẩu mới"
      case 5: return _stepFive(); // "Đổi mật khẩu thành công!"
      default: return _stepOne();
    }
  }

  // --- Placeholder for your Screen 1 (Design: Forgot Password) ---
  Widget _stepOne() => Column(
    children: [
      const Text("Quên mật khẩu?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Text("Vui lòng nhập email đã đăng ký để đặt lại mật khẩu", textAlign: TextAlign.center),
      const SizedBox(height: 30),
      TextField(decoration: InputDecoration(hintText: "Nhập email của bạn", border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)))),
      const SizedBox(height: 30),
      ElevatedButton(
        onPressed: _nextStep,
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFF6797E1)),
        child: const Text("Đặt lại mật khẩu", style: TextStyle(color: Colors.white)),
      )
    ],
  );

  // Note: You can follow this pattern for steps 2-5 based on your images!
  Widget _stepTwo() => const Center(child: Text("Step 2: Check Email UI"));
  Widget _stepThree() => const Center(child: Text("Step 3: Verification UI"));
  Widget _stepFour() => const Center(child: Text("Step 4: New Password UI"));
  Widget _stepFive() => const Center(child: Text("Step 5: Success UI"));
}