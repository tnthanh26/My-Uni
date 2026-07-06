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
      'reportCount': 0,
      'hasReportedComments': false,
      'reportedCommentCount': 0,
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
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteComment({
    required String collection,
    required String postId,
    required String commentId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final repliesSnapshot = await firestore
        .collection(collection)
        .doc(postId)
        .collection('comments')
        .where('parentCommentId', isEqualTo: commentId)
        .get();

    final batch = firestore.batch();

    final commentRef = firestore
        .collection(collection)
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    batch.delete(commentRef);

    for (var doc in repliesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    int totalToDelete = 1 + repliesSnapshot.docs.length;
    final postRef = firestore.collection(collection).doc(postId);
    batch.update(postRef, {
      'commentCount': FieldValue.increment(-totalToDelete),
    });

    await batch.commit();

    await _refreshPostCommentReportState(
      collection: collection,
      postId: postId,
    );
  }

  static Future<void> dismissCommentReport({
    required String collection,
    required String postId,
    required String commentId,
  }) async {
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({
      'isReported': false,
      'reportCount': 0,
    });

    await _refreshPostCommentReportState(
      collection: collection,
      postId: postId,
    );
  }

  static Future<void> _refreshPostCommentReportState({
    required String collection,
    required String postId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final reportedComments = await firestore
        .collection(collection)
        .doc(postId)
        .collection('comments')
        .where('isReported', isEqualTo: true)
        .get();

    final validReportedCount = reportedComments.docs.where((doc) {
      final data = doc.data();
      final count = data['reportCount'] ?? 0;
      return count > 0;
    }).length;

    await firestore.collection(collection).doc(postId).update({
      'hasReportedComments': validReportedCount > 0,
      'reportedCommentCount': validReportedCount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}