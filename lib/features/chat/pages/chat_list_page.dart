import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../theme/app_colors.dart';
import '../../../utils/base64_image_cache.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import 'chat_detail_page.dart';
import 'search_user_page.dart';

String _removeVietnameseDiacritics(String str) {
  var withDiacritics =
      'àáãảạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳỵỷỹđÀÁÃẢẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲỴỶỸĐ';
  var withoutDiacritics =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyydaaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyd';
  for (int i = 0; i < withDiacritics.length; i++) {
    str = str.replaceAll(withDiacritics[i], withoutDiacritics[i]);
  }
  return str;
}

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('vi', timeago.ViMessages());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0.5,
        title: const Text(
          'Đoạn chat',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search_rounded, color: AppColors.hcmusTeal),
            tooltip: 'Tìm sinh viên',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchUserPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Container(
              height: 44,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : const Color(0xFFE4E7EC),
                ),
              ),
              child: TextField(
                controller: _searchController,
                textAlignVertical: TextAlignVertical.center,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 13,
                  height: 1.2,
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF1D2939),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  fillColor: Colors.transparent,
                  hintText: 'Tìm kiếm cuộc trò chuyện...',
                  hintStyle: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? Colors.white38
                        : const Color(0xFF98A2B3),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: isDark
                        ? Colors.white54
                        : const Color(0xFF667085),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark
                          ? Colors.white54
                          : const Color(0xFF667085),
                    ),
                  )
                      : null,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.only(right: 8),
                ),
              ),
            ),
          ),

          // Danh sách các cuộc trò chuyện Realtime
          Expanded(
            child: StreamBuilder<List<ChatRoom>>(
              stream: _chatService.getUserChatRoomsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rooms = snapshot.data ?? [];

                final filteredRooms = rooms.where((room) {
                  final otherName = room.getOtherUserName(currentUid).toLowerCase();
                  final cleanName = _removeVietnameseDiacritics(otherName);
                  final q = _searchQuery.trim().toLowerCase();
                  final cleanQ = _removeVietnameseDiacritics(q);
                  return otherName.contains(q) || cleanName.contains(cleanQ);
                }).toList();

                if (filteredRooms.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 64,
                            color: AppColors.hcmusTeal.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Chưa có đoạn chat nào',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Bấm vào biểu tượng Nhắn tin ở bài viết hoặc trang cá nhân của sinh viên khác để bắt đầu trao đổi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  itemCount: filteredRooms.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final room = filteredRooms[index];

                    final otherUid = room.getOtherUserId(currentUid);
                    final otherName = room.getOtherUserName(currentUid);
                    final otherPhoto = room.getOtherUserPhoto(currentUid);

                    String timeStr = '';

                    if (room.lastMessageTime != null) {
                      timeStr = timeago.format(
                        room.lastMessageTime!,
                        locale: 'vi',
                      );
                    }

                    final unreadCount = room.unreadCounts[currentUid] ?? 0;
                    final bool isUnread = unreadCount > 0;

                    final Color itemColor = isUnread
                        ? (
                        isDark
                            ? const Color(0xFF18212B)
                            : const Color(0xFFF3F8FF)
                    )
                        : Colors.transparent;

                    final Color primaryTextColor = isDark
                        ? Colors.white
                        : const Color(0xFF1D2939);

                    final Color secondaryTextColor = isDark
                        ? Colors.white60
                        : const Color(0xFF667085);

                    return Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _chatService.markRoomAsRead(room.id);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatDetailPage(
                                roomId: room.id,
                                targetUserId: otherUid,
                                targetUserName: otherName,
                                targetUserPhoto: otherPhoto,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: itemColor,
                            borderRadius: BorderRadius.circular(14),
                            border: isUnread
                                ? Border.all(
                              color: AppColors.hcmusTeal.withValues(
                                alpha: isDark ? 0.24 : 0.16,
                              ),
                            )
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(otherUid)
                                        .snapshots(),
                                    builder: (context, userSnap) {
                                      String resolvedPhoto =
                                          Base64ImageCache.getCachedUserAvatar(
                                              otherUid) ??
                                              otherPhoto;
                                      String resolvedName = otherName;

                                      if (userSnap.hasData &&
                                          userSnap.data?.data() != null) {
                                        final uData = userSnap.data!.data()
                                        as Map<String, dynamic>;
                                        resolvedName = uData['displayName'] ??
                                            uData['name'] ??
                                            uData['fullName'] ??
                                            otherName;
                                        resolvedPhoto = uData['photoURL'] ??
                                            uData['photoUrl'] ??
                                            uData['avatar'] ??
                                            uData['authorAvatar'] ??
                                            uData['avatarUrl'] ??
                                            uData['userAvatar'] ??
                                            resolvedPhoto;
                                        Base64ImageCache.updateUserAvatar(
                                            otherUid, resolvedPhoto);
                                      }

                                      final avatarProvider =
                                      Base64ImageCache.getAvatarProvider(
                                          resolvedPhoto);

                                      return CircleAvatar(
                                        radius: 26,
                                        backgroundColor:
                                        AppColors.hcmusTeal.withValues(
                                          alpha: 0.15,
                                        ),
                                        backgroundImage: avatarProvider,
                                        child: avatarProvider == null
                                            ? Text(
                                          resolvedName
                                              .trim()
                                              .isNotEmpty
                                              ? resolvedName
                                              .trim()[0]
                                              .toUpperCase()
                                              : 'S',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight:
                                            FontWeight.w700,
                                            color: AppColors.hcmusTeal,
                                          ),
                                        )
                                            : null,
                                      );
                                    },
                                  ),
                                  Positioned(
                                    right: -1,
                                    bottom: -1,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.surfaceDark
                                            : Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.verified_rounded,
                                        size: 14,
                                        color: AppColors.hcmusTeal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            otherName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'Nunito',
                                              fontSize: 15.5,
                                              height: 1.2,
                                              fontWeight: isUnread
                                                  ? FontWeight.w800
                                                  : FontWeight.w700,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                        ),
                                        if (timeStr.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              fontFamily:
                                              'Encode Sans Expanded',
                                              fontSize: 10.5,
                                              fontWeight: isUnread
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: isUnread
                                                  ? AppColors.hcmusTeal
                                                  : secondaryTextColor,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            room.lastMessage.isNotEmpty
                                                ? room.lastMessage
                                                : 'Bắt đầu cuộc trò chuyện',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily:
                                              'Encode Sans Expanded',
                                              fontSize: 12.5,
                                              height: 1.3,
                                              fontWeight: isUnread
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: isUnread
                                                  ? primaryTextColor.withValues(
                                                alpha: 0.82,
                                              )
                                                  : secondaryTextColor,
                                            ),
                                          ),
                                        ),
                                        if (isUnread) ...[
                                          const SizedBox(width: 10),
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: AppColors.hcmusTeal,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
