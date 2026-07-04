import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'post_detail_page.dart';

class PostActionRow extends StatefulWidget {
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

  @override
  State<PostActionRow> createState() => _PostActionRowState();
}

class _PostActionRowState extends State<PostActionRow> {
  DateTime _lastLikeTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _sendNotification({
    required String targetUserId,
    required String type,
    required String content,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (widget.collectionPath == 'official_news' || currentUser == null || currentUser.uid == targetUserId) return;

    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': targetUserId,
      'type': type,
      'title': type == 'like' ? 'Yêu thích' : 'Bình luận',
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'relatedPostId': widget.docId,
      'collectionPath': widget.collectionPath,
    });
  }

  Future<void> _handleLike(bool isLiked, int currentLikeCount) async {
    final now = DateTime.now();
    // 500ms synchronous debounce check to completely prevent double-click / spam race conditions
    if (now.difference(_lastLikeTapTime) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastLikeTapTime = now;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final postRef = FirebaseFirestore.instance.collection(widget.collectionPath).doc(widget.docId);
      final userLikeRef = postRef.collection('likes').doc(user.uid);

      if (isLiked) {
        // Direct write to trigger Firestore's local cache optimistic update instantly
        // Check to prevent likeCount from dropping below 0
        final newLikeCount = currentLikeCount > 0 ? FieldValue.increment(-1) : 0;
        postRef.update({'likeCount': newLikeCount});
        userLikeRef.delete();
      } else {
        // Direct write to trigger Firestore's local cache optimistic update instantly
        postRef.update({'likeCount': FieldValue.increment(1)});
        userLikeRef.set({
          'userId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Chỉ gửi thông báo nếu hành động thực sự là "Like" mới
      if (!isLiked) {
        if (widget.onLike != null) {
          widget.onLike!();
        } else {
          final String? ownerId = widget.data['authorId'] ?? widget.data['uploaderId'] ?? widget.data['uid'];
          if (ownerId != null) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
            final userData = userDoc.data();
            final rawName = userData?['displayName']?.toString().trim();
            final senderName = (rawName != null && rawName.isNotEmpty)
                ? rawName
                : (user.displayName != null && user.displayName!.trim().isNotEmpty
                    ? user.displayName!.trim()
                    : "Ai đó");

            await _sendNotification(
              targetUserId: ownerId,
              type: 'like',
              content: '$senderName đã thích bài viết của bạn.',
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Lỗi khi xử lý Like: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final Color defaultColor = isDarkMode ? Colors.white60 : Colors.grey[600]!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection(widget.collectionPath).doc(widget.docId).snapshots(),
      builder: (context, postSnapshot) {
        final postData = postSnapshot.hasData && postSnapshot.data!.exists
            ? postSnapshot.data!.data() as Map<String, dynamic>
            : widget.data;

        final int rawLikeCount = postData['likeCount'] ?? 0;
        final int currentLikeCount = rawLikeCount < 0 ? 0 : rawLikeCount;
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
          .collection(widget.collectionPath)
          .doc(widget.docId)
          .collection('likes')
          .doc(user?.uid ?? 'guest')
          .snapshots(),
      builder: (context, snapshot) {
        bool isLiked = snapshot.hasData && snapshot.data!.exists;
        return _buildActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: '$likeCount',
          color: isLiked ? Colors.redAccent : defaultColor,
          onTap: () => _handleLike(isLiked, likeCount),
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
          .doc(widget.docId)
          .snapshots(),
      builder: (context, snapshot) {
        bool isSaved = snapshot.hasData && snapshot.data!.exists;
        return _buildActionButton(
          icon: isSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
          label: 'Lưu',
          color: isSaved ? Colors.amber : defaultColor,
          onTap: () => widget.onSave(widget.docId, widget.data),
        );
      },
    );
  }

  void _navigateToDetail(BuildContext context) {
    if (widget.isInDetail) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          docId: widget.docId,
          initialPostData: widget.data,
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