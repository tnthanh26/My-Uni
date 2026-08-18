import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeBannerData {
  final String greeting;
  final String text;
  final List<TextSpan> spans;

  WelcomeBannerData({
    required this.greeting,
    required this.text,
    required this.spans,
  });
}

class WelcomeBannerService {
  static const String _prefKeyLastIndex = 'welcome_banner_last_quote_index';

  /// Lấy lời chào theo thời gian trong ngày
  static String getGreeting(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) {
      return "Chào buổi sáng!";
    } else if (hour >= 12 && hour < 18) {
      return "Chào buổi chiều!";
    } else {
      return "Chào buổi tối!";
    }
  }

  /// Danh sách 25 câu nói ngắn gọn cho ngày trống (ngắn gọn, tránh tràn text)
  static const List<String> _emptyStateQuotes = [
    // Thư giãn
    "Lịch hôm nay trống. Tận hưởng ngày thư giãn nhé!",
    "Không lớp, không deadline. Hiếm lắm đó!",
    "Một ngày hoàn toàn tự do dành cho bạn.",
    "Hôm nay thong thả, nạp lại năng lượng thôi!",
    "Lịch trống trải. Bạn đã hoàn thành tốt lắm!",
    "Hôm nay rảnh rỗi, nghỉ ngơi xả hơi thôi!",

    // Động viên
    "Ngày mới tuyệt vời! Sẵn sàng cho điều tốt đẹp.",
    "Hôm nay là thời điểm hoàn hảo để học điều mới.",
    "Giữ tinh thần tích cực cho một ngày hiệu quả!",
    "Dành thời gian chăm sóc bản thân hôm nay nhé.",
    "Mỗi ngày mới là một cơ hội để bứt phá.",
    "Hãy biến hôm nay thành một ngày đáng nhớ!",

    // Năng suất
    "Lịch trống là cơ hội để chuẩn bị cho tuần mới.",
    "Rảnh rỗi là lúc xem lại mục tiêu cá nhân.",
    "Dành thời gian đọc một cuốn sách hay hôm nay.",
    "Lên kế hoạch trước giúp bạn luôn chủ động.",
    "Tập trung hoàn thành mục tiêu cá nhân hôm nay!",
    "Làm điều bạn yêu thích trong khoảng nghỉ này.",

    // Hài hước nhẹ nhàng
    "Hôm nay MyUni không có gì để nhắc bạn cả!",
    "Không deadline nào đuổi theo bạn hôm nay.",
    "Thảnh thơi thật sự! Đừng quên ăn uống đầy đủ.",
    "Hôm nay thong dong, thích làm gì thì làm!",
    "Chế độ nghỉ ngơi đã được kích hoạt!",
    "Một ngày bình yên không lo bị giục nộp bài.",
    "Hôm nay hoàn toàn thuộc về bạn!",
  ];

  /// Sinh dữ liệu banner thông minh dựa trên 3 chỉ số
  static Future<WelcomeBannerData> generateBannerData({
    required int todayClasses,
    required int todayDeadlines,
    required int todayEvents,
    required DateTime now,
  }) async {
    final greeting = getGreeting(now);
    final bool hasClasses = todayClasses > 0;
    final bool hasDeadlines = todayDeadlines > 0;
    final bool hasEvents = todayEvents > 0;

    // Trường hợp 0: Không có bất kỳ hoạt động nào hôm nay
    if (!hasClasses && !hasDeadlines && !hasEvents) {
      final quote = await _getRandomQuoteWithoutRepeat();
      return WelcomeBannerData(
        greeting: greeting,
        text: quote,
        spans: [TextSpan(text: quote)],
      );
    }

    // Trường hợp 1: Có cả 3 hoạt động
    if (hasClasses && hasEvents && hasDeadlines) {
      return WelcomeBannerData(
        greeting: greeting,
        text:
            "Hôm nay bạn có $todayClasses lớp học, $todayEvents sự kiện và $todayDeadlines deadline.",
        spans: [
          const TextSpan(text: "Hôm nay bạn có "),
          TextSpan(
            text: "$todayClasses lớp học",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: ", "),
          TextSpan(
            text: "$todayEvents sự kiện",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: " và "),
          TextSpan(
            text: "$todayDeadlines deadline",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: "."),
        ],
      );
    }

    // Trường hợp 2: Lớp + Sự kiện
    if (hasClasses && hasEvents && !hasDeadlines) {
      return WelcomeBannerData(
        greeting: greeting,
        text: "Hôm nay bạn có $todayClasses lớp học và $todayEvents sự kiện.",
        spans: [
          const TextSpan(text: "Hôm nay bạn có "),
          TextSpan(
            text: "$todayClasses lớp học",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: " và "),
          TextSpan(
            text: "$todayEvents sự kiện",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: " đang chờ."),
        ],
      );
    }

    // Trường hợp 3: Lớp + Deadline
    if (hasClasses && hasDeadlines && !hasEvents) {
      return WelcomeBannerData(
        greeting: greeting,
        text:
            "Hôm nay bạn có $todayClasses lớp học và $todayDeadlines deadline.",
        spans: [
          const TextSpan(text: "Hôm nay bạn có "),
          TextSpan(
            text: "$todayClasses lớp học",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: " và "),
          TextSpan(
            text: "$todayDeadlines deadline",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: " cần xong."),
        ],
      );
    }

    // Trường hợp 4: Sự kiện + Deadline
    if (hasEvents && hasDeadlines && !hasClasses) {
      return WelcomeBannerData(
        greeting: greeting,
        text:
            "Hôm nay bạn có $todayEvents sự kiện và $todayDeadlines deadline.",
        spans: [
          const TextSpan(text: "Hôm nay bạn có "),
          TextSpan(
            text: "$todayEvents sự kiện",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: " và "),
          TextSpan(
            text: "$todayDeadlines deadline",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: " cần nộp."),
        ],
      );
    }

    // Trường hợp 5: Chỉ có Lớp học
    if (hasClasses && !hasEvents && !hasDeadlines) {
      return WelcomeBannerData(
        greeting: greeting,
        text: "Hôm nay bạn có $todayClasses lớp học.",
        spans: [
          const TextSpan(text: "Hôm nay bạn có "),
          TextSpan(
            text: "$todayClasses lớp học",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: ". Đi học đúng giờ nhé!"),
        ],
      );
    }

    // Trường hợp 6: Chỉ có Sự kiện
    if (hasEvents && !hasClasses && !hasDeadlines) {
      return WelcomeBannerData(
        greeting: greeting,
        text: "Hôm nay bạn có $todayEvents sự kiện.",
        spans: [
          const TextSpan(text: "Hôm nay bạn có "),
          TextSpan(
            text: "$todayEvents sự kiện",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: " đừng bỏ lỡ."),
        ],
      );
    }

    // Trường hợp 7: Chỉ có Deadline
    return WelcomeBannerData(
      greeting: greeting,
      text: "Hôm nay bạn có $todayDeadlines deadline.",
      spans: [
        const TextSpan(text: "Hôm nay bạn có "),
        TextSpan(
          text: "$todayDeadlines deadline",
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const TextSpan(text: " cần hoàn thành."),
      ],
    );
  }

  /// Lấy câu ngẫu nhiên không trùng với câu lần trước
  static Future<String> _getRandomQuoteWithoutRepeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastIndex = prefs.getInt(_prefKeyLastIndex) ?? -1;

      final rand = Random();
      int newIndex = rand.nextInt(_emptyStateQuotes.length);

      if (_emptyStateQuotes.length > 1 && newIndex == lastIndex) {
        newIndex = (newIndex + 1) % _emptyStateQuotes.length;
      }

      await prefs.setInt(_prefKeyLastIndex, newIndex);
      return _emptyStateQuotes[newIndex];
    } catch (_) {
      final rand = Random();
      return _emptyStateQuotes[rand.nextInt(_emptyStateQuotes.length)];
    }
  }
}
