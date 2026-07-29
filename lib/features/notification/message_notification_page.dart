import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/notification_model.dart';
import '../services/notification_service.dart';
import '../chat/pages/chat_detail_page.dart';
import '../chat/pages/chat_list_page.dart';
import '../chat/services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/base64_image_cache.dart';

class _GroupedMessageNoti {
  final MyUniNotification latestNoti;
  final List<MyUniNotification> allNotis;
  final int unreadCount;

  _GroupedMessageNoti({
    required this.latestNoti,
    required this.allNotis,
    required this.unreadCount,
  });
}

class MessageNotificationScreen extends StatelessWidget {
  const MessageNotificationScreen({super.key});

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

              await NotificationService.deleteAllMessageNotifications();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Đã xóa tất cả thông báo tin nhắn")),
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

  void _showDeleteGroupDialog(BuildContext context, _GroupedMessageNoti group) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          "Xóa thông báo tin nhắn",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          "Bạn có chắc muốn xóa thông báo từ ${group.latestNoti.senderName ?? 'sinh viên này'} không?",
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

              for (var noti in group.allNotis) {
                await NotificationService.deleteNotification(noti.id);
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Đã xóa thông báo tin nhắn")),
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

  void _handleGroupTap(BuildContext context, _GroupedMessageNoti group) async {
    // Đánh dấu tất cả thông báo thuộc người gửi này là đã đọc
    for (var noti in group.allNotis) {
      if (!noti.isRead) {
        NotificationService.markAsRead(noti.id);
      }
    }

    final roomId = group.latestNoti.roomId;
    if (roomId != null && roomId.isNotEmpty) {
      final currentUid = ChatService().currentUserId ?? '';
      final peerUid = group.latestNoti.senderId ??
          roomId.split('_').firstWhere((id) => id != currentUid, orElse: () => '');
      ChatService().markRoomAsRead(roomId);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            roomId: roomId,
            targetUserId: peerUid,
            targetUserName: group.latestNoti.senderName ?? group.latestNoti.title,
            targetUserPhoto: group.latestNoti.senderAvatar ?? '',
          ),
        ),
      );
    }
  }

  Widget _buildGroupedMessageItem(BuildContext context, _GroupedMessageNoti group, bool isDarkMode) {
    final noti = group.latestNoti;
    final timeStr = timeago.format(noti.timestamp, locale: 'vi');
    final isUnread = group.unreadCount > 0;
    final senderName = (noti.senderName != null && noti.senderName!.isNotEmpty)
        ? noti.senderName!
        : (noti.title.isNotEmpty ? noti.title : 'Một sinh viên');
    final avatarUrl = noti.senderAvatar ?? '';

    String previewContent = noti.content.isNotEmpty ? noti.content : 'Đã gửi cho bạn một tin nhắn';
    if (group.unreadCount > 1) {
      previewContent = '[${group.unreadCount} tin nhắn mới] $previewContent';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread
            ? (isDarkMode
                ? AppColors.hcmusTeal.withValues(alpha: 0.12)
                : const Color(0xFFEFF8F8))
            : (isDarkMode ? const Color(0xFF15171A) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnread
              ? AppColors.hcmusTeal.withValues(alpha: 0.3)
              : (isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3)),
        ),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _handleGroupTap(context, group),
          onLongPress: () => _showDeleteGroupDialog(context, group),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar người nhắn kèm icon nhắn tin nhỏ ở góc
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.hcmusTeal.withValues(alpha: 0.15),
                      backgroundImage: Base64ImageCache.getAvatarProvider(avatarUrl),
                      child: avatarUrl.isEmpty
                          ? Text(
                              senderName.isNotEmpty ? senderName[0].toUpperCase() : 'S',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.hcmusTeal,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          size: 12,
                          color: AppColors.hcmusTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Nội dung tin nhắn
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              senderName,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 15,
                                fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: isUnread ? AppColors.hcmusTeal : Colors.grey,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        previewContent,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                          color: isUnread
                              ? (isDarkMode ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF334155))
                              : (isDarkMode ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),

                // Huy hiệu số tin chưa đọc (nếu > 0)
                if (isUnread)
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.hcmusTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      group.unreadCount > 99 ? '99+' : '${group.unreadCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F1113) : const Color(0xFFF8FAFC),
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
            tooltip: "Đánh dấu tất cả là đã đọc",
            icon: const Icon(
              Icons.done_all_rounded,
              color: Color(0xFF5893D8),
            ),
            onPressed: () async {
              await NotificationService.markAllMessageNotificationsAsRead();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Đã đánh dấu tất cả thông báo tin nhắn là đã đọc")),
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
        stream: NotificationService.getMessageNotifications(),
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
              child: CircularProgressIndicator(color: AppColors.hcmusTeal),
            );
          }

          final rawNotifications = snapshot.data!;

          if (rawNotifications.isEmpty) {
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
                      Icons.mark_chat_read_outlined,
                      size: 44,
                      color: isDarkMode ? Colors.white38 : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Bạn chưa có thông báo tin nhắn nào",
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

          // Gộp danh sách thông báo theo phòng chat (roomId / senderId)
          final Map<String, List<MyUniNotification>> groupedMap = {};
          for (var noti in rawNotifications) {
            final key = noti.roomId ?? noti.senderId ?? noti.id;
            groupedMap.putIfAbsent(key, () => []).add(noti);
          }

          final List<_GroupedMessageNoti> groupedList = [];
          groupedMap.forEach((key, list) {
            list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            final latest = list.first;
            final unreadCount = list.where((n) => !n.isRead).length;
            groupedList.add(_GroupedMessageNoti(
              latestNoti: latest,
              allNotis: list,
              unreadCount: unreadCount,
            ));
          });

          groupedList.sort((a, b) => b.latestNoti.timestamp.compareTo(a.latestNoti.timestamp));

          final totalUnreadGroups = groupedList.where((g) => g.unreadCount > 0).length;

          return Column(
            children: [
              // Thẻ tổng quan số thông báo chưa đọc (Style y hệt NotificationScreen)
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
                            color: Colors.black.withValues(alpha: 0.03),
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
                        color: AppColors.hcmusTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.hcmusTeal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        totalUnreadGroups > 0
                            ? "Bạn có $totalUnreadGroups cuộc trò chuyện chưa đọc"
                            : "Bạn đã xem hết thông báo tin nhắn rồi",
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

              // Danh sách thông báo tin nhắn đã gộp gọn gàng
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  itemCount: groupedList.length,
                  itemBuilder: (context, index) {
                    final group = groupedList[index];
                    return _buildGroupedMessageItem(context, group, isDarkMode);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chat_list_fab',
        backgroundColor: AppColors.hcmusTeal,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: "Danh sách cuộc trò chuyện",
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatListPage()),
          );
        },
        child: const Icon(
          Icons.chat_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
