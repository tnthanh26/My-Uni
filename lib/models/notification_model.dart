import 'package:cloud_firestore/cloud_firestore.dart';

class MyUniNotification {
  final String id;
  final String type;
  final String title;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  MyUniNotification({
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
      type: data['type'] ?? 'info',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
    );
  }
}