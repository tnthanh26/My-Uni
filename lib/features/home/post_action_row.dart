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
  
  // Trạng thái local tối ưu (Optimistic UI) để phản hồi tức thì
  bool? _localIsLiked;
  int? _localLikeCount;

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

  Future<bool> _isUserPending() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      final String? verificationStatus = data?['verificationStatus'];
      final bool isVerified = data?['isVerified'] ?? false;
      final bool isRestricted = (verificationStatus == 'pending') ||
          (verificationStatus == 'rejected') ||
          (!isVerified && verificationStatus != 'approved');

      if (isRestricted) {
        if (mounted) {
          final isRejected = verificationStatus == 'rejected';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isRejected
                  ? 'Tài khoản của bạn đã bị từ chối xác thực nên chưa thể tương tác.'
                  : 'Tài khoản của bạn đang chờ kiểm duyệt viên xác thực nên chưa thể tương tác.'),
              backgroundColor: isRejected ? Colors.red.shade900 : Colors.amber.shade900,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return true;
      }
    }
    return false;
  }

  Future<void> _handleLike(bool isLiked, int currentLikeCount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (await _isUserPending()) return;

    try {
      final postRef = FirebaseFirestore.instance.collection(widget.collectionPath).doc(widget.docId);
      final userLikeRef = postRef.collection('likes').doc(user.uid);

      if (isLiked) {
        final newLikeCount = currentLikeCount > 0 ? FieldValue.increment(-1) : 0;
        await postRef.update({'likeCount': newLikeCount});
        userLikeRef.delete();
      } else {
        await postRef.update({'likeCount': FieldValue.increment(1)});
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
    if (user == null) return const SizedBox.shrink();

    final Color defaultColor = isDarkMode ? Colors.white60 : Colors.grey[600]!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final String? verificationStatus = userData['verificationStatus'];
          final bool isVerified = userData['isVerified'] ?? false;
          final bool isRestricted = (verificationStatus == 'pending') ||
              (verificationStatus == 'rejected') ||
              (!isVerified && verificationStatus != 'approved');

          if (isRestricted) {
            return const SizedBox.shrink();
          }
        }

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
        bool isLikedFromServer = snapshot.hasData && snapshot.data!.exists;

        // Áp dụng trạng thái Optimistic UI
        bool displayLiked = _localIsLiked ?? isLikedFromServer;
        int displayLikeCount = _localLikeCount ?? likeCount;

        // Đồng bộ hóa lại local state sau khi render xong (tránh lỗi thay đổi state trong build phase)
        if (_localIsLiked == isLikedFromServer && _localIsLiked != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _localIsLiked = null;
                _localLikeCount = null;
              });
            }
          });
        }

        return _buildActionButton(
          icon: displayLiked ? Icons.favorite : Icons.favorite_border,
          label: '$displayLikeCount',
          color: displayLiked ? Colors.redAccent : defaultColor,
          isLikedButton: true,
          isLiked: displayLiked,
          onTap: () async {
            final now = DateTime.now();
            if (now.difference(_lastLikeTapTime) < const Duration(milliseconds: 400)) {
              return; // Chặn spam click
            }
            if (await _isUserPending()) return;
            _lastLikeTapTime = now;

            final nextLiked = !displayLiked;
            setState(() {
              _localIsLiked = nextLiked;
              _localLikeCount = likeCount + (nextLiked ? 1 : -1);
              if (_localLikeCount! < 0) _localLikeCount = 0;
            });

            _handleLike(isLikedFromServer, likeCount);
          },
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
          onTap: () async {
            if (await _isUserPending()) return;
            widget.onSave(widget.docId, widget.data);
          },
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
    bool isLikedButton = false,
    bool isLiked = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLikedButton
                ? AnimatedScale(
                    scale: isLiked ? 1.25 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    child: Icon(icon, size: 20, color: color),
                  )
                : Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}