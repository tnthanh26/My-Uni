import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

class CreateMaterialPage extends StatefulWidget {
  const CreateMaterialPage({super.key});

  @override
  State<CreateMaterialPage> createState() => _CreateMaterialPageState();
}

class _CreateMaterialPageState extends State<CreateMaterialPage> {
  final _courseController = TextEditingController();
  final _teacherController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedSemester = 'HK1 2025-2026';

  File? _attachedFile;
  String? _fileName;
  bool _isImage = false;
  bool _isSubmitting = false;

  final List<String> _semesters = ['HK1 2025-2026', 'HK3 2024-2025', 'HK2 2024-2025', 'HK1 2024-2025'];

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'],
        allowMultiple: false, // Chỉ chọn 1 file
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String extension = path.extension(file.path).toLowerCase();

        setState(() {
          _attachedFile = file;
          _fileName = result.files.single.name;
          _isImage = ['.jpg', '.jpeg', '.png'].contains(extension);
        });
        debugPrint("Đã chọn file: $_fileName");
      } else {
        // Người dùng hủy chọn
        debugPrint("Người dùng đã hủy chọn file");
      }
    } catch (e) {
      debugPrint("Lỗi FilePicker: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Không thể mở trình chọn tệp: $e"))
      );
    }
  }

  Future<void> _submitMaterial() async {
    if (_courseController.text.isEmpty || _attachedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tên môn và chọn file")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String? encodedFileData;
      final bytes = await _attachedFile!.readAsBytes();

      if (_isImage) {
        var compressed = await FlutterImageCompress.compressWithList(bytes, quality: 20, minWidth: 500);
        encodedFileData = base64Encode(compressed);
      } else {
        encodedFileData = base64Encode(bytes);
      }

      await FirebaseFirestore.instance.collection('study_materials').add({
        'semester': _selectedSemester,
        'courseName': _courseController.text.trim(),
        'teacherName': _teacherController.text.trim(),
        'content': _contentController.text.trim(),
        'fileData': encodedFileData,
        'fileName': _fileName,
        'isImage': _isImage,
        'timestamp': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
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
        title: const Text("Tài Liệu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(onPressed: _isSubmitting ? null : _submitMaterial, child: const Text("Lưu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
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
          _buildLabel("Nội dung mô tả", isDarkMode),
          _buildContentField(isDarkMode, "Mô tả về tài liệu..."),
          const SizedBox(height: 20),
          _buildLabel("Đính kèm tệp", isDarkMode),
          const SizedBox(height: 10),

          // KHU VỰC CHỌN FILE + NÚT XÓA (X)
          _attachedFile != null
              ? Stack(children: [
            Container(
              width: 140, height: 120,
              decoration: BoxDecoration(border: Border.all(color: mainColor), borderRadius: BorderRadius.circular(10)),
              child: _buildFilePreview(),
            ),
            Positioned(top: 5, right: 5, child: GestureDetector(
              onTap: () => setState(() { _attachedFile = null; _fileName = null; }),
              child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)),
            )),
          ])
              : GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: 140, height: 120,
              decoration: BoxDecoration(color: isDarkMode ? Colors.white10 : Colors.grey[100], border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid), borderRadius: BorderRadius.circular(10)),
              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_circle_outline, color: mainColor), Text("Thêm File/Ảnh", style: TextStyle(fontSize: 10))]),
            ),
          ),
        ]),
      ),
    );
  }

  // --- HÀM HELPER ĐỒNG BỘ ---
  Widget _buildLabel(String text, bool isDark) => Text(text, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14));

  Widget _buildDropdown() => DropdownButtonFormField<String>(
    value: _selectedSemester,
    items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
    onChanged: (v) => setState(() => _selectedSemester = v!),
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
    child: TextField(controller: _contentController, maxLines: 3, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: const TextStyle(fontSize: 14))),
  );

  Widget _buildFilePreview() {
    if (_isImage) return ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_attachedFile!, fit: BoxFit.cover));
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.description, size: 40, color: Colors.blue), Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(_fileName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)))]);
  }
}