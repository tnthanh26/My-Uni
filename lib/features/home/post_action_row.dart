import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'post_detail_page.dart';

class PostActionRow extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Function(String, Map<String, dynamic>) onSave;
  final String collectionPath;
  final VoidCallback? onLike;
  final bool isInDetail;

  const PostActionRow({
    super.key,
    required this.docId,
    required this.data,
    required this.onSave,
    required this.collectionPath,
    this.onLike,
    this.isInDetail = false,
  });

  Future<void> _sendNotification({
    required String targetUserId,
    required String type,
    required String content,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (collectionPath == 'official_news' || currentUser == null || currentUser.uid == targetUserId) return;

    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': targetUserId,
      'type': type,
      'title': type == 'like' ? 'Yêu thích' : 'Bình luận',
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'relatedPostId': docId,
      'collectionPath': collectionPath,
    });
  }

  Future<void> _handleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final postRef = FirebaseFirestore.instance.collection(collectionPath).doc(docId);
    final userLikeRef = postRef.collection('likes').doc(user.uid);

    final docSnapshot = await userLikeRef.get();

    if (docSnapshot.exists) {
      await userLikeRef.delete();
      await postRef.update({'likeCount': FieldValue.increment(-1)});
    } else {
      await userLikeRef.set({
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await postRef.update({'likeCount': FieldValue.increment(1)});

      if (onLike != null) {
        onLike!();
      } else {
        final String? ownerId = data['authorId'] ?? data['uploaderId'] ?? data['uid'];

        if (ownerId != null) {
          _sendNotification(
            targetUserId: ownerId,
            type: 'like',
            content: '${user.displayName ?? "Ai đó"} đã thích bài viết của bạn.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final Color defaultColor = isDarkMode ? Colors.white60 : Colors.grey[600]!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection(collectionPath).doc(docId).snapshots(),
      builder: (context, postSnapshot) {
        final postData = postSnapshot.hasData && postSnapshot.data!.exists
            ? postSnapshot.data!.data() as Map<String, dynamic>
            : data;

        final int currentLikeCount = postData['likeCount'] ?? 0;
        final int currentCommentCount = postData['commentCount'] ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLikeButton(user, isDarkMode, defaultColor, currentLikeCount),

              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                label: '$currentCommentCount',
                color: defaultColor,
                onTap: () => _navigateToDetail(context),
              ),

              _buildSaveButton(user, isDarkMode, defaultColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLikeButton(User? user, bool isDarkMode, Color defaultColor, int likeCount) {
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
          label: '$likeCount',
          color: isLiked ? Colors.redAccent : defaultColor,
          onTap: _handleLike,
        );
      },
    );
  }

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
          onTap: () => onSave(docId, data),
        );
      },
    );
  }

  void _navigateToDetail(BuildContext context) {
    if (isInDetail) return;
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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