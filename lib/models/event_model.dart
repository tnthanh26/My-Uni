import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final DateTime dateTime;
  final String location;
  final String reminder;
  final String description;

  EventModel({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.location,
    required this.reminder,
    required this.description,
  });

  // Chuyển đổi từ Firestore Document thành EventModel
  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      // Firestore Timestamp -> Dart DateTime
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      location: data['location'] ?? '',
      reminder: data['reminder'] ?? 'None',
      description: data['description'] ?? '',
    );
  }

  // Chuyển đổi từ EventModel thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      // Dart DateTime -> Firestore Timestamp
      'dateTime': Timestamp.fromDate(dateTime),
      'location': location,
      'reminder': reminder,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(), // Lưu thời gian tạo
    };
  }
}