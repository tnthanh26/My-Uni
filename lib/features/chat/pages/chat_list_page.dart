import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../theme/app_colors.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import 'chat_detail_page.dart';

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
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm Google M3 Style
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFF4F8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                  hintText: 'Tìm kiếm cuộc trò chuyện...',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
                  return otherName.contains(_searchQuery);
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
                  itemCount: filteredRooms.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 72,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  itemBuilder: (context, index) {
                    final room = filteredRooms[index];
                    final otherUid = room.getOtherUserId(currentUid);
                    final otherName = room.getOtherUserName(currentUid);
                    final otherPhoto = room.getOtherUserPhoto(currentUid);
                    final unreadCount = room.getUnreadCount(currentUid);

                    String timeStr = '';
                    if (room.lastMessageTime != null) {
                      timeStr = timeago.format(room.lastMessageTime!, locale: 'vi');
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.hcmusTeal.withValues(alpha: 0.15),
                            backgroundImage: otherPhoto.isNotEmpty ? NetworkImage(otherPhoto) : null,
                            child: otherPhoto.isEmpty
                                ? Text(
                                    otherName.isNotEmpty ? otherName[0].toUpperCase() : 'S',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.hcmusTeal,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
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
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              otherName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeStr.isNotEmpty)
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: unreadCount > 0 ? AppColors.hcmusTeal : Colors.grey,
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                room.lastMessage.isNotEmpty
                                    ? room.lastMessage
                                    : 'Bắt đầu cuộc trò chuyện',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: unreadCount > 0
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Colors.grey,
                                  fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.hcmusTeal,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
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
                      onTap: () {
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
