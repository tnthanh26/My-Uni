class AnonymousUtils {
  /// Tên hiển thị cố định cho tác giả bài đăng (không đánh số #000-999)
  static String get anonymousPostAuthorName => 'Sinh viên ẩn danh';

  /// Tạo tên hiển thị ẩn danh kèm mã số từ 001 đến 999 dựa trên userID và postID.
  /// Dành riêng cho người bình luận (commenter) trong cùng 1 bài viết để phân biệt nhiều người thảo luận.
  static String getAnonymousName(String? uid, String? postId) {
    if (uid == null || uid.isEmpty) return 'Sinh viên ẩn danh';
    final seed = '${uid}_${postId ?? ''}';
    final num = (seed.hashCode.abs() % 999) + 1;
    final formattedNum = num.toString().padLeft(3, '0');
    return 'Sinh viên ẩn danh #$formattedNum';
  }
}
