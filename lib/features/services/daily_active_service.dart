import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DailyActiveService {
  static Future<void> logDailyActiveUser() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(authUser.uid);

    final userSnap = await userRef.get();

    if (!userSnap.exists) return;

    final data = userSnap.data() ?? {};

    await FirebaseFirestore.instance
        .collection('daily_active_users')
        .doc(todayKey)
        .collection('users')
        .doc(authUser.uid)
        .set({
      'uid': authUser.uid,
      'displayName': data['displayName'] ?? authUser.displayName ?? '',
      'email': data['email'] ?? authUser.email ?? '',
      'studentId': data['studentId'] ?? '',
      'role': data['role'] ?? '',
      'university': data['university'] ?? '',
      'cohort': data['cohort'] ?? '',
      'verificationLevel': data['verificationLevel'] ?? '',
      'verificationMethod': data['verificationMethod'] ?? '',
      'status': data['status'] ?? '',
      'isVerified': data['isVerified'] ?? false,
      'lastActiveAt': FieldValue.serverTimestamp(),
      'dateKey': todayKey,
    }, SetOptions(merge: true));
  }
}