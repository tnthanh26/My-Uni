import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'post_detail_page.dart';

class PostActionRow extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Function(String, Map<String, dynamic>) onSave;
  final String collectionPath;

  const PostActionRow({
    super.key,
    required this.docId,
    required this.data,
    required this.onSave,
    required this.collectionPath,
  });

  // Hàm xử lý Like/Unlike thực tế trên Firestore
  Future<void> _handleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final postRef = FirebaseFirestore.instance.collection(collectionPath).doc(docId);
    final userLikeRef = postRef.collection('likes').doc(user.uid);

    final docSnapshot = await userLikeRef.get();

    if (docSnapshot.exists) {
      // Nếu đã like rồi thì Unlike
      await userLikeRef.delete();
      await postRef.update({'likeCount': FieldValue.increment(-1)});
    } else {
      // Nếu chưa like thì Like
      await userLikeRef.set({'timestamp': FieldValue.serverTimestamp()});
      await postRef.update({'likeCount': FieldValue.increment(1)});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final Color defaultColor = isDarkMode ? Colors.white60 : Colors.grey[600]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. NÚT THÍCH (Xử lý tại chỗ)
          _buildLikeButton(user, isDarkMode, defaultColor),

          // 2. NÚT BÌNH LUẬN (Bấm vào để điều hướng sang Detail)
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
            label: '${data['commentCount'] ?? 0}',
            color: defaultColor,
            onTap: () => _navigateToDetail(context),
          ),

          // 3. NÚT LƯU (Xử lý tại chỗ qua callback onSave)
          _buildSaveButton(user, isDarkMode, defaultColor),
        ],
      ),
    );
  }

  // Widget riêng cho nút Like để quản lý Stream
  Widget _buildLikeButton(User? user, bool isDarkMode, Color defaultColor) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(docId)
          .collection('likes')
          .doc(user?.uid ?? 'guest')
          .snapshots(),
      builder: (context, snapshot) {
        bool isLiked = snapshot.hasData && snapshot.data!.exists;
        return _buildActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: '${data['likeCount'] ?? 0}',
          color: isLiked ? Colors.redAccent : defaultColor,
          onTap: _handleLike, // Gọi hàm Like/Unlike trực tiếp
        );
      },
    );
  }

  // Widget riêng cho nút Lưu
  Widget _buildSaveButton(User? user, bool isDarkMode, Color defaultColor) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid ?? 'guest')
          .collection('saved_posts')
          .doc(docId)
          .snapshots(),
      builder: (context, snapshot) {
        bool isSaved = snapshot.hasData && snapshot.data!.exists;
        return _buildActionButton(
          icon: isSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
          label: 'Lưu',
          color: isSaved ? Colors.amber : defaultColor,
          onTap: () => onSave(docId, data), // Gọi hàm onSave từ tab truyền vào
        );
      },
    );
  }

  // Hàm điều hướng sang trang chi tiết
  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          docId: docId,
          initialPostData: data,
        ),
      ),
    );
  }

  // Widget helper tạo Layout cho từng nút
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // Đảm bảo bắt sự kiện click chính xác
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}