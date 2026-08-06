import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../services/content_service.dart';

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

  final List<String> _suggestedHashtags = [
    "Hỏi đáp",
    "Chia sẻ",
    "Đăng Ký Môn Học",
    "Ngoại ngữ",
    "Nghiên cứu KH",
    "Học phí",
    "Học bổng",
    "Điểm rèn luyện",
    "Thủ tục",
    "Tân sinh viên",
    "Quân sự",
    "CLB",
    "Trọ/KTX",
    "Tìm đồ",
    "Tìm việc",
    "Thanh Lý",
    "Nghỉ lễ",
    "Nghỉ hè"
  ];



  File? _newImageFile;
  String? _existingImageUrl;
  bool _isSubmitting = false;

  // Poll State
  bool _isPollEnabled = false;
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void initState() {
    super.initState();
    _isAnonymous = widget.existingData?['isAnonymous'] ?? false;
    _contentController = TextEditingController(text: widget.existingData?['content'] ?? '');
    _selectedHashtags = List<String>.from(widget.existingData?['hashtags'] ?? []);
    _existingImageUrl = widget.existingData?['imageUrl'];
    
    // Load existing poll if editing
    if (widget.existingData?['poll'] != null) {
      _isPollEnabled = true;
      List<dynamic> options = widget.existingData!['poll']['options'] ?? [];
      _pollOptionControllers.clear();
      for (var opt in options) {
        _pollOptionControllers.add(TextEditingController(text: opt.toString()));
      }
      if (_pollOptionControllers.length < 2) {
        while (_pollOptionControllers.length < 2) {
          _pollOptionControllers.add(TextEditingController());
        }
      }
    }
    
    _loadUserData();
  }

  @override
  void dispose() {
    _contentController.dispose();
    for (var controller in _pollOptionControllers) {
      controller.dispose();
    }
    super.dispose();
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
        });
      }
    } catch (_) {}
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

  void _addPollOption() {
    if (_pollOptionControllers.length < 5) {
      setState(() {
        _pollOptionControllers.add(TextEditingController());
      });
    }
  }

  void _removePollOption(int index) {
    if (_pollOptionControllers.length > 2) {
      setState(() {
        _pollOptionControllers[index].dispose();
        _pollOptionControllers.removeAt(index);
      });
    }
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vui lòng nhập nội dung"))
      );
      return;
    }

    Map<String, dynamic>? pollData;
    if (_isPollEnabled) {
      List<String> options = _pollOptionControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      if (options.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Vui lòng nhập ít nhất 2 tùy chọn khảo sát"))
        );
        return;
      }
      pollData = {
        'options': options,
        'votes': widget.existingData?['poll']?['votes'] ?? {},
      };
    }

    // Gom tất cả văn bản lại để quét một lượt (bao gồm nội dung và các option của poll)
    String combinedText = content;
    if (_isPollEnabled) {
      combinedText += " ${_pollOptionControllers.map((c) => c.text).join(' ')}";
    }

    // 1. Kiểm tra từ cấm (Blacklist) - Bắt buộc sửa
    List<String> blacklistViolations = ContentService.getBlacklistedWords(combinedText);
    if (blacklistViolations.isNotEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Yêu cầu sửa nội dung"),
          content: Text("Nội dung hoặc lựa chọn khảo sát chứa từ ngữ không phù hợp: (${blacklistViolations.join(', ')}). Vui lòng xóa hoặc sửa lại để tiếp tục."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Quay lại sửa"),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Kiểm tra từ nhạy cảm (Sensitive List) - Cảnh báo trước khi đăng
    List<String> sensitiveViolations = ContentService.getSensitiveWords(combinedText);
    if (sensitiveViolations.isNotEmpty) {
      bool shouldSubmit = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Cảnh báo từ ngữ nhạy cảm"),
          content: Text("Nội dung chứa từ ngữ nhạy cảm: (${sensitiveViolations.join(', ')}). Nếu tiếp tục đăng, bài viết sẽ ở trạng thái chờ duyệt bởi Quản trị viên. Bạn có muốn tiếp tục?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Quay lại sửa"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Vẫn đăng"),
            ),
          ],
        ),
      ) ?? false;

      if (!shouldSubmit) {
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String? finalImageBase64 = _existingImageUrl;

      if (_newImageFile != null) {
        finalImageBase64 = await _processImageToBase64(_newImageFile!);
      }

      // --- 1. TẠO MAP CHỨA CÁC TRƯỜNG MÀ CẢ EDIT VÀ CREATE ĐỀU DÙNG ---
      final commonData = {
        'authorName': _isAnonymous ? 'Sinh viên ẩn danh' : _realUserName,
        'authorAvatar': _isAnonymous ? null : _userPhotoBase64,
        'content': content,
        'hashtags': _selectedHashtags,
        'imageUrl': finalImageBase64,
        'isAnonymous': _isAnonymous,
        'updatedAt': FieldValue.serverTimestamp(),
        'poll': pollData,
      };

      if (widget.docId != null) {
        // --- 2. CHẾ ĐỘ SỬA (UPDATE) ---
        // Chỉ gửi commonData. TUYỆT ĐỐI không gửi status, isReported, authorId...
        await FirebaseFirestore.instance
            .collection('forum_posts')
            .doc(widget.docId)
            .update(commonData);

      } else {
        // Copy commonData và bổ sung các trường khởi tạo ban đầu
        final postData = Map<String, dynamic>.from(commonData);
        postData['authorId'] = uid;
        postData['status'] = 'pending';
        postData['isToxicChecked'] = false;
        postData['isReported'] = false;
        postData['reportCount'] = 0;
        postData['type'] = 'forum';
        postData['timestamp'] = FieldValue.serverTimestamp();
        postData['likeCount'] = 0;
        postData['commentCount'] = 0;

        await FirebaseFirestore.instance.collection('forum_posts').add(postData);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Có lỗi xảy ra: ${e.toString()}"))
        );
      }
    }
  }

  void _showAllHashtagsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            const Color figmaHeaderBlue = Color(0xFF457EC0);

            final orderedHashtags = [
              ..._suggestedHashtags.where((tag) => _selectedHashtags.contains(tag)),
              ..._suggestedHashtags.where((tag) => !_selectedHashtags.contains(tag)),
            ];

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Tất cả chủ đề",
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        "(${_selectedHashtags.length}/5)",
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 14,
                          color: isDarkMode ? Colors.white38 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: orderedHashtags.map((tag) {
                      bool isSelected = _selectedHashtags.contains(tag);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              _selectedHashtags.remove(tag);
                            } else {
                              if (_selectedHashtags.length < 5) {
                                _selectedHashtags.add(tag);
                              }
                            }
                          });
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                              Text(tag, style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 11, color: isDarkMode ? Colors.white70 : Colors.black)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: figmaHeaderBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Hoàn tất",
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color figmaHeaderBlue = Color(0xFF457EC0);
    const Color figmaDashedColor = Color(0xFF1C95BE);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 550.0;
    final orderedHashtags = [
      ..._suggestedHashtags.where((tag) => _selectedHashtags.contains(tag)),
      ..._suggestedHashtags.where((tag) => !_selectedHashtags.contains(tag)),
    ];

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
                        color: Color(0xFFFFFDFD),
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
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550.0),
          child: Container(
            width: double.infinity,
            height: isTablet ? null : double.infinity,
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
                      _isAnonymous ? 'Sinh viên ẩn danh' : _realUserName,
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
              SizedBox(
                height: 36,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: _showAllHashtagsBottomSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white10 : const Color(0xEBEDEDED),
                              borderRadius: BorderRadius.circular(16),
                              border: null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Tất cả",
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 11,
                                    color: isDarkMode ? Colors.white70 : Colors.black,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.arrow_forward_ios_outlined, size: 10, color: Color(0xFF306CFE))
                              ],
                            ),
                          ),
                        ),
                      ),
                      ...orderedHashtags.map((tag) {
                        bool isSelected = _selectedHashtags.contains(tag);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () => setState(() => isSelected ? _selectedHashtags.remove(tag) : (_selectedHashtags.length < 5 ? _selectedHashtags.add(tag) : null)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Content Area
              Text("Nội dung", style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: isDarkMode ? Colors.white : const Color(0xFF1E1E1E))),
              const SizedBox(height: 8),
              SizedBox(
                height: 219,
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
                    hintText: "Vui lòng nhập văn bản",
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

              // Poll Section Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.poll_outlined, color: figmaHeaderBlue),
                      const SizedBox(width: 8),
                      Text(
                        "Tạo cuộc khảo sát",
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isPollEnabled,
                    onChanged: (val) => setState(() => _isPollEnabled = val),
                    activeColor: figmaHeaderBlue,
                  ),
                ],
              ),

              if (_isPollEnabled) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
                  ),
                  child: Column(
                    children: [
                      ..._pollOptionControllers.asMap().entries.map((entry) {
                        int idx = entry.key;
                        TextEditingController controller = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white : Colors.black),
                                  decoration: InputDecoration(
                                    hintText: "Lựa chọn ${idx + 1}",
                                    hintStyle: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white30 : Colors.grey),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              if (_pollOptionControllers.length > 2)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                  onPressed: () => _removePollOption(idx),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      if (_pollOptionControllers.length < 5)
                        TextButton.icon(
                          onPressed: _addPollOption,
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text("Thêm lựa chọn"),
                          style: TextButton.styleFrom(foregroundColor: figmaHeaderBlue),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Upload Image
              if (!_isPollEnabled) // Hide image upload if poll is enabled (optional, or keep both)
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
                          "Nhấn để thêm Ảnh",
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
    )));
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