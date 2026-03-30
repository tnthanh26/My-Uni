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