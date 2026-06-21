import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import '../../utils/formatters.dart';
import '../services/content_service.dart';

class CreateMaterialPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existingData;

  const CreateMaterialPage({super.key, this.docId, this.existingData});

  @override
  State<CreateMaterialPage> createState() => _CreateMaterialPageState();
}

class _CreateMaterialPageState extends State<CreateMaterialPage> {
  late TextEditingController _courseController;
  late TextEditingController _teacherController;
  late TextEditingController _contentController;
  late TextEditingController _schoolYearController;
  String _selectedSemester = '2';

  File? _attachedFile;
  String? _fileName;
  String? _existingFileData;
  bool _isImage = false;
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

    String initialSemester = '2';
    String initialYear = '2025-2026';

    if (widget.existingData != null) {
      _fileName = widget.existingData!['fileName'];
      _isImage = widget.existingData!['isImage'] ?? false;
      _existingFileData = widget.existingData!['fileData'];

      if (widget.existingData!['semester'] != null) {
        final semStr = widget.existingData!['semester'].toString();
        final regExp = RegExp(r'HK(\d)\s+(.*)');
        final match = regExp.firstMatch(semStr);
        if (match != null) {
          initialSemester = match.group(1) ?? '2';
          initialYear = match.group(2) ?? '2025-2026';
        }
      }
    }

    _selectedSemester = initialSemester;
    _schoolYearController = TextEditingController(text: initialYear);
  }

  @override
  void dispose() {
    _courseController.dispose();
    _teacherController.dispose();
    _contentController.dispose();
    _schoolYearController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx'
        ],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String extension = path.extension(file.path).toLowerCase();

        setState(() {
          _attachedFile = file;
          _fileName = result.files.single.name;
          _isImage = ['.jpg', '.jpeg', '.png'].contains(extension);
          _existingFileData = null;
        });
      }
    } catch (e) {
      debugPrint("Lỗi FilePicker: $e");
    }
  }

  Future<void> _submitMaterial() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng đăng nhập để thực hiện")),
      );
      return;
    }

    if (_courseController.text.isEmpty ||
        (_attachedFile == null && _existingFileData == null) ||
        _schoolYearController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vui lòng nhập đầy đủ thông tin và chọn file"),
        ),
      );
      return;
    }

    final fullSemester =
        "HK$_selectedSemester ${_schoolYearController.text.trim()}";

    String combinedText =
        "${_courseController.text} ${_contentController.text} ${_fileName ?? ''}";
    List<String> violations = ContentService.getViolatedWords(combinedText);

    if (violations.isNotEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Tài liệu không hợp lệ"),
          content: Text(
            "Tên tài liệu hoặc mô tả chứa từ ngữ vi phạm: (${violations.join(', ')}). Vui lòng chỉnh sửa lại.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Đã hiểu"),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? encodedFileData = _existingFileData;

      if (_attachedFile != null) {
        final bytes = await _attachedFile!.readAsBytes();

        if (_isImage) {
          var compressed = await FlutterImageCompress.compressWithList(
            bytes,
            quality: 20,
            minWidth: 500,
          );
          encodedFileData = base64Encode(compressed);
        } else {
          encodedFileData = base64Encode(bytes);
        }
      }

      final Map<String, dynamic> commonData = {
        'semester': fullSemester,
        'courseName': _courseController.text.trim(),
        'teacherName': _teacherController.text.trim(),
        'content': _contentController.text.trim(),
        'fileData': encodedFileData,
        'fileName': _fileName,
        'isImage': _isImage,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance
            .collection('study_materials')
            .doc(widget.docId)
            .update(commonData);
      } else {
        final Map<String, dynamic> materialData =
        Map<String, dynamic>.from(commonData);

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final userData = userDoc.data();

        materialData['authorId'] = user.uid;
        materialData['authorName'] =
            userData?['displayName'] ?? 'Sinh viên MyUni';
        materialData['authorAvatar'] = userData?['photoUrl'] ?? '';
        materialData['status'] = 'pending';
        materialData['isToxicChecked'] = false;
        materialData['isReported'] = false;
        materialData['reportCount'] = 0;
        materialData['type'] = 'material';
        materialData['likeCount'] = 0;
        materialData['commentCount'] = 0;
        materialData['timestamp'] = FieldValue.serverTimestamp();

        await FirebaseFirestore.instance
            .collection('study_materials')
            .add(materialData);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Lỗi đăng tài liệu: $e");

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
    const Color figmaDashedColor = Color(0xFF1C95BE);
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
                    widget.docId != null ? "Sửa Tài Liệu" : "Tài Liệu",
                    style: const TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: Color(0xFFFFFDFD),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submitMaterial,
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
                        color: Colors.white,
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
                  Expanded(
                    flex: 2,
                    child: _buildSectionLabel(context, "Học kỳ"),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: _buildSectionLabel(context, "Năm học"),
                  ),
                ],
              ),
              _buildSemesterInput(context),
              const SizedBox(height: 24),

              _buildSectionLabel(context, "Khóa học"),
              _buildUnderlineTextField(
                context,
                _courseController,
                "Tên môn học",
              ),
              const SizedBox(height: 24),

              _buildSectionLabel(context, "Giảng viên"),
              _buildUnderlineTextField(
                context,
                _teacherController,
                "Tên giảng viên",
              ),
              const SizedBox(height: 24),

              _buildSectionLabel(context, "Nội dung mô tả"),
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
                    color:
                    isDarkMode ? Colors.white : const Color(0xFF1E1E1E),
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
              const SizedBox(height: 24),

              _buildSectionLabel(context, "Đính kèm tệp"),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: (_attachedFile == null && _existingFileData == null)
                    ? _pickFile
                    : null,
                child: CustomPaint(
                  painter: (_attachedFile == null && _existingFileData == null)
                      ? DashRectPainter(
                    color:
                    isDarkMode ? Colors.white30 : figmaDashedColor,
                  )
                      : null,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration:
                    (_attachedFile != null || _existingFileData != null)
                        ? BoxDecoration(
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white30
                            : figmaDashedColor,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    )
                        : null,
                    alignment: Alignment.center,
                    child: (_attachedFile != null || _existingFileData != null)
                        ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _buildFilePreview(context),
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
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                        : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Nhấn để thêm\nẢnh/Tài liệu",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.white38
                              : figmaDashedColor,
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
              dropdownColor:
              isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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

  Widget _buildFilePreview(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (_attachedFile != null) {
      if (_isImage) {
        return Image.file(
          _attachedFile!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      }
    } else if (_existingFileData != null) {
      if (_isImage) {
        return Image.memory(
          base64Decode(_existingFileData!),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      }
    }

    return Container(
      width: 120,
      height: 120,
      color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.description,
            size: 40,
            color: Color(0xFF457EC0),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _fileName ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
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