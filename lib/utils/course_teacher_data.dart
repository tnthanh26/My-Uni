import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CourseTeacherData {
  static final List<String> _customCourses = [];
  static final List<String> _customTeachers = [];

  static const List<String> defaultCourses = [
    'Nhập môn lập trình',
    'Kỹ thuật lập trình',
    'Cấu trúc dữ liệu và giải thuật',
    'Lập trình hướng đối tượng',
    'Cơ sở dữ liệu',
    'Hệ quản trị cơ sở dữ liệu',
    'Kiến trúc máy tính',
    'Hệ điều hành',
    'Mạng máy tính',
    'Nhập môn công nghệ phần mềm',
    'Phân tích thiết kế hệ thống thông tin',
    'Kiểm thử phần mềm',
    'Đảm bảo chất lượng phần mềm',
    'Thiết kế giao diện người dùng (UI/UX)',
    'Lập trình ứng dụng di động',
    'Lập trình ứng dụng Web',
    'Nhập môn Trí tuệ nhân tạo',
    'Học máy (Machine Learning)',
    'Học sâu (Deep Learning)',
    'Thị giác máy tính (Computer Vision)',
    'Xử lý ngôn ngữ tự nhiên (NLP)',
    'Nhập môn Khai thác dữ liệu',
    'An toàn và bảo mật thông tin',
    'Mạng máy tính nâng cao',
    'Điện toán đám mây (Cloud Computing)',
    'Phát triển hệ thống phân tán',
    'Toán rời rạc',
    'Lý thuyết đồ thị',
    'Xác suất thống kê ứng dụng trong CNTT',
    'Khóa luận tốt nghiệp / Đồ án tốt nghiệp',
  ];

  static const List<String> defaultTeachers = [
    'GS.TS. Lê Hoài Bắc',
    'PGS.TS. Vũ Hải Quân',
    'PGS.TS. Hồ Bảo Quốc',
    'PGS.TS. Đinh Điền',
    'PGS.TS. Nguyễn Đình Thúc',
    'PGS.TS. Lý Quốc Ngọc',
    'PGS.TS. Lê Hoàng Thái',
    'PGS.TS. Trần Minh Triết',
    'PGS.TS. Nguyễn Văn Vũ',
    'PGS.TS. Lê Nguyễn Hoài Nam',
    'TS. Đinh Bá Tiến',
    'TS. Bùi Tiến Lên',
    'TS. Lâm Quang Vũ',
    'TS. Châu Thành Đức',
    'TS. Lê Thị Nhàn',
    'TS. Ngô Huy Biên',
    'TS. Ngô Minh Nhựt',
    'TS. Nguyễn Đức Hoàng Hạ',
    'TS. Nguyễn Hải Minh',
    'TS. Nguyễn Ngọc Thảo',
    'TS. Nguyễn Thanh Phương',
    'TS. Nguyễn Thị Hồng Nhung',
    'TS. Nguyễn Thị Minh Tuyền',
    'TS. Phạm Nguyễn Cương',
    'TS. Nguyễn Trần Minh Thư',
    'TS. Nguyễn Trường Sơn',
    'TS. Phạm Thị Bạch Huệ',
    'TS. Trần Thái Sơn',
    'TS. Trần Trung Dũng',
    'TS. Võ Hoài Việt',
    'TS. Nguyễn Tiến Huy',
    'TS. Trương Toàn Thịnh',
    'TS. Lê Thanh Tùng',
    'TS. Lê Trung Nghĩa',
    'TS. Vũ Thị Mỹ Hằng',
    'TS. Lê Khánh Duy',
    'TS. Trần Duy Hoàng',
    'TS. Bùi Duy Đăng',
    'TS. Nguyễn Hồng Bửu Long',
    'TS. Lê Ngọc Thành',
    'TS. Cấn Trần Thành Trung',
    'TS. Bùi Văn Thạch',
    'TS. Trương Phước Hưng',
    'TS. Lê Trung Hoàng',
    'TS. Đỗ Đức Hào',
    'TS. Nguyễn Tuấn Nam',
  ];

  /// Lấy toàn bộ danh sách môn học (mặc định trong Code + môn bổ sung từ Firebase)
  static List<String> get hcmusCourses {
    final combined = List<String>.from(defaultCourses);
    for (var c in _customCourses) {
      if (!combined.contains(c)) {
        combined.add(c);
      }
    }
    return combined;
  }

  /// Lấy toàn bộ danh sách giảng viên (mặc định trong Code + giảng viên bổ sung từ Firebase)
  static List<String> get hcmusTeachers {
    final combined = List<String>.from(defaultTeachers);
    for (var t in _customTeachers) {
      if (!combined.contains(t)) {
        combined.add(t);
      }
    }
    return combined;
  }

  /// Đồng bộ danh sách từ Firestore collection: `hcmus_courses_teachers`
  /// 2 documents: `courses` và `teachers`
  static Future<void> initDynamicSync() async {
    try {
      final coursesDocRef = FirebaseFirestore.instance
          .collection('hcmus_courses_teachers')
          .doc('courses');
      final teachersDocRef = FirebaseFirestore.instance
          .collection('hcmus_courses_teachers')
          .doc('teachers');

      final coursesDoc = await coursesDocRef.get();
      final teachersDoc = await teachersDocRef.get();

      // Nếu doc courses chưa tồn tại trên Firebase, tự động tạo mới
      if (!coursesDoc.exists) {
        await coursesDocRef.set({
          'items': defaultCourses,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (coursesDoc.data()?['items'] is List) {
        _customCourses.clear();
        for (var item in coursesDoc.data()!['items']) {
          if (item != null && item.toString().trim().isNotEmpty) {
            _customCourses.add(item.toString().trim());
          }
        }
      }

      // Nếu doc teachers chưa tồn tại trên Firebase, tự động tạo mới
      if (!teachersDoc.exists) {
        await teachersDocRef.set({
          'items': defaultTeachers,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (teachersDoc.data()?['items'] is List) {
        _customTeachers.clear();
        for (var item in teachersDoc.data()!['items']) {
          if (item != null && item.toString().trim().isNotEmpty) {
            _customTeachers.add(item.toString().trim());
          }
        }
      }
    } catch (e) {
      debugPrint("Error syncing dynamic courses and teachers from Firebase: $e");
    }
  }

  /// Tự động cập nhật môn học / giảng viên lên Firebase
  static Future<void> addCustomItemToFirebase({
    String? newCourse,
    String? newTeacher,
  }) async {
    try {
      final String? c = (newCourse != null && newCourse.trim().isNotEmpty) ? newCourse.trim() : null;
      final String? t = (newTeacher != null && newTeacher.trim().isNotEmpty) ? newTeacher.trim() : null;

      // Cập nhật bộ nhớ tạm cục bộ trước để giao diện sinh viên mượt mà lập tức
      if (c != null && !_customCourses.contains(c) && !defaultCourses.contains(c)) {
        _customCourses.add(c);
      }
      if (t != null && !_customTeachers.contains(t) && !defaultTeachers.contains(t)) {
        _customTeachers.add(t);
      }

      if (c != null) {
        final coursesDocRef = FirebaseFirestore.instance
            .collection('hcmus_courses_teachers')
            .doc('courses');

        final coursesDoc = await coursesDocRef.get();
        if (!coursesDoc.exists) {
          final list = List<String>.from(defaultCourses);
          if (!list.contains(c)) list.add(c);
          await coursesDocRef.set({
            'items': list,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (!defaultCourses.contains(c)) {
          await coursesDocRef.set({
            'items': FieldValue.arrayUnion([c]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      if (t != null) {
        final teachersDocRef = FirebaseFirestore.instance
            .collection('hcmus_courses_teachers')
            .doc('teachers');

        final teachersDoc = await teachersDocRef.get();
        if (!teachersDoc.exists) {
          final list = List<String>.from(defaultTeachers);
          if (!list.contains(t)) list.add(t);
          await teachersDocRef.set({
            'items': list,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (!defaultTeachers.contains(t)) {
          await teachersDocRef.set({
            'items': FieldValue.arrayUnion([t]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint("Error pushing course/teacher to Firebase: $e");
    }
  }

  static List<String> filterCourses(String query) {
    if (query.trim().isEmpty) return hcmusCourses;
    final q = query.toLowerCase().trim();
    return hcmusCourses.where((c) => c.toLowerCase().contains(q)).toList();
  }

  static List<String> filterTeachers(String query) {
    if (query.trim().isEmpty) return hcmusTeachers;
    final q = query.toLowerCase().trim();
    return hcmusTeachers.where((t) => t.toLowerCase().contains(q)).toList();
  }
}
