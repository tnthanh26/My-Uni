import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Item tùy chọn trong AppActionBottomSheet
class AppActionItem {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;

  const AppActionItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.isDanger = false,
  });
}

/// Utility class quản lý các Dialog xác nhận & BottomSheet tùy chọn chuẩn hóa cho toàn app My-Uni
class AppActionDialogs {
  static const Color _dangerColor = Color(0xFFE5484D);

  /// 1. Dialog Xác nhận Xóa / Hành động nguy hiểm (Standardized Confirmation Dialog)
  /// Sử dụng `await AppActionDialogs.showConfirmDialog(...)` -> trả về true nếu bấm đồng ý, false/null nếu hủy.
  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Xóa',
    String cancelText = 'Hủy',
    bool isDanger = true,
    IconData? customIcon,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF1F2937);

    final Color secondaryTextColor = isDarkMode
        ? Colors.white60
        : const Color(0xFF667085);

    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE4E7EC);

    final Color actionButtonColor = isDanger
        ? _dangerColor
        : AppColors.hcmusTeal;

    final IconData icon =
        customIcon ??
        (isDanger ? Icons.delete_outline_rounded : Icons.info_outline_rounded);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1C1E21) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: actionButtonColor.withValues(
                    alpha: isDarkMode ? 0.18 : 0.10,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: actionButtonColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
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
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext, false);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: secondaryTextColor,
                        side: BorderSide(color: borderColor),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        cancelText,
                        style: const TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(dialogContext, true);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: actionButtonColor,
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
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// 2. BottomSheet Tùy chọn Thao tác (Standardized Action Bottom Sheet)
  /// Hiển thị danh sách tùy chọn (Sửa, Xóa, Báo cáo, v.v.) kéo từ dưới lên với giao diện mượt mà.
  static Future<T?> showActionBottomSheet<T>({
    required BuildContext context,
    String? title,
    required List<AppActionItem> actions,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color backgroundColor = isDarkMode
        ? const Color(0xFF1C1E21)
        : Colors.white;

    final Color primaryTextColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1D2939);

    final Color secondaryTextColor = isDarkMode
        ? Colors.white54
        : const Color(0xFF667085);

    final Color handleColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.2)
        : const Color(0xFFEAECF0);

    final Color dividerColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFF2F4F7);

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              if (title != null && title.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Divider(height: 1, thickness: 1, color: dividerColor),
              ],
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: actions.map((item) {
                      final Color itemColor = item.isDanger
                          ? _dangerColor
                          : primaryTextColor;

                      final Color iconColor = item.isDanger
                          ? _dangerColor
                          : (isDarkMode
                                ? AppColors.hcmusTeal
                                : const Color(0xFF344054));

                      return ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: item.isDanger
                                ? _dangerColor.withValues(
                                    alpha: isDarkMode ? 0.15 : 0.08,
                                  )
                                : AppColors.hcmusTeal.withValues(
                                    alpha: isDarkMode ? 0.12 : 0.06,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item.icon, size: 20, color: iconColor),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: itemColor,
                          ),
                        ),
                        subtitle: item.subtitle != null
                            ? Text(
                                item.subtitle!,
                                style: TextStyle(
                                  fontFamily: 'Encode Sans Expanded',
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          item.onTap();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
