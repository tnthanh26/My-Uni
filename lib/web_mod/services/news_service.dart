import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NewsService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Stream news created by current collaborator from both collections.
  static Stream<List<Map<String, dynamic>>> getMyNews() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    final controller =
    StreamController<List<Map<String, dynamic>>>.broadcast();

    List<Map<String, dynamic>> officialItems = [];
    List<Map<String, dynamic>> facultyItems = [];

    void emitCombined() {
      final results = <Map<String, dynamic>>[
        ...officialItems,
        ...facultyItems,
      ];

      results.sort((a, b) {
        DateTime getDateTime(Map<String, dynamic> item) {
          final value =
              item['createdAt'] ?? item['publishedAt'] ?? item['timestamp'];

          if (value is Timestamp) return value.toDate();
          if (value is DateTime) return value;

          return DateTime.fromMillisecondsSinceEpoch(0);
        }

        return getDateTime(b).compareTo(getDateTime(a));
      });

      if (!controller.isClosed) {
        controller.add(results);
      }
    }

    Query<Map<String, dynamic>> ownedQuery(String collectionPath) {
      final email = user.email?.trim() ?? '';

      if (email.isEmpty) {
        return _firestore
            .collection(collectionPath)
            .where('createdBy', isEqualTo: user.uid);
      }

      return _firestore.collection(collectionPath).where(
        Filter.or(
          Filter('createdBy', isEqualTo: user.uid),
          Filter('createdByEmail', isEqualTo: email),
        ),
      );
    }

    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
    officialSubscription;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
    facultySubscription;

    officialSubscription =
        ownedQuery('official_news').snapshots().listen((snapshot) {
          officialItems = snapshot.docs.map((doc) {
            return {
              ...doc.data(),
              'docId': doc.id,
              'collectionPath': 'official_news',
            };
          }).toList();

          emitCombined();
        }, onError: controller.addError);

    facultySubscription =
        ownedQuery('faculty_official_news').snapshots().listen((snapshot) {
          facultyItems = snapshot.docs.map((doc) {
            return {
              ...doc.data(),
              'docId': doc.id,
              'collectionPath': 'faculty_official_news',
            };
          }).toList();

          emitCombined();
        }, onError: controller.addError);

    controller.onCancel = () async {
      await officialSubscription.cancel();
      await facultySubscription.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Create news entry in `official_news` or `faculty_official_news`.
  static Future<void> createNews({
    required bool isFacultyNews,
    String? facultyId,
    String? facultyCode,
    String? facultyName,
    required String title,
    required String summary,
    required String content,
    required String department,
    required List<String> hashtags,
    String? imageUrl,
    String imageSource = 'none',
    String? link,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Chưa đăng nhập.');
    }

    final cleanTitle = title.trim();
    final cleanSummary = summary.trim();
    final cleanContent = content.trim();
    final cleanDepartment = department.trim();
    final cleanImageUrl = imageUrl?.trim() ?? '';
    final cleanLink = link?.trim() ?? '';

    if (cleanTitle.isEmpty) {
      throw Exception('Tiêu đề bài viết không được để trống.');
    }

    if (cleanSummary.isEmpty && cleanContent.isEmpty) {
      throw Exception('Bài viết phải có tóm tắt hoặc nội dung.');
    }

    if (cleanDepartment.isEmpty) {
      throw Exception('Đơn vị đăng tin không được để trống.');
    }

    if (isFacultyNews &&
        ((facultyId?.trim().isEmpty ?? true) ||
            (facultyCode?.trim().isEmpty ?? true) ||
            (facultyName?.trim().isEmpty ?? true))) {
      throw Exception('Thiếu thông tin khoa phát hành.');
    }

    final now = DateTime.now();
    final publishedDateKey = DateFormat('yyyy-MM-dd').format(now);
    final publishedDateText = DateFormat('dd/MM/yyyy').format(now);

    final targetCollection =
    isFacultyNews ? 'faculty_official_news' : 'official_news';

    final cleanFacultyId = facultyId?.trim();
    final cleanFacultyCode = facultyCode?.trim();
    final cleanFacultyName = facultyName?.trim();

    final fallbackAuthorName = isFacultyNews
        ? (cleanFacultyName ?? cleanDepartment)
        : 'HCMUS Official';

    final authorName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : fallbackAuthorName;

    final authorAvatar = user.photoURL?.trim() ?? '';

    final normalizedHashtags = hashtags
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

    final normalizedImageSource =
    cleanImageUrl.isEmpty ? 'none' : imageSource.trim();

    final docData = <String, dynamic>{
      'authorAvatar': authorAvatar,
      'authorId': user.uid,
      'authorName': authorName,
      'category': isFacultyNews ? 'faculty_news' : 'student_info',
      'collectionPath': targetCollection,
      'commentCount': 0,
      'content': cleanContent.isNotEmpty ? cleanContent : cleanSummary,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      'createdByEmail': user.email?.trim() ?? '',
      'department': cleanDepartment,
      'hashtags': normalizedHashtags,
      'imageSource': normalizedImageSource,
      'imageUrl': cleanImageUrl,
      'imageUrls': cleanImageUrl.isEmpty ? <String>[] : [cleanImageUrl],
      'likeCount': 0,
      'link': cleanLink,
      'publishedAt': FieldValue.serverTimestamp(),
      'publishedDateKey': publishedDateKey,
      'publishedDateText': publishedDateText,
      'saveType': isFacultyNews ? 'faculty' : 'general',
      'source': 'collaborator',
      'sourceArticleUrl': cleanLink,
      'sourceName': isFacultyNews
          ? 'Cộng tác viên ${cleanFacultyName ?? cleanDepartment}'
          : cleanDepartment,
      'sourceUrl': cleanLink,
      'summary': cleanSummary.isNotEmpty ? cleanSummary : cleanContent,
      'thumbnailUrl': cleanImageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'title': cleanTitle,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isFacultyNews) {
      docData.addAll({
        'facultyId': cleanFacultyId,
        'facultyCode': cleanFacultyCode,
        'facultyName': cleanFacultyName,
      });
    }

    await _firestore.collection(targetCollection).add(docData);
  }

  /// Delete news created by current user.
  static Future<void> deleteNews({
    required String collectionPath,
    required String docId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Chưa đăng nhập.');
    }

    if (collectionPath != 'official_news' &&
        collectionPath != 'faculty_official_news') {
      throw Exception('Collection tin tức không hợp lệ.');
    }

    final docRef = _firestore.collection(collectionPath).doc(docId);
    final snap = await docRef.get();

    if (!snap.exists) {
      throw Exception('Bài viết không tồn tại.');
    }

    final data = snap.data();
    final createdBy = data?['createdBy']?.toString();
    final createdByEmail = data?['createdByEmail']?.toString();

    if (createdBy != user.uid && createdByEmail != user.email) {
      throw Exception(
        'Bạn không có quyền xóa bài viết này vì bạn không phải là tác giả.',
      );
    }

    await docRef.delete();
  }

  /// Update news created by current user.
  static Future<void> updateNews({
    required String collectionPath,
    required String docId,
    required String title,
    required String summary,
    required String content,
    required String department,
    String? imageUrl,
    String? link,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Chưa đăng nhập.');
    }

    if (collectionPath != 'official_news' &&
        collectionPath != 'faculty_official_news') {
      throw Exception('Collection tin tức không hợp lệ.');
    }

    final cleanTitle = title.trim();
    final cleanSummary = summary.trim();
    final cleanContent = content.trim();
    final cleanDepartment = department.trim();
    final cleanImageUrl = imageUrl?.trim() ?? '';
    final cleanLink = link?.trim() ?? '';

    if (cleanTitle.isEmpty) {
      throw Exception('Tiêu đề bài viết không được để trống.');
    }

    if (cleanSummary.isEmpty && cleanContent.isEmpty) {
      throw Exception('Bài viết phải có tóm tắt hoặc nội dung.');
    }

    if (cleanDepartment.isEmpty) {
      throw Exception('Đơn vị đăng tin không được để trống.');
    }

    final docRef = _firestore.collection(collectionPath).doc(docId);
    final snap = await docRef.get();

    if (!snap.exists) {
      throw Exception('Bài viết không tồn tại.');
    }

    final data = snap.data();
    final createdBy = data?['createdBy']?.toString();
    final createdByEmail = data?['createdByEmail']?.toString();

    if (createdBy != user.uid && createdByEmail != user.email) {
      throw Exception(
        'Bạn không có quyền chỉnh sửa bài viết này vì bạn không phải là tác giả.',
      );
    }

    final updateData = <String, dynamic>{
      'title': cleanTitle,
      'summary': cleanSummary.isNotEmpty ? cleanSummary : cleanContent,
      'content': cleanContent.isNotEmpty ? cleanContent : cleanSummary,
      'department': cleanDepartment,
      'imageUrl': cleanImageUrl,
      'thumbnailUrl': cleanImageUrl,
      'imageUrls': cleanImageUrl.isEmpty ? <String>[] : [cleanImageUrl],
      'link': cleanLink,
      'sourceArticleUrl': cleanLink,
      'sourceUrl': cleanLink,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.update(updateData);
  }
}