// myspace_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Deadline {
  final String id;
  final String title;
  final String? description;
  final DateTime dueDate;
  final TimeOfDay dueTime;
  bool isCompleted;

  Deadline({
    required this.id,
    required this.title,
    this.description,
    required this.dueDate,
    required this.dueTime,
    this.isCompleted = false,
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
    };
  }
}

class StudyClass {
  final String id;
  final String name;
  final String start;
  final String end;
  final String room;
  final int weekday; // Giữ nguyên int: 2 cho T2, 3 cho T3...
  final Color color; // Giữ nguyên kiểu Color

  StudyClass({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.room,
    required this.weekday,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'start': start,
      'end': end,
      'room': room,
      'weekday': weekday, // Đẩy lên Firebase dạng int
      'colorValue': color.value, // Firebase không hiểu Color, nên ta lưu mã int của màu
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class AutoDeadlineConfig {
  final bool isEnabled;
  final String provider;
  final String emailAddress;
  final List<String> allowedSenders;
  final List<String> subjectKeywords;
  final bool onlyUnread;
  final bool includeAttachments;
  final bool permissionRequested;
  final bool permissionGranted;
  final DateTime? updatedAt;

  const AutoDeadlineConfig({
    required this.isEnabled,
    required this.provider,
    required this.emailAddress,
    required this.allowedSenders,
    required this.subjectKeywords,
    required this.onlyUnread,
    required this.includeAttachments,
    required this.permissionRequested,
    required this.permissionGranted,
    this.updatedAt,
  });

  factory AutoDeadlineConfig.empty({String emailAddress = ''}) {
    return AutoDeadlineConfig(
      isEnabled: false,
      provider: 'gmail',
      emailAddress: emailAddress,
      allowedSenders: const [],
      subjectKeywords: const [],
      onlyUnread: true,
      includeAttachments: false,
      permissionRequested: false,
      permissionGranted: false,
      updatedAt: null,
    );
  }

  AutoDeadlineConfig copyWith({
    bool? isEnabled,
    String? provider,
    String? emailAddress,
    List<String>? allowedSenders,
    List<String>? subjectKeywords,
    bool? onlyUnread,
    bool? includeAttachments,
    bool? permissionRequested,
    bool? permissionGranted,
    DateTime? updatedAt,
  }) {
    return AutoDeadlineConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      provider: provider ?? this.provider,
      emailAddress: emailAddress ?? this.emailAddress,
      allowedSenders: allowedSenders ?? this.allowedSenders,
      subjectKeywords: subjectKeywords ?? this.subjectKeywords,
      onlyUnread: onlyUnread ?? this.onlyUnread,
      includeAttachments: includeAttachments ?? this.includeAttachments,
      permissionRequested: permissionRequested ?? this.permissionRequested,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'provider': provider,
      'emailAddress': emailAddress,
      'allowedSenders': allowedSenders,
      'subjectKeywords': subjectKeywords,
      'onlyUnread': onlyUnread,
      'includeAttachments': includeAttachments,
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
      provider: map['provider'] ?? 'gmail',
      emailAddress: map['emailAddress'] ?? '',
      allowedSenders: List<String>.from(map['allowedSenders'] ?? const []),
      subjectKeywords: List<String>.from(map['subjectKeywords'] ?? const []),
      onlyUnread: map['onlyUnread'] ?? true,
      includeAttachments: map['includeAttachments'] ?? false,
      permissionRequested: map['permissionRequested'] ?? false,
      permissionGranted: map['permissionGranted'] ?? false,
      updatedAt: parsedUpdatedAt,
    );
  }
}
