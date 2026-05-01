import 'package:flutter/material.dart';

class ModEmptyState extends StatelessWidget {
  const ModEmptyState({
    super.key,
    this.text = "Không có bài viết cần xử lý!",
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.done_all_rounded, size: 80, color: Colors.green[100]),
          const SizedBox(height: 20),
          Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
              fontFamily: 'Nunito',
            ),
          ),
        ],
      ),
    );
  }
}