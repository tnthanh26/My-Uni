import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateReviewPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existingData;

  const CreateReviewPage({super.key, this.docId, this.existingData});

  @override
  State<CreateReviewPage> createState() => _CreateReviewPageState();
}

class _CreateReviewPageState extends State<CreateReviewPage> {
  late TextEditingController _courseController;
  late TextEditingController _teacherController;
  late TextEditingController _contentController;
  late String _selectedSemester;
  late int _rating;
  bool _isSubmitting = false;

  final List<String> _semesters = [
    'HK1 2025-2026',
    'HK3 2024-2025',
    'HK2 2024-2025',
    'HK1 2024-2025'
  ];

  @override
  void initState() {
    super.initState();
    // Khởi tạo dữ liệu từ existingData nếu đang ở chế độ chỉnh sửa
    _courseController = TextEditingController(text: widget.existingData?['courseName'] ?? '');
    _teacherController = TextEditingController(text: widget.existingData?['teacherName'] ?? '');
    _contentController = TextEditingController(text: widget.existingData?['content'] ?? '');
    _selectedSemester = widget.existingData?['semester'] ?? 'HK1 2025-2026';
    _rating = widget.existingData?['rating'] ?? 0;
  }

  Future<void> _submitReview() async {
    if (_courseController.text.isEmpty || _rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vui lòng nhập tên môn và chọn số sao"))
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Chưa đăng nhập tài khoản");

      // Gom dữ liệu chung. Việc đưa authorId vào đây giúp "vá" dữ liệu cho các bài cũ
      // vốn dĩ trước đó bạn lỡ quên không lưu authorId.
      final reviewData = {
        'authorId': user.uid,
        'semester': _selectedSemester,
        'courseName': _courseController.text.trim(),
        'teacherName': _teacherController.text.trim(),
        'rating': _rating,
        'content': _contentController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.docId != null) {
        // CHẾ ĐỘ CHỈNH SỬA: Sử dụng update để bổ sung/cập nhật dữ liệu
        await FirebaseFirestore.instance
            .collection('course_reviews')
            .doc(widget.docId)
            .update(reviewData);
      } else {
        // CHẾ ĐỘ TẠO MỚI: Thêm các trường khởi tạo mặc định
        reviewData['timestamp'] = FieldValue.serverTimestamp();
        reviewData['likes'] = 0;
        reviewData['comments'] = 0;
        await FirebaseFirestore.instance
            .collection('course_reviews')
            .add(reviewData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Lưu đánh giá thành công!"))
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Có lỗi xảy ra: ${e.toString()}"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const Color mainColor = Color(0xFF6797E1);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: mainColor,
        elevation: 0,
        leading: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy", style: TextStyle(color: Colors.white, fontSize: 16))
        ),
        title: Text(
            widget.docId == null ? "Review" : "Sửa Review",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitReview,
            child: _isSubmitting
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            )
                : const Text("Lưu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(
                children: List.generate(5, (i) => IconButton(
                  onPressed: () => setState(() => _rating = i + 1),
                  icon: Icon(
                      i < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32
                  ),
                )),
              ),
              const SizedBox(height: 20),
              _buildLabel("Nội dung", isDarkMode),
              _buildContentField(isDarkMode, "Nhập đánh giá của bạn..."),
            ]
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) => Text(
      text,
      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14)
  );

  Widget _buildDropdown() => DropdownButtonFormField<String>(
    value: _selectedSemester,
    items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
    onChanged: (v) => setState(() => _selectedSemester = v!),
    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 0)),
  );

  Widget _buildTextField(TextEditingController ctrl, String hint, bool isDark) => TextField(
    controller: ctrl,
    style: TextStyle(color: isDark ? Colors.white : Colors.black),
    decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14)
    ),
  );

  Widget _buildContentField(bool isDark, String hint) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10)
    ),
    child: TextField(
        controller: _contentController,
        maxLines: 5,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14)
        )
    ),
  );
}