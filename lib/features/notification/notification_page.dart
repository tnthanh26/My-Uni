import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/notification_model.dart';
import '../../models/event_model.dart';
import '../chat/pages/chat_detail_page.dart';
import '../chat/services/chat_service.dart';
import '../event/create_personal_event_page.dart';
import '../home/post_detail_page.dart';
import '../services/notification_service.dart';
import 'package:my_uni/utils/app_feedback.dart';
import 'package:my_uni/utils/base64_image_cache.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  static const Color _primaryColor = Color(0xFF5893D8);
  static const Color _dangerColor = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode =
        Theme.of(context).brightness == Brightness.dark;

    final Color backgroundColor = isDarkMode
        ? const Color(0xFF101214)
        : const Color(0xFFF8FAFC);

    final Color appBarColor = isDarkMode
        ? const Color(0xFF101214)
        : Colors.white;

    final Color primaryTextColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1D2939);

    final Color dividerColor = isDarkMode
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFEAECF0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: primaryTextColor,
          ),
        ),
        title: Text(
          'Thông báo',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Tùy chọn',
            color: isDarkMode
                ? const Color(0xFF222427)
                : Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            icon: Icon(
              Icons.more_vert_rounded,
              color: primaryTextColor,
            ),
            onSelected: (value) async {
              if (value == 'read_all') {
                await NotificationService.markAllAsRead();

                if (context.mounted) {
                  AppFeedback.showSuccess(
                    context,
                    'Đã đánh dấu tất cả là đã đọc',
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
                        'Đánh dấu tất cả đã đọc',
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
                        'Xóa tất cả',
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
        stream: NotificationService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(isDarkMode);
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: _primaryColor,
                strokeWidth: 2.5,
              ),
            );
          }

          final List<MyUniNotification> notifications =
          snapshot.data!;

          if (notifications.isEmpty) {
            return _buildEmptyState(isDarkMode);
          }

          final int unreadCount = notifications
              .where((notification) => !notification.isRead)
              .length;

          return Column(
            children: [
              _buildUnreadSummary(
                unreadCount,
                isDarkMode,
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    unreadCount > 0 ? 4 : 10,
                    16,
                    20,
                  ),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final MyUniNotification noti =
                    notifications[index];

                    return Padding(
                      padding:
                      const EdgeInsets.only(bottom: 10),
                      child: _buildNotificationItem(
                        context,
                        noti,
                      ),
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

  Widget _buildUnreadSummary(
      int unreadCount,
      bool isDarkMode,
      ) {
    if (unreadCount <= 0) {
      return const SizedBox(height: 8);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        13,
        18,
        7,
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: _primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$unreadCount thông báo chưa đọc',
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

  Widget _buildNotificationItem(
      BuildContext context,
      MyUniNotification noti,
      ) {
    final bool isDarkMode =
        Theme.of(context).brightness == Brightness.dark;

    final bool isUnread = !noti.isRead;

    final Color cardColor = isUnread
        ? (isDarkMode
        ? const Color(0xFF18212B)
        : const Color(0xFFF3F8FF))
        : (isDarkMode
        ? const Color(0xFF15171A)
        : Colors.white);

    final Color borderColor = isUnread
        ? _primaryColor.withOpacity(0.25)
        : (isDarkMode
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFEAECF0));

    final Color primaryTextColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1D2939);

    final Color secondaryTextColor = isDarkMode
        ? Colors.white60
        : const Color(0xFF667085);

    final bool isEventNoti = noti.type == 'faculty_event' || noti.collectionPath == 'faculty_events';

    String displayContent = noti.content.trim();
    displayContent = displayContent
        .replaceAll('Khoa Khoa ', 'Khoa ')
        .replaceAll('Khoa Khoa', 'Khoa')
        .replaceAll('Khoa  vừa', 'Khoa vừa');

    if (displayContent.startsWith('đã ')) {
      displayContent = 'Ai đó $displayContent';
    } else if (displayContent.startsWith(' đã ')) {
      displayContent = 'Ai đó$displayContent';
    }

    if (displayContent.isEmpty) {
      displayContent = 'Bạn có một thông báo mới.';
    }

    // Process event notification title and badges
    String displayTitle = noti.title.trim().isNotEmpty ? noti.title : 'Thông báo mới';
    String? eventBadgeText;
    Color eventBadgeColor = _primaryColor;

    if (isEventNoti) {
      if (displayTitle.contains('Cập nhật sự kiện')) {
        eventBadgeText = 'CẬP NHẬT SỰ KIỆN';
        eventBadgeColor = const Color(0xFFF79009); // Amber
        displayTitle = displayTitle
            .replaceAll('🔄 ', '')
            .replaceAll('🔄', '')
            .replaceFirst('Cập nhật sự kiện: ', '')
            .replaceFirst('Cập nhật sự kiện:', '')
            .trim();
      } else if (displayTitle.contains('Sự kiện mới')) {
        eventBadgeText = 'SỰ KIỆN MỚI';
        eventBadgeColor = _primaryColor;
        displayTitle = displayTitle
            .replaceAll('📌 ', '')
            .replaceAll('📌', '')
            .replaceFirst('Sự kiện mới: ', '')
            .replaceFirst('Sự kiện mới:', '')
            .trim();
      } else {
        eventBadgeText = 'SỰ KIỆN KHOA';
        eventBadgeColor = _primaryColor;
      }
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _handleNotificationTap(context, noti);
        },
        onLongPress: () {
          _showDeleteOneDialog(context, noti);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: isDarkMode
                ? const []
                : [
              BoxShadow(
                color:
                Colors.black.withOpacity(0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _getNotificationIcon(
                context,
                noti.type,
                title: noti.title,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    if (isEventNoti && eventBadgeText != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: eventBadgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          eventBadgeText,
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: eventBadgeColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayTitle,
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 15,
                              height: 1.25,
                              fontWeight: isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatNotificationTime(
                            noti.timestamp,
                          ),
                          style: TextStyle(
                            fontFamily:
                            'Encode Sans Expanded',
                            fontSize: 10.5,
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isUnread
                                ? _primaryColor
                                : secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      displayContent,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily:
                        'Encode Sans Expanded',
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: isUnread
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: isUnread
                            ? primaryTextColor.withOpacity(
                          0.82,
                        )
                            : secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.center,
                children: [
                  InkWell(
                    borderRadius:
                    BorderRadius.circular(20),
                    onTap: () {
                      _showDeleteOneDialog(
                        context,
                        noti,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: isDarkMode
                            ? Colors.white38
                            : const Color(0xFF98A2B3),
                      ),
                    ),
                  ),
                  if (isUnread) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                      const BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getNotificationIcon(
      BuildContext context,
      String type, {
      String? title,
      }) {
    final bool isDarkMode =
        Theme.of(context).brightness == Brightness.dark;

    late final IconData iconData;
    late final Color iconColor;

    switch (type) {
      case 'trending':
        iconData =
            Icons.local_fire_department_rounded;
        iconColor = const Color(0xFFF79009);
        break;

      case 'faculty_event':
        if (title != null && (title.contains('Cập nhật') || title.contains('🔄'))) {
          iconData = Icons.edit_calendar_rounded;
          iconColor = const Color(0xFFF79009); // Amber
        } else {
          iconData = Icons.event_available_rounded;
          iconColor = _primaryColor; // Blue
        }
        break;

      case 'warning':
        iconData = Icons.warning_amber_rounded;
        iconColor = const Color(0xFFF04438);
        break;

      case 'chat':
        iconData =
            Icons.mark_chat_unread_rounded;
        iconColor = const Color(0xFF12B76A);
        break;

      case 'comment':
        iconData =
            Icons.chat_bubble_outline_rounded;
        iconColor = _primaryColor;
        break;

      case 'like':
        iconData =
            Icons.thumb_up_alt_outlined;
        iconColor = const Color(0xFFEE46BC);
        break;

      case 'report':
        iconData =
            Icons.report_outlined;
        iconColor = const Color(0xFFF04438);
        break;

      case 'success':
        iconData =
            Icons.check_circle_outline_rounded;
        iconColor = const Color(0xFF12B76A);
        break;

      default:
        iconData =
            Icons.notifications_none_rounded;
        iconColor = isDarkMode
            ? Colors.white70
            : const Color(0xFF667085);
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        iconData,
        size: 22,
        color: iconColor,
      ),
    );
  }

  String _formatNotificationTime(
      DateTime timestamp,
      ) {
    final DateTime now = DateTime.now();

    Duration difference = now.difference(timestamp);

    if (difference.isNegative) {
      difference = Duration.zero;
    }

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} giờ';
    }

    if (difference.inDays == 1) {
      return 'Hôm qua';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} ngày';
    }

    if (timestamp.year == now.year) {
      return DateFormat('dd/MM').format(timestamp);
    }

    return DateFormat('dd/MM/yy').format(timestamp);
  }

  Future<void> _handleNotificationTap(
      BuildContext context,
      MyUniNotification noti,
      ) async {
    if (!noti.isRead) {
      await NotificationService.markAsRead(
        noti.id,
      );
    }

    if (!context.mounted) {
      return;
    }

    if (noti.type == 'chat' ||
        noti.roomId != null) {
      final String? roomId = noti.roomId;

      if (roomId != null &&
          roomId.isNotEmpty) {
        final String currentUid =
            ChatService().currentUserId ?? '';

        final String peerUid =
            noti.senderId ??
                roomId.split('_').firstWhere(
                      (id) => id != currentUid,
                  orElse: () => '',
                );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChatDetailPage(
                  roomId: roomId,
                  targetUserId: peerUid,
                  targetUserName:
                  noti.senderName ?? noti.title,
                  targetUserPhoto:
                  noti.senderAvatar ?? '',
                ),
          ),
        );

        return;
      }
    }

    if (noti.relatedPostId == null ||
        noti.collectionPath == null) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Container(
          color: Colors.black.withOpacity(0.18),
          child: const Center(
            child: CircularProgressIndicator(
              color: _primaryColor,
            ),
          ),
        );
      },
    );

    try {
      final DocumentSnapshot<Map<String, dynamic>>
      postDoc = await FirebaseFirestore.instance
          .collection(noti.collectionPath!)
          .doc(noti.relatedPostId)
          .get()
          .timeout(
        const Duration(seconds: 5),
      );

      if (!context.mounted) {
        return;
      }

      Navigator.pop(context);

      final bool isCommentNotification =
      _isCommentNotification(noti);

      if (!postDoc.exists) {
        _showUnavailableDialog(
          context,
          noti.id,
          isComment: isCommentNotification,
        );
        return;
      }

      final Map<String, dynamic> postData =
      postDoc.data()!;

      if (noti.collectionPath == 'faculty_events' ||
          noti.type == 'faculty_event') {
        _showFacultyEventDetailsModal(context, noti.relatedPostId!, postData);
        return;
      }

      if (postData['status'] == 'hidden') {
        _showUnavailableDialog(
          context,
          noti.id,
          isComment: isCommentNotification,
        );
        return;
      }

      if (noti.reportedCommentId != null) {
        final commentDoc = await FirebaseFirestore
            .instance
            .collection(noti.collectionPath!)
            .doc(noti.relatedPostId)
            .collection('comments')
            .doc(noti.reportedCommentId)
            .get();

        if (!context.mounted) {
          return;
        }

        if (!commentDoc.exists) {
          _showUnavailableDialog(
            context,
            noti.id,
            isComment: true,
          );
          return;
        }
      }

      if (!context.mounted) {
        return;
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
    } on FirebaseException catch (e) {
      if (!context.mounted) {
        return;
      }

      Navigator.pop(context);

      if (e.code == 'permission-denied' ||
          e.code == 'not-found') {
        _showUnavailableDialog(
          context,
          noti.id,
          isComment:
          _isCommentNotification(noti),
        );
      } else {
        AppFeedback.showError(
          context,
          'Lỗi hệ thống: ${e.message ?? e.code}',
        );
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      Navigator.pop(context);

      _showUnavailableDialog(
        context,
        noti.id,
        isComment:
        _isCommentNotification(noti),
      );
    }
  }

  bool _isCommentNotification(
      MyUniNotification noti,
      ) {
    return noti.reportedCommentId != null ||
        noti.type == 'comment' ||
        noti.title
            .toLowerCase()
            .contains('bình luận') ||
        noti.content
            .toLowerCase()
            .contains('bình luận');
  }

  void _showUnavailableDialog(
      BuildContext parentContext,
      String notiId, {
        bool isComment = false,
      }) {
    final bool isDarkMode =
        Theme.of(parentContext).brightness ==
            Brightness.dark;

    final Color textColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1F2937);

    final Color secondaryTextColor =
    isDarkMode
        ? Colors.white60
        : const Color(0xFF667085);

    final Color borderColor = isDarkMode
        ? Colors.white.withOpacity(0.12)
        : const Color(0xFFE4E7EC);

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkMode
              ? const Color(0xFF1C1E21)
              : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(20),
          ),
          titlePadding:
          const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            8,
          ),
          contentPadding:
          const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20,
          ),
          actionsPadding:
          const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20,
          ),
          title: Text(
            isComment
                ? 'Bình luận không khả dụng'
                : 'Bài viết không khả dụng',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          content: Text(
            isComment
                ? 'Bình luận này đã bị xóa hoặc không còn tồn tại.'
                : 'Bài viết này đã bị xóa hoặc không còn tồn tại.',
            style: TextStyle(
              fontFamily:
              'Encode Sans Expanded',
              fontSize: 13,
              height: 1.45,
              color: secondaryTextColor,
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(
                          dialogContext,
                        );
                      },
                      style:
                      OutlinedButton.styleFrom(
                        foregroundColor:
                        secondaryTextColor,
                        side: BorderSide(
                          color: borderColor,
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Đóng',
                        style: TextStyle(
                          fontFamily:
                          'Encode Sans Expanded',
                          fontSize: 13,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(
                          dialogContext,
                        );

                        await NotificationService
                            .deleteNotification(
                          notiId,
                        );

                        if (parentContext
                            .mounted) {
                          AppFeedback.showInfo(
                            parentContext,
                            'Đã xóa thông báo',
                          );
                        }
                      },
                      style:
                      FilledButton.styleFrom(
                        backgroundColor:
                        _dangerColor,
                        foregroundColor:
                        Colors.white,
                        elevation: 0,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Xóa',
                        style: TextStyle(
                          fontFamily:
                          'Encode Sans Expanded',
                          fontSize: 12,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAllDialog(
      BuildContext parentContext,
      ) {
    final bool isDarkMode =
        Theme.of(parentContext).brightness ==
            Brightness.dark;

    final Color textColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1F2937);

    final Color secondaryTextColor =
    isDarkMode
        ? Colors.white60
        : const Color(0xFF667085);

    final Color borderColor = isDarkMode
        ? Colors.white.withOpacity(0.12)
        : const Color(0xFFE4E7EC);

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkMode
              ? const Color(0xFF1C1E21)
              : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(20),
          ),
          titlePadding:
          const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            8,
          ),
          contentPadding:
          const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20,
          ),
          actionsPadding:
          const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20,
          ),
          title: Text(
            'Xóa tất cả thông báo?',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          content: Text(
            'Toàn bộ thông báo sẽ bị xóa và không thể khôi phục.',
            style: TextStyle(
              fontFamily:
              'Encode Sans Expanded',
              fontSize: 13,
              height: 1.45,
              color: secondaryTextColor,
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(
                          dialogContext,
                        );
                      },
                      style:
                      OutlinedButton.styleFrom(
                        foregroundColor:
                        secondaryTextColor,
                        side: BorderSide(
                          color: borderColor,
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          fontFamily:
                          'Encode Sans Expanded',
                          fontSize: 13,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(
                          dialogContext,
                        );

                        await NotificationService
                            .deleteAllNotifications();

                        if (parentContext
                            .mounted) {
                          AppFeedback.showInfo(
                            parentContext,
                            'Đã xóa tất cả thông báo',
                          );
                        }
                      },
                      style:
                      FilledButton.styleFrom(
                        backgroundColor:
                        _dangerColor,
                        foregroundColor:
                        Colors.white,
                        elevation: 0,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Xóa tất cả',
                        style: TextStyle(
                          fontFamily:
                          'Encode Sans Expanded',
                          fontSize: 13,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showDeleteOneDialog(
      BuildContext parentContext,
      MyUniNotification noti,
      ) {
    final bool isDarkMode =
        Theme.of(parentContext).brightness ==
            Brightness.dark;

    final Color textColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1F2937);

    final Color secondaryTextColor =
    isDarkMode
        ? Colors.white60
        : const Color(0xFF667085);

    final Color borderColor = isDarkMode
        ? Colors.white.withOpacity(0.12)
        : const Color(0xFFE4E7EC);

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkMode
              ? const Color(0xFF1C1E21)
              : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(20),
          ),
          titlePadding:
          const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            8,
          ),
          contentPadding:
          const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20,
          ),
          actionsPadding:
          const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20,
          ),
          title: Text(
            'Xóa thông báo?',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          content: Text(
            'Bạn có chắc muốn xóa thông báo này không?',
            style: TextStyle(
              fontFamily:
              'Encode Sans Expanded',
              fontSize: 13,
              height: 1.45,
              color: secondaryTextColor,
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(
                          dialogContext,
                        );
                      },
                      style:
                      OutlinedButton.styleFrom(
                        foregroundColor:
                        secondaryTextColor,
                        side: BorderSide(
                          color: borderColor,
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          fontFamily:
                          'Encode Sans Expanded',
                          fontSize: 13,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(
                          dialogContext,
                        );

                        await NotificationService
                            .deleteNotification(
                          noti.id,
                        );

                        if (parentContext
                            .mounted) {
                          AppFeedback.showInfo(
                            parentContext,
                            'Đã xóa thông báo',
                          );
                        }
                      },
                      style:
                      FilledButton.styleFrom(
                        backgroundColor:
                        _dangerColor,
                        foregroundColor:
                        Colors.white,
                        elevation: 0,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Xóa',
                        style: TextStyle(
                          fontFamily:
                          'Encode Sans Expanded',
                          fontSize: 13,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(
      bool isDarkMode,
      ) {
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
                color: _primaryColor.withOpacity(
                  isDarkMode ? 0.14 : 0.09,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 34,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có thông báo',
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
              'Các thông báo về lượt thích, bình luận và hoạt động mới sẽ xuất hiện tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily:
                'Encode Sans Expanded',
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

  Widget _buildErrorState(
      bool isDarkMode,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
        ),
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
              'Không thể tải thông báo',
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
              'Vui lòng kiểm tra kết nối và thử lại.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily:
                'Encode Sans Expanded',
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

  Future<void> _launchURL(String urlString) async {
    final cleanUrl = urlString.trim();
    if (cleanUrl.isEmpty) return;
    final Uri url = Uri.parse(cleanUrl);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _showFacultyEventDetailsModal(
      BuildContext context,
      String docId,
      Map<String, dynamic> data,
      ) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    const Color primaryColor = Color(0xFF5893D8);

    final Color bgColor = isDark
        ? const Color(0xFF1C1E21)
        : Colors.white;

    final Color surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF8FAFC);

    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE4E7EC);

    final Color textColor = isDark
        ? Colors.white
        : const Color(0xFF1D2939);

    final Color secondaryText = isDark
        ? Colors.white60
        : const Color(0xFF667085);

    final String eventName = (
        data['eventName'] ??
            data['title'] ??
            'Sự kiện Khoa'
    ).toString();

    final String description =
    (data['description'] ?? '').toString();

    final String eventDateText = (
        data['eventDateText'] ??
            data['date'] ??
            ''
    ).toString();

    final String locationName =
    (data['locationName'] ?? '').toString();

    final String locationAddress =
    (data['locationAddress'] ?? '').toString();

    final String facultyName = (
        data['facultyName'] ??
            data['department'] ??
            'Khoa HCMUS'
    ).toString();

    final String onlineUrl = (
        data['onlineUrl'] ??
            data['onlineLink'] ??
            ''
    ).toString().trim();

    final bool isOnline =
        data['isOnline'] == true ||
            onlineUrl.isNotEmpty;

    final String sourceArticleUrl = (
        data['sourceArticleUrl'] ??
            data['registrationUrl'] ??
            data['link'] ??
            onlineUrl
    ).toString();

    final String? thumbnailUrl =
        data['thumbnailUrl'] ??
            (
                data['imageUrls'] != null &&
                    (data['imageUrls'] as List).isNotEmpty
                    ? data['imageUrls'][0]
                    : null
            );

    final String rawContact = (
        data['contact'] ??
            data['contactInfo'] ??
            ''
    ).toString().trim();

    final String rawOrganizer = (
        data['organizer'] ??
            data['organizerName'] ??
            ''
    ).toString().trim();

    String displayContact = rawContact.isNotEmpty
        ? rawContact
        : rawOrganizer;

    if (displayContact.isNotEmpty &&
        !displayContact
            .toLowerCase()
            .startsWith('liên hệ')) {
      displayContact = 'Liên hệ: $displayContact';
    }

    final List<String> locParts = [];

    if (locationName.trim().isNotEmpty) {
      locParts.add(locationName.trim());
    }

    if (locationAddress.trim().isNotEmpty &&
        locationAddress.trim() != locationName.trim()) {
      locParts.add(locationAddress.trim());
    }

    String locStr = locParts.join(' • ');

    if (locStr.trim().isEmpty) {
      locStr = isOnline
          ? 'Trực tuyến'
          : 'Chưa cập nhật địa điểm';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.44),
      builder: (bottomContext) {
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight:
              MediaQuery.of(bottomContext).size.height *
                  0.88,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(
                    top: 10,
                    bottom: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white24
                        : const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      18,
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        if (thumbnailUrl != null &&
                            thumbnailUrl.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius:
                            BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                Base64ImageCache.buildSmartImage(
                                  imageUrl: thumbnailUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fallbackAsset: 'assets/images/news.png',
                                ),

                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient:
                                      LinearGradient(
                                        begin:
                                        Alignment.topCenter,
                                        end: Alignment
                                            .bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black
                                              .withValues(
                                            alpha: 0.30,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                if (isOnline)
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration:
                                      BoxDecoration(
                                        color: Colors.black
                                            .withValues(
                                          alpha: 0.46,
                                        ),
                                        borderRadius:
                                        BorderRadius
                                            .circular(10),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(
                                            alpha: 0.20,
                                          ),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize:
                                        MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons
                                                .videocam_outlined,
                                            size: 13,
                                            color:
                                            Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Online',
                                            style: TextStyle(
                                              fontFamily:
                                              'Encode Sans Expanded',
                                              color:
                                              Colors.white,
                                              fontSize: 10,
                                              fontWeight:
                                              FontWeight
                                                  .w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        Text(
                          facultyName,
                          style: const TextStyle(
                            fontFamily:
                            'Encode Sans Expanded',
                            color: primaryColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 7),

                        Text(
                          eventName,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            height: 1.3,
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (eventDateText.isNotEmpty)
                          _buildFacultyEventInfoRow(
                            icon: Icons.access_time_rounded,
                            text: eventDateText,
                            iconColor: primaryColor,
                            textColor: textColor,
                            fontWeight: FontWeight.w600,
                          ),

                        if (eventDateText.isNotEmpty)
                          const SizedBox(height: 11),

                        _buildFacultyEventInfoRow(
                          icon: isOnline
                              ? Icons.videocam_outlined
                              : Icons.location_on_outlined,
                          text: locStr,
                          iconColor: primaryColor,
                          textColor: secondaryText,
                        ),

                        if (displayContact.isNotEmpty) ...[
                          const SizedBox(height: 11),
                          _buildFacultyEventInfoRow(
                            icon:
                            Icons.contact_phone_outlined,
                            text: displayContact,
                            iconColor: primaryColor,
                            textColor: secondaryText,
                          ),
                        ],

                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 20),

                          Divider(
                            height: 1,
                            color: borderColor,
                          ),

                          const SizedBox(height: 18),

                          Text(
                            'Thông tin chi tiết',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            description,
                            style: TextStyle(
                              fontFamily:
                              'Encode Sans Expanded',
                              fontSize: 12.5,
                              color: secondaryText,
                              height: 1.55,
                            ),
                          ),
                        ],

                        if (onlineUrl.isNotEmpty ||
                            (
                                sourceArticleUrl.isNotEmpty &&
                                    sourceArticleUrl != onlineUrl
                            )) ...[
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              if (onlineUrl.isNotEmpty)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      _launchURL(onlineUrl);
                                    },
                                    icon: const Icon(
                                      Icons
                                          .videocam_outlined,
                                      size: 17,
                                    ),
                                    label: const Text(
                                      'Tham gia',
                                      style: TextStyle(
                                        fontFamily:
                                        'Encode Sans Expanded',
                                        fontSize: 12,
                                        fontWeight:
                                        FontWeight.w600,
                                      ),
                                    ),
                                    style:
                                    OutlinedButton.styleFrom(
                                      foregroundColor:
                                      primaryColor,
                                      side: BorderSide(
                                        color: primaryColor
                                            .withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                      minimumSize:
                                      const Size(
                                        double.infinity,
                                        42,
                                      ),
                                      shape:
                                      RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius
                                            .circular(12),
                                      ),
                                    ),
                                  ),
                                ),

                              if (onlineUrl.isNotEmpty &&
                                  sourceArticleUrl
                                      .isNotEmpty &&
                                  sourceArticleUrl !=
                                      onlineUrl)
                                const SizedBox(width: 9),

                              if (sourceArticleUrl
                                  .isNotEmpty &&
                                  sourceArticleUrl !=
                                      onlineUrl)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      _launchURL(
                                        sourceArticleUrl,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons
                                          .open_in_new_rounded,
                                      size: 17,
                                    ),
                                    label: const Text(
                                      'Bài viết gốc',
                                      style: TextStyle(
                                        fontFamily:
                                        'Encode Sans Expanded',
                                        fontSize: 12,
                                        fontWeight:
                                        FontWeight.w600,
                                      ),
                                    ),
                                    style:
                                    OutlinedButton.styleFrom(
                                      foregroundColor:
                                      secondaryText,
                                      side: BorderSide(
                                        color: borderColor,
                                      ),
                                      minimumSize:
                                      const Size(
                                        double.infinity,
                                        42,
                                      ),
                                      shape:
                                      RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius
                                            .circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(bottomContext);

                              _openCreatePersonalEventFromNotification(
                                context,
                                docId,
                                data,
                              );
                            },
                            icon: const Icon(
                              Icons.event_available_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              'Quan tâm và thêm vào lịch',
                              style: TextStyle(
                                fontFamily:
                                'Encode Sans Expanded',
                                fontSize: 13,
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                              primaryColor,
                              foregroundColor:
                              Colors.white,
                              elevation: 0,
                              shape:
                              RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(
                                  12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFacultyEventInfoRow({
    required IconData icon,
    required String text,
    required Color iconColor,
    required Color textColor,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            icon,
            size: 17,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 12.5,
              height: 1.45,
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  void _openCreatePersonalEventFromNotification(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final String eventName = (data['eventName'] ?? data['title'] ?? 'Sự kiện Khoa').toString();
    final String description = (data['description'] ?? '').toString();
    final String locationName = (data['locationName'] ?? '').toString();
    final String locationAddress = (data['locationAddress'] ?? '').toString();
    final String facultyName = (data['facultyName'] ?? data['department'] ?? 'Khoa HCMUS').toString();
    final String onlineUrl = (data['onlineUrl'] ?? data['onlineLink'] ?? '').toString().trim();
    final bool isOnline = data['isOnline'] == true || onlineUrl.isNotEmpty;
    final String sourceArticleUrl = (data['sourceArticleUrl'] ?? data['registrationUrl'] ?? data['link'] ?? onlineUrl).toString();

    DateTime parsedDateTime = DateTime.now();
    if (data['startAt'] != null && data['startAt'] is Timestamp) {
      parsedDateTime = (data['startAt'] as Timestamp).toDate();
    } else if (data['startDateTime'] != null && data['startDateTime'] is String) {
      final parsed = DateTime.tryParse(data['startDateTime']);
      if (parsed != null) parsedDateTime = parsed;
    } else if (data['registrationDeadlineAt'] != null && data['registrationDeadlineAt'] is Timestamp) {
      parsedDateTime = (data['registrationDeadlineAt'] as Timestamp).toDate();
    }

    final List<String> locParts = [];
    if (locationName.trim().isNotEmpty) locParts.add(locationName.trim());
    if (locationAddress.trim().isNotEmpty && locationAddress.trim() != locationName.trim()) {
      locParts.add(locationAddress.trim());
    }
    String locStr = locParts.join(' - ');
    if (locStr.trim().isEmpty) {
      locStr = isOnline ? 'Online' : (facultyName.isNotEmpty ? facultyName : 'Chưa cập nhật địa điểm');
    }

    final eventToEdit = EventModel(
      id: docId,
      title: eventName,
      dateTime: parsedDateTime,
      location: locStr,
      reminder: '15 phút trước',
      description: '',
      sourceArticleUrl: sourceArticleUrl,
      onlineUrl: onlineUrl,
      isOnline: isOnline,
      facultyEventId: docId,
      isFromFacultyEvent: true,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePersonalEventPage(event: eventToEdit),
      ),
    );
  }
}