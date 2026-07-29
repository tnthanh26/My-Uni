import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../theme/app_colors.dart';
import '../services/chat_service.dart';
import 'chat_detail_page.dart';

class SearchUserPage extends StatefulWidget {
  const SearchUserPage({super.key});

  @override
  State<SearchUserPage> createState() => _SearchUserPageState();
}

class _SearchUserPageState extends State<SearchUserPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _searchQuery = '';

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: 'Tìm sinh viên theo Tên, MSSV, Khoa...',
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.grey,
              fontSize: 14,
            ),
            border: InputBorder.none,
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _searchQuery.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.manage_search_rounded,
                      size: 72,
                      color: isDark ? Colors.white24 : AppColors.hcmusTeal.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tìm kiếm sinh viên HCMUS',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nhập Tên, MSSV, Khoa hoặc Email để bắt đầu tìm kiếm bạn học',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').limit(50).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Đã xảy ra lỗi khi tải danh sách sinh viên',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                // Lọc danh sách sinh viên theo từ khóa tìm kiếm (bỏ qua bản thân)
                final filteredUsers = docs.where((doc) {
                  if (doc.id == currentUid) return false;

                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final name = (data['displayName'] ?? data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final mssv = (data['studentId'] ?? data['mssv'] ?? '').toString().toLowerCase();
                  final faculty = (data['faculty'] ?? data['department'] ?? '').toString().toLowerCase();

                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery) ||
                      mssv.contains(_searchQuery) ||
                      faculty.contains(_searchQuery);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: isDark ? Colors.white24 : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không tìm thấy sinh viên phù hợp với "$_searchQuery"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: filteredUsers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = filteredUsers[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final targetUid = doc.id;

              final name = data['displayName'] ?? data['name'] ?? 'Sinh viên HCMUS';
              final photo = data['photoURL'] ?? data['avatar'] ?? '';
              final email = data['email'] ?? '';
              final mssv = data['studentId'] ?? data['mssv'] ?? '';
              final faculty = data['faculty'] ?? data['department'] ?? '';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar sinh viên
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.hcmusTeal.withValues(alpha: 0.15),
                      backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                      child: photo.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'S',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.hcmusTeal,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // Thông tin sinh viên
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 15,
                                color: AppColors.hcmusTeal,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (mssv.toString().isNotEmpty || faculty.toString().isNotEmpty)
                            Text(
                              [
                                if (mssv.toString().isNotEmpty) 'MSSV: $mssv',
                                if (faculty.toString().isNotEmpty) faculty,
                              ].join(' • '),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )
                          else if (email.toString().isNotEmpty)
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Nút Nhắn tin
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.hcmusTeal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        try {
                          final roomId = await _chatService.getOrCreateChatRoom(
                            targetUid,
                            targetName: name,
                            targetPhoto: photo,
                          );

                          if (context.mounted && roomId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailPage(
                                  roomId: roomId,
                                  targetUserId: targetUid,
                                  targetUserName: name,
                                  targetUserPhoto: photo,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Không thể bắt đầu chat: ${e.toString().replaceAll('Exception: ', '')}')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
