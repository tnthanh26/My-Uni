import '../models/weather_models.dart';

class WeatherAlertService {
  ScheduleItem? pickRelevantClassForToday(List<ScheduleItem> schedules) {
    if (schedules.isEmpty) return null;

    final now = DateTime.now();

    final todaySchedules = schedules.where((item) {
      return item.startTime.year == now.year &&
          item.startTime.month == now.month &&
          item.startTime.day == now.day;
    }).toList();

    if (todaySchedules.isEmpty) return null;

    todaySchedules.sort((a, b) => a.startTime.compareTo(b.startTime));

    // 1. lớp đang diễn ra
    for (final item in todaySchedules) {
      if (!now.isBefore(item.startTime) && !now.isAfter(item.endTime)) {
        return item;
      }
    }

    // 2. lớp sắp tới gần nhất
    for (final item in todaySchedules) {
      if (item.startTime.isAfter(now)) {
        return item;
      }
    }

    return null;
  }

  WeatherAlertResult evaluate({
    required ScheduleItem schedule,
    required List<HourlyForecast> forecasts,
  }) {
    final slotForecasts = forecasts.where((forecast) {
      return _isHourRelevantToClass(
        forecast.time,
        schedule.startTime,
        schedule.endTime,
      );
    }).toList();

    if (slotForecasts.isEmpty) {
      return WeatherAlertResult.none();
    }

    final int maxRainProbability = slotForecasts
        .map((e) => e.rainProbability)
        .reduce((a, b) => a > b ? a : b);

    final bool hasThunderstorm =
    slotForecasts.any((e) => e.isThunderstorm);

    final bool hasHeavyRain =
    slotForecasts.any((e) => e.isHeavyRain);

    final String timeRange =
        '${_formatHour(schedule.startTime)}–${_formatHour(schedule.endTime)}';

    if (hasThunderstorm) {
      return WeatherAlertResult(
        shouldShow: true,
        level: WeatherAlertLevel.thunderstorm,
        title: 'Dự báo Giông Sét',
        subtitle: 'Trong khung $timeRange.',
        classStart: schedule.startTime,
        classEnd: schedule.endTime,
      );
    }

    if (hasHeavyRain || maxRainProbability >= 70) {
      return WeatherAlertResult(
        shouldShow: true,
        level: WeatherAlertLevel.heavyRain,
        title: 'Khả năng mưa ≥70%',
        subtitle: 'Trong khung $timeRange.',
        classStart: schedule.startTime,
        classEnd: schedule.endTime,
      );
    }

    if (maxRainProbability >= 40) {
      return WeatherAlertResult(
        shouldShow: true,
        level: WeatherAlertLevel.lightRain,
        title: 'Khả năng mưa ≥40%',
        subtitle: 'Trong khung $timeRange.',
        classStart: schedule.startTime,
        classEnd: schedule.endTime,
      );
    }

    return WeatherAlertResult.none();
    /*
    return WeatherAlertResult(
      shouldShow: true,
      level: WeatherAlertLevel.heavyRain,
      title: 'TEST: Không có mưa',
      subtitle: 'Test widget thời tiết.',
      classStart: schedule.startTime,
      classEnd: schedule.endTime,
    );
    */
  }

  bool _isHourRelevantToClass(
      DateTime hourlyTime,
      DateTime classStart,
      DateTime classEnd,
      ) {
    final hourly = DateTime(
      hourlyTime.year,
      hourlyTime.month,
      hourlyTime.day,
      hourlyTime.hour,
    );

    final startHour = DateTime(
      classStart.year,
      classStart.month,
      classStart.day,
      classStart.hour,
    );

    final endHour = DateTime(
      classEnd.year,
      classEnd.month,
      classEnd.day,
      classEnd.hour,
    );

    return !hourly.isBefore(startHour) && !hourly.isAfter(endHour);
  }

  String _formatHour(DateTime dt) {
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.hour}:$minute';
  }
}