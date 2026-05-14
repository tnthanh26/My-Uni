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
    final uid = _auth.currentUser?.uid;

    return _activities
        .where('createdBy', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> createActivity({
    required String title,
    required String description,
    required String location,
    required String organizerName,
    required int trainingPoint,
    required DateTime startTime,
    required DateTime endTime,
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

  static Future<void> addAttendanceFromQr({
    required String activityId,
    required Map<String, dynamic> studentData,
  }) async {
    final checker = _auth.currentUser;

    final uid = studentData['uid'];
    final studentId = studentData['studentId'];

    if (uid == null && studentId == null) {
      throw Exception('QR thiếu uid hoặc MSSV.');
    }

    final docId = uid ?? studentId;

    await attendanceRef(activityId).doc(docId).set({
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
    }, SetOptions(merge: true));

    await _activities.doc(activityId).update({
      'attendanceCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}