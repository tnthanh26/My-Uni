import 'package:flutter/material.dart';
import 'package:my_uni/features/home/home_page.dart';

void showOnboardingDialog(BuildContext context) {
  final homeState = context.findAncestorStateOfType<HomePageState>();
  if (homeState != null) {
    homeState.startWalkthrough();
  } else {
    HomePage.showWalkthroughNotifier.value = false;
    HomePage.showWalkthroughNotifier.value = true;
  }
}

// Walkthrough step data class
class WalkthroughStepData {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  WalkthroughStepData({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });
}

// Dynamic getter for walkthrough steps so Hot Reload updates content immediately
List<WalkthroughStepData> get walkthroughSteps => [
  WalkthroughStepData(
    title: "Trang chủ MyUni",
    description:
        "Cập nhật tin tức chính thức từ HCMUS, diễn đàn thảo luận sôi nổi, review môn học và kho tài liệu học tập phong phú.",
    icon: Icons.home_rounded,
    accentColor: const Color(0xFF6C63FF),
  ),
  WalkthroughStepData(
    title: "Hoạt động & Sự kiện",
    description:
        "Quản lý sự kiện cá nhân, khám phá các hoạt động do trường và khoa tổ chức, đồng thời theo dõi lịch sử tham gia một cách thuận tiện.",
    icon: Icons.event_rounded,
    accentColor: const Color(0xFFFF9800),
  ),
  WalkthroughStepData(
    title: "Hỏi Đáp cùng AI",
    description:
        "Trò chuyện trực tiếp với trợ lý ảo Ú Em để giải đáp nhanh chóng các câu hỏi về quy chế học vụ và thủ tục hành chính.",
    icon: Icons.chat_bubble_rounded,
    accentColor: const Color(0xFF00BFA5),
  ),
  WalkthroughStepData(
    title: "Góc nhỏ MySpace",
    description:
        "Không gian cá nhân tập trung mọi hoạt động học tập của bạn, từ thời khóa biểu, deadline, sự kiện cá nhân đến các cảnh báo thời tiết theo lịch học trong ngày.",
    icon: Icons.space_dashboard_rounded,
    accentColor: const Color(0xFF9C27B0),
  ),
  WalkthroughStepData(
    title: "Tài Khoản & Tiện ích",
    description:
        "Quản lý hồ sơ cá nhân, thẻ sinh viên QR và nội dung của bạn, đồng thời truy cập nhanh tin nhắn, tìm kiếm sinh viên, tiện ích và cài đặt.",
    icon: Icons.person_rounded,
    accentColor: const Color(0xFF2196F3),
  ),
];

// Spotlight painter to draw a dark transparent background with a rounded rectangular hole over the target tab
class WalkthroughSpotlightPainter extends CustomPainter {
  final int step;
  final double screenWidth;
  final double screenHeight;
  final double paddingBottom;

  WalkthroughSpotlightPainter({
    required this.step,
    required this.screenWidth,
    required this.screenHeight,
    required this.paddingBottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);

    if (step < 0 || step >= walkthroughSteps.length) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, screenWidth, screenHeight),
        overlayPaint,
      );
      return;
    }

    final double itemWidth = screenWidth / walkthroughSteps.length;
    final double cx = (step + 0.5) * itemWidth;
    final double cy = screenHeight - paddingBottom - 32;

    final double rectWidth = itemWidth * 0.9;
    const double rectHeight = 52;

    final RRect spotlightRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: rectWidth,
        height: rectHeight,
      ),
      const Radius.circular(16),
    );

    canvas.saveLayer(Rect.fromLTWH(0, 0, screenWidth, screenHeight), Paint());

    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenWidth, screenHeight),
      overlayPaint,
    );

    final clearPaint = Paint()..blendMode = BlendMode.clear;

    canvas.drawRRect(spotlightRRect, clearPaint);

    canvas.restore();

    final borderPaint = Paint()
      ..color = const Color(0xFF00D4AA).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawRRect(spotlightRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant WalkthroughSpotlightPainter oldDelegate) {
    return oldDelegate.step != step ||
        oldDelegate.screenWidth != screenWidth ||
        oldDelegate.screenHeight != screenHeight ||
        oldDelegate.paddingBottom != paddingBottom;
  }
}

// Triangle painter for tooltip arrow
class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0); // Top-left
    path.lineTo(size.width, 0); // Top-right
    path.lineTo(size.width / 2, size.height); // Bottom-center
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
