import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ActivityService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _activities =>
      _firestore.collection('student_activities');

  static CollectionReference<Map<String, dynamic>> get _facultyEvents =>
      _firestore.collection('faculty_events');

  static CollectionReference<Map<String, dynamic>> attendanceRef(String activityId) {
    return _activities.doc(activityId).collection('attendance');
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getMyActivities() {
    final user = _auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    final uid = user.uid;
    final email = user.email;

    Query<Map<String, dynamic>> query = _activities;

    if (email != null && email.isNotEmpty) {
      query = query.where(
        Filter.or(
          Filter('createdBy', isEqualTo: uid),
          Filter('createdByEmail', isEqualTo: email),
        ),
      );
    } else {
      query = query.where('createdBy', isEqualTo: uid);
    }

    return query
        .where('status', isNotEqualTo: 'deleted')
        .orderBy('status')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> deleteActivity(String activityId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Chưa đăng nhập.');
    }

    final docRef = _activities.doc(activityId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data();
    final createdBy = data?['createdBy']?.toString();
    final createdByEmail = data?['createdByEmail']?.toString();

    // Verify ownership
    if (createdBy != user.uid && createdByEmail != user.email) {
      throw Exception('Bạn không có quyền xóa hoạt động này vì bạn không phải là người tạo.');
    }

    // 1. Delete corresponding faculty_events doc if present
    final String? facultyEventId = data?['facultyEventId']?.toString();
    if (facultyEventId != null && facultyEventId.isNotEmpty) {
      try {
        await _facultyEvents.doc(facultyEventId).delete();
      } catch (e) {
        // Silently ignore if faculty event already deleted or not existing
      }
    }

    // 2. Query all attendance documents under this activity to clean up students' history
    final attendanceSnapshot = await attendanceRef(activityId).get();
    if (attendanceSnapshot.docs.isNotEmpty) {
      final batch = _firestore.batch();

      for (var doc in attendanceSnapshot.docs) {
        final attData = doc.data();
        String? studentUid = attData['uid']?.toString();
        final docId = doc.id;

        if (studentUid == null || studentUid.isEmpty) {
          if (docId.length == 28 || !RegExp(r'^\d+$').hasMatch(docId)) {
            studentUid = docId;
          }
        }

        if (studentUid != null && studentUid.isNotEmpty) {
          final userAttendedDoc = _firestore
              .collection('users')
              .doc(studentUid)
              .collection('attended_activities')
              .doc(activityId);
          batch.delete(userAttendedDoc);
        }

        batch.delete(doc.reference);
      }

      await batch.commit();
    }

    // 3. Delete main activity document from database
    await docRef.delete();
  }

  static Future<void> deleteAttendance(String activityId, String docId) async {
    final activityDoc = _activities.doc(activityId);
    final attendanceDoc = attendanceRef(activityId).doc(docId);

    await _firestore.runTransaction((transaction) async {
      final attendanceSnapshot = await transaction.get(attendanceDoc);

      if (!attendanceSnapshot.exists) return;

      final data = attendanceSnapshot.data();
      String? studentUid = data?['uid']?.toString();

      if (studentUid == null || studentUid.isEmpty) {
        if (docId.length == 28 || !RegExp(r'^\d+$').hasMatch(docId)) {
          studentUid = docId;
        }
      }

      transaction.delete(attendanceDoc);

      if (studentUid != null && studentUid.isNotEmpty) {
        final userAttendedDoc = _firestore
            .collection('users')
            .doc(studentUid)
            .collection('attended_activities')
            .doc(activityId);
        transaction.delete(userAttendedDoc);
      }

      transaction.update(activityDoc, {
        'attendanceCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> createActivity({
    required String title,
    required String description,
    required String location,
    required String organizerName,
    required int trainingPoint,
    required DateTime startTime,
    required DateTime endTime,
    bool requiresRegistration = false,
    List<String> registeredStudentIds = const [],
    String? imageUrl,
    String? contact,
    String facultyId = 'fit',
    String facultyCode = 'FIT',
    String facultyName = 'Khoa Công nghệ Thông tin',
    bool isOnline = false,
    String? onlineUrl,
    DateTime? registrationDeadline,
    String? registrationUrl,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Chưa đăng nhập.');
    }

    final cleanImageUrl = imageUrl?.trim() ?? '';
    final imageUrls = cleanImageUrl.isNotEmpty ? [cleanImageUrl] : <String>[];

    // Format eventDateText e.g. "09h30 - 10h30, 05/08/2026"
    final startTimeStr = DateFormat('HH:mm').format(startTime);
    final endTimeStr = DateFormat('HH:mm').format(endTime);
    final dateStr = DateFormat('dd/MM/yyyy').format(startTime);
    final eventDateTextStr = '$startTimeStr - $endTimeStr, $dateStr';

    final nowTs = FieldValue.serverTimestamp();

    // 1. Create document in `faculty_events` so students see it in the app
    final facultyEventDoc = await _facultyEvents.add({
      'aiExtractionVersion': 2,
      'articleType': 'invitation',
      'confidence': 1.0,
      'contact': contact ?? 'Liên hệ: $organizerName (${user.email ?? ""})',
      'createdAt': nowTs,
      'updatedAt': nowTs,
      'lastExtractedAt': nowTs,
      'description': description,
      'endAt': Timestamp.fromDate(endTime),
      'endDate': null,
      'endDateTime': endTime.toIso8601String(),
      'eventDateText': eventDateTextStr,
      'eventName': title,
      'eventStatus': 'upcoming',
      'evidence': <String>[
        '$organizerName tổ chức $title',
        'Thời gian: $eventDateTextStr',
        'Địa điểm: $location',
      ],
      'facultyCode': facultyCode,
      'facultyId': facultyId,
      'facultyName': facultyName,
      'imageUrls': imageUrls,
      'thumbnailUrl': cleanImageUrl,
      'isAllDay': false,
      'isOnline': isOnline,
      'isValidEvent': true,
      'locationAddress': '',
      'locationName': location,
      'missingFields': <String>[],
      'onlineUrl': isOnline ? (onlineUrl ?? location) : null,
      'organizer': organizerName,
      'registrationDeadline': registrationDeadline?.toIso8601String(),
      'registrationDeadlineAt': registrationDeadline != null
          ? Timestamp.fromDate(registrationDeadline)
          : null,
      'registrationUrl': registrationUrl ?? '',
      'rejectionReason': null,
      'shouldPublish': true,
      'source': 'collaborator',
      'sourceArticleUrl': registrationUrl ?? '',
      'sourceCandidateId': null,
      'sourceCollection': 'collaborator_created',
      'sourceName': organizerName,
      'startAt': Timestamp.fromDate(startTime),
      'startDate': null,
      'startDateTime': startTime.toIso8601String(),
      'createdBy': user.uid,
      'createdByEmail': user.email ?? '',
    });

    // 2. Create document in `student_activities` so attendance management works as before
    final studentActivityDoc = await _activities.add({
      'title': title,
      'description': description,
      'location': location,
      'organizerName': organizerName,
      'trainingPoint': trainingPoint,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': 'active',
      'requiresRegistration': requiresRegistration,
      'registeredStudentIds': registeredStudentIds,
      'imageUrl': cleanImageUrl,
      'facultyEventId': facultyEventDoc.id,
      'createdBy': user.uid,
      'createdByEmail': user.email ?? '',
      'createdAt': nowTs,
      'updatedAt': nowTs,
      'attendanceCount': 0,
    });

    // Link activityId back to faculty_events doc
    await facultyEventDoc.update({
      'activityId': studentActivityDoc.id,
    });
  }

  static Future<void> closeActivity(String activityId) async {
    await _activities.doc(activityId).update({
      'status': 'ended',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> reopenActivity(String activityId) async {
    await _activities.doc(activityId).update({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getAttendance(String activityId) {
    return attendanceRef(activityId)
        .orderBy('checkedInAt', descending: true)
        .snapshots();
  }

  static Future<bool> addAttendanceFromQr({
    required String activityId,
    required Map<String, dynamic> studentData,
    bool force = false,
  }) async {
    final checker = _auth.currentUser;

    final uid = studentData['uid']?.toString();
    final studentId = studentData['studentId']?.toString();

    if ((uid == null || uid.isEmpty) && (studentId == null || studentId.isEmpty)) {
      throw Exception('QR thiếu uid hoặc MSSV.');
    }

    final docId = (uid != null && uid.isNotEmpty) ? uid : studentId!;

    final activityDoc = _activities.doc(activityId);
    final attendanceDoc = attendanceRef(activityId).doc(docId);

    if (!force) {
      final activitySnapshot = await activityDoc.get();
      if (!activitySnapshot.exists) throw Exception('Hoạt động không tồn tại.');

      final activityData = activitySnapshot.data()!;
      final requiresRegistration = activityData['requiresRegistration'] ?? false;
      final registeredStudentIds =
          List<String>.from(activityData['registeredStudentIds'] ?? []);

      if (requiresRegistration) {
        if (studentId == null || !registeredStudentIds.contains(studentId)) {
          throw Exception('NOT_REGISTERED');
        }
      }
    }

    return _firestore.runTransaction<bool>((transaction) async {
      final activitySnapshot = await transaction.get(activityDoc);
      if (!activitySnapshot.exists) throw Exception('Hoạt động không tồn tại.');
      
      final activityData = activitySnapshot.data()!;
      final requiresRegistration = activityData['requiresRegistration'] ?? false;
      final registeredStudentIds =
          List<String>.from(activityData['registeredStudentIds'] ?? []);

      final attendanceSnapshot = await transaction.get(attendanceDoc);

      if (attendanceSnapshot.exists) {
        return false;
      }

      transaction.set(attendanceDoc, {
        'uid': uid,
        'studentId': studentId,
        'displayName': studentData['displayName'] ?? '',
        'faculty': studentData['faculty'] ?? '',
        'cohort': studentData['cohort'] ?? '',
        'university': studentData['university'] ?? '',
        'isVerified': studentData['isVerified'] ?? false,
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkedInBy': checker?.uid,
        'checkedInByEmail': checker?.email,
        'checkInMethod': 'student_qr',
        'isExtra': requiresRegistration && !registeredStudentIds.contains(studentId),
      });

      if (uid != null && uid.isNotEmpty) {
        final userAttendedDoc = _firestore
            .collection('users')
            .doc(uid)
            .collection('attended_activities')
            .doc(activityId);
        transaction.set(userAttendedDoc, {
          'activityId': activityId,
          'title': activityData['title'] ?? '',
          'trainingPoint': activityData['trainingPoint'] ?? 0,
          'organizerName': activityData['organizerName'] ?? '',
          'checkedInAt': FieldValue.serverTimestamp(),
          'checkInMethod': 'student_qr',
        });
      }

      transaction.update(activityDoc, {
        'attendanceCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  static Future<bool> checkInToEventFromStudent({
    required String activityId,
    required String studentUid,
    required Map<String, dynamic> studentData,
  }) async {
    final studentId = studentData['studentId']?.toString();
    if (studentId == null || studentId.isEmpty || studentId == 'Chưa cập nhật MSSV') {
      throw Exception('Vui lòng cập nhật MSSV trong trang Cá nhân trước khi điểm danh.');
    }

    final activityDoc = _activities.doc(activityId);
    final attendanceDoc = attendanceRef(activityId).doc(studentUid);
    final userAttendedDoc = _firestore
        .collection('users')
        .doc(studentUid)
        .collection('attended_activities')
        .doc(activityId);

    final activitySnapshot = await activityDoc.get();
    if (!activitySnapshot.exists) throw Exception('Hoạt động không tồn tại.');

    final activityData = activitySnapshot.data()!;
    final status = activityData['status'] ?? 'active';
    if (status != 'active') {
      throw Exception('Hoạt động này đã đóng check-in.');
    }

    final requiresRegistration = activityData['requiresRegistration'] ?? false;
    final registeredStudentIds =
        List<String>.from(activityData['registeredStudentIds'] ?? []);

    if (requiresRegistration && !registeredStudentIds.contains(studentId)) {
      await attendanceDoc.set({
        'uid': studentUid,
        'studentId': studentId,
        'displayName': studentData['displayName'] ?? '',
        'faculty': studentData['faculty'] ?? '',
        'cohort': studentData['cohort'] ?? '',
        'university': studentData['university'] ?? '',
        'isVerified': studentData['isVerified'] ?? false,
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkedInBy': studentUid,
        'checkedInByEmail': studentData['email'] ?? '',
        'checkInMethod': 'event_qr',
        'isExtra': true,
        'isApproved': false,
      });
      throw Exception('Chưa có ds đăng ký, vui lòng nhờ CTV xét duyệt');
    }

    return _firestore.runTransaction<bool>((transaction) async {
      final attendanceSnapshot = await transaction.get(attendanceDoc);
      if (attendanceSnapshot.exists) {
        return false;
      }

      transaction.set(attendanceDoc, {
        'uid': studentUid,
        'studentId': studentId,
        'displayName': studentData['displayName'] ?? '',
        'faculty': studentData['faculty'] ?? '',
        'cohort': studentData['cohort'] ?? '',
        'university': studentData['university'] ?? '',
        'isVerified': studentData['isVerified'] ?? false,
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkedInBy': studentUid,
        'checkedInByEmail': studentData['email'] ?? '',
        'checkInMethod': 'event_qr',
        'isExtra': false,
      });

      transaction.set(userAttendedDoc, {
        'activityId': activityId,
        'title': activityData['title'] ?? '',
        'trainingPoint': activityData['trainingPoint'] ?? 0,
        'organizerName': activityData['organizerName'] ?? '',
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkInMethod': 'event_qr',
      });

      transaction.update(activityDoc, {
        'attendanceCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  static Future<void> approveAttendanceRequest({
    required String activityId,
    required String studentUid,
    required Map<String, dynamic> studentData,
  }) async {
    final activityDoc = _activities.doc(activityId);
    final attendanceDoc = attendanceRef(activityId).doc(studentUid);
    final userAttendedDoc = _firestore
        .collection('users')
        .doc(studentUid)
        .collection('attended_activities')
        .doc(activityId);

    final activitySnapshot = await activityDoc.get();
    if (!activitySnapshot.exists) throw Exception('Hoạt động không tồn tại.');
    final activityData = activitySnapshot.data()!;

    await _firestore.runTransaction((transaction) async {
      transaction.update(attendanceDoc, {
        'isApproved': FieldValue.delete(),
        'checkedInAt': FieldValue.serverTimestamp(),
      });

      transaction.set(userAttendedDoc, {
        'activityId': activityId,
        'title': activityData['title'] ?? '',
        'trainingPoint': activityData['trainingPoint'] ?? 0,
        'organizerName': activityData['organizerName'] ?? '',
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkInMethod': 'event_qr',
      });

      transaction.update(activityDoc, {
        'attendanceCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> rejectAttendanceRequest({
    required String activityId,
    required String studentUid,
  }) async {
    await attendanceRef(activityId).doc(studentUid).delete();
  }

  static Future<void> updateActivity({
    required String activityId,
    required String title,
    required String description,
    required String location,
    required String organizerName,
    required int trainingPoint,
    required DateTime startTime,
    required DateTime endTime,
    bool requiresRegistration = false,
    String? imageUrl,
    bool isOnline = false,
    String? onlineUrl,
    DateTime? registrationDeadline,
    String? registrationUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Chưa đăng nhập.');
    }

    final docRef = _activities.doc(activityId);
    final snap = await docRef.get();
    if (!snap.exists) {
      throw Exception('Hoạt động không tồn tại.');
    }

    final data = snap.data();
    final createdBy = data?['createdBy']?.toString();
    final createdByEmail = data?['createdByEmail']?.toString();

    if (createdBy != user.uid && createdByEmail != user.email) {
      throw Exception('Bạn không có quyền sửa hoạt động này vì bạn không phải là người tạo.');
    }

    final cleanImageUrl = imageUrl?.trim() ?? '';
    final imageUrls = cleanImageUrl.isNotEmpty ? [cleanImageUrl] : <String>[];

    final startTimeStr = DateFormat('HH:mm').format(startTime);
    final endTimeStr = DateFormat('HH:mm').format(endTime);
    final dateStr = DateFormat('dd/MM/yyyy').format(startTime);
    final eventDateTextStr = '$startTimeStr - $endTimeStr, $dateStr';

    final nowTs = FieldValue.serverTimestamp();

    await docRef.update({
      'title': title,
      'description': description,
      'location': location,
      'organizerName': organizerName,
      'trainingPoint': trainingPoint,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'requiresRegistration': requiresRegistration,
      'imageUrl': cleanImageUrl,
      'updatedAt': nowTs,
    });

    final String? facultyEventId = data?['facultyEventId']?.toString();
    if (facultyEventId != null && facultyEventId.isNotEmpty) {
      try {
        await _facultyEvents.doc(facultyEventId).update({
          'eventName': title,
          'description': description,
          'locationAddress': '',
          'locationName': location,
          'evidence': <String>[
            '$organizerName tổ chức $title',
            'Thời gian: $eventDateTextStr',
            'Địa điểm: $location',
          ],
          'organizer': organizerName,
          'startAt': Timestamp.fromDate(startTime),
          'startDateTime': startTime.toIso8601String(),
          'endAt': Timestamp.fromDate(endTime),
          'endDateTime': endTime.toIso8601String(),
          'eventDateText': eventDateTextStr,
          'isOnline': isOnline,
          'onlineUrl': isOnline ? (onlineUrl ?? location) : null,
          'registrationDeadline': registrationDeadline?.toIso8601String(),
          'registrationDeadlineAt': registrationDeadline != null
              ? Timestamp.fromDate(registrationDeadline)
              : null,
          'registrationUrl': registrationUrl ?? '',
          'imageUrls': imageUrls,
          'thumbnailUrl': cleanImageUrl,
          'updatedAt': nowTs,
        });
      } catch (e) {
        // Silently ignore if faculty event fails to update
      }
    }
  }
}