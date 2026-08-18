import 'package:cloud_firestore/cloud_firestore.dart';

class MyUniNotification {
  final String id;
  final String? relatedPostId;
  final String? collectionPath;
  final String? reportedCommentId;
  final String? roomId;
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;
  final String type;
  final String title;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  MyUniNotification({
    this.relatedPostId,
    this.collectionPath,
    this.reportedCommentId,
    this.roomId,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });

  // Chuyển dữ liệu từ Firestore (Map) sang Object
  factory MyUniNotification.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return MyUniNotification(
      id: doc.id,
      relatedPostId: data['relatedPostId'],
      collectionPath: data['collectionPath'],
      reportedCommentId: data['reportedCommentId'],
      roomId: data['roomId'],
      senderId: data['senderId'],
      senderName: data['senderName'],
      senderAvatar: data['senderAvatar'],
      type: data['type'] ?? 'info',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }
}
