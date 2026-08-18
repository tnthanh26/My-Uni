import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _dobDayController = TextEditingController();
  final _dobMonthController = TextEditingController();
  final _dobYearController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _cohortStartController = TextEditingController();
  final _cohortEndController = TextEditingController();

  String _getFormattedDob() {
    final d = _dobDayController.text.trim();
    final m = _dobMonthController.text.trim();
    final y = _dobYearController.text.trim();
    if (d.isEmpty && m.isEmpty && y.isEmpty) return '';
    return '$d - $m - $y';
  }

  String _getFormattedCohort() {
    final start = _cohortStartController.text.trim();
    final end = _cohortEndController.text.trim();
    if (start.isEmpty && end.isEmpty) return '';
    return '$start - $end';
  }

  String? selectedFaculty;
  String? selectedUniversity;
  String? _currentPhotoBase64;
  File? _imageFile;
  bool _isLoading = false;

  // Variables to track initial state for change detection
  String _initialName = '';
  String _initialDob = '';
  String? _initialFaculty;
  String? _initialUniversity;
  String _initialStudentId = '';
  String _initialCohort = '';
  String? _initialPhotoBase64;

  final List<String> universities = ['VNU - HCMUS (CS1)', 'VNU - HCMUS (CS2)'];

  final List<String> faculties = [
    'Công nghệ thông tin',
    'Địa chất',
    'Điện tử – Viễn thông',
    'Hóa học',
    'Khoa học và Công nghệ Vật liệu',
    'Khoa Môi trường',
    'Sinh học – Công nghệ Sinh học',
    'Khoa học Liên ngành',
    'Toán – Tin học',
    'Vật lý – Vật lý Kỹ thuật',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  bool _hasChanges() {
    final currentDob = _getFormattedDob();
    final currentCohort = _getFormattedCohort();
    return _nameController.text != _initialName ||
        currentDob != _initialDob ||
        selectedFaculty != _initialFaculty ||
        selectedUniversity != _initialUniversity ||
        _studentIdController.text != _initialStudentId ||
        currentCohort != _initialCohort ||
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
            child: const Text(
              'Ở lại',
              style: TextStyle(color: Color(0xFF296ED8)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Thoát',
              style: TextStyle(color: Color(0xFF736B67)),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobDayController.dispose();
    _dobMonthController.dispose();
    _dobYearController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    _cohortStartController.dispose();
    _cohortEndController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      _emailController.text = FirebaseAuth.instance.currentUser?.email ?? "";

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        setState(() {
          _nameController.text = data['displayName'] ?? '';
          _currentPhotoBase64 = data['photoUrl'];

          if (faculties.contains(data['faculty'])) {
            selectedFaculty = data['faculty'];
          }

          if (universities.contains(data['university'])) {
            selectedUniversity = data['university'];
          }

          _studentIdController.text = data['studentId'] ?? '';

          // Parse dob
          final dobStr = data['dob'] ?? '';
          final dobDigits = dobStr.replaceAll(RegExp(r'\D'), '');
          if (dobDigits.length == 8) {
            _dobDayController.text = dobDigits.substring(0, 2);
            _dobMonthController.text = dobDigits.substring(2, 4);
            _dobYearController.text = dobDigits.substring(4, 8);
          } else {
            _dobDayController.clear();
            _dobMonthController.clear();
            _dobYearController.clear();
          }

          // Parse cohort
          final cohortStr = data['cohort'] ?? '';
          final cohortDigits = cohortStr.replaceAll(RegExp(r'\D'), '');
          if (cohortDigits.length == 8) {
            _cohortStartController.text = cohortDigits.substring(0, 4);
            _cohortEndController.text = cohortDigits.substring(4, 8);
          } else {
            _cohortStartController.clear();
            _cohortEndController.clear();
          }

          // Initialize variables for change detection
          _initialName = _nameController.text;
          _initialDob = _getFormattedDob();
          _initialFaculty = selectedFaculty;
          _initialUniversity = selectedUniversity;
          _initialStudentId = _studentIdController.text;
          _initialCohort = _getFormattedCohort();
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
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

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

    final day = _dobDayController.text.trim();
    final month = _dobMonthController.text.trim();
    final year = _dobYearController.text.trim();

    // Validate Date of Birth
    if (day.isNotEmpty || month.isNotEmpty || year.isNotEmpty) {
      if (day.length != 2 || month.length != 2 || year.length != 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ngày sinh không hợp lệ (định dạng dd-mm-yyyy).'),
          ),
        );
        return;
      }
      final dInt = int.tryParse(day) ?? 0;
      final mInt = int.tryParse(month) ?? 0;
      final yInt = int.tryParse(year) ?? 0;
      if (dInt < 1 ||
          dInt > 31 ||
          mInt < 1 ||
          mInt > 12 ||
          yInt < 1900 ||
          yInt > DateTime.now().year) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ngày sinh hoặc tháng hoặc năm không hợp lệ.'),
          ),
        );
        return;
      }
    }
    final dobText = _getFormattedDob();

    final startCohort = _cohortStartController.text.trim();
    final endCohort = _cohortEndController.text.trim();

    // Validate Cohort
    if (startCohort.isNotEmpty || endCohort.isNotEmpty) {
      if (startCohort.length != 4 || endCohort.length != 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Niên khóa không hợp lệ (mỗi năm phải đủ 4 chữ số).'),
          ),
        );
        return;
      }
      final sInt = int.tryParse(startCohort) ?? 0;
      final eInt = int.tryParse(endCohort) ?? 0;
      if (sInt >= eInt) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Năm bắt đầu niên khóa phải bé hơn năm kết thúc.'),
          ),
        );
        return;
      }
    }
    final cohortText = _getFormattedCohort();

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

      final Map<String, dynamic> updateData = {
        'displayName': _nameController.text.trim(),
        'dob': dobText,
        'faculty': selectedFaculty,
        'university': selectedUniversity,
        'photoUrl': finalPhotoBase64,
        'studentId': _studentIdController.text.trim(),
        'cohort': cohortText,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(updateData, SetOptions(merge: true));

      // Sync name & avatar changes to forum posts, study materials, and comments
      final newName = _nameController.text.trim();
      final newAvatar = finalPhotoBase64;
      if (newName != _initialName || newAvatar != _initialPhotoBase64) {
        await _syncProfileToPostsAndComments(uid, newName, newAvatar);
      }

      if (mounted) {
        // Reset initial values after saving to avoid "unsaved changes" dialog when popping
        setState(() {
          _initialName = _nameController.text.trim();
          _initialDob = dobText;
          _initialFaculty = selectedFaculty;
          _initialUniversity = selectedUniversity;
          _initialStudentId = _studentIdController.text.trim();
          _initialCohort = cohortText;
          _initialPhotoBase64 = finalPhotoBase64;
          _imageFile = null;
          _currentPhotoBase64 = finalPhotoBase64;
        });

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật hồ sơ thành công!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncProfileToPostsAndComments(
    String uid,
    String newName,
    String? newAvatar,
  ) async {
    final firestore = FirebaseFirestore.instance;

    // 1. Sync forum_posts (only non-anonymous posts)
    try {
      final forumQuery = await firestore
          .collection('forum_posts')
          .where('authorId', isEqualTo: uid)
          .get();

      if (forumQuery.docs.isNotEmpty) {
        WriteBatch batch = firestore.batch();
        int count = 0;
        for (var doc in forumQuery.docs) {
          final data = doc.data();
          if (data['isAnonymous'] != true) {
            batch.update(doc.reference, {
              'authorName': newName,
              'authorAvatar': newAvatar,
            });
            count++;
            if (count >= 400) {
              await batch.commit();
              batch = firestore.batch();
              count = 0;
            }
          }
        }
        if (count > 0) {
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint("Lỗi đồng bộ forum_posts: $e");
    }

    // 2. Sync study_materials
    try {
      final materialsQuery = await firestore
          .collection('study_materials')
          .where('authorId', isEqualTo: uid)
          .get();

      if (materialsQuery.docs.isNotEmpty) {
        WriteBatch batch = firestore.batch();
        int count = 0;
        for (var doc in materialsQuery.docs) {
          batch.update(doc.reference, {
            'authorName': newName,
            'authorAvatar': newAvatar,
          });
          count++;
          if (count >= 400) {
            await batch.commit();
            batch = firestore.batch();
            count = 0;
          }
        }
        if (count > 0) {
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint("Lỗi đồng bộ study_materials: $e");
    }

    // 3. Sync comments (collection group query for all comment subcollections)
    try {
      final commentsQuery = await firestore
          .collectionGroup('comments')
          .where('authorId', isEqualTo: uid)
          .get();

      if (commentsQuery.docs.isNotEmpty) {
        WriteBatch batch = firestore.batch();
        int count = 0;
        for (var doc in commentsQuery.docs) {
          batch.update(doc.reference, {
            'authorName': newName,
            'authorAvatar': newAvatar,
          });
          count++;
          if (count >= 400) {
            await batch.commit();
            batch = firestore.batch();
            count = 0;
          }
        }
        if (count > 0) {
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint("Lỗi đồng bộ comments: $e");
    }

    // 4. Sync chat_rooms participantPhotos and participantNames
    try {
      final chatRoomsQuery = await firestore
          .collection('chat_rooms')
          .where('participants', arrayContains: uid)
          .get();

      if (chatRoomsQuery.docs.isNotEmpty) {
        WriteBatch batch = firestore.batch();
        int count = 0;
        for (var doc in chatRoomsQuery.docs) {
          batch.update(doc.reference, {
            'participantNames.$uid': newName,
            'participantPhotos.$uid': newAvatar ?? '',
          });
          count++;
          if (count >= 400) {
            await batch.commit();
            batch = firestore.batch();
            count = 0;
          }
        }
        if (count > 0) {
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint("Lỗi đồng bộ chat_rooms: $e");
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

  InputDecoration _dobPartDecoration(BuildContext context, String hint) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6797E1), width: 1.4),
      ),
    );
  }

  Widget _buildDateOfBirthCard(BuildContext context) {
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
              Icons.cake_outlined,
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
                  'Ngày sinh',
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? Colors.white70
                        : const Color(0xFF344054),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    SizedBox(
                      width: 55,
                      child: TextField(
                        controller: _dobDayController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        onChanged: (value) {
                          if (value.length == 2) {
                            FocusScope.of(context).nextFocus();
                          }
                        },
                        style: const TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _dobPartDecoration(context, 'dd'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        '-',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      width: 55,
                      child: TextField(
                        controller: _dobMonthController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        onChanged: (value) {
                          if (value.length == 2) {
                            FocusScope.of(context).nextFocus();
                          }
                        },
                        style: const TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _dobPartDecoration(context, 'mm'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        '-',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      width: 75,
                      child: TextField(
                        controller: _dobYearController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        style: const TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _dobPartDecoration(context, 'yyyy'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCohortCard(BuildContext context, {bool enabled = false}) {
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
                  'Niên khóa',
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? Colors.white70
                        : const Color(0xFF344054),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    SizedBox(
                      width: 75,
                      child: TextField(
                        controller: _cohortStartController,
                        enabled: enabled,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        onChanged: (value) {
                          if (value.length == 4) {
                            FocusScope.of(context).nextFocus();
                          }
                        },
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? (isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1F2937))
                              : (isDarkMode ? Colors.white38 : Colors.black38),
                        ),
                        decoration: _dobPartDecoration(context, 'yyyy'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        '-',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      width: 75,
                      child: TextField(
                        controller: _cohortEndController,
                        enabled: enabled,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? (isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1F2937))
                              : (isDarkMode ? Colors.white38 : Colors.black38),
                        ),
                        decoration: _dobPartDecoration(context, 'yyyy'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
                    color: isDarkMode
                        ? Colors.white70
                        : const Color(0xFF344054),
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

  Widget _buildUniversityDropdownCard(BuildContext context) {
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
              Icons.location_on_outlined,
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
                  'Cơ sở học tập',
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? Colors.white70
                        : const Color(0xFF344054),
                  ),
                ),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  initialValue: selectedUniversity,
                  isExpanded: true,
                  dropdownColor: isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : Colors.white,
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
                    "Chọn cơ sở",
                    style: TextStyle(
                      color: isDarkMode ? Colors.white24 : Colors.black26,
                      fontSize: 14,
                      fontFamily: 'Encode Sans Expanded',
                    ),
                  ),
                  selectedItemBuilder: (context) {
                    return universities.map((u) {
                      return Text(
                        u,
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
                  items: universities.map((u) {
                    return DropdownMenuItem(
                      value: u,
                      child: Text(
                        u,
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedUniversity = val),
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
                    color: isDarkMode
                        ? Colors.white70
                        : const Color(0xFF344054),
                  ),
                ),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  initialValue: selectedFaculty,
                  isExpanded: true,
                  dropdownColor: isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : Colors.white,
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
        backgroundColor: isDarkMode
            ? const Color(0xFF0F1113)
            : const Color(0xFFF8FAFC),
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
                        color: isDarkMode
                            ? const Color(0xFF15171A)
                            : Colors.white,
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
                        _buildTextFieldCard(
                          context,
                          icon: Icons.email_outlined,
                          label: 'Email',
                          controller: _emailController,
                          enabled: false,
                        ),
                        _buildDateOfBirthCard(context),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _buildSectionTitle('Học tập', isDarkMode),
                    _buildGroup(
                      isDarkMode: isDarkMode,
                      children: [
                        _buildUniversityDropdownCard(context),
                        _buildDropdownFieldCard(context, 'Khoa'),
                        _buildTextFieldCard(
                          context,
                          icon: Icons.badge_outlined,
                          label: 'MSSV',
                          controller: _studentIdController,
                          enabled: false,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        _buildCohortCard(context, enabled: false),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6797E1),
                          disabledBackgroundColor: const Color(
                            0xFF6797E1,
                          ).withOpacity(0.5),
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
                  child: CircularProgressIndicator(color: Color(0xFF6797E1)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
