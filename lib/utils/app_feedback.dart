import 'package:flutter/material.dart';

enum AppFeedbackType {
  success,
  error,
  info,
  warning,
}

class AppFeedback {
  AppFeedback._();

  static const Color _primaryColor = Color(0xFF5893D8);
  static const Color _successColor = Color(0xFF2E9D65);
  static const Color _errorColor = Color(0xFFD64545);
  static const Color _warningColor = Color(0xFFE6971E);

  /// Hiển thị SnackBar chuẩn đồng bộ toàn bộ app
  static void showSnackBar(
    BuildContext context, {
    required String message,
    AppFeedbackType type = AppFeedbackType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color accentColor = switch (type) {
      AppFeedbackType.success => _successColor,
      AppFeedbackType.error => _errorColor,
      AppFeedbackType.info => _primaryColor,
      AppFeedbackType.warning => _warningColor,
    };

    final IconData icon = switch (type) {
      AppFeedbackType.success => Icons.check_circle_outline_rounded,
      AppFeedbackType.error => Icons.error_outline_rounded,
      AppFeedbackType.info => Icons.info_outline_rounded,
      AppFeedbackType.warning => Icons.warning_amber_rounded,
    };

    final Color backgroundColor = isDark
        ? const Color(0xFF282B30)
        : const Color(0xFF1F2937);

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor,
          elevation: 4,
          duration: duration,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: accentColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          action: actionLabel != null && onAction != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: accentColor,
                  onPressed: onAction,
                )
              : null,
        ),
      );
  }

  /// Shorthand cho thông báo thành công
  static void showSuccess(BuildContext context, String message) {
    showSnackBar(
      context,
      message: message,
      type: AppFeedbackType.success,
    );
  }

  /// Shorthand cho thông báo lỗi
  static void showError(BuildContext context, String message) {
    showSnackBar(
      context,
      message: message,
      type: AppFeedbackType.error,
    );
  }

  /// Shorthand cho thông báo thông tin / đồng bộ
  static void showInfo(BuildContext context, String message) {
    showSnackBar(
      context,
      message: message,
      type: AppFeedbackType.info,
    );
  }

  /// Shorthand cho thông báo cảnh báo
  static void showWarning(BuildContext context, String message) {
    showSnackBar(
      context,
      message: message,
      type: AppFeedbackType.warning,
    );
  }

  /// Dialog xác nhận đồng bộ thiết kế chuẩn toàn ứng dụng
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String cancelText = 'Hủy',
    String confirmText = 'Xác nhận',
    bool isDangerous = false,
  }) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color surfaceColor = isDark ? const Color(0xFF1C1E21) : Colors.white;
    final Color primaryTextColor = isDark ? Colors.white : const Color(0xFF1D2939);
    final Color secondaryTextColor = isDark ? Colors.white60 : const Color(0xFF667085);

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: surfaceColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
          actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          title: Text(
            title,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 13,
              height: 1.45,
              color: secondaryTextColor,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                cancelText,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: isDangerous ? _errorColor : _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                confirmText,
                style: const TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
