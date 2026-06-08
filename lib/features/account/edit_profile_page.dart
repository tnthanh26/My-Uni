import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../utils/formatters.dart';

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

  // Variables to track initial state for change detection
  String _initialName = '';
  String _initialPhone = '';
  String _initialDob = '';
  String? _initialFaculty;
  String _initialStudentId = '';
  String _initialCohort = '';
  String? _initialPhotoBase64;

  final List<String> faculties = [
    'Công nghệ thông tin',
    'Hệ thống thông tin',
    'Khoa học máy tính',
    'Kỹ thuật phần mềm',
    'An toàn thông tin',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  bool _hasChanges() {
    return _nameController.text != _initialName ||
        _phoneController.text != _initialPhone ||
        _dobController.text != _initialDob ||
        selectedFaculty != _initialFaculty ||
        _studentIdController.text != _initialStudentId ||
        _cohortController.text != _initialCohort ||
        _imageFile != null ||
        _currentPhotoBase64 != _initialPhotoBase64;
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges()) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Thoát mà không lưu?',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bạn có những thay đổi chưa được lưu. Bạn có chắc chắn muốn thoát?',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại', style: TextStyle(color: Color(0xFF296ED8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thoát', style: TextStyle(color: Color(0xFF736B67))),
          ),
        ],
      ),
    );

    return result ?? false;
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
      final uid = FirebaseAuth.instance.currentUser!.uid;
      _emailController.text = FirebaseAuth.instance.currentUser?.email ?? "";

      final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;

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

          // Initialize variables for change detection
          _initialName = _nameController.text;
          _initialPhone = _phoneController.text;
          _initialDob = _dobController.text;
          _initialFaculty = selectedFaculty;
          _initialStudentId = _studentIdController.text;
          _initialCohort = _cohortController.text;
          _initialPhotoBase64 = _currentPhotoBase64;
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

  void _removeImage() {
    setState(() {
      _imageFile = null;
      _currentPhotoBase64 = null;
    });
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
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String? finalPhotoBase64 = _currentPhotoBase64;

      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();

        final compressedBytes = await FlutterImageCompress.compressWithList(
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
        // Reset initial values after saving to avoid "unsaved changes" dialog when popping
        setState(() {
          _initialName = _nameController.text.trim();
          _initialPhone = _phoneController.text.trim();
          _initialDob = _dobController.text.trim();
          _initialFaculty = selectedFaculty;
          _initialStudentId = _studentIdController.text.trim();
          _initialCohort = _cohortController.text.trim();
          _initialPhotoBase64 = finalPhotoBase64;
          _imageFile = null;
          _currentPhotoBase64 = finalPhotoBase64;
        });

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật hồ sơ thành công!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lưu thất bại: $e')),
        );
      }
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
    return Divider(
      height: 1,
      indent: 64,
      color: isDarkMode ? Colors.white10 : const Color(0xFFEAEFF5),
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
        List<TextInputFormatter>? inputFormatters,
      }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6797E1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF6797E1), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white70 : const Color(0xFF344054),
                  ),
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  minLines: 1,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? (isDarkMode ? Colors.white : const Color(0xFF1F2937))
                        : (isDarkMode ? Colors.white38 : Colors.black38),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white24 : Colors.black26,
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.white.withOpacity(0.04)
                        : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF6797E1),
                        width: 1.4,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFieldCard(BuildContext context, String label) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(top: 2),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white70 : const Color(0xFF344054),
                  ),
                ),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  value: selectedFaculty,
                  isExpanded: true,
                  dropdownColor:
                  isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDarkMode ? Colors.white38 : Colors.grey,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.white.withOpacity(0.04)
                        : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF6797E1),
                        width: 1.4,
                      ),
                    ),
                  ),
                  hint: Text(
                    "Chọn khoa",
                    style: TextStyle(
                      color: isDarkMode ? Colors.white24 : Colors.black26,
                      fontSize: 14,
                      fontFamily: 'Encode Sans Expanded',
                    ),
                  ),
                  selectedItemBuilder: (context) {
                    return faculties.map((f) {
                      return Text(
                        f,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF1F2937),
                        ),
                      );
                    }).toList();
                  },
                  items: faculties.map((f) {
                    return DropdownMenuItem(
                      value: f,
                      child: Text(
                        f,
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedFaculty = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _buildAvatarProvider() {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    }

    if (_currentPhotoBase64 != null && _currentPhotoBase64!.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(_currentPhotoBase64!));
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final avatarProvider = _buildAvatarProvider();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor:
        isDarkMode ? const Color(0xFF0F1113) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDarkMode ? Colors.white : Colors.black,
              size: 20,
            ),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
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
                                radius: 48,
                                backgroundColor: isDarkMode
                                    ? Colors.white10
                                    : Colors.grey[200],
                                backgroundImage: avatarProvider,
                                child: avatarProvider == null
                                    ? Icon(
                                  Icons.person,
                                  size: 48,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.grey,
                                )
                                    : null,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(99),
                                onTap: _pickImage,
                                child: Container(
                                  width: 34,
                                  height: 34,
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
                                    size: 17,
                                  ),
                                ),
                              ),
                            ),
                            if (avatarProvider != null)
                              Positioned(
                                left: 0,
                                bottom: 0,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(99),
                                  onTap: _removeImage,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6C6C),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.white,
                                      size: 17,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Cập nhật thông tin cá nhân',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF1F2937),
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
                        hint: '01 - 01 - 2004',
                        keyboardType: TextInputType.number,
                        inputFormatters: [DateInputFormatter()],
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
                        keyboardType: TextInputType.number,
                        inputFormatters: [CohortInputFormatter()],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6797E1),
                        disabledBackgroundColor:
                        const Color(0xFF6797E1).withOpacity(0.5),
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
      ),)
    );
  }
}