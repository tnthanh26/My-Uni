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

  static Future<void> deleteComment({
    required String collection,
    required String postId,
    required String commentId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    
    // Find replies
    final repliesSnapshot = await firestore
        .collection(collection)
        .doc(postId)
        .collection('comments')
        .where('parentCommentId', isEqualTo: commentId)
        .get();

    final batch = firestore.batch();

    // Delete the comment
    final commentRef = firestore
        .collection(collection)
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    
    batch.delete(commentRef);

    // Delete replies
    for (var doc in repliesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Decrement commentCount on the post
    int totalToDelete = 1 + repliesSnapshot.docs.length;
    final postRef = firestore.collection(collection).doc(postId);
    batch.update(postRef, {
      'commentCount': FieldValue.increment(-totalToDelete),
    });

    await batch.commit();
  }
}