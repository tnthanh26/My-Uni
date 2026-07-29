class AnonymousUtils {
  /// Tạo tên hiển thị ẩn danh kèm mã số từ 001 đến 999 dựa trên userID và postID.
  /// Trong cùng 1 bài viết, 1 người dùng sẽ giữ nguyên 1 mã số cố định.
  /// Khi sang bài viết khác, mã số sẽ thay đổi để bảo đảm tính riêng tư.
  static String getAnonymousName(String? uid, String? postId) {
    if (uid == null || uid.isEmpty) return 'Sinh viên ẩn danh';
    final seed = '${uid}_${postId ?? ''}';
    final num = (seed.hashCode.abs() % 999) + 1;
    final formattedNum = num.toString().padLeft(3, '0');
    return 'Sinh viên ẩn danh #$formattedNum';
  }
}
