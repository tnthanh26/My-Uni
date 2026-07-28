import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/notification_model.dart';
import '../services/notification_service.dart';
import '../home/post_detail_page.dart';
import '../chat/pages/chat_detail_page.dart';
import '../chat/services/chat_service.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDarkMode ? const Color(0xFF0F1113) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Thông báo",
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            fontFamily: 'Nunito',
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Đọc tất cả",
            icon: const Icon(
              Icons.done_all_rounded,
              color: Color(0xFF5893D8),
            ),
            onPressed: () async {
              await NotificationService.markAllAsRead();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Đã đánh dấu tất cả là đã đọc"),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: "Xóa tất cả",
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
            onPressed: () => _showDeleteAllDialog(context),
          ),
        ],
        backgroundColor: isDarkMode ? const Color(0xFF111315) : Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
            height: 1,
          ),
        ),
      ),
      body: StreamBuilder<List<MyUniNotification>>(
        stream: NotificationService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Đã có lỗi xảy ra",
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5893D8)),
            );
          }

          final notifications = snapshot.data!;

          if (notifications.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white10
                        : const Color(0xFFE9EEF3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 42,
                      color: isDarkMode ? Colors.white38 : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Bạn chưa có thông báo nào",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final unreadCount = notifications.where((n) => !n.isRead).length;

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white10
                        : const Color(0xFFE9EEF3),
                  ),
                  boxShadow: isDarkMode
                      ? []
                      : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5893D8).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        color: Color(0xFF5893D8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        unreadCount > 0
                            ? "Bạn có $unreadCount thông báo chưa đọc"
                            : "Bạn đã xem hết thông báo rồi",
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white70
                              : const Color(0xFF344054),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final noti = notifications[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildNotificationItem(context, noti),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleNotificationTap(
      BuildContext context,
      MyUniNotification noti,
      ) async {
    NotificationService.markAsRead(noti.id);

    if (noti.type == 'chat' || noti.roomId != null) {
      final roomId = noti.roomId;
      if (roomId != null && roomId.isNotEmpty) {
        final currentUid = ChatService().currentUserId ?? '';
        final peerUid = noti.senderId ?? roomId.split('_').firstWhere((id) => id != currentUid, orElse: () => '');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              roomId: roomId,
              targetUserId: peerUid,
              targetUserName: noti.senderName ?? noti.title,
              targetUserPhoto: noti.senderAvatar ?? '',
            ),
          ),
        );
        return;
      }
    }

    if (noti.relatedPostId != null && noti.collectionPath != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Container(
          color: Colors.black.withOpacity(0.18),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF5893D8)),
          ),
        ),
      );

      try {
        final postDoc = await FirebaseFirestore.instance
            .collection(noti.collectionPath!)
            .doc(noti.relatedPostId)
            .get()
            .timeout(const Duration(seconds: 5));

        if (!context.mounted) return;
        Navigator.pop(context);

        final bool isCommentNotification = noti.reportedCommentId != null ||
            noti.title.toLowerCase().contains("bình luận") ||
            noti.content.toLowerCase().contains("bình luận");

        if (postDoc.exists) {
          final postData = postDoc.data() as Map<String, dynamic>;

          if (postData['status'] == 'hidden') {
            _showUnavailableDialog(context, noti.id, isComment: isCommentNotification);
          } else {
            // Nếu đây là thông báo liên quan đến bình luận cụ thể, hãy kiểm tra xem bình luận đó còn tồn tại không
            if (noti.reportedCommentId != null) {
              final commentDoc = await FirebaseFirestore.instance
                  .collection(noti.collectionPath!)
                  .doc(noti.relatedPostId)
                  .collection('comments')
                  .doc(noti.reportedCommentId)
                  .get();

              if (!commentDoc.exists) {
                _showUnavailableDialog(context, noti.id, isComment: true);
                return;
              }
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(
                  docId: noti.relatedPostId!,
                  initialPostData: postData,
                ),
              ),
            );
          }
        } else {
          _showUnavailableDialog(context, noti.id, isComment: isCommentNotification);
        }
      } on FirebaseException catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context);

        final bool isCommentNotification = noti.reportedCommentId != null ||
            noti.title.toLowerCase().contains("bình luận") ||
            noti.content.toLowerCase().contains("bình luận");

        if (e.code == 'permission-denied' || e.code == 'not-found') {
          _showUnavailableDialog(context, noti.id, isComment: isCommentNotification);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi hệ thống: ${e.message}")),
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context);
        final bool isCommentNotification = noti.reportedCommentId != null ||
            noti.title.toLowerCase().contains("bình luận") ||
            noti.content.toLowerCase().contains("bình luận");
        _showUnavailableDialog(context, noti.id, isComment: isCommentNotification);
      }
    }
  }

  void _showUnavailableDialog(BuildContext context, String notiId, {bool isComment = false}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          "Thông báo",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          isComment
              ? "Bình luận này đã bị xóa hoặc không còn tồn tại."
              : "Bài viết này đã bị xóa hoặc không còn tồn tại.",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Đóng",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await NotificationService.deleteNotification(notiId);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Đã xóa thông báo")),
                );
              }
            },
            child: const Text(
              "Xóa thông báo",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          "Xóa tất cả thông báo",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          "Bạn có chắc muốn xóa toàn bộ thông báo không? Hành động này không thể hoàn tác.",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Hủy",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await NotificationService.deleteAllNotifications();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Đã xóa tất cả thông báo")),
                );
              }
            },
            child: const Text(
              "Xóa tất cả",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteOneDialog(
      BuildContext context,
      MyUniNotification noti,
      ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          "Xóa thông báo",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          "Bạn có chắc muốn xóa thông báo này không?",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Hủy",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await NotificationService.deleteNotification(noti.id);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Đã xóa thông báo")),
                );
              }
            },
            child: const Text(
              "Xóa",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
      BuildContext context,
      MyUniNotification noti,
      ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color unreadBg = isDarkMode
        ? const Color(0xFF66ACFE).withOpacity(0.10)
        : const Color(0xFFEEF6FF);

    final Color cardBg = noti.isRead
        ? (isDarkMode ? const Color(0xFF15171A) : Colors.white)
        : unreadBg;

    final Color borderColor = noti.isRead
        ? (isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3))
        : const Color(0xFF66ACFE).withOpacity(0.28);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _handleNotificationTap(context, noti),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: isDarkMode
                ? []
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _getIcon(context, noti.type),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            noti.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              fontFamily: 'Encode Sans Expanded',
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('h:mm a').format(noti.timestamp),
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white38
                                : Colors.grey[600],
                            fontSize: 11,
                            fontFamily: 'Encode Sans Expanded',
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showDeleteOneDialog(context, noti),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: isDarkMode
                                  ? Colors.white38
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Builder(
                      builder: (context) {
                        String displayContent = noti.content;
                        if (displayContent.startsWith(' đã ')) {
                          displayContent = 'Ai đó$displayContent';
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            NotificationService.updateNotificationContent(noti.id, displayContent);
                          });
                        }
                        return Text(
                          displayContent,
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white70
                                : const Color(0xFF4B5563),
                            height: 1.45,
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (!noti.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF5893D8),
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (!noti.isRead) const SizedBox(width: 8),
                        Text(
                          noti.isRead ? "Đã xem" : "Chưa đọc",
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: noti.isRead
                                ? (isDarkMode
                                ? Colors.white38
                                : Colors.grey[600])
                                : const Color(0xFF5893D8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getIcon(BuildContext context, String type) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    IconData iconData;
    Color iconColor;
    Color bgColor;

    switch (type) {
      case 'trending':
        iconData = Icons.whatshot_rounded;
        iconColor = Colors.orange;
        bgColor = Colors.orange.withOpacity(0.14);
        break;
      case 'warning':
        iconData = Icons.warning_amber_rounded;
        iconColor = Colors.redAccent;
        bgColor = Colors.redAccent.withOpacity(0.14);
        break;
      case 'chat':
        iconData = Icons.mark_chat_unread_rounded;
        iconColor = const Color(0xFF10B981);
        bgColor = const Color(0xFF10B981).withOpacity(0.14);
        break;
      case 'comment':
        iconData = Icons.chat_bubble_outline_rounded;
        iconColor = const Color(0xFF5893D8);
        bgColor = const Color(0xFF5893D8).withOpacity(0.14);
        break;
      case 'like':
        iconData = Icons.thumb_up_off_alt_rounded;
        iconColor = Colors.pinkAccent;
        bgColor = Colors.pinkAccent.withOpacity(0.14);
        break;
      default:
        iconData = Icons.notifications_none_rounded;
        iconColor = isDarkMode ? Colors.white70 : Colors.black54;
        bgColor = isDarkMode
            ? Colors.white.withOpacity(0.10)
            : Colors.black.withOpacity(0.06);
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(iconData, size: 23, color: iconColor),
    );
  }
}