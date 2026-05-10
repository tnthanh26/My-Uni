import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _cohortController = TextEditingController();

  String? selectedFaculty;
  String? _currentPhotoBase64;
  File? _imageFile;
  bool _isLoading = false;

  final List<String> faculties = [
    'Công nghệ thông tin',
    'Hệ thống thông tin',
    'Khoa học máy tính',
    'Kỹ thuật phần mềm',
    'An toàn thông tin'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    _cohortController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      _emailController.text = FirebaseAuth.instance.currentUser?.email ?? "";

      var doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        var data = doc.data()!;
        setState(() {
          _nameController.text = data['displayName'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _dobController.text = data['dob'] ?? '';
          _currentPhotoBase64 = data['photoUrl'];
          if (faculties.contains(data['faculty'])) {
            selectedFaculty = data['faculty'];
          }
          _studentIdController.text = data['studentId'] ?? '';
          _cohortController.text = data['cohort'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Lỗi load dữ liệu: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên người dùng.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String? finalPhotoBase64 = _currentPhotoBase64;

      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        var compressedBytes = await FlutterImageCompress.compressWithList(
          bytes,
          quality: 20,
          minWidth: 500,
          minHeight: 500,
        );
        finalPhotoBase64 = base64Encode(compressedBytes);
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dob': _dobController.text.trim(),
        'faculty': selectedFaculty,
        'photoUrl': finalPhotoBase64,
        'studentId': _studentIdController.text.trim(),
        'cohort': _cohortController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật hồ sơ thành công!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lưu thất bại: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Encode Sans Expanded',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
        ),
      ),
    );
  }

  Widget _buildGroup({
    required bool isDarkMode,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
        ),
        boxShadow: isDarkMode
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 64),
      child: Divider(
        height: 1,
        color: isDarkMode ? Colors.white10 : const Color(0xFFEAEFF5),
      ),
    );
  }

  Widget _buildTextFieldCard(
      BuildContext context, {
        required IconData icon,
        required String label,
        required TextEditingController controller,
        String? hint,
        bool enabled = true,
        TextInputType? keyboardType,
      }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF6797E1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF6797E1), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 14,
                color: enabled
                    ? (isDarkMode ? Colors.white : Colors.black87)
                    : (isDarkMode ? Colors.white38 : Colors.black38),
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white24 : Colors.black26,
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFieldCard(BuildContext context, String label) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF6797E1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school_outlined,
              color: Color(0xFF6797E1),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: selectedFaculty,
              isExpanded: true,
              alignment: Alignment.centerRight,
              dropdownColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
              decoration: const InputDecoration(border: InputBorder.none),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDarkMode ? Colors.white38 : Colors.grey,
              ),
              hint: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "Chọn khoa",
                  style: TextStyle(
                    color: isDarkMode ? Colors.white24 : Colors.black26,
                    fontSize: 14,
                    fontFamily: 'Encode Sans Expanded',
                  ),
                ),
              ),
              items: faculties
                  .map(
                    (f) => DropdownMenuItem(
                  value: f,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      f,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              )
                  .toList(),
              onChanged: (val) => setState(() => selectedFaculty = val),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider _buildAvatarProvider() {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    }

    if (_currentPhotoBase64 != null && _currentPhotoBase64!.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(_currentPhotoBase64!));
      } catch (_) {
        return const AssetImage('assets/images/cat_avatar.jpg');
      }
    }

    return const AssetImage('assets/images/cat_avatar.jpg');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDarkMode ? const Color(0xFF0F1113) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chỉnh sửa hồ sơ',
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: isDarkMode ? const Color(0xFF111315) : Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
            height: 1,
          ),
        ),
      ),
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: _isLoading,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white10
                            : const Color(0xFFE9EEF3),
                      ),
                      boxShadow: isDarkMode
                          ? []
                          : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF6797E1),
                                  width: 3,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 56,
                                backgroundColor: isDarkMode
                                    ? Colors.white10
                                    : Colors.grey[200],
                                backgroundImage: _buildAvatarProvider(),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(99),
                                onTap: _pickImage,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6797E1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Cập nhật thông tin cá nhân',
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color:
                            isDarkMode ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  _buildSectionTitle('Thông tin cá nhân', isDarkMode),
                  _buildGroup(
                    isDarkMode: isDarkMode,
                    children: [
                      _buildTextFieldCard(
                        context,
                        icon: Icons.person_outline_rounded,
                        label: 'Tên người dùng',
                        controller: _nameController,
                        hint: 'Thanh',
                      ),
                      _buildDivider(isDarkMode),
                      _buildTextFieldCard(
                        context,
                        icon: Icons.email_outlined,
                        label: 'Email',
                        controller: _emailController,
                        enabled: false,
                      ),
                      _buildDivider(isDarkMode),
                      _buildTextFieldCard(
                        context,
                        icon: Icons.phone_outlined,
                        label: 'Số điện thoại',
                        controller: _phoneController,
                        hint: '09xxxxxx',
                        keyboardType: TextInputType.phone,
                      ),
                      _buildDivider(isDarkMode),
                      _buildTextFieldCard(
                        context,
                        icon: Icons.cake_outlined,
                        label: 'Ngày sinh',
                        controller: _dobController,
                        hint: '01-01-2004',
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _buildSectionTitle('Học tập', isDarkMode),
                  _buildGroup(
                    isDarkMode: isDarkMode,
                    children: [
                      _buildDropdownFieldCard(context, 'Khoa'),
                      _buildDivider(isDarkMode),
                      _buildTextFieldCard(
                        context,
                        icon: Icons.badge_outlined,
                        label: 'MSSV',
                        controller: _studentIdController,
                      ),
                      _buildDivider(isDarkMode),
                      _buildTextFieldCard(
                        context,
                        icon: Icons.school_outlined,
                        label: 'Niên khóa',
                        controller: _cohortController,
                        hint: '2022 - 2026',
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6797E1),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.save_outlined, size: 20),
                      label: const Text(
                        'Lưu thay đổi',
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.16),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6797E1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}