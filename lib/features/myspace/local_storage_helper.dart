import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/myspace_models.dart';

class LocalStorageHelper {
  static const String _deadlineKey = 'user_deadlines';
  static const String _scheduleKey = 'user_schedule';
  static const String _autoDeadlineConfigKey = 'auto_deadline_config';

  static List<Deadline> get _defaultDeadlines => [
    Deadline(
      id: "1",
      title: "Bài tập 1 CS101",
      dueDate: DateTime.now(),
      dueTime: const TimeOfDay(hour: 10, minute: 0),
      isCompleted: true,
    ),
    Deadline(
      id: "2",
      title: "Form khảo sát",
      dueDate: DateTime.now().add(const Duration(days: 2)),
      dueTime: const TimeOfDay(hour: 16, minute: 0),
    ),
    Deadline(
      id: "3",
      title: "Bài tập 2 CS101",
      dueDate: DateTime.now().add(const Duration(days: 4)),
      dueTime: const TimeOfDay(hour: 23, minute: 59),
    ),
  ];

  static List<StudyClass> get _defaultSchedule => [
    StudyClass(
      id: "1",
      name: "CS101 - Computer Science",
      start: "07:30",
      end: "09:10",
      room: "I21",
      weekday: 2,
      color: const Color(0xFFFFC374),
    ),
    StudyClass(
      id: "2",
      name: "Hệ điều hành",
      start: "09:30",
      end: "11:10",
      room: "C31",
      weekday: 3,
      color: Colors.blueAccent,
    ),
    StudyClass(
      id: "3",
      name: "Cấu trúc dữ liệu",
      start: "07:30",
      end: "09:10",
      room: "B22",
      weekday: 4,
      color: Colors.greenAccent,
    ),
  ];

  static Future<void> clearAutoDeadlineConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_autoDeadlineConfigKey);
  }

  // --- LƯU DEADLINES ---
  static Future<void> saveDeadlines(List<Deadline> deadlines) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      deadlines.map((d) => {
        'id': d.id,
        'title': d.title,
        'description': d.description,
        'dueDate': d.dueDate.toIso8601String(),
        'dueTimeHour': d.dueTime.hour,
        'dueTimeMinute': d.dueTime.minute,
        'isCompleted': d.isCompleted,
      }).toList(),
    );
    await prefs.setString(_deadlineKey, encodedData);
  }

  // --- LƯU SCHEDULE ---
  static Future<void> saveSchedule(List<StudyClass> schedule) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      schedule.map((c) => {
        'id': c.id,
        'name': c.name,
        'start': c.start,
        'end': c.end,
        'room': c.room,
        'weekday': c.weekday,
        'colorValue': c.color.value,
      }).toList(),
    );
    await prefs.setString(_scheduleKey, encodedData);
  }

  static Future<List<Deadline>> getDeadlines() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_deadlineKey);

    if (data == null || data == '[]') {
      return _defaultDeadlines; // Trả về đúng mẫu bạn đưa
    }

    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((item) => Deadline(
      id: item['id'],
      title: item['title'],
      description: item['description'] ?? "",
      dueDate: DateTime.parse(item['dueDate']),
      dueTime: TimeOfDay(hour: item['dueTimeHour'], minute: item['dueTimeMinute']),
      isCompleted: item['isCompleted'] ?? false,
    )).toList();
  }

  static Future<List<StudyClass>> getSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_scheduleKey);

    if (data == null || data == '[]') {
      return [];
    }

    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((item) => StudyClass(
      id: item['id'],
      name: item['name'],
      start: item['start'],
      end: item['end'],
      room: item['room'],
      weekday: item['weekday'],
      color: Color(item['colorValue']),
    )).toList();
  }

  static Future<void> saveAutoDeadlineConfig(AutoDeadlineConfig config) async {
    final prefs = await SharedPreferences.getInstance();

    final encodedData = jsonEncode({
      'isEnabled': config.isEnabled,
      'provider': config.provider,
      'moodleUrl': config.moodleUrl,
      'permissionRequested': config.permissionRequested,
      'permissionGranted': config.permissionGranted,
      'updatedAt': config.updatedAt?.toIso8601String(),
    });

    await prefs.setString(_autoDeadlineConfigKey, encodedData);
  }

  static Future<AutoDeadlineConfig> getAutoDeadlineConfig({
    String moodleUrl = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_autoDeadlineConfigKey);

    if (data == null || data.trim().isEmpty) {
      return AutoDeadlineConfig.empty(moodleUrl: moodleUrl);
    }

    final Map<String, dynamic> decoded =
    Map<String, dynamic>.from(jsonDecode(data));

    final config = AutoDeadlineConfig.fromMap(decoded);

    final String savedMoodleUrl = config.moodleUrl.trim();

    return config.copyWith(
      moodleUrl: savedMoodleUrl.isEmpty ? moodleUrl : savedMoodleUrl,
    );
  }

  // --- RESET DATA ---
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deadlineKey);
    await prefs.remove(_scheduleKey);
    await prefs.remove(_autoDeadlineConfigKey);
  }
}