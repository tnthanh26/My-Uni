import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DeletingAccountPage extends StatefulWidget {
  final DateTime? scheduledDeleteAt;

  const DeletingAccountPage({
    super.key,
    this.scheduledDeleteAt,
  });

  @override
  State<DeletingAccountPage> createState() => _DeletingAccountPageState();
}

class _DeletingAccountPageState extends State<DeletingAccountPage> {
  bool _isCancelling = false;

  Future<void> _cancelDeletion(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isCancelling = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'status': 'active',
        'scheduledDeleteAt': FieldValue.delete(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã khôi phục tài khoản thành công!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi khi khôi phục tài khoản: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final deleteDateText = widget.scheduledDeleteAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(widget.scheduledDeleteAt!)
        : 'sau 3 ngày';

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F1113) : Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_forever_rounded, size: 82, color: Colors.orangeAccent),
              const SizedBox(height: 20),
              const Text(
                'Tài khoản đang chờ xóa',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Tài khoản của bạn đang trong hàng chờ xóa và sẽ bị xóa vĩnh viễn vào lúc:\n\n$deleteDateText\n\nTrong thời gian này, bạn không thể truy cập các tính năng của MyUni. Nếu đây là sự nhầm lẫn hoặc bạn muốn tiếp tục sử dụng, hãy nhấn nút bên dưới để khôi phục tài khoản.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.5,
                  fontSize: 15,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              _isCancelling
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6797E1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _cancelDeletion(context),
                      child: const Text(
                        'Hủy yêu cầu xóa (Khôi phục)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
              const SizedBox(height: 12),
              TextButton(
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
                child: Text(
                  'Quay lại đăng nhập bằng tài khoản khác',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
