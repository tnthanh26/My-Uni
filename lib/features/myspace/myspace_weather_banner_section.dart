import 'package:flutter/material.dart';
import './models/myspace_models.dart';
import './services/myspace_weather_coordinator.dart';
import './services/weather_alert_service.dart';
import './models/weather_models.dart';
import './services/weather_service.dart';
import 'weather_alert_card.dart';

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
      final campusId = mapUniversityToCampusId(widget.userUniversity);
      if (campusId == null) {
        return WeatherAlertResult.none();
      }

      final scheduleItems = widget.todayClasses.map((c) {
        return ScheduleItem(
          id: c.id,
          title: c.name,
          startTime: _combineTodayAndTime(c.start),
          endTime: _combineTodayAndTime(c.end),
          campusId: campusId,
          room: c.room,
        );
      }).toList();

      final coordinator = MySpaceWeatherCoordinator(
        weatherService: WeatherService(),
        alertService: WeatherAlertService(),
      );

      return await coordinator.buildWeatherAlertForToday(
        schedules: scheduleItems,
      );
    } catch (_) {
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

  String? mapUniversityToCampusId(String university) {
    switch (university.trim()) {
      case 'VNU - HCMUS (CS1)':
        return 'us_cs1';
      case 'VNU - HCMUS (CS2)':
        return 'us_cs2';
      default:
        return null;
    }
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