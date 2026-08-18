import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/weather_models.dart';

class WeatherService {
  Future<List<HourlyForecast>> fetchHourlyForecast({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&hourly=precipitation_probability,precipitation,weathercode'
      '&timezone=auto'
      '&forecast_days=1',
    );

    debugPrint('[WeatherService] Bắt đầu gọi API Open-Meteo: $uri');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      debugPrint(
        '[WeatherService] Lỗi gọi API: Mã phản hồi ${response.statusCode}',
      );
      throw Exception('Failed to fetch weather forecast');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final hourly = data['hourly'];

    final List<dynamic> times = hourly['time'] ?? [];
    final List<dynamic> rainProbabilities =
        hourly['precipitation_probability'] ?? [];
    final List<dynamic> precipitations = hourly['precipitation'] ?? [];
    final List<dynamic> weatherCodes = hourly['weathercode'] ?? [];

    final List<HourlyForecast> forecasts = [];

    for (int i = 0; i < times.length; i++) {
      forecasts.add(
        HourlyForecast(
          time: DateTime.parse(times[i]),
          rainProbability: (rainProbabilities[i] ?? 0) as int,
          precipitation: (precipitations[i] ?? 0).toDouble(),
          weatherCode: (weatherCodes[i] ?? 0) as int,
        ),
      );
    }

    debugPrint(
      '[WeatherService] Tải thành công ${forecasts.length} dòng dữ liệu thời tiết theo giờ.',
    );
    return forecasts;
  }
}
