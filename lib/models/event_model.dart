import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final DateTime dateTime;
  final String location;
  final String reminder;
  final String description;
  final int? notificationId;
  final String? sourceArticleUrl;
  final String? facultyEventId;
  final bool isFromFacultyEvent;

  EventModel({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.location,
    required this.reminder,
    required this.description,
    this.notificationId,
    this.sourceArticleUrl,
    this.facultyEventId,
    this.isFromFacultyEvent = false,
  });

  // Chuyển đổi từ Firestore Document thành EventModel
  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final fId = data['facultyEventId']?.toString();
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      // Firestore Timestamp -> Dart DateTime
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      location: data['location'] ?? '',
      reminder: data['reminder'] ?? 'Không',
      description: data['description'] ?? '',
      notificationId: data['notificationId'],
      sourceArticleUrl: (data['sourceArticleUrl'] ?? data['link'] ?? data['registrationUrl'])?.toString(),
      facultyEventId: fId,
      isFromFacultyEvent: data['isFromFacultyEvent'] == true || (fId != null && fId.isNotEmpty),
    );
  }

  // Chuyển đổi từ EventModel thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'dateTime': Timestamp.fromDate(dateTime),
      'location': location,
      'reminder': reminder,
      'description': description,
      'notificationId': notificationId,
      'sourceArticleUrl': sourceArticleUrl,
      'facultyEventId': facultyEventId,
      'isFromFacultyEvent': isFromFacultyEvent,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}