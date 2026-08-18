class OfficialContentHelper {
  static bool isOfficialEvent(dynamic titleData, dynamic summaryData) {
    final String title = titleData?.toString().toLowerCase() ?? "";
    final String summary = summaryData?.toString().toLowerCase() ?? "";
    final String text = "$title $summary".trim();

    if (text.isEmpty) return false;

    return text.contains('hội thảo') ||
        text.contains('seminar') ||
        text.contains('workshop') ||
        text.contains('talkshow') ||
        text.contains('tọa đàm') ||
        text.contains('webinar') ||
        text.contains('sự kiện') ||
        text.contains('event') ||
        text.contains('ngày hội') ||
        text.contains('diễn đàn') ||
        text.contains('hội thao');
  }

  static String getOfficialImageByContent(
    dynamic titleData,
    dynamic summaryData,
  ) {
    final String title = titleData?.toString().toLowerCase() ?? "";
    final String summary = summaryData?.toString().toLowerCase() ?? "";
    final String text = "$title $summary";

    // 1. Ưu tiên kiểm tra theo tiêu đề (Title) trước vì Tiêu đề mang tín hiệu chính xác nhất
    String? matchedFromTitle = _matchImageByText(title);
    if (matchedFromTitle != null) return matchedFromTitle;

    // 2. Nếu Tiêu đề chưa khớp category cụ thể thì kiểm tra toàn bộ nội dung/tóm tắt
    String? matchedFromText = _matchImageByText(text);
    if (matchedFromText != null) return matchedFromText;

    // 3. Mặc định dùng ảnh thông báo (announcement.jpg) thay vì news.png bị mờ
    return 'assets/images/announcement.jpg';
  }

  static String? _matchImageByText(String text) {
    if (text.isEmpty) return null;

    // Tốt nghiệp & Bảo vệ khóa luận / đề tài / luận văn
    if (text.contains('tốt nghiệp') ||
        text.contains('bảo vệ đề tài') ||
        text.contains('bảo vệ khóa luận') ||
        text.contains('bảo vệ luận văn') ||
        text.contains('graduation')) {
      return 'assets/images/graduation.jpg';
    }

    // Học bổng
    if (text.contains('học bổng') || text.contains('scholarship')) {
      return 'assets/images/scholarship.jpg';
    }

    // Hội thảo / Seminar / Workshop / Talkshow / Tọa đàm
    if (text.contains('hội thảo') ||
        text.contains('seminar') ||
        text.contains('workshop') ||
        text.contains('talkshow') ||
        text.contains('tọa đàm') ||
        text.contains('webinar')) {
      return 'assets/images/seminar.jpg';
    }

    // Tuyển dụng & Thực tập (kiểm tra từ khóa rõ ràng tránh khớp nhầm)
    if (text.contains('tuyển dụng') ||
        text.contains('việc làm') ||
        text.contains('tuyển thực tập') ||
        text.contains('thực tập sinh') ||
        text.contains('recruitment') ||
        text.contains('internship')) {
      return 'assets/images/job.jpg';
    }

    // Cuộc thi & Giải thưởng
    if (text.contains('cuộc thi') ||
        text.contains('contest') ||
        text.contains('hackathon') ||
        text.contains('giải thưởng') ||
        text.contains('olympic')) {
      return 'assets/images/contest.jpg';
    }

    // Thể thao & Giải đấu
    if (text.contains('thể thao') ||
        text.contains('bóng đá') ||
        text.contains('bóng rổ') ||
        text.contains('cầu lông') ||
        text.contains('hội thao') ||
        text.contains('giải đấu')) {
      return 'assets/images/sport.jpg';
    }

    // Nghệ thuật & Âm nhạc
    if (text.contains('nghệ thuật') ||
        text.contains('văn nghệ') ||
        text.contains('âm nhạc') ||
        text.contains('concert')) {
      return 'assets/images/art.jpg';
    }

    // Thông báo & Quy định & Giáo vụ
    if (text.contains('thông báo') ||
        text.contains('quy định') ||
        text.contains('giáo vụ') ||
        text.contains('chuyên ngành') ||
        text.contains('lịch thi') ||
        text.contains('đăng ký')) {
      return 'assets/images/announcement.jpg';
    }

    return null;
  }

  static String getOfficialCategoryTag(
    dynamic titleData,
    dynamic summaryData,
    dynamic hashtagsData,
  ) {
    if (hashtagsData != null &&
        hashtagsData is List &&
        hashtagsData.isNotEmpty) {
      final String firstTag = hashtagsData.first
          .toString()
          .replaceAll('#', '')
          .trim();
      if (firstTag.isNotEmpty) return firstTag;
    }

    final String text = titleData?.toString().toLowerCase() ?? "";

    if (text.contains('hội thảo') ||
        text.contains('seminar') ||
        text.contains('workshop') ||
        text.contains('talkshow') ||
        text.contains('tọa đàm') ||
        text.contains('webinar')) {
      return 'Hội thảo';
    }
    if (text.contains('sự kiện') ||
        text.contains('event') ||
        text.contains('ngày hội') ||
        text.contains('diễn đàn') ||
        text.contains('hội thao')) {
      return 'Sự kiện';
    }
    if (text.contains('tốt nghiệp') ||
        text.contains('bảo vệ đề tài') ||
        text.contains('bảo vệ khóa luận') ||
        text.contains('bảo vệ luận văn')) {
      return 'Tốt nghiệp';
    }
    if (text.contains('học bổng') || text.contains('scholarship')) {
      return 'Học bổng';
    }
    if (text.contains('học phí') ||
        text.contains('tuition') ||
        text.contains('lệ phí') ||
        text.contains('nộp tiền')) {
      return 'Học phí';
    }
    if (text.contains('tuyển dụng') ||
        text.contains('việc làm') ||
        text.contains('thực tập')) {
      return 'Tuyển dụng';
    }
    if (text.contains('cuộc thi') ||
        text.contains('contest') ||
        text.contains('hackathon') ||
        text.contains('olympic')) {
      return 'Cuộc thi';
    }

    return 'Thông báo';
  }
}
