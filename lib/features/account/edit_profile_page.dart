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
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      _emailController.text = FirebaseAuth.instance.currentUser?.email ?? "";

      var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
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
        });
      }
    } catch (e) {
      debugPrint("Lỗi load dữ liệu: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên người dùng.')));
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
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật hồ sơ thành công!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDarkMode ? Colors.white : Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chỉnh sửa hồ sơ',
          style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6797E1)))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar section
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF6797E1), width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: isDarkMode ? Colors.white10 : Colors.grey[200],
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!) as ImageProvider
                        : (_currentPhotoBase64 != null
                        ? MemoryImage(base64Decode(_currentPhotoBase64!))
                        : const AssetImage('assets/images/cat_avatar.jpg') as ImageProvider),
                  ),
                ),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(color: Color(0xFF6797E1), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Fields
            _buildTextField(context, 'Tên người dùng', _nameController, hint: 'Thanh'),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            _buildTextField(context, 'Email', _emailController, enabled: false),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            _buildTextField(context, 'Số điện thoại', _phoneController, hint: '09xxxxxx'),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            _buildTextField(context, 'Ngày sinh', _dobController, hint: '01-01-2004'),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            _buildDropdownField(context, 'Khoa'),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            _buildStaticField(context, 'Niên khóa', '2022 - 2026'),
            Divider(height: 1, color: Theme.of(context).dividerColor),

            const SizedBox(height: 60),

            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6797E1),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
              child: const Text('Lưu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context, String label, TextEditingController controller,
      {String? hint, bool enabled = true}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              enabled: enabled,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 16,
                  color: enabled ? (isDarkMode ? Colors.white : Colors.black) : Colors.grey
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: isDarkMode ? Colors.white24 : Colors.black26),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticField(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDropdownField(BuildContext context, String label) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: selectedFaculty,
              isExpanded: true,
              alignment: Alignment.centerRight,
              // Quan trọng: Màu nền menu xổ xuống
              dropdownColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
              decoration: const InputDecoration(border: InputBorder.none),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              hint: const Align(
                  alignment: Alignment.centerRight,
                  child: Text("Chọn khoa", style: TextStyle(color: Colors.black26, fontSize: 16))
              ),
              items: faculties.map((f) => DropdownMenuItem(
                  value: f,
                  child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(f, style: const TextStyle(fontSize: 16))
                  )
              )).toList(),
              onChanged: (val) => setState(() => selectedFaculty = val),
            ),
          ),
        ],
      ),
    );
  }
}