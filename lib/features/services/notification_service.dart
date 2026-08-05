import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../models/notification_model.dart';
import '../home/faculty_helper.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static const String _channelId = 'my_uni_urgent_channel_v3';
  static const String _channelName = 'MyUni Notifications';
  static const String _channelDescription = 'Thông báo nhắc nhở sự kiện MyUni';

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<bool> _isNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notificationsEnabled') ?? true;
  }

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notificationsPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('User clicked notification: ${details.payload}');
      },
    );

    if (kIsWeb) return;

    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await androidPlugin?.createNotificationChannel(channel);
      await androidPlugin?.requestNotificationsPermission();

      final bool? canSchedule =
      await androidPlugin?.canScheduleExactNotifications();

      if (canSchedule == false) {
        await androidPlugin?.requestExactAlarmsPermission();
      }
    }

    if (Platform.isIOS) {
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _auth.authStateChanges().listen((user) {
      if (user != null) {
        startFacultyEventListener();
        startNotificationsListener();
      } else {
        stopFacultyEventListener();
        stopNotificationsListener();
      }
    });

    if (_auth.currentUser != null) {
      startFacultyEventListener();
      startNotificationsListener();
    }
  }

  static StreamSubscription? _facultyEventsSubscription;
  static StreamSubscription? _userDocSubscription;
  static StreamSubscription? _userNotificationsSubscription;
  static final Set<String> _notifiedEventIds = {};
  static final Set<String> _notifiedDocIds = {};

  static void stopFacultyEventListener() {
    _facultyEventsSubscription?.cancel();
    _userDocSubscription?.cancel();
    _facultyEventsSubscription = null;
    _userDocSubscription = null;
  }

  static void stopNotificationsListener() {
    _userNotificationsSubscription?.cancel();
    _userNotificationsSubscription = null;
  }

  static void startNotificationsListener() {
    final user = _auth.currentUser;
    if (user == null) {
      stopNotificationsListener();
      return;
    }

    if (_userNotificationsSubscription != null) return;

    _userNotificationsSubscription = _db
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) async {
      final prefs = await SharedPreferences.getInstance();
      final List<String> cachedNotified =
          prefs.getStringList('notified_user_noti_ids') ?? [];
      _notifiedDocIds.addAll(cachedNotified);

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final String notiDocId = doc.id;
          final Map<String, dynamic>? data = doc.data();

          if (data == null || data['isRead'] == true) continue;
          if (_notifiedDocIds.contains(notiDocId)) continue;

          _notifiedDocIds.add(notiDocId);
          await prefs.setStringList(
            'notified_user_noti_ids',
            _notifiedDocIds.toList(),
          );

          final String title = (data['title'] ?? 'Thông báo mới').toString();
          final String content = (data['content'] ?? '').toString();

          int notiId = notiDocId.hashCode.abs() % 1000000;

          await showInstantNotification(
            id: notiId,
            title: title,
            body: content,
          );
        }
      }
    });
  }

  static void startFacultyEventListener() {
    final user = _auth.currentUser;
    if (user == null) {
      stopFacultyEventListener();
      return;
    }

    if (_facultyEventsSubscription != null) return;

    String? userFacultyStr;
    List<String> followedFaculties = [];

    _userDocSubscription = _db
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists) {
        final data = userDoc.data();
        userFacultyStr = data?['faculty']?.toString();
        followedFaculties = (data?['followedFaculties'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      }
    });

    _facultyEventsSubscription = _db
        .collection('faculty_events')
        .snapshots()
        .listen((snapshot) async {
      final prefs = await SharedPreferences.getInstance();
      final List<String> cachedNotified =
          prefs.getStringList('notified_faculty_event_ids') ?? [];
      _notifiedEventIds.addAll(cachedNotified);

      for (var change in snapshot.docChanges) {
        final doc = change.doc;
        final String docId = doc.id;
        final Map<String, dynamic>? data = doc.data();

        if (data == null || data['shouldPublish'] == false) {
          continue;
        }

        final bool isMatch = _matchesUserFaculties(
          data,
          userFacultyStr,
          followedFaculties,
        );

        if (!isMatch) continue;

        if (change.type == DocumentChangeType.added) {
          if (_notifiedEventIds.contains(docId)) continue;

          final DateTime? createdTime = _extractEventCreatedTime(data);
          if (createdTime != null &&
              DateTime.now().difference(createdTime).inHours.abs() > 48) {
            _notifiedEventIds.add(docId);
            continue;
          }

          _notifiedEventIds.add(docId);
          await prefs.setStringList(
            'notified_faculty_event_ids',
            _notifiedEventIds.toList(),
          );

          final String eventTitle =
              (data['eventName'] ?? data['title'] ?? 'Sự kiện sinh viên mới')
                  .toString();
          final String rawFaculty =
              (data['facultyName'] ?? data['department'] ?? 'Khoa')
                  .toString()
                  .trim();
          final String facultyName = rawFaculty.toLowerCase().startsWith('khoa ')
              ? rawFaculty
              : (rawFaculty.isNotEmpty ? 'Khoa $rawFaculty' : 'Khoa');
          final String eventDateText =
              (data['eventDateText'] ?? data['date'] ?? '').toString();
          final String locationName =
              (data['locationName'] ?? '').toString();

          String bodyStr = facultyName;
          if (eventDateText.isNotEmpty) bodyStr += ' • $eventDateText';
          if (locationName.isNotEmpty) bodyStr += ' • $locationName';

          try {
            final existing = await _db
                .collection('notifications')
                .where('userId', isEqualTo: user.uid)
                .where('relatedPostId', isEqualTo: docId)
                .limit(1)
                .get();

            if (existing.docs.isEmpty) {
              await _db.collection('notifications').add({
                'userId': user.uid,
                'title': '📌 Sự kiện mới: $eventTitle',
                'content': bodyStr,
                'type': 'faculty_event',
                'timestamp': FieldValue.serverTimestamp(),
                'isRead': false,
                'relatedPostId': docId,
                'collectionPath': 'faculty_events',
              });
            }
          } catch (e) {
            debugPrint('Lỗi lưu in-app notification: $e');
          }
        } else if (change.type == DocumentChangeType.modified) {
          // Kiểm tra thời gian sự kiện: Chỉ thông báo nếu sự kiện ở tương lai hoặc được gia hạn/đổi lịch sang tương lai
          final DateTime? startTime = _extractEventStartTime(data);
          final DateTime? endTime = _extractEventEndTime(data);
          final now = DateTime.now();

          bool isUpcomingOrRescheduled = false;
          if (endTime != null && endTime.isAfter(now)) {
            isUpcomingOrRescheduled = true;
          } else if (startTime != null &&
              startTime.isAfter(now.subtract(const Duration(hours: 2)))) {
            isUpcomingOrRescheduled = true;
          } else if (startTime == null && endTime == null) {
            isUpcomingOrRescheduled = true;
          }

          if (!isUpcomingOrRescheduled) continue;

          final String eventTitle =
              (data['eventName'] ?? data['title'] ?? 'Sự kiện sinh viên')
                  .toString();
          final String rawFaculty =
              (data['facultyName'] ?? data['department'] ?? 'Khoa')
                  .toString()
                  .trim();
          final String facultyName = rawFaculty.toLowerCase().startsWith('khoa ')
              ? rawFaculty
              : (rawFaculty.isNotEmpty ? 'Khoa $rawFaculty' : 'Khoa');
          final String eventDateText =
              (data['eventDateText'] ?? data['date'] ?? '').toString();
          final String locationName =
              (data['locationName'] ?? '').toString();

          String bodyStr = '$facultyName • Vừa cập nhật thông tin';
          if (eventDateText.isNotEmpty) bodyStr += ' • $eventDateText';
          if (locationName.isNotEmpty) bodyStr += ' • $locationName';

          try {
            await _db.collection('notifications').add({
              'userId': user.uid,
              'title': '🔄 Cập nhật sự kiện: $eventTitle',
              'content': bodyStr,
              'type': 'faculty_event',
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
              'relatedPostId': docId,
              'collectionPath': 'faculty_events',
            });
          } catch (e) {
            debugPrint('Lỗi lưu notification khi update event: $e');
          }
        }
      }
    });
  }

  static DateTime? _extractEventStartTime(Map<String, dynamic> data) {
    if (data['startAt'] is Timestamp) {
      return (data['startAt'] as Timestamp).toDate();
    }
    if (data['startDate'] is Timestamp) {
      return (data['startDate'] as Timestamp).toDate();
    }
    return null;
  }

  static DateTime? _extractEventEndTime(Map<String, dynamic> data) {
    if (data['endAt'] is Timestamp) {
      return (data['endAt'] as Timestamp).toDate();
    }
    if (data['endDate'] is Timestamp) {
      return (data['endDate'] as Timestamp).toDate();
    }
    return null;
  }

  static DateTime? _extractEventCreatedTime(Map<String, dynamic> data) {
    if (data['createdAt'] is Timestamp) {
      return (data['createdAt'] as Timestamp).toDate();
    }
    if (data['timestamp'] is Timestamp) {
      return (data['timestamp'] as Timestamp).toDate();
    }
    if (data['lastExtractedAt'] is Timestamp) {
      return (data['lastExtractedAt'] as Timestamp).toDate();
    }
    if (data['startAt'] is Timestamp) {
      return (data['startAt'] as Timestamp).toDate();
    }
    return null;
  }

  static bool _matchesUserFaculties(
    Map<String, dynamic> data,
    String? userFacultyStr,
    List<String> followedFaculties,
  ) {
    final FacultyInfo? primaryFac =
        FacultyHelper.findFacultyByAccountString(userFacultyStr);
    final List<FacultyInfo> followedFacs = followedFaculties
        .map((id) => FacultyHelper.findById(id))
        .whereType<FacultyInfo>()
        .toList();

    final String eventFacId =
        (data['facultyId'] ?? '').toString().toLowerCase();
    final String eventFacCode =
        (data['facultyCode'] ?? '').toString().toLowerCase();
    final String eventFacName =
        (data['facultyName'] ?? data['department'] ?? '').toString().toLowerCase();

    if (primaryFac != null) {
      if (eventFacId == primaryFac.id.toLowerCase() ||
          eventFacCode == primaryFac.code.toLowerCase() ||
          primaryFac.matchKeywords.any((kw) =>
              eventFacName.contains(kw) || eventFacId.contains(kw))) {
        return true;
      }
    }

    for (final fac in followedFacs) {
      if (eventFacId == fac.id.toLowerCase() ||
          eventFacCode == fac.code.toLowerCase() ||
          fac.matchKeywords.any((kw) =>
              eventFacName.contains(kw) || eventFacId.contains(kw))) {
        return true;
      }
    }

    if (userFacultyStr != null && userFacultyStr.trim().isNotEmpty) {
      final cleanUserFac = userFacultyStr.toLowerCase();
      if (eventFacName.contains(cleanUserFac) ||
          (eventFacId.isNotEmpty && cleanUserFac.contains(eventFacId)) ||
          (eventFacCode.isNotEmpty && cleanUserFac.contains(eventFacCode))) {
        return true;
      }
    }

    if (primaryFac == null && followedFacs.isEmpty) {
      return true;
    }

    return false;
  }

  static Stream<List<MyUniNotification>> getNotifications() {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => MyUniNotification.fromFirestore(doc))
          .where((n) => n.type != 'chat' && n.type != 'message' && n.roomId == null)
          .toList(),
    );
  }

  static Stream<List<MyUniNotification>> getMessageNotifications() {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => MyUniNotification.fromFirestore(doc))
          .where((n) => n.type == 'chat' || n.roomId != null)
          .toList(),
    );
  }

  static Future<void> markAsRead(String docId) async {
    try {
      await _db.collection('notifications').doc(docId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('Lỗi markAsRead: $e');
    }
  }

  static Future<void> updateNotificationContent(String docId, String newContent) async {
    try {
      await _db.collection('notifications').doc(docId).update({
        'content': newContent,
      });
    } catch (e) {
      debugPrint('Lỗi updateNotificationContent: $e');
    }
  }

  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!await _isNotificationsEnabled()) return;

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isRead': true,
      });
    }

    await batch.commit();
  }

  static Future<void> markAllMessageNotificationsAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final type = data['type'];
      final roomId = data['roomId'];
      if (type == 'chat' || roomId != null) {
        batch.update(doc.reference, {
          'isRead': true,
        });
      }
    }

    await batch.commit();
  }

  static Future<void> deleteAllMessageNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final type = data['type'];
      final roomId = data['roomId'];
      if (type == 'chat' || roomId != null) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
  }

  static Future<void> deleteNotification(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  static Future<void> deleteAllNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!await _isNotificationsEnabled()) return;

    final location = tz.getLocation('Asia/Ho_Chi_Minh');
    final scheduled = tz.TZDateTime.from(scheduledDate, location);
    final now = tz.TZDateTime.now(location);

    if (!scheduled.isAfter(now)) return;

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            showWhen: true,
            when: scheduled.millisecondsSinceEpoch,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('KẾT QUẢ: Lỗi zonedSchedule: $e');
    }
  }

  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted =
      await androidPlugin?.requestNotificationsPermission();

      return granted ?? false;
    }

    if (Platform.isIOS) {
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      final bool? granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      return granted ?? false;
    }

    return true;
  }
}