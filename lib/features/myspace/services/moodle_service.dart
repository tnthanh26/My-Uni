import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MoodleService {
  static Future<String?> connectAndGetToken({
    required String moodleUrl,
    required String username,
    required String password,
  }) async {
    try {
      final cleanedUrl = moodleUrl.trim().replaceAll(RegExp(r'/$'), '');

      final response = await http.post(
        Uri.parse('$cleanedUrl/login/token.php'),
        body: {
          'username': username,
          'password': password,
          'service': 'moodle_mobile_app',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('MOODLE CONNECT ERROR: status code ${response.statusCode}');
        return null;
      }

      final bodyText = response.body.trim();
      if (bodyText.startsWith('<') || bodyText.toLowerCase().contains('<html')) {
        debugPrint('MOODLE CONNECT ERROR: Moodle returned HTML instead of JSON token (likely using SSO/Outlook login).');
        return null;
      }

      final data = jsonDecode(bodyText);

      debugPrint('MOODLE TOKEN RESPONSE: $data');

      if (data is Map && data['token'] != null) {
        return data['token'].toString();
      }

      return null;
    } catch (e) {
      debugPrint('MOODLE CONNECT ERROR: $e');
      return null;
    }
  }

  static Future<List<dynamic>?> fetchUpcomingEvents({
    required String moodleUrl,
    required String token,
  }) async {
    try {
      final cleanedUrl = moodleUrl.trim().replaceAll(RegExp(r'/$'), '');

      final response = await http.post(
        Uri.parse('$cleanedUrl/webservice/rest/server.php'),
        body: {
          'wstoken': token,
          'wsfunction': 'core_calendar_get_calendar_upcoming_view',
          'moodlewsrestformat': 'json',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('FETCH MOODLE EVENTS ERROR: status code ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);

      debugPrint('MOODLE EVENTS RESPONSE: $data');

      if (data is Map && data.containsKey('exception')) {
        debugPrint('MOODLE API EXCEPTION: ${data['message']}');
        return null;
      }

      return data['events'] as List<dynamic>?;
    } catch (e) {
      debugPrint('FETCH MOODLE EVENTS ERROR: $e');
      return null;
    }
  }
}