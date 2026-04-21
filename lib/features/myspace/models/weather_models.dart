class ScheduleItem {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String campusId;
  final String room;

  ScheduleItem({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.campusId,
    required this.room,
  });
}

class CampusLocation {
  final String campusId;
  final String name;
  final double latitude;
  final double longitude;

  const CampusLocation({
    required this.campusId,
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class HourlyForecast {
  final DateTime time;
  final int rainProbability; // %
  final double precipitation; // mm
  final int weatherCode;

  HourlyForecast({
    required this.time,
    required this.rainProbability,
    required this.precipitation,
    required this.weatherCode,
  });

  bool get isHeavyRain => precipitation >= 7.6;

  bool get isThunderstorm =>
      weatherCode == 95 || weatherCode == 96 || weatherCode == 99;
}

enum WeatherAlertLevel {
  none,
  lightRain,
  heavyRain,
  thunderstorm,
}

class WeatherAlertResult {
  final bool shouldShow;
  final WeatherAlertLevel level;
  final String title;
  final String subtitle;
  final DateTime? classStart;
  final DateTime? classEnd;

  WeatherAlertResult({
    required this.shouldShow,
    required this.level,
    required this.title,
    required this.subtitle,
    this.classStart,
    this.classEnd,
  });

  factory WeatherAlertResult.none() {
    return WeatherAlertResult(
      shouldShow: false,
      level: WeatherAlertLevel.none,
      title: '',
      subtitle: '',
    );
  }
}