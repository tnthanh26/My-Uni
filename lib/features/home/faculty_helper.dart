import 'package:flutter/material.dart';

class FacultyInfo {
  final String id;
  final String code;
  final String name;
  final String shortName;
  final IconData icon;
  final List<String> matchKeywords;

  const FacultyInfo({
    required this.id,
    required this.code,
    required this.name,
    required this.shortName,
    required this.icon,
    required this.matchKeywords,
  });
}

class FacultyHelper {
  // 3 Khoa hiện tại đang có dữ liệu crawling trong collection `faculty_official_news`
  static const List<FacultyInfo> activeFaculties = [
    FacultyInfo(
      id: 'fit',
      code: 'FIT',
      name: 'Khoa Công nghệ Thông tin',
      shortName: 'Khoa CNTT',
      icon: Icons.computer_rounded,
      matchKeywords: [
        'công nghệ thông tin',
        'cntt',
        'fit',
        'khoa công nghệ thông tin'
      ],
    ),
    FacultyInfo(
      id: 'chemistry',
      code: 'CHEM',
      name: 'Khoa Hóa học',
      shortName: 'Khoa Hóa',
      icon: Icons.science_rounded,
      matchKeywords: [
        'hóa học',
        'chem',
        'chemistry',
        'khoa hóa học',
        'hóa'
      ],
    ),
    FacultyInfo(
      id: 'physics',
      code: 'PHYS',
      name: 'Khoa Vật lý - Vật lý Kỹ thuật',
      shortName: 'Khoa Vật lý',
      icon: Icons.bolt_rounded,
      matchKeywords: [
        'vật lý',
        'phys',
        'physics',
        'vật lý – vật lý kỹ thuật',
        'vật lý - vật lý kỹ thuật',
        'khoa vật lý - vật lý kỹ thuật'
      ],
    ),
  ];

  // Tất cả các Khoa của HCMUS được dùng khi đăng ký / chỉnh sửa tài khoản
  static const List<String> allHcmusFaculties = [
    'Công nghệ thông tin',
    'Hóa học',
    'Vật lý – Vật lý Kỹ thuật',
    'Địa chất',
    'Điện tử – Viễn thông',
    'Khoa học và Công nghệ Vật liệu',
    'Khoa Môi trường',
    'Sinh học – Công nghệ Sinh học',
    'Khoa học Liên ngành',
    'Toán – Tin học',
  ];

  /// Khớp tên Khoa được lưu trong tài khoản user sang `FacultyInfo` (nếu nằm trong 3 khoa active)
  static FacultyInfo? findFacultyByAccountString(String? facultyStr) {
    if (facultyStr == null ||
        facultyStr.trim().isEmpty ||
        facultyStr == 'Chưa cập nhật khoa') {
      return null;
    }
    final lower = facultyStr.trim().toLowerCase();

    for (final f in activeFaculties) {
      if (f.id.toLowerCase() == lower ||
          f.code.toLowerCase() == lower ||
          f.name.toLowerCase() == lower) {
        return f;
      }
      for (final kw in f.matchKeywords) {
        if (lower.contains(kw) || kw.contains(lower)) {
          return f;
        }
      }
    }
    return null;
  }

  /// Tìm `FacultyInfo` theo ID (fit, chemistry, physics)
  static FacultyInfo? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final f in activeFaculties) {
      if (f.id.toLowerCase() == id.toLowerCase()) return f;
    }
    return null;
  }
}
