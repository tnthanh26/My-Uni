import 'package:cloud_firestore/cloud_firestore.dart';

class ModNotificationService {
  static Future<void> sendPostNotification({
    required String userId,
    required String title,
    required String content,
    required String type,
    required String postId,
    required String collectionPath,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': title,
      'content': content,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'relatedPostId': postId,
      'collectionPath': collectionPath,
    });
  }

  static Future<void> sendUserNotification({
    required String userId,
    required String title,
    required String content,
    required String type,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': title,
      'content': content,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'relatedPostId': null,
      'collectionPath': 'users',
    });
  }
}