import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/formatters.dart';
import '../services/content_service.dart';

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
  late TextEditingController _schoolYearController;
  String _selectedSemester = '2';
  late int _rating;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _courseController =
        TextEditingController(text: widget.existingData?['courseName'] ?? '');
    _teacherController =
        TextEditingController(text: widget.existingData?['teacherName'] ?? '');
    _contentController =
        TextEditingController(text: widget.existingData?['content'] ?? '');
    _rating = widget.existingData?['rating'] ?? 0;

    String initialSemester = '2';
    String initialYear = '2025-2026';

    if (widget.existingData?['semester'] != null) {
      final semStr = widget.existingData!['semester'].toString();
      final regExp = RegExp(r'HK(\d)\s+(.*)');
      final match = regExp.firstMatch(semStr);
      if (match != null) {
        initialSemester = match.group(1) ?? '2';
        initialYear = match.group(2) ?? '2025-2026';
      }
    }
    _selectedSemester = initialSemester;
    _schoolYearController = TextEditingController(text: initialYear);
  }

  Future<void> _submitReview() async {
    if (_courseController.text.isEmpty ||
        _rating == 0 ||
        _schoolYearController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vui lòng nhập đầy đủ thông tin và chọn số sao"),
        ),
      );
      return;
    }

    final fullSemester = "HK$_selectedSemester ${_schoolYearController.text.trim()}";

    String combinedText =
        "${_courseController.text} ${_teacherController.text} ${_contentController.text}";
    List<String> violations = ContentService.getViolatedWords(combinedText);

    if (violations.isNotEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Nội dung không hợp lệ"),
          content: Text(
            "Thông tin review có chứa từ ngữ vi phạm: (${violations.join(', ')}). Bạn cần sửa lại trước khi lưu.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Để mình sửa"),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Chưa đăng nhập tài khoản");

      if (widget.docId != null) {
        final updateData = {
          'semester': fullSemester,
          'courseName': _courseController.text.trim(),
          'teacherName': _teacherController.text.trim(),
          'rating': _rating,
          'content': _contentController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('course_reviews')
            .doc(widget.docId)
            .update(updateData);
      } else {
        final reviewData = {
          'authorId': user.uid,
          'semester': fullSemester,
          'courseName': _courseController.text.trim(),
          'teacherName': _teacherController.text.trim(),
          'rating': _rating,
          'content': _contentController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'isToxicChecked': false,
          'isReported': false,
          'reportCount': 0,
          'type': 'review',
          'timestamp': FieldValue.serverTimestamp(),
          'likeCount': 0,
          'commentCount': 0,
        };

        await FirebaseFirestore.instance
            .collection('course_reviews')
            .add(reviewData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lưu đánh giá thành công!")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Có lỗi xảy ra: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color figmaHeaderBlue = Color(0xFF457EC0);
    const Color starYellow = Color(0xFFFFCB45);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : figmaHeaderBlue,
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.25),
                offset: Offset(0, 1),
                blurRadius: 4,
              )
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      "Hủy",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: Color(0xFFFFFDFD),
                      ),
                    ),
                  ),
                  Text(
                    widget.docId == null ? "Review" : "Sửa Review",
                    style: const TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: Color(0xFFFFFDFD),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submitReview,
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      "Đăng",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: Color(0xFFFFFDFD),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF121212) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(flex: 2, child: _buildSectionLabel(context, "Học kỳ")),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: _buildSectionLabel(context, "Năm học")),
                ],
              ),
              _buildSemesterInput(context),
              const SizedBox(height: 24),

              _buildSectionLabel(context, "Khóa học"),
              _buildUnderlineTextField(context, _courseController, "Tên môn học"),
              const SizedBox(height: 24),

              _buildSectionLabel(context, "Giảng viên"),
              _buildUnderlineTextField(context, _teacherController, "Tên giảng viên"),
              const SizedBox(height: 24),

              _buildSectionLabel(context, "Trải nghiệm của bạn về khóa học này?"),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: Container(
                      margin: const EdgeInsets.only(right: 11.6),
                      child: Icon(
                        Icons.star,
                        color: i < _rating
                            ? starYellow
                            : (isDarkMode
                            ? Colors.white12
                            : const Color(0xFFF2F2F2)),
                        size: 34,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              _buildSectionLabel(context, "Nội dung"),
              const SizedBox(height: 10),
              SizedBox(
                height: 214,
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 15,
                    color: isDarkMode
                        ? Colors.white
                        : const Color(0xFF1E1E1E),
                  ),
                  decoration: InputDecoration(
                    hintText: "Nội dung",
                    hintStyle: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 15,
                      color: isDarkMode
                          ? Colors.white30
                          : const Color(0xFF8E8E93),
                    ),

                    contentPadding: const EdgeInsets.all(16),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? Colors.white24
                            : const Color(0xFF8E8E93),
                      ),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF457EC0),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Encode Sans Expanded',
          fontWeight: FontWeight.w400,
          fontSize: 15,
          color: isDarkMode ? Colors.white70 : const Color(0xFF1E1E1E),
        ),
      ),
    );
  }

  Widget _buildSemesterInput(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: EdgeInsets.zero,
            child: DropdownButtonFormField<String>(
              value: _selectedSemester,
              dropdownColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
              ),
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 15,
                color: isDarkMode ? Colors.white : const Color(0xFF1E1E1E),
              ),
              items: ['1', '2', '3'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text("Học kỳ $value"),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() => _selectedSemester = newValue);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: _buildUnderlineTextField(
            context,
            _schoolYearController,
            "Năm học (2024-2025)",
            inputFormatters: [SchoolYearInputFormatter()],
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildUnderlineTextField(
      BuildContext context,
      TextEditingController ctrl,
      String hint, {
        List<TextInputFormatter>? inputFormatters,
        TextInputType? keyboardType,
      }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.only(left: 8),
      child: TextField(
        controller: ctrl,
        inputFormatters: inputFormatters,
        keyboardType: keyboardType,
        style: TextStyle(
          fontFamily: 'Encode Sans Expanded',
          fontSize: 15,
          color: isDarkMode ? Colors.white : const Color(0xFF1E1E1E),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontSize: 15,
            color: isDarkMode ? Colors.white30 : const Color(0xFF8E8E93),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 8,
          ),
        ),
      ),
    );
  }
}