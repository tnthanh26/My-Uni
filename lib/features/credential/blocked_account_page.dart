import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockedAccountPage extends StatelessWidget {
  const BlockedAccountPage({super.key, this.reason, this.status});

  final String? reason;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F1113) : Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.block_rounded,
                size: 82,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                'Tài khoản đã bị khóa',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                reason != null && reason!.trim().isNotEmpty
                    ? 'Lý do: $reason'
                    : 'Tài khoản của bạn hiện không thể tiếp tục sử dụng MyUni.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.5,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();

                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  }
                },
                child: const Text('Quay lại đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
