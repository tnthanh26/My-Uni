import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'widgets/mod_empty_state.dart';
import 'widgets/mod_error_state.dart';
import 'widgets/user_card.dart';
import 'widgets/post_card.dart';
import 'widgets/official_news_card.dart';
import 'widgets/user_activity_dialog.dart';
import 'services/mod_notification_service.dart';
import 'services/user_moderation_service.dart';
import 'services/user_activity_service.dart';
import 'services/post_moderation_service.dart';
import 'dart:convert';
import 'file_helper_stub.dart'
if (dart.library.html) 'file_helper_web.dart';

class ModDashboard extends StatefulWidget {
  const ModDashboard({super.key});

  @override
  State<ModDashboard> createState() => _ModDashboardState();
}

class _ModDashboardState extends State<ModDashboard> {
  int _selectedCollIndex = 0;
  int _filterStatusIndex = 0;
  String _userSearchKeyword = '';

  final List<String> _collections = [
    'forum_posts',
    'course_reviews',
    'study_materials',
    'official_news',
    'users',
  ];

  final List<String> _collTitles = [
    'Diễn đàn sinh viên',
    'Đánh giá môn học',
    'Tài liệu học thuật',
    'Thông báo chính thức',
    'Quản lý người dùng',
  ];

  final List<String> _filterLabels = ['Chờ duyệt', 'Bị báo cáo', 'Tất cả bài viết'];

  bool get _isOfficialNews => _collections[_selectedCollIndex] == 'official_news';
  bool get _isUsers => _collections[_selectedCollIndex] == 'users';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          // --- SIDEBAR ---
          Container(
            width: 260,
            color: const Color(0xFF1A1F37),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 50),
                const SizedBox(height: 10),
                const Text(
                  "MYUNI MOD",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 2,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 40),
                _buildSidebarSectionTitle("NỘI DUNG"),
                _buildMenuItem(0, Icons.forum_outlined, "Diễn đàn"),
                _buildMenuItem(1, Icons.rate_review_outlined, "Đánh giá"),
                _buildMenuItem(2, Icons.description_outlined, "Tài liệu"),
                _buildMenuItem(3, Icons.campaign_outlined, "Thông báo chính thức"),

                const SizedBox(height: 18),
                _buildSidebarSectionTitle("QUẢN TRỊ"),
                _buildMenuItem(4, Icons.people_alt_outlined, "Người dùng"),
                const Spacer(),
                _buildModAvatar(user),
              ],
            ),
          ),

          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _collTitles[_selectedCollIndex],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1F37),
                              fontFamily: 'Nunito',
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (!_isOfficialNews && !_isUsers)
                        Row(
                          children: List.generate(
                            _filterLabels.length,
                                (index) => _buildFilterTab(index),
                          ),
                        )
                      else if (_isOfficialNews)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            "Quản lý trực tiếp các thông báo chính thức từ website trường",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Quản lý trạng thái tài khoản người dùng trong hệ thống",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontFamily: 'Nunito',
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: 420,
                              child: TextField(
                                onChanged: (value) {
                                  setState(() => _userSearchKeyword = value);
                                },
                                decoration: InputDecoration(
                                  hintText: "Tìm theo tên hoặc email...",
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor: const Color(0xFFF5F7FA),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        )
                    ],
                  ),
                ),
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(int index) {
    bool isSelected = _filterStatusIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _filterStatusIndex = index),
      child: Container(
        margin: const EdgeInsets.only(right: 32),
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(bottom: BorderSide(color: Colors.blueAccent, width: 3))
              : null,
        ),
        child: Text(
          _filterLabels[index],
          style: TextStyle(
            fontFamily: 'Nunito',
            color: isSelected ? Colors.blueAccent : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontFamily: 'Nunito',
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title) {
    bool isSelected = _selectedCollIndex == index;
    return InkWell(
      onTap: () => setState(() {
        _selectedCollIndex = index;
        _filterStatusIndex = 0;
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey),
            const SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Nunito',
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isUsers) {
      final query = FirebaseFirestore.instance
          .collection('users')
          .orderBy('lastUpdated', descending: true);

      return StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data?.docs ?? [];

          final keyword = _userSearchKeyword.trim().toLowerCase();

          final docs = keyword.isEmpty
              ? allDocs
              : allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['displayName'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            return name.contains(keyword) || email.contains(keyword);
          }).toList();

          if (docs.isEmpty) {
            return _buildEmptyState(customText: "Chưa có người dùng nào!");
          }

          return ListView.builder(
            padding: const EdgeInsets.all(32),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final uid = docs[index].id;
              return _buildUserCard(uid, data);
            },
          );
        },
      );
    }

    if (_isOfficialNews) {
      final query = FirebaseFirestore.instance
          .collection('official_news')
          .orderBy('timestamp', descending: true);

      return StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return _buildEmptyState(customText: "Không có thông báo chính thức nào!");

          return ListView.builder(
            padding: const EdgeInsets.all(32),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              return OfficialNewsCard(
                docId: docId,
                data: data,
                onEdit: () => _handleEditOfficialNews(docId, data),
                onDelete: () => _handleDeleteOfficialNews(docId),
              );
            },
          );
        },
      );
    }

    Query query = FirebaseFirestore.instance.collection(_collections[_selectedCollIndex]);
    if (_filterStatusIndex == 0) {
      query = query.where('status', isEqualTo: 'pending');
    } else if (_filterStatusIndex == 1) {
      query = query.where('isReported', isEqualTo: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('updatedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(32),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            return PostCard(
              docId: docId,
              data: data,
              collection: _collections[_selectedCollIndex],
              onApprove: () => _handleApprovePost(docId, data),
              onDelete: () => _handleDeletePost(docId, data),
              onRestore: () => _handleRestorePost(docId, data),
              onDismissReport: () => _handleDismissReport(docId, data),
              onViewMaterial: () => _viewMaterial(data),
            );
          },
        );
      },
    );
  }

  Widget _buildUserCard(String uid, Map<String, dynamic> data) {
    return UserCard(
      uid: uid,
      data: data,
      onSuspend: () => _handleSuspendUser(uid, data),
      onRestore: () => _handleRestoreUser(uid, data),
      onViewActivity: () => _showUserActivity(uid, data),
    );
  }

  void _viewMaterial(Map<String, dynamic> data) {
    if (data['fileData'] == null) return;

    final String base64str = data['fileData'];
    final String fileName = data['fileName'] ?? "tai_lieu.pdf";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(fileName, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data['isImage'] == true)
              Image.memory(base64Decode(base64str))
            else ...[
              const Icon(Icons.picture_as_pdf, size: 80, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text("Đây là tài liệu định dạng PDF/File.", textAlign: TextAlign.center),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text("TẢI XUỐNG"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              FileHelper.downloadFile(base64str, fileName);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showUserActivity(String uid, Map<String, dynamic> userData) async {
    try {
      final activity = await UserActivityService.getUserActivity(uid);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => UserActivityDialog(
          displayName: userData['displayName'] ?? 'user',
          forumPosts: activity.forumPosts,
          reviews: activity.reviews,
          materials: activity.materials,
          logs: activity.logs,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể tải hoạt động user: $e")),
      );
    }
  }

  Future<void> _handleSuspendUser(String uid, Map<String, dynamic> data) async {
    final TextEditingController reasonController = TextEditingController();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Khóa tài khoản?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: "Nhập lý do khóa tài khoản...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Khóa",
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final reason = reasonController.text.trim().isEmpty
        ? "Tài khoản vi phạm quy định cộng đồng MyUni."
        : reasonController.text.trim();

    await UserModerationService.suspendUser(
      uid: uid,
      data: data,
      reason: reason,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã khóa tài khoản người dùng.")),
      );
    }
  }

  Future<void> _handleRestoreUser(String uid, Map<String, dynamic> data) async {
    await UserModerationService.restoreUser(
      uid: uid,
      data: data,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã khôi phục tài khoản người dùng.")),
      );
    }
  }

  Future<void> _handleApprovePost(String docId, Map<String, dynamic> data) async {
    await PostModerationService.approvePost(
      collection: _collections[_selectedCollIndex],
      docId: docId,
    );

    _sendNotification(
      userId: data['authorId'],
      title: "Bài viết đã được duyệt",
      content: "Bài viết của bạn đã được phê duyệt thành công.",
      type: 'comment',
      postId: docId,
    );
  }

  Future<void> _handleDeletePost(String docId, Map<String, dynamic> data) async {
    String reason = "Vi phạm tiêu chuẩn cộng đồng.";
    bool isReported = data['isReported'] ?? false;

    if (!isReported) {
      final TextEditingController reasonController = TextEditingController();
      bool? confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Lý do xóa bài", style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(hintText: "Nhập lý do cụ thể gửi user..."),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xác nhận", style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm != true) return;
      reason = reasonController.text.isEmpty
          ? "Nội dung không phù hợp với quy định của MyUni."
          : reasonController.text;
    }

    await PostModerationService.deletePost(
      collection: _collections[_selectedCollIndex],
      docId: docId,
    );

    _sendNotification(
      userId: data['authorId'],
      title: "Bài viết bị gỡ bỏ",
      content: "Lý do: $reason",
      type: 'warning',
      postId: docId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã gỡ bài viết và gửi thông báo.")),
      );
    }
  }

  Future<void> _handleRestorePost(String docId, Map<String, dynamic> data) async {
    await PostModerationService.restorePost(
      collection: _collections[_selectedCollIndex],
      docId: docId,
    );

    _sendNotification(
      userId: data['authorId'],
      title: "Bài viết đã được khôi phục",
      content: "Sau khi xem xét lại, Mod đã khôi phục bài viết của bạn.",
      type: 'comment',
      postId: docId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã khôi phục bài viết")),
      );
    }
  }

  Future<void> _handleDismissReport(String docId, Map<String, dynamic> data) async {
    await PostModerationService.dismissReport(
      collection: _collections[_selectedCollIndex],
      docId: docId,
    );
  }

  Future<void> _handleEditOfficialNews(String docId, Map<String, dynamic> data) async {
    final titleController = TextEditingController(text: data['title'] ?? '');
    final summaryController = TextEditingController(text: data['summary'] ?? '');
    final departmentController = TextEditingController(text: data['department'] ?? '');
    final linkController = TextEditingController(text: data['link'] ?? '');
    final dateController = TextEditingController(text: data['date'] ?? '');

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Chỉnh sửa thông báo",
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Nunito'),
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "Tiêu đề"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: departmentController,
                  decoration: const InputDecoration(labelText: "Phòng ban / đơn vị"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: "Ngày hiển thị"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkController,
                  decoration: const InputDecoration(labelText: "Link bài viết"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: summaryController,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: "Tóm tắt"),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Lưu", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('official_news').doc(docId).update({
      'title': titleController.text.trim(),
      'summary': summaryController.text.trim(),
      'department': departmentController.text.trim(),
      'link': linkController.text.trim(),
      'date': dateController.text.trim(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã cập nhật thông báo chính thức.")),
      );
    }
  }

  Future<void> _handleDeleteOfficialNews(String docId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Xóa thông báo?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Bài viết official news sẽ bị xóa khỏi Firebase. Không gửi thông báo cho user."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('official_news').doc(docId).delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã xóa thông báo chính thức.")),
      );
    }
  }

  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String content,
    required String type,
    required String postId,
  }) async {
    await ModNotificationService.sendPostNotification(
      userId: userId,
      title: title,
      content: content,
      type: type,
      postId: postId,
      collectionPath: _collections[_selectedCollIndex],
    );
  }

  Widget _buildModAvatar(User? user) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? "Moderator",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      Text(
                        user?.email ?? "",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text(
                        "Đăng xuất?",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      content: const Text(
                        "Bạn có chắc muốn đăng xuất khỏi tài khoản Moderator?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Hủy"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            "Đăng xuất",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true) return;

                  await FirebaseAuth.instance.signOut();

                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                          (route) => false,
                    );
                  }
                },
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: Colors.redAccent,
                ),
                label: const Text(
                  "Đăng xuất",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Nunito',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Colors.redAccent.withOpacity(0.35),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    String text = "Không có bài viết cần xử lý!",
    String? customText,
  }) {
    return ModEmptyState(
      text: customText ?? text,
    );
  }

  Widget _buildErrorState(String error) {
    return ModErrorState(error: error);
  }
}