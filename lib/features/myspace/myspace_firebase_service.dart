import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/myspace_models.dart';

class MySpaceFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get userId => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference get _deadlineRef =>
      _db.collection('users').doc(userId).collection('deadlines');

  CollectionReference get _scheduleRef =>
      _db.collection('users').doc(userId).collection('schedule');

  DocumentReference get _autoDeadlineConfigRef =>
      _db.collection('users').doc(userId).collection('settings').doc('auto_deadline_config');

  // --- DEADLINES ---
  Future<void> saveDeadline(Deadline d) async {
    if (userId == null) return;
    await _deadlineRef.doc(d.id).set({
      'title': d.title,
      'description': d.description,
      'dueDate': d.dueDate.toIso8601String(),
      'dueTimeHour': d.dueTime.hour,
      'dueTimeMinute': d.dueTime.minute,
      'isCompleted': d.isCompleted,
      'isMoodleSynced': d.isMoodleSynced,
      'reminders': d.reminders,
      'notificationIds': d.notificationIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Deadline>> getDeadlines() async {
    if (userId == null) return [];
    try {
      final snapshot = await _deadlineRef.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _mapDataToDeadline(doc.id, data);
      }).toList();
    } catch (e) {
      debugPrint("Error fetching deadlines: $e");
      return [];
    }
  }

  Future<void> deleteDeadline(String id) async {
    await _deadlineRef.doc(id).delete();
  }

  // --- SCHEDULE ---
  Future<void> saveSchedule(StudyClass s) async {
    if (userId == null) return;
    await _scheduleRef.doc(s.id).set({
      'name': s.name,
      'start': s.start,
      'end': s.end,
      'room': s.room,
      'weekday': s.weekday,
      'colorValue': s.color.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<StudyClass>> getSchedule() async {
    if (userId == null) return [];
    try {
      final snapshot = await _scheduleRef
          .orderBy('weekday')
          .orderBy('start')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StudyClass(
          id: doc.id,
          name: data['name']?.toString() ?? '',
          start: data['start']?.toString() ?? '',
          end: data['end']?.toString() ?? '',
          room: data['room']?.toString() ?? '',
          weekday: data['weekday'] ?? 2,
          color: Color(data['colorValue'] ?? 0xFF5893D8),
        );
      }).toList();
    } catch (e) {
      debugPrint("Error fetching schedule: $e");
      return [];
    }
  }

  Future<void> deleteSchedule(String id) async {
    await _scheduleRef.doc(id).delete();
  }

  Future<void> syncAllDeadlines(List<Deadline> localDeadlines) async {
    if (userId == null || localDeadlines.isEmpty) return;

    final batch = _db.batch();
    for (var d in localDeadlines) {
      final docRef = _deadlineRef.doc(d.id);
      batch.set(docRef, {
        'title': d.title,
        'description': d.description,
        'dueDate': d.dueDate.toIso8601String(),
        'dueTimeHour': d.dueTime.hour,
        'dueTimeMinute': d.dueTime.minute,
        'isCompleted': d.isCompleted,
        'isMoodleSynced': d.isMoodleSynced,
        'reminders': d.reminders,
        'notificationIds': d.notificationIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> syncAllSchedule(List<StudyClass> localSchedule) async {
    if (userId == null || localSchedule.isEmpty) return;

    final batch = _db.batch();
    for (var s in localSchedule) {
      final docRef = _scheduleRef.doc(s.id);
      batch.set(docRef, {
        'name': s.name,
        'start': s.start,
        'end': s.end,
        'room': s.room,
        'weekday': s.weekday,
        'colorValue': s.color.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> saveAutoDeadlineConfig(AutoDeadlineConfig config) async {
    if (userId == null) return;
    await _autoDeadlineConfigRef.set(config.toMap(), SetOptions(merge: true));
  }

  Future<AutoDeadlineConfig?> getAutoDeadlineConfig() async {
    if (userId == null) return null;
    try {
      final snapshot = await _autoDeadlineConfigRef.get();
      if (!snapshot.exists) return null;
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return null;
      return AutoDeadlineConfig.fromMap(data);
    } catch (e) {
      debugPrint("Error fetching auto deadline config: $e");
      return null;
    }
  }

  Stream<List<StudyClass>> scheduleStream() {
    if (userId == null) return Stream.value([]);
    return _scheduleRef.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StudyClass(
          id: doc.id,
          name: data['name']?.toString() ?? '',
          start: data['start']?.toString() ?? '',
          end: data['end']?.toString() ?? '',
          room: data['room']?.toString() ?? '',
          weekday: data['weekday'] ?? 2,
          color: Color(data['colorValue'] ?? 0xFF5893D8),
        );
      }).toList();
      list.sort((a, b) {
        final dayCompare = a.weekday.compareTo(b.weekday);
        if (dayCompare != 0) return dayCompare;
        return a.start.compareTo(b.start);
      });
      return list;
    });
  }

  Stream<List<Deadline>> deadlineStream() {
    if (userId == null) return Stream.value([]);
    return _deadlineRef
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _mapDataToDeadline(doc.id, data);
      }).toList();
    });
  }

  Deadline _mapDataToDeadline(String id, Map<String, dynamic> data) {
    DateTime parsedDate = DateTime.now();
    try {
      final rawDate = data['dueDate'];
      if (rawDate is String) {
        parsedDate = DateTime.parse(rawDate);
      } else if (rawDate is Timestamp) {
        parsedDate = rawDate.toDate();
      }
    } catch (_) {}

    return Deadline(
      id: id,
      title: data['title']?.toString() ?? 'Không tên',
      description: data['description']?.toString() ?? '',
      dueDate: parsedDate,
      dueTime: TimeOfDay(
        hour: data['dueTimeHour'] ?? 0,
        minute: data['dueTimeMinute'] ?? 0,
      ),
      isCompleted: data['isCompleted'] ?? false,
      isMoodleSynced: data['isMoodleSynced'] ?? false,
      reminders: List<String>.from(data['reminders'] ?? []),
      notificationIds: List<int>.from(data['notificationIds'] ?? []),
    );
  }
}