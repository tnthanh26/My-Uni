import '../campus_data.dart';
import 'weather_alert_service.dart';
import '../models/weather_models.dart';
import 'weather_service.dart';

class MySpaceWeatherCoordinator {
  final WeatherService weatherService;
  final WeatherAlertService alertService;

  MySpaceWeatherCoordinator({
    required this.weatherService,
    required this.alertService,
  });

  Future<WeatherAlertResult> buildWeatherAlertForToday({
    required List<ScheduleItem> schedules,
  }) async {
    final selectedClass = alertService.pickRelevantClassForToday(schedules);

    if (selectedClass == null) {
      return WeatherAlertResult.none();
    }

    final campus = CampusData.getCampusById(selectedClass.campusId);
    if (campus == null) {
      return WeatherAlertResult.none();
    }

    final forecasts = await weatherService.fetchHourlyForecast(
      latitude: campus.latitude,
      longitude: campus.longitude,
    );

    return alertService.evaluate(
      schedule: selectedClass,
      forecasts: forecasts,
    );
  }
}