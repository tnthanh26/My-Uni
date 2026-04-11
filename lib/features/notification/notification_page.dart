import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/notification_model.dart';
import '../../notification_service.dart';
import '../home/post_detail_page.dart';

class NotificationScreen extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Thông báo",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<MyUniNotification>>(
        stream: NotificationService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Đã có lỗi xảy ra"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final notifications = snapshot.data!;

          if (notifications.isEmpty) {
            return const Center(child: Text("Bạn chưa có thông báo nào"));
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
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
            // Xử lý bài viết đã bị xóa
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Bài viết này không còn tồn tại")),
            );
          }
        }
      },
      child: Container(
        color: noti.isRead ? Colors.white : const Color(0xFFFFF5F5),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _getIcon(noti.type),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(noti.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        DateFormat('h.mm a').format(noti.timestamp),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    noti.content,
                    style: TextStyle(color: Colors.grey[800], height: 1.3),
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

  Widget _getIcon(String type) {
    IconData iconData;
    switch (type) {
      case 'trending': iconData = Icons.whatshot_outlined; break;
      case 'warning': iconData = Icons.warning_amber_rounded; break;
      case 'comment': iconData = Icons.chat_bubble_outline_rounded; break;
      case 'like': iconData = Icons.thumb_up_off_alt; break;
      default: iconData = Icons.notifications_none;
    }
    return Icon(iconData, size: 28, color: Colors.black);
  }
}