import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _activities =>
      _firestore.collection('student_activities');

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
    // 1. Mark the activity as deleted in the main document
    await _activities.doc(activityId).update({
      'status': 'deleted',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Query all attendance documents under this activity to clean up students' history
    final attendanceSnapshot = await attendanceRef(activityId).get();
    if (attendanceSnapshot.docs.isNotEmpty) {
      final batch = _firestore.batch();

      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data();
        String? studentUid = data['uid']?.toString();
        final docId = doc.id;

        if (studentUid == null || studentUid.isEmpty) {
          // Fallback if uid field is empty but docId is a Firebase UID
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

        // Clean up the attendance subcollection document
        batch.delete(doc.reference);
      }

      await batch.commit();
    }
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
        // Fallback to docId if it looks like a Firebase UID
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
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Chưa đăng nhập.');
    }

    await _activities.add({
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
      'createdBy': user.uid,
      'createdByEmail': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'attendanceCount': 0,
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

      // Write to student's attended_activities history if uid exists
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

    // Get activity info to check registration & status
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
      // Create a pending attendance document in the attendance subcollection
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
        'isApproved': false, // Needs CTV approval
      });
      throw Exception('Chưa có ds đăng ký, vui lòng nhờ CTV xét duyệt');
    }

    return _firestore.runTransaction<bool>((transaction) async {
      final attendanceSnapshot = await transaction.get(attendanceDoc);
      if (attendanceSnapshot.exists) {
        return false; // Already checked in
      }

      // Add to event's attendance subcollection
      transaction.set(attendanceDoc, {
        'uid': studentUid,
        'studentId': studentId,
        'displayName': studentData['displayName'] ?? '',
        'faculty': studentData['faculty'] ?? '',
        'cohort': studentData['cohort'] ?? '',
        'university': studentData['university'] ?? '',
        'isVerified': studentData['isVerified'] ?? false,
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkedInBy': studentUid, // Checked in by self
        'checkedInByEmail': studentData['email'] ?? '',
        'checkInMethod': 'event_qr', // Scanned event QR code
        'isExtra': false,
      });

      // Add to student's history
      transaction.set(userAttendedDoc, {
        'activityId': activityId,
        'title': activityData['title'] ?? '',
        'trainingPoint': activityData['trainingPoint'] ?? 0,
        'organizerName': activityData['organizerName'] ?? '',
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkInMethod': 'event_qr',
      });

      // Increment count
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
      // 1. Update the attendance doc to remove 'isApproved' (meaning it's approved)
      transaction.update(attendanceDoc, {
        'isApproved': FieldValue.delete(),
        'checkedInAt': FieldValue.serverTimestamp(),
      });

      // 2. Add to student's history
      transaction.set(userAttendedDoc, {
        'activityId': activityId,
        'title': activityData['title'] ?? '',
        'trainingPoint': activityData['trainingPoint'] ?? 0,
        'organizerName': activityData['organizerName'] ?? '',
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkInMethod': 'event_qr',
      });

      // 3. Increment count
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
}