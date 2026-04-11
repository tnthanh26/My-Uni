import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

class CreateMaterialPage extends StatefulWidget {
  final String? docId; // Thêm trường này
  final Map<String, dynamic>? existingData; // Thêm trường này

  const CreateMaterialPage({super.key, this.docId, this.existingData});

  @override
  State<CreateMaterialPage> createState() => _CreateMaterialPageState();
}

class _CreateMaterialPageState extends State<CreateMaterialPage> {
  late TextEditingController _courseController;
  late TextEditingController _teacherController;
  late TextEditingController _contentController;
  String _selectedSemester = 'HK1 2025-2026';

  File? _attachedFile;
  String? _fileName;
  String? _existingFileData; // Lưu trữ data file cũ nếu không thay đổi file mới
  bool _isImage = false;
  bool _isSubmitting = false;

  final List<String> _semesters = ['HK1 2025-2026', 'HK3 2024-2025', 'HK2 2024-2025', 'HK1 2024-2025'];

  @override
  void initState() {
    super.initState();
    // Khởi tạo controller với dữ liệu cũ nếu có (chế độ Edit)
    _courseController = TextEditingController(text: widget.existingData?['courseName'] ?? '');
    _teacherController = TextEditingController(text: widget.existingData?['teacherName'] ?? '');
    _contentController = TextEditingController(text: widget.existingData?['content'] ?? '');

    if (widget.existingData != null) {
      _selectedSemester = widget.existingData!['semester'] ?? _semesters[0];
      _fileName = widget.existingData!['fileName'];
      _isImage = widget.existingData!['isImage'] ?? false;
      _existingFileData = widget.existingData!['fileData'];
    }
  }

  @override
  void dispose() {
    _courseController.dispose();
    _teacherController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String extension = path.extension(file.path).toLowerCase();

        setState(() {
          _attachedFile = file;
          _fileName = result.files.single.name;
          _isImage = ['.jpg', '.jpeg', '.png'].contains(extension);
          _existingFileData = null; // Reset file cũ vì đã chọn file mới
        });
      }
    } catch (e) {
      debugPrint("Lỗi FilePicker: $e");
    }
  }

  Future<void> _submitMaterial() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng đăng nhập để thực hiện")));
      return;
    }

    // Nếu không có file đính kèm mới VÀ cũng không có file cũ thì báo lỗi
    if (_courseController.text.isEmpty || (_attachedFile == null && _existingFileData == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tên môn và chọn file")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String? encodedFileData = _existingFileData;

      // Nếu người dùng chọn file mới thì mới encode lại
      if (_attachedFile != null) {
        final bytes = await _attachedFile!.readAsBytes();
        if (_isImage) {
          var compressed = await FlutterImageCompress.compressWithList(bytes, quality: 20, minWidth: 500);
          encodedFileData = base64Encode(compressed);
        } else {
          encodedFileData = base64Encode(bytes);
        }
      }

      final Map<String, dynamic> materialData = {
        'semester': _selectedSemester,
        'courseName': _courseController.text.trim(),
        'teacherName': _teacherController.text.trim(),
        'content': _contentController.text.trim(),
        'fileData': encodedFileData,
        'fileName': _fileName,
        'isImage': _isImage,
        'timestamp': widget.existingData != null ? widget.existingData!['timestamp'] : FieldValue.serverTimestamp(),
      };

      if (widget.docId != null) {
        // Chế độ Cập nhật (Update)
        await FirebaseFirestore.instance.collection('study_materials').doc(widget.docId).update(materialData);
      } else {
        // Chế độ Tạo mới (Create)
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data();

        materialData['authorId'] = user.uid;
        materialData['authorName'] = userData?['displayName'] ?? 'Sinh viên MyUni';
        materialData['authorAvatar'] = userData?['photoUrl'] ?? '';
        materialData['likeCount'] = 0;
        materialData['commentCount'] = 0;
        materialData['timestamp'] = FieldValue.serverTimestamp();

        await FirebaseFirestore.instance.collection('study_materials').add(materialData);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Lỗi nộp tài liệu: $e");
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color figmaHeaderBlue = Color(0xFF457EC0);
    const Color figmaDashedColor = Color(0xFF1C95BE);
    const Color figmaHintColor = Color(0xFF8E8E93);
    const Color figmaLabelColor = Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: Container(
          decoration: const BoxDecoration(
            color: figmaHeaderBlue,
            boxShadow: [
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
                    child: Text(
                      "Hủy",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: -0.0041,
                      ),
                    ),
                  ),
                  Text(
                    widget.docId != null ? "Sửa Tài Liệu" : "Tài Liệu",
                    style: const TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: Color(0xFFFFFDFD),
                      letterSpacing: -0.0041,
                    ),
                  ),
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submitMaterial,
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                      "Lưu",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: Colors.white,
                        letterSpacing: -0.0041,
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel("Học kỳ"),
              _buildDropdown(),
              const SizedBox(height: 24),

              _buildSectionLabel("Khóa học"),
              _buildUnderlineTextField(_courseController, "Tên môn học"),
              const SizedBox(height: 24),

              _buildSectionLabel("Giảng viên"),
              _buildUnderlineTextField(_teacherController, "Tên giảng viên"),
              const SizedBox(height: 24),

              _buildSectionLabel("Nội dung mô tả"),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 214,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: figmaHintColor),
                ),
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: figmaLabelColor),
                  decoration: const InputDecoration(
                    hintText: "Nội dung",
                    hintStyle: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: figmaHintColor),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionLabel("Đính kèm tệp"),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: (_attachedFile == null && _existingFileData == null) ? _pickFile : null,
                child: CustomPaint(
                  painter: (_attachedFile == null && _existingFileData == null) ? DashRectPainter(color: figmaDashedColor) : null,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: (_attachedFile != null || _existingFileData != null)
                        ? BoxDecoration(border: Border.all(color: figmaDashedColor), borderRadius: BorderRadius.circular(20))
                        : null,
                    alignment: Alignment.center,
                    child: (_attachedFile != null || _existingFileData != null)
                        ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _buildFilePreview(),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _attachedFile = null;
                              _fileName = null;
                              _existingFileData = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                        : const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Nhấn để thêm\nẢnh/Tài liệu",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 12,
                          color: figmaDashedColor,
                        ),
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

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Encode Sans Expanded',
        fontWeight: FontWeight.w400,
        fontSize: 15,
        color: Color(0xFF1E1E1E),
        letterSpacing: -0.0024,
      ),
    );
  }

  Widget _buildUnderlineTextField(TextEditingController ctrl, String hint) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF8E8E93), width: 1.0)),
      ),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: Color(0xFF1E1E1E)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: Color(0xFF8E8E93)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF8E8E93), width: 1.0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedSemester,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1E1E1E), size: 24),
          items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _selectedSemester = v!),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.fromLTRB(8, 0, 0, 8),
            border: InputBorder.none,
          ),
          style: const TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: Color(0xFF1E1E1E),
          ),
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    // Ưu tiên hiển thị file mới chọn
    if (_attachedFile != null) {
      if (_isImage) return Image.file(_attachedFile!, width: 120, height: 120, fit: BoxFit.cover);
    } else if (_existingFileData != null) {
      // Hiển thị preview từ data base64 cũ
      if (_isImage) return Image.memory(base64Decode(_existingFileData!), width: 120, height: 120, fit: BoxFit.cover);
    }

    return Container(
      width: 120, height: 120,
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description, size: 40, color: Colors.blue),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(_fileName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
          )
        ],
      ),
    );
  }
}

class DashRectPainter extends CustomPainter {
  final Color color;
  DashRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 6, dashSpace = 3;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20),
    );

    Path path = Path()..addRRect(rrect);
    Path dashPath = Path();

    for (var metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}