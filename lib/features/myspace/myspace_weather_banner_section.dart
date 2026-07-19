import 'package:flutter/material.dart';
import './models/myspace_models.dart';
import './services/myspace_weather_coordinator.dart';
import './services/weather_alert_service.dart';
import './models/weather_models.dart';
import './services/weather_service.dart';
import 'weather_alert_card.dart';
import 'campus_data.dart';

class MySpaceWeatherBannerSection extends StatefulWidget {
  final List<StudyClass> todayClasses;
  final String userUniversity;

  const MySpaceWeatherBannerSection({
    super.key,
    required this.todayClasses,
    required this.userUniversity,
  });

  @override
  State<MySpaceWeatherBannerSection> createState() =>
      _MySpaceWeatherBannerSectionState();
}

class _MySpaceWeatherBannerSectionState
    extends State<MySpaceWeatherBannerSection> {
  late Future<WeatherAlertResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadWeatherAlert();
  }

  @override
  void didUpdateWidget(covariant MySpaceWeatherBannerSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.todayClasses != widget.todayClasses ||
        oldWidget.userUniversity != widget.userUniversity) {
      _future = _loadWeatherAlert();
    }
  }

  Future<WeatherAlertResult> _loadWeatherAlert() async {
    try {
      final defaultCampusId = CampusData.mapUniversityToCampusId(widget.userUniversity);
      debugPrint('[WeatherBanner] Bắt đầu nạp thời tiết cho trường: ${widget.userUniversity} (defaultCampusId: $defaultCampusId)');

      final scheduleItems = widget.todayClasses.map((c) {
        final classCampusId = c.campusId ?? defaultCampusId ?? '';
        return ScheduleItem(
          id: c.id,
          title: c.name,
          startTime: _combineTodayAndTime(c.start),
          endTime: _combineTodayAndTime(c.end),
          campusId: classCampusId,
          room: c.room,
        );
      }).where((item) => item.campusId.isNotEmpty).toList();

      if (scheduleItems.isEmpty) {
        debugPrint('[WeatherBanner] Không tìm thấy campusId phù hợp cho môn học nào hôm nay.');
        return WeatherAlertResult.none();
      }

      debugPrint('[WeatherBanner] Số lượng môn học hôm nay cần kiểm tra: ${scheduleItems.length}');

      final coordinator = MySpaceWeatherCoordinator(
        weatherService: WeatherService(),
        alertService: WeatherAlertService(),
      );

      final result = await coordinator.buildWeatherAlertForToday(
        schedules: scheduleItems,
      );

      debugPrint('[WeatherBanner] Kết quả phân tích thời tiết: level=${result.level}, title="${result.title}", shouldShow=${result.shouldShow}');
      return result;
    } catch (e) {
      debugPrint('[WeatherBanner] Lỗi trong quá trình nạp thời tiết: $e');
      return WeatherAlertResult.none();
    }
  }

  DateTime _combineTodayAndTime(String time) {
    final now = DateTime.now();
    final parts = time.split(':');

    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherAlertResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final result = snapshot.data ?? WeatherAlertResult.none();

        if (!result.shouldShow) {
          return const SizedBox.shrink(); // 👈 KHÔNG HIỆN GÌ
        }

        return WeatherAlertCard(alert: result);
      },
    );
  }
}