import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class CreatePostPage extends StatefulWidget {
  final String? docId; // Thêm ID để update
  final Map<String, dynamic>? existingData; // Dữ liệu cũ để đổ vào form

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

  final List<String> _suggestedHashtags = ["Hỏi đáp", "Quân sự", "Học phí", "Tìm đồ", "Chia sẻ"];
  File? _newImageFile; // Ảnh mới chọn từ máy
  String? _existingImageUrl; // Ảnh cũ từ Firestore (Base64)
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo dữ liệu: Nếu có existingData thì lấy, không thì để mặc định
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

      // Xử lý ảnh: Ưu tiên ảnh mới chọn, nếu không thì giữ ảnh cũ
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
        // CHẾ ĐỘ CHỈNH SỬA
        await FirebaseFirestore.instance.collection('forum_posts').doc(widget.docId).update(postData);
      } else {
        // CHẾ ĐỘ TẠO MỚI
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
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const Color mainColor = Color(0xFF6797E1);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: mainColor,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Hủy", style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
        title: Text(widget.docId == null ? "Diễn Đàn" : "Sửa Bài Đăng", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitPost,
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Lưu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header User
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF252525) : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[700],
                    backgroundImage: (!_isAnonymous && _userPhotoBase64 != null) ? MemoryImage(base64Decode(_userPhotoBase64!)) : null,
                    child: (_isAnonymous || _userPhotoBase64 == null) ? const Icon(Icons.person, color: Colors.white54) : null,
                  ),
                  const SizedBox(width: 12),
                  Text(_isAnonymous ? 'Vô danh tiểu tốt' : _realUserName, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _isAnonymous = !_isAnonymous),
                    icon: Icon(_isAnonymous ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _isAnonymous ? mainColor : (isDarkMode ? Colors.white38 : Colors.grey)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text("Chọn chủ đề", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedHashtags.map((tag) {
                bool isSelected = _selectedHashtags.contains(tag);
                return InkWell(
                  onTap: () => setState(() => isSelected ? _selectedHashtags.remove(tag) : (_selectedHashtags.length < 5 ? _selectedHashtags.add(tag) : null)),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? mainColor : (isDarkMode ? const Color(0xFF2C2C2C) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? mainColor : (isDarkMode ? Colors.white10 : Colors.grey.shade300)),
                    ),
                    child: Text("#$tag", style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            const Text("Nội dung", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey.shade300),
              ),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "Bạn đang nghĩ gì...",
                  hintStyle: TextStyle(color: isDarkMode ? Colors.white24 : Colors.black38),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text("Ảnh bài đăng", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            (_newImageFile != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty))
                ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _newImageFile != null
                      ? Image.file(_newImageFile!, width: 120, height: 120, fit: BoxFit.cover)
                      : Image.memory(base64Decode(_existingImageUrl!), width: 120, height: 120, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _newImageFile = null;
                      _existingImageUrl = null;
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
                : GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF252525) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: mainColor.withOpacity(0.5)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: mainColor),
                    Text("Thêm ảnh", style: TextStyle(color: mainColor, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}