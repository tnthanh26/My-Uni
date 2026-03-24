import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreateReviewPage extends StatefulWidget {
  const CreateReviewPage({super.key});

  @override
  State<CreateReviewPage> createState() => _CreateReviewPageState();
}

class _CreateReviewPageState extends State<CreateReviewPage> {
  final _courseController = TextEditingController();
  final _teacherController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedSemester = 'HK1 2025-2026';
  int _rating = 0;
  bool _isSubmitting = false;

  final List<String> _semesters = ['HK1 2025-2026', 'HK3 2024-2025', 'HK2 2024-2025', 'HK1 2024-2025'];

  Future<void> _submitReview() async {
    if (_courseController.text.isEmpty || _rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tên môn và chọn số sao")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance.collection('course_reviews').add({
        'semester': _selectedSemester,
        'courseName': _courseController.text.trim(),
        'teacherName': _teacherController.text.trim(),
        'rating': _rating,
        'content': _contentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const Color mainColor = Color(0xFF6797E1);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: mainColor, elevation: 0,
        leading: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy", style: TextStyle(color: Colors.white, fontSize: 16))),
        title: const Text("Review", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(onPressed: _isSubmitting ? null : _submitReview, child: const Text("Lưu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildLabel("Học kỳ", isDarkMode),
          _buildDropdown(),
          const SizedBox(height: 20),
          _buildLabel("Khóa học", isDarkMode),
          _buildTextField(_courseController, "Tên môn học", isDarkMode),
          const SizedBox(height: 20),
          _buildLabel("Giảng viên", isDarkMode),
          _buildTextField(_teacherController, "Tên giảng viên", isDarkMode),
          const SizedBox(height: 20),
          _buildLabel("Trải nghiệm của bạn về khóa học này?", isDarkMode),
          Row(children: List.generate(5, (i) => IconButton(
            onPressed: () => setState(() => _rating = i + 1),
            icon: Icon(i < _rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
          ))),
          const SizedBox(height: 20),
          _buildLabel("Nội dung", isDarkMode),
          _buildContentField(isDarkMode, "Nhập đánh giá của bạn..."),
        ]),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) => Text(text, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14));

  Widget _buildDropdown() => DropdownButtonFormField<String>(
    value: _selectedSemester,
    items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
    onChanged: (v) => setState(() => _selectedSemester = v!),
    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 0)),
  );

  Widget _buildTextField(TextEditingController ctrl, String hint, bool isDark) => TextField(
    controller: ctrl,
    style: TextStyle(color: isDark ? Colors.white : Colors.black),
    decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 14)),
  );

  Widget _buildContentField(bool isDark, String hint) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
    child: TextField(controller: _contentController, maxLines: 5, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: const TextStyle(fontSize: 14))),
  );
}