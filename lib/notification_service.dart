import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static const String _channelId = 'my_uni_urgent_channel';
  static const String _channelName = 'MyUni Notifications';
  static const String _channelDescription = 'Thông báo nhắc nhở sự kiện MyUni';

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
    InitializationSettings(android: androidInit);

    // Khởi tạo plugin với tham số có tên (Named parameters)
    await _notificationsPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('User clicked notification: ${details.payload}');
      },
    );
    await _notificationsPlugin.cancelAll();
    debugPrint('ĐÃ XÓA TẤT CẢ THÔNG BÁO CŨ ĐỂ TEST MỚI');

    if (!kIsWeb && Platform.isAndroid) {
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
      await androidPlugin?.requestExactAlarmsPermission();
    }

    debugPrint('--- INIT DONE ---');

    // TEST 1: Nổ ngay lập tức để check Icon/Channel
    // await showInstantNotification(
    //   id: 999,
    //   title: 'Hệ thống MyUni',
    //   body: 'Thông báo tức thời hoạt động OK!',
    // );

    // TEST 2: Hẹn giờ sau 20 giây
    await testAfter20Seconds();
  }

  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
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
          fullScreenIntent: true,
        ),
      ),
    );
    debugPrint('SHOW INSTANT OK -> id=$id');
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final location = tz.getLocation('Asia/Ho_Chi_Minh');
    final now = tz.TZDateTime.now(location);
    final scheduled = tz.TZDateTime.from(scheduledDate, location);

    if (!scheduled.isAfter(now)) return;

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ),
      // ĐỔI LẠI THÀNH exactAllowWhileIdle cho máy ảo dễ thở
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint('ĐẶT LỊCH OK -> ID: $id');
  }

  static Future<void> testAfter20Seconds() async {
    final location = tz.getLocation('Asia/Ho_Chi_Minh');
    final target = tz.TZDateTime.now(location).add(const Duration(seconds: 20));

    await scheduleNotification(
      id: 123456,
      title: 'Hẹn giờ MyUni',
      body: 'Thông báo này nổ sau 20 giây!',
      scheduledDate: target,
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}