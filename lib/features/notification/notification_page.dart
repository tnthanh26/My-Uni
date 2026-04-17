import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/notification_model.dart';
import '../../notification_service.dart';
import '../home/post_detail_page.dart';

class NotificationScreen extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Thông báo",
          style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 24,
              fontFamily: 'Nunito'
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: isDarkMode ? Colors.white12 : const Color(0xFFDFE6E9), height: 1),
        ),
      ),
      body: StreamBuilder<List<MyUniNotification>>(
        stream: NotificationService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Đã có lỗi xảy ra"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF5893D8)));

          final notifications = snapshot.data!;

          if (notifications.isEmpty) {
            return Center(
              child: Text(
                "Bạn chưa có thông báo nào",
                style: TextStyle(color: isDarkMode ? Colors.white38 : Colors.grey),
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 70,
                color: isDarkMode ? Colors.white12 : Colors.grey[200]
            ),
            itemBuilder: (context, index) {
              final noti = notifications[index];
              return _buildNotificationItem(context, noti);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, MyUniNotification noti) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Màu nền cho thông báo chưa đọc (Dark: Xanh mờ, Light: Hồng mờ)
    Color unreadColor = isDarkMode
        ? const Color(0xFF5893D8).withOpacity(0.1)
        : const Color(0xFFFFF5F5);

    return InkWell(
      onTap: () async {
        NotificationService.markAsRead(noti.id);

        if (noti.relatedPostId != null && noti.collectionPath != null) {
          final postDoc = await FirebaseFirestore.instance
              .collection(noti.collectionPath!)
              .doc(noti.relatedPostId)
              .get();

          if (postDoc.exists) {
            final postData = postDoc.data() as Map<String, dynamic>;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(
                  docId: noti.relatedPostId!,
                  initialPostData: postData,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Bài viết này không còn tồn tại")),
            );
          }
        }
      },
      child: Container(
        color: noti.isRead
            ? (isDarkMode ? Colors.transparent : Colors.white)
            : unreadColor,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _getIcon(context, noti.type),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          noti.title,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDarkMode ? Colors.white : Colors.black
                          )
                      ),
                      Text(
                        DateFormat('h:mm a').format(noti.timestamp),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    noti.content,
                    style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.grey[800],
                        height: 1.3,
                        fontFamily: 'Encode Sans Expanded'
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getIcon(BuildContext context, String type) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'trending':
        iconData = Icons.whatshot_outlined;
        iconColor = Colors.orange;
        break;
      case 'warning':
        iconData = Icons.warning_amber_rounded;
        iconColor = Colors.redAccent;
        break;
      case 'comment':
        iconData = Icons.chat_bubble_outline_rounded;
        iconColor = const Color(0xFF5893D8);
        break;
      case 'like':
        iconData = Icons.thumb_up_off_alt;
        iconColor = Colors.pinkAccent;
        break;
      default:
        iconData = Icons.notifications_none;
        iconColor = isDarkMode ? Colors.white70 : Colors.black54;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle
      ),
      child: Icon(iconData, size: 24, color: iconColor),
    );
  }
}