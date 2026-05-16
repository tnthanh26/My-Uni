class OfficialContentHelper {
  static bool isOfficialEvent(dynamic titleData, dynamic summaryData) {
    final String title = titleData?.toString().toLowerCase() ?? "";
    final String summary = summaryData?.toString().toLowerCase() ?? "";

    final List<String> keywords = [
      'seminar',
      'talkshow',
      'hội thảo',
      'cuộc thi',
      'chào tân sinh viên',
      'ngày hội',
      'lễ tốt nghiệp',
      'workshop',
      'sự kiện',
      'mời tham gia',
      'đăng ký tham gia',
    ];

    final String content = "$title $summary";
    return keywords.any((k) => content.contains(k));
  }

  static String getOfficialImageByContent(dynamic titleData, dynamic summaryData) {
    final String title = titleData?.toString().toLowerCase() ?? "";
    final String summary = summaryData?.toString().toLowerCase() ?? "";
    final String text = "$title $summary";

    if (text.contains('học bổng') || text.contains('scholarship')) {
      return 'assets/images/scholarship.jpg';
    }
    if (text.contains('tuyển dụng') ||
        text.contains('việc làm') ||
        text.contains('intern') ||
        text.contains('thực tập')) {
      return 'assets/images/job.jpg';
    }
    if (text.contains('hội thảo') ||
        text.contains('seminar') ||
        text.contains('workshop') ||
        text.contains('talkshow')) {
      return 'assets/images/seminar.jpg';
    }
    if (text.contains('thể thao') ||
        text.contains('bóng đá') ||
        text.contains('giải đấu')) {
      return 'assets/images/sport.jpg';
    }
    if (text.contains('công nghệ') ||
        text.contains('tech') ||
        text.contains('lập trình')) {
      return 'assets/images/tech.jpg';
    }
    if (text.contains('nghệ thuật') ||
        text.contains('văn nghệ') ||
        text.contains('âm nhạc')) {
      return 'assets/images/art.jpg';
    }
    if (text.contains('lễ tốt nghiệp') || text.contains('graduation')) {
      return 'assets/images/graduation.jpg';
    }
    if (text.contains('cuộc thi') ||
        text.contains('contest') ||
        text.contains('giải thưởng')) {
      return 'assets/images/contest.jpg';
    }
    if (text.contains('thông báo') || text.contains('quy định')) {
      return 'assets/images/announcement.jpg';
    }
    if (text.contains('y tế') || text.contains('khám chữa bệnh')) {
      return 'assets/images/health.jpg';
    }

    return 'assets/images/news.png';
  }
}