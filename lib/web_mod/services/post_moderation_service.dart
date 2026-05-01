import 'package:cloud_firestore/cloud_firestore.dart';

class PostModerationService {
  static Future<void> approvePost({
    required String collection,
    required String docId,
  }) async {
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(docId)
        .update({
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deletePost({
    required String collection,
    required String docId,
  }) async {
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(docId)
        .update({
      'status': 'hidden',
      'isReported': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> restorePost({
    required String collection,
    required String docId,
  }) async {
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(docId)
        .update({
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> dismissReport({
    required String collection,
    required String docId,
  }) async {
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(docId)
        .update({
      'isReported': false,
      'reportCount': 0,
    });
  }
}