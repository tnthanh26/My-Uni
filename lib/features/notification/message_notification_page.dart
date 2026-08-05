import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/notification_model.dart';
import '../services/notification_service.dart';
import '../chat/pages/chat_detail_page.dart';
import '../chat/pages/chat_list_page.dart';
import '../chat/services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/base64_image_cache.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_uni/widgets/app_action_dialogs.dart';

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

  static const Color _dangerColor = Color(0xFFE5484D);

  void _showDeleteAllDialog(BuildContext parentContext) async {
    final confirm = await AppActionDialogs.showConfirmDialog(
      context: parentContext,
      title: 'Xóa tất cả thông báo?',
      message: 'Toàn bộ thông báo tin nhắn sẽ bị xóa và không thể khôi phục.',
      confirmText: 'Xóa tất cả',
    );
    if (confirm == true) {
      await NotificationService.deleteAllMessageNotifications();
    }
  }

  void _showDeleteGroupDialog(
    BuildContext parentContext,
    _GroupedMessageNoti group,
  ) async {
    final String senderName =
        group.latestNoti.senderName?.trim().isNotEmpty == true
            ? group.latestNoti.senderName!
            : "sinh viên này";

    final confirm = await AppActionDialogs.showConfirmDialog(
      context: parentContext,
      title: 'Xóa thông báo?',
      message: 'Bạn có chắc muốn xóa tất cả thông báo tin nhắn từ $senderName không?',
      confirmText: 'Xóa',
    );
    if (confirm == true) {
      for (final noti in group.allNotis) {
        await NotificationService.deleteNotification(noti.id);
      }
    }
  }

  Future<void> _handleGroupTap(
    BuildContext context,
    _GroupedMessageNoti group,
  ) async {
    final String? roomId = group.latestNoti.roomId;

    if (roomId == null || roomId.isEmpty) {
      return;
    }

    final String currentUid = ChatService().currentUserId ?? '';

    String peerUid = group.latestNoti.senderId ?? '';

    if (peerUid.isEmpty) {
      peerUid = roomId.split('_').firstWhere(
            (id) => id != currentUid,
        orElse: () => '',
      );
    }

    final String resolvedPhoto = (peerUid.isNotEmpty
            ? Base64ImageCache.getCachedUserAvatar(peerUid)
            : null) ??
        group.latestNoti.senderAvatar ??
        '';

    // 1. Thực hiện điều hướng NGAY LẬP TỨC để app ko bị khựng
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailPage(
          roomId: roomId,
          targetUserId: peerUid,
          targetUserName:
              group.latestNoti.senderName ?? group.latestNoti.title,
          targetUserPhoto: resolvedPhoto,
        ),
      ),
    );

    // 2. Cập nhật trạng thái đã đọc trên Firestore chạy ngầm (không dùng await cản trở)
    try {
      for (final noti in group.allNotis) {
        if (!noti.isRead) {
          NotificationService.markAsRead(noti.id);
        }
      }
      ChatService().markRoomAsRead(roomId);
    } catch (e) {
      debugPrint("Lỗi cập nhật trạng thái đã đọc trong chat ngầm: $e");
    }
  }

  Widget _buildUnreadBadge(int unreadCount) {
    final String badgeText = unreadCount > 99 ? '99+' : '$unreadCount';

    return Container(
      constraints: const BoxConstraints(
        minWidth: 20,
        minHeight: 20,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.hcmusTeal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        badgeText,
        style: const TextStyle(
          fontSize: 10,
          height: 1.2,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildGroupedMessageItem(
    BuildContext context,
    _GroupedMessageNoti group,
    bool isDarkMode,
  ) {
    final MyUniNotification noti = group.latestNoti;

    final String timeStr = timeago.format(
      noti.timestamp,
      locale: 'vi',
    );

    final bool isUnread = group.unreadCount > 0;

    final String currentUid = ChatService().currentUserId ?? '';
    String senderUid = noti.senderId ?? '';
    if (senderUid.isEmpty && noti.roomId != null && noti.roomId!.isNotEmpty) {
      senderUid = noti.roomId!.split('_').firstWhere(
        (id) => id != currentUid,
        orElse: () => '',
      );
    }

    final String initialName = noti.senderName?.trim().isNotEmpty == true
        ? noti.senderName!
        : noti.title.trim().isNotEmpty
            ? noti.title
            : 'Một sinh viên';

    final String initialAvatar = noti.senderAvatar ?? '';

    final String previewContent = noti.content.trim().isNotEmpty
        ? noti.content.trim()
        : 'Đã gửi cho bạn một tin nhắn';

    final Color primaryTextColor =
        isDarkMode ? Colors.white : const Color(0xFF1D2939);

    final Color secondaryTextColor =
        isDarkMode ? Colors.white60 : const Color(0xFF667085);

    final Color unreadBackgroundColor = isDarkMode
        ? AppColors.hcmusTeal.withValues(alpha: 0.08)
        : AppColors.hcmusTeal.withValues(alpha: 0.06);

    return Material(
      color: isUnread ? unreadBackgroundColor : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          _handleGroupTap(context, group);
        },
        onLongPress: () {
          _showDeleteGroupDialog(context, group);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          child: StreamBuilder<DocumentSnapshot>(
            stream: senderUid.isNotEmpty
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(senderUid)
                    .snapshots()
                : null,
            builder: (context, userSnap) {
              String resolvedPhoto = (senderUid.isNotEmpty
                      ? Base64ImageCache.getCachedUserAvatar(senderUid)
                      : null) ??
                  initialAvatar;
              String resolvedName = initialName;

              if (userSnap.hasData && userSnap.data?.data() != null) {
                final uData = userSnap.data!.data() as Map<String, dynamic>;
                resolvedName = uData['displayName'] ??
                    uData['name'] ??
                    uData['fullName'] ??
                    initialName;
                resolvedPhoto = uData['photoURL'] ??
                    uData['photoUrl'] ??
                    uData['avatar'] ??
                    uData['authorAvatar'] ??
                    uData['avatarUrl'] ??
                    uData['userAvatar'] ??
                    resolvedPhoto;
                if (senderUid.isNotEmpty) {
                  Base64ImageCache.updateUserAvatar(senderUid, resolvedPhoto);
                }
              }

              final avatarProvider =
                  Base64ImageCache.getAvatarProvider(resolvedPhoto);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: AppColors.hcmusTeal.withValues(
                          alpha: 0.14,
                        ),
                        backgroundImage: avatarProvider,
                        child: avatarProvider == null
                            ? Text(
                                resolvedName.isNotEmpty
                                    ? resolvedName[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.hcmusTeal,
                                ),
                              )
                            : null,
                      ),
                      if (isUnread)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.hcmusTeal,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDarkMode
                                    ? const Color(0xFF101214)
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resolvedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 15,
                            fontWeight:
                                isUnread ? FontWeight.w800 : FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          previewContent,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight:
                                isUnread ? FontWeight.w600 : FontWeight.w400,
                            color: isUnread
                                ? primaryTextColor.withValues(
                                    alpha: 0.85,
                                  )
                                : secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              isUnread ? FontWeight.w600 : FontWeight.w400,
                          color: isUnread
                              ? AppColors.hcmusTeal
                              : secondaryTextColor,
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(height: 8),
                        _buildUnreadBadge(group.unreadCount),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.hcmusTeal,
        strokeWidth: 2.5,
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: isDarkMode
                  ? Colors.white38
                  : const Color(0xFF98A2B3),
            ),
            const SizedBox(height: 12),
            Text(
              "Không thể tải thông báo",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDarkMode
                    ? Colors.white
                    : const Color(0xFF344054),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "Vui lòng kiểm tra kết nối và thử lại.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 12,
                color: isDarkMode
                    ? Colors.white54
                    : const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.hcmusTeal.withValues(
                  alpha: isDarkMode ? 0.12 : 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_chat_read_outlined,
                size: 34,
                color: AppColors.hcmusTeal,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Chưa có thông báo tin nhắn",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDarkMode
                    ? Colors.white
                    : const Color(0xFF344054),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Thông báo về các tin nhắn mới sẽ xuất hiện tại đây.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 12,
                height: 1.45,
                color: isDarkMode
                    ? Colors.white54
                    : const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnreadSummary(
      int totalUnreadGroups,
      bool isDarkMode,
      ) {
    if (totalUnreadGroups <= 0) {
      return const SizedBox(height: 8);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 7),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.hcmusTeal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$totalUnreadGroups cuộc trò chuyện chưa đọc",
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white60
                    : const Color(0xFF667085),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode =
        Theme.of(context).brightness == Brightness.dark;

    final Color backgroundColor = isDarkMode
        ? const Color(0xFF101214)
        : Colors.white;

    final Color appBarColor = isDarkMode
        ? const Color(0xFF101214)
        : Colors.white;

    final Color primaryIconColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1D2939);

    final Color dividerColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFEAECF0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: "Quay lại",
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: primaryIconColor,
          ),
        ),
        title: Text(
          "Thông báo",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: primaryIconColor,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: "Tùy chọn",
            color: isDarkMode
                ? const Color(0xFF222427)
                : Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            icon: Icon(
              Icons.more_vert_rounded,
              color: primaryIconColor,
            ),
            onSelected: (value) async {
              if (value == 'read_all') {
                await NotificationService
                    .markAllMessageNotificationsAsRead();

                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Đã đánh dấu tất cả thông báo là đã đọc",
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                }
              }

              if (value == 'delete_all' &&
                  context.mounted) {
                _showDeleteAllDialog(context);
              }
            },
            itemBuilder: (menuContext) {
              final Color menuTextColor = isDarkMode
                  ? Colors.white
                  : const Color(0xFF344054);

              return [
                PopupMenuItem<String>(
                  value: 'read_all',
                  child: Row(
                    children: [
                      Icon(
                        Icons.done_all_rounded,
                        size: 20,
                        color: menuTextColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Đánh dấu tất cả đã đọc",
                        style: TextStyle(
                          fontFamily:
                          'Encode Sans Expanded',
                          fontSize: 12,
                          color: menuTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/trash.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          _dangerColor,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Xóa tất cả",
                        style: TextStyle(
                          fontFamily:
                          'Encode Sans Expanded',
                          fontSize: 12,
                          color: menuTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            width: double.infinity,
            height: 1,
            color: dividerColor,
          ),
        ),
      ),
      body: StreamBuilder<List<MyUniNotification>>(
        stream:
        NotificationService.getMessageNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(isDarkMode);
          }

          if (!snapshot.hasData) {
            return _buildLoadingState();
          }

          final List<MyUniNotification> rawNotifications =
          snapshot.data!;

          if (rawNotifications.isEmpty) {
            return _buildEmptyState(isDarkMode);
          }

          final Map<String, List<MyUniNotification>>
          groupedMap = {};

          for (final noti in rawNotifications) {
            final String key =
                noti.roomId ?? noti.senderId ?? noti.id;

            groupedMap.putIfAbsent(
              key,
                  () => <MyUniNotification>[],
            );

            groupedMap[key]!.add(noti);
          }

          final List<_GroupedMessageNoti> groupedList = [];

          groupedMap.forEach((key, list) {
            list.sort(
                  (a, b) =>
                  b.timestamp.compareTo(a.timestamp),
            );

            final MyUniNotification latest = list.first;

            final int unreadCount =
                list.where((noti) => !noti.isRead).length;

            groupedList.add(
              _GroupedMessageNoti(
                latestNoti: latest,
                allNotis: list,
                unreadCount: unreadCount,
              ),
            );
          });

          groupedList.sort(
                (a, b) => b.latestNoti.timestamp.compareTo(
              a.latestNoti.timestamp,
            ),
          );

          final int totalUnreadGroups = groupedList
              .where((group) => group.unreadCount > 0)
              .length;

          return Column(
            children: [
              _buildUnreadSummary(
                totalUnreadGroups,
                isDarkMode,
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    8,
                    totalUnreadGroups > 0 ? 3 : 8,
                    8,
                    20,
                  ),
                  itemCount: groupedList.length,
                  separatorBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 75),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: dividerColor,
                      ),
                    );
                  },
                  itemBuilder: (context, index) {
                    final _GroupedMessageNoti group =
                    groupedList[index];

                    return _buildGroupedMessageItem(
                      context,
                      group,
                      isDarkMode,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'message_notification_chat_list_fab',
        tooltip: 'Danh sách trò chuyện',
        backgroundColor: AppColors.hcmusTeal,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChatListPage(),
            ),
          );
        },
        child: const Icon(
          Icons.forum_rounded,
          size: 23,
        ),
      ),
    );
  }
}
