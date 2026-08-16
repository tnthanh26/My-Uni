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

  /// Trả về URL đăng nhập Moodle (login/index.php)
  static String getSsoLaunchUrl(String moodleUrl) {
    final cleanedUrl = moodleUrl.trim().replaceAll(RegExp(r'/$'), '');
    return '$cleanedUrl/login/index.php';
  }

  /// Trả về URL Moodle Mobile launch với passport và urlscheme chuẩn Moodle Mobile
  static String getMobileLaunchUrl(String moodleUrl) {
    final cleanedUrl = moodleUrl.trim().replaceAll(RegExp(r'/$'), '');
    return '$cleanedUrl/admin/tool/mobile/launch.php?service=moodle_mobile_app&passport=1000&urlscheme=moodlemobile';
  }

  /// Trích xuất wstoken hoặc token từ URL redirect SSO
  static String? extractTokenFromUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // 1. Kiểm tra query parameters
      if (uri.queryParameters.containsKey('wstoken')) {
        return uri.queryParameters['wstoken'];
      }
      if (uri.queryParameters.containsKey('token')) {
        return uri.queryParameters['token'];
      }

      // 2. Kiểm tra fragment (#token=... hoặc #wstoken=...)
      if (uri.hasFragment) {
        final fragment = uri.fragment;
        final params = Uri.splitQueryString(fragment);
        if (params.containsKey('wstoken')) return params['wstoken'];
        if (params.containsKey('token')) return params['token'];
      }

      // 3. Kiểm tra custom scheme string Regex (vd: moodlemobile://token=XXX hoặc moodlemobile://wstoken=XXX)
      final regExp = RegExp(r'(?:wstoken|token)=([a-fA-F0-9]{32})');
      final match = regExp.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }

      // 4. Trích xuất mã 32 ký tự Hex (MD5 format wstoken) từ chuỗi bất kỳ
      final hexRegExp = RegExp(r'\b([a-f0-9]{32})\b');
      final hexMatch = hexRegExp.firstMatch(url);
      if (hexMatch != null && hexMatch.groupCount >= 1) {
        // Tránh khớp nhầm chuỗi commit hash hoặc ID không phải token nếu có từ khóa token/key quanh đó
        if (url.contains('token') || url.contains('key') || url.contains('managetokens') || url.contains('wstoken')) {
          return hexMatch.group(1);
        }
      }
    } catch (e) {
      debugPrint('EXTRACT MOODLE TOKEN ERROR: $e');
    }
    return null;
  }
}