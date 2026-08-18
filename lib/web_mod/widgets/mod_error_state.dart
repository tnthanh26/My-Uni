import 'package:flutter/material.dart';

class ModErrorState extends StatelessWidget {
  const ModErrorState({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.report_gmailerrorred_outlined,
              color: Colors.redAccent,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              "THIẾU CHỈ MỤC (INDEX)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              error,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
