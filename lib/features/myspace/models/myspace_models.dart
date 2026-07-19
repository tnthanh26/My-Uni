// myspace_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Deadline {
  final String id;
  final String title;
  final String? description;
  final DateTime dueDate;
  final TimeOfDay dueTime;
  final bool isMoodleSynced;
  bool isCompleted;
  final List<String> reminders;
  final List<int> notificationIds;

  Deadline({
    required this.id,
    required this.title,
    this.description,
    required this.dueDate,
    required this.dueTime,
    this.isCompleted = false,
    this.isMoodleSynced = false,
    this.reminders = const [],
    this.notificationIds = const [],
  });

  // Chuyển từ Object sang Map để đẩy lên Firebase
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'dueTimeHour': dueTime.hour,
      'dueTimeMinute': dueTime.minute,
      'isCompleted': isCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
      'isMoodleSynced': isMoodleSynced,
      'reminders': reminders,
      'notificationIds': notificationIds,
    };
  }
}

class StudyClass {
  final String id;
  final String name;
  final String start;
  final String end;
  final String room;
  final String? campusId;
  final int weekday; // Giữ nguyên int: 2 cho T2, 3 cho T3...
  final Color color; // Giữ nguyên kiểu Color

  StudyClass({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.room,
    this.campusId,
    required this.weekday,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'start': start,
      'end': end,
      'room': room,
      'campusId': campusId,
      'weekday': weekday, // Đẩy lên Firebase dạng int
      'colorValue': color.value, // Firebase không hiểu Color, nên ta lưu mã int của màu
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class AutoDeadlineConfig {
  final bool isEnabled;
  final String provider;
  final String moodleUrl;
  final bool permissionRequested;
  final bool permissionGranted;
  final DateTime? updatedAt;

  const AutoDeadlineConfig({
    required this.isEnabled,
    required this.provider,
    required this.moodleUrl,
    required this.permissionRequested,
    required this.permissionGranted,
    this.updatedAt,
  });

  factory AutoDeadlineConfig.empty({String moodleUrl = ''}) {
    return AutoDeadlineConfig(
      isEnabled: false,
      provider: 'moodle',
      moodleUrl: moodleUrl,
      permissionRequested: false,
      permissionGranted: false,
      updatedAt: null,
    );
  }

  AutoDeadlineConfig copyWith({
    bool? isEnabled,
    String? provider,
    String? moodleUrl,
    bool? permissionRequested,
    bool? permissionGranted,
    DateTime? updatedAt,
  }) {
    return AutoDeadlineConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      provider: provider ?? this.provider,
      moodleUrl: moodleUrl ?? this.moodleUrl,
      permissionRequested: permissionRequested ?? this.permissionRequested,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'provider': provider,
      'moodleUrl': moodleUrl,
      'permissionRequested': permissionRequested,
      'permissionGranted': permissionGranted,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory AutoDeadlineConfig.fromMap(Map<String, dynamic> map) {
    final dynamic rawUpdatedAt = map['updatedAt'];
    DateTime? parsedUpdatedAt;

    if (rawUpdatedAt is Timestamp) {
      parsedUpdatedAt = rawUpdatedAt.toDate();
    } else if (rawUpdatedAt is String && rawUpdatedAt.isNotEmpty) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt);
    }

    return AutoDeadlineConfig(
      isEnabled: map['isEnabled'] ?? false,
      provider: map['provider'] ?? 'moodle',
      moodleUrl: map['moodleUrl'] ?? '',

      permissionRequested: map['permissionRequested'] ?? false,
      permissionGranted: map['permissionGranted'] ?? false,
      updatedAt: parsedUpdatedAt,
    );
  }
}
