import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModLogService {
  static Future<void> addUserActionLog({
    required String targetUserId,
    required String targetUserEmail,
    required String action,
    required String reason,
  }) async {
    final mod = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('moderation_logs').add({
      'targetUserId': targetUserId,
      'targetUserEmail': targetUserEmail,
      'action': action,
      'reason': reason,
      'modId': mod?.uid,
      'modEmail': mod?.email,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}