import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class CreatePostPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existingData;

  const CreatePostPage({super.key, this.docId, this.existingData});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  late bool _isAnonymous;
  late TextEditingController _contentController;
  late List<String> _selectedHashtags;

  String _realUserName = "Đang tải...";
  String? _userPhotoBase64;
  bool _isLoadingUser = true;

  final List<String> _suggestedHashtags = ["Hỏi đáp", "Quân sự", "Học phí", "Tìm đồ", "Chia sẻ", "Tìm việc"];
  File? _newImageFile;
  String? _existingImageUrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _isAnonymous = widget.existingData?['isAnonymous'] ?? false;
    _contentController = TextEditingController(text: widget.existingData?['content'] ?? '');
    _selectedHashtags = List<String>.from(widget.existingData?['hashtags'] ?? []);
    _existingImageUrl = widget.existingData?['imageUrl'];
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        var data = doc.data()!;
        setState(() {
          _realUserName = data['displayName'] ?? 'Sinh viên MyUni';
          _userPhotoBase64 = data['photoUrl'];
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _newImageFile = File(pickedFile.path));
  }

  Future<String?> _processImageToBase64(File file) async {
    final bytes = await file.readAsBytes();
    var compressedBytes = await FlutterImageCompress.compressWithList(
      bytes, quality: 20, minWidth: 500, minHeight: 500,
    );
    return base64Encode(compressedBytes);
  }

  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập nội dung")));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String? finalImageBase64 = _existingImageUrl;
      if (_newImageFile != null) {
        finalImageBase64 = await _processImageToBase64(_newImageFile!);
      }

      final postData = {
        'authorName': _isAnonymous ? 'Vô danh tiểu tốt' : _realUserName,
        'authorAvatar': _isAnonymous ? null : _userPhotoBase64,
        'content': _contentController.text.trim(),
        'hashtags': _selectedHashtags,
        'imageUrl': finalImageBase64,
        'isAnonymous': _isAnonymous,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance.collection('forum_posts').doc(widget.docId).update(postData);
      } else {
        postData['authorId'] = uid;
        postData['timestamp'] = FieldValue.serverTimestamp();
        postData['likeCount'] = 0;
        postData['commentCount'] = 0;
        await FirebaseFirestore.instance.collection('forum_posts').add(postData);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
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
                    child: Text(
                      "Hủy",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                  Text(
                    widget.docId == null ? "Diễn Đàn" : "Sửa Bài Đăng",
                    style: const TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: Color(0xFFFFFDFD),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submitPost,
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                      "Lưu",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: Colors.white.withOpacity(0.5),
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
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Card (Figma style)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22.5,
                      backgroundColor: isDarkMode ? Colors.white10 : Colors.grey[300],
                      backgroundImage: (!_isAnonymous && _userPhotoBase64 != null) ? MemoryImage(base64Decode(_userPhotoBase64!)) : null,
                      child: (_isAnonymous || _userPhotoBase64 == null) ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isAnonymous ? 'Vô danh tiểu tốt' : _realUserName,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _isAnonymous = !_isAnonymous),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: isDarkMode ? Colors.white10 : Colors.white,
                            shape: BoxShape.circle
                        ),
                        child: Icon(
                          _isAnonymous ? Icons.visibility_off : Icons.visibility,
                          size: 24,
                          color: isDarkMode ? Colors.white70 : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Hashtags
              Row(
                children: [
                  Text("Chọn chủ đề", style: TextStyle(fontFamily: 'Lato', fontSize: 15, color: isDarkMode ? Colors.white : const Color(0xFF1E1E1E))),
                  const SizedBox(width: 8),
                  Text("(${_selectedHashtags.length}/5)", style: TextStyle(fontFamily: 'Lato', fontSize: 15, color: isDarkMode ? Colors.white38 : const Color(0xFF1E1E1E).withOpacity(0.5))),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _suggestedHashtags.map((tag) {
                  bool isSelected = _selectedHashtags.contains(tag);
                  return GestureDetector(
                    onTap: () => setState(() => isSelected ? _selectedHashtags.remove(tag) : (_selectedHashtags.length < 5 ? _selectedHashtags.add(tag) : null)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected ? figmaHeaderBlue.withOpacity(0.2) : (isDarkMode ? Colors.white10 : const Color(0xEBEDEDED)),
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected ? Border.all(color: figmaHeaderBlue) : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tag, size: 13, color: Color(0xFF306CFE)),
                          const SizedBox(width: 2),
                          Text(tag, style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 10, color: isDarkMode ? Colors.white70 : Colors.black)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Content Area
              Text("Nội dung", style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: isDarkMode ? Colors.white : const Color(0xFF1E1E1E))),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 219,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDarkMode ? Colors.white24 : const Color(0xFF8E8E93)),
                ),
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: "Vui lòng nhập văn bản",
                    hintStyle: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 12, color: isDarkMode ? Colors.white30 : const Color(0xFF8E8E93)),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Upload Image
              GestureDetector(
                onTap: _pickImage,
                child: CustomPaint(
                  painter: DashRectPainter(color: isDarkMode ? Colors.white30 : figmaDashedColor),
                  child: Container(
                    width: 130,
                    height: 130,
                    alignment: Alignment.center,
                    child: (_newImageFile != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty))
                        ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _newImageFile != null
                              ? Image.file(_newImageFile!, width: 120, height: 120, fit: BoxFit.cover)
                              : Image.memory(base64Decode(_existingImageUrl!), width: 120, height: 120, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => setState(() { _newImageFile = null; _existingImageUrl = null; }),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
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
                          color: isDarkMode ? Colors.white38 : figmaDashedColor,
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