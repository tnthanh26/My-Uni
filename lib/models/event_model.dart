import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final DateTime dateTime;
  final DateTime? endDateTime;
  final String location;
  final String reminder;
  final String description;
  final int? notificationId;
  final String? sourceArticleUrl;
  final String? onlineUrl;
  final bool isOnline;
  final String? facultyEventId;
  final bool isFromFacultyEvent;
  final String? contact;
  final String? facultyName;
  final String? imageUrl;

  EventModel({
    required this.id,
    required this.title,
    required this.dateTime,
    this.endDateTime,
    required this.location,
    required this.reminder,
    required this.description,
    this.notificationId,
    this.sourceArticleUrl,
    this.onlineUrl,
    this.isOnline = false,
    this.facultyEventId,
    this.isFromFacultyEvent = false,
    this.contact,
    this.facultyName,
    this.imageUrl,
  });

  // Chuyển đổi từ Firestore Document thành EventModel
  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final fId = data['facultyEventId']?.toString();
    final String? oUrl = (data['onlineUrl'] ?? data['onlineLink'])?.toString();
    final bool online = data['isOnline'] == true || (oUrl != null && oUrl.trim().isNotEmpty);
    DateTime? endDt;
    if (data['endDateTime'] != null && data['endDateTime'] is Timestamp) {
      endDt = (data['endDateTime'] as Timestamp).toDate();
    }
    final String? fName = (data['facultyName'] ?? data['department'] ?? data['organizer'] ?? data['organizerName'])?.toString();
    final String? imgUrl = (data['imageUrl'] ?? data['thumbnailUrl'] ?? data['bannerUrl'] ?? data['image'] ?? data['thumbnail'])?.toString();

    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      // Firestore Timestamp -> Dart DateTime
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      endDateTime: endDt,
      location: data['location'] ?? '',
      reminder: data['reminder'] ?? 'Không',
      description: data['description'] ?? '',
      notificationId: data['notificationId'],
      sourceArticleUrl: (data['sourceArticleUrl'] ?? data['link'] ?? data['registrationUrl'] ?? oUrl)?.toString(),
      onlineUrl: oUrl,
      isOnline: online,
      facultyEventId: fId,
      isFromFacultyEvent: fId != null && fId.trim().isNotEmpty,
      contact: (data['contact'] ?? data['organizer'] ?? data['organizerName'])?.toString(),
      facultyName: fName,
      imageUrl: imgUrl,
    );
  }

  // Chuyển đổi từ EventModel thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'dateTime': Timestamp.fromDate(dateTime),
      if (endDateTime != null) 'endDateTime': Timestamp.fromDate(endDateTime!),
      'location': location,
      'reminder': reminder,
      'description': description,
      'notificationId': notificationId,
      'sourceArticleUrl': sourceArticleUrl,
      'onlineUrl': onlineUrl,
      'isOnline': isOnline,
      'facultyEventId': facultyEventId,
      'isFromFacultyEvent': isFromFacultyEvent,
      if (contact != null) 'contact': contact,
      if (facultyName != null) 'facultyName': facultyName,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}