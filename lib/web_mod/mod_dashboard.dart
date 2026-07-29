import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'widgets/mod_empty_state.dart';
import 'widgets/mod_error_state.dart';
import 'widgets/user_card.dart';
import 'widgets/post_card.dart';
import 'widgets/official_news_card.dart';
import 'widgets/user_activity_dialog.dart';
import 'widgets/mod_comment_dialog.dart';
import 'services/mod_notification_service.dart';
import 'services/user_moderation_service.dart';
import 'services/user_activity_service.dart';
import 'services/post_moderation_service.dart';
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
  bool _isActionInProgress = false;

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

  final List<String> _filterLabels = ['Bị báo cáo', 'Tất cả bài viết'];

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
                              width: 360,
                              height: 46,
                              child: TextField(
                                onChanged: (value) {
                                  setState(() => _userSearchKeyword = value);
                                },
                                decoration: InputDecoration(
                                  hintText: "Tìm theo tên hoặc email...",
                                  prefixIcon: const Icon(Icons.search, size: 20),
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
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_filterStatusIndex == index) return;
        Timer(const Duration(milliseconds: 50), () {
          if (mounted) {
            setState(() => _filterStatusIndex = index);
          }
        });
      },
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_selectedCollIndex == index) return;
        Timer(const Duration(milliseconds: 50), () {
          if (mounted) {
            setState(() {
              _selectedCollIndex = index;
              _filterStatusIndex = 0;
            });
          }
        });
      },
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
      final query = FirebaseFirestore.instance.collection('users');

      return StreamBuilder<QuerySnapshot>(
        key: const ValueKey('users-stream-stable'),
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());

          final bool isLoading = snapshot.connectionState == ConnectionState.waiting;
          final allDocs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);

          // Sort in memory: Pending verification accounts first, then by lastUpdated/createdAt descending
          allDocs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;

            final bool isVerifiedA = dataA['isVerified'] ?? false;
            final String statusA = dataA['verificationStatus'] ?? (isVerifiedA ? 'approved' : 'pending');
            final bool isPendingA = (statusA == 'pending') || (!isVerifiedA && statusA != 'approved' && statusA != 'rejected');

            final bool isVerifiedB = dataB['isVerified'] ?? false;
            final String statusB = dataB['verificationStatus'] ?? (isVerifiedB ? 'approved' : 'pending');
            final bool isPendingB = (statusB == 'pending') || (!isVerifiedB && statusB != 'approved' && statusB != 'rejected');

            // 1. Pending accounts first
            if (isPendingA && !isPendingB) return -1;
            if (!isPendingA && isPendingB) return 1;

            // 2. Sort by timestamp descending
            final Timestamp? tA = dataA['lastUpdated'] as Timestamp? ?? dataA['createdAt'] as Timestamp?;
            final Timestamp? tB = dataB['lastUpdated'] as Timestamp? ?? dataB['createdAt'] as Timestamp?;
            if (tA == null && tB == null) return 0;
            if (tA == null) return 1;
            if (tB == null) return -1;
            return tB.compareTo(tA);
          });

          // Local filtering based on keyword
          final keyword = _userSearchKeyword.trim().toLowerCase();
          final docs = keyword.isEmpty
              ? allDocs
              : allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['displayName'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            return name.contains(keyword) || email.contains(keyword);
          }).toList();

          if (docs.isEmpty && !isLoading) {
            return _buildEmptyState(customText: keyword.isEmpty ? "Chưa có người dùng nào!" : "Không tìm thấy người dùng phù hợp!");
          }

          return Stack(
            children: [
              ListView.builder(
                key: const PageStorageKey('users-list-stable'),
                padding: const EdgeInsets.all(32),
                cacheExtent: 2500,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final uid = docs[index].id;
                  return _buildUserCard(uid, data);
                },
              ),
              if (isLoading)
                const Center(child: CircularProgressIndicator()),
            ],
          );
        },
      );
    }

    if (_isOfficialNews) {
      final query = FirebaseFirestore.instance
          .collection('official_news')
          .orderBy('publishedAt', descending: true);

      return StreamBuilder<QuerySnapshot>(
        key: const ValueKey('official-news-stream-stable'),
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());

          final bool isLoading = snapshot.connectionState == ConnectionState.waiting;
          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty && !isLoading) {
            return _buildEmptyState(customText: "Không có thông báo chính thức nào!");
          }

          return Stack(
            children: [
              ListView.builder(
                key: const PageStorageKey('official-news-list-stable'),
                padding: const EdgeInsets.all(32),
                cacheExtent: 2500,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final docId = docs[index].id;
                  return OfficialNewsCard(
                    key: ValueKey(docId),
                    docId: docId,
                    data: data,
                    onEdit: () => _handleEditOfficialNews(docId, data),
                    onDelete: () => _handleDeleteOfficialNews(docId),
                  );
                },
              ),
              if (isLoading)
                const Center(child: CircularProgressIndicator()),
            ],
          );
        },
      );
    }

    Query query = FirebaseFirestore.instance
        .collection(_collections[_selectedCollIndex])
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      key: ValueKey('posts-stream-$_selectedCollIndex-$_filterStatusIndex'),
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("🔥 FIRESTORE ERROR:");
          debugPrint(snapshot.error.toString());

          return _buildErrorState(snapshot.error.toString());
        }

        final bool isLoading = snapshot.connectionState == ConnectionState.waiting;
        final allDocs = snapshot.data?.docs ?? [];

        final List<QueryDocumentSnapshot> docs = _filterStatusIndex == 0
            ? allDocs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final int reportCount = d['reportCount'] ?? 0;
                final int reportedCommentCount = d['reportedCommentCount'] ?? 0;

                return reportCount > 0 || reportedCommentCount > 0;
              }).toList()
            : allDocs;

        if (docs.isEmpty && !isLoading) {
          return _buildEmptyState();
        }

        return Stack(
          children: [
            ListView.builder(
              key: PageStorageKey('posts-list-$_selectedCollIndex-$_filterStatusIndex'),
              padding: const EdgeInsets.all(32),
              cacheExtent: 2500,
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final docId = docs[index].id;
                return PostCard(
                  key: ValueKey(docId),
                  docId: docId,
                  data: data,
                  collection: _collections[_selectedCollIndex],
                  onApprove: () {},
                  onDelete: () => _handleDeletePost(docId, data),
                  onRestore: () => _handleRestorePost(docId, data),
                  onDismissReport: () => _handleDismissReport(docId, data),
                  onViewMaterial: () => _viewMaterial(data),
                  onViewComments: () => _handleViewComments(docId, _collections[_selectedCollIndex]),
                );
              },
            ),
            if (isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        );
      },
    );
  }

  void _handleViewComments(String postId, String collection) {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    showDialog(
      context: context,
      builder: (ctx) => ModCommentDialog(
        collection: collection,
        postId: postId,
      ),
    ).then((_) {
      _isActionInProgress = false;
    });
  }

  Widget _buildUserCard(String uid, Map<String, dynamic> data) {
    return UserCard(
      key: ValueKey(uid),
      uid: uid,
      data: data,
      onSuspend: () => _handleSuspendUser(uid, data),
      onRestore: () => _handleRestoreUser(uid, data),
      onViewActivity: () => _showUserActivity(uid, data),
      onApproveVerification: () => _handleApproveVerification(uid, data),
      onRejectVerification: () => _handleRejectVerification(uid, data),
      onDeleteUser: () => _handleDeleteUserAccount(uid, data),
    );
  }

  Future<void> _handleApproveVerification(String uid, Map<String, dynamic> data) async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;

    try {
      await UserModerationService.approveVerification(uid: uid, data: data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Đã duyệt xác thực cho ${data['displayName'] ?? 'tài khoản'}!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi duyệt xác thực: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isActionInProgress = false;
    }
  }

  Future<void> _handleRejectVerification(String uid, Map<String, dynamic> data) async {
    if (_isActionInProgress) return;

    final reasonController = TextEditingController();
    bool deleteAfterReject = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Từ chối xác thực tài khoản", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Nhập lý do từ chối xác thực cho ${data['displayName'] ?? 'người dùng'}:"),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: "VD: MSSV hoặc thông tin khoa chưa đúng",
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.redAccent,
                title: const Text(
                  "Xóa luôn tài khoản khỏi hệ thống (Giúp người dùng có thể tạo lại tài khoản mới với email này)",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent),
                ),
                value: deleteAfterReject,
                onChanged: (val) {
                  setDialogState(() {
                    deleteAfterReject = val ?? false;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text(
                deleteAfterReject ? "Từ chối & Xóa TK" : "Từ chối",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;
    _isActionInProgress = true;

    try {
      final reason = reasonController.text.trim().isEmpty
          ? "Thông tin hồ sơ sinh viên không hợp lệ"
          : reasonController.text.trim();

      if (deleteAfterReject) {
        await UserModerationService.deleteUserAccount(
          uid: uid,
          data: data,
          reason: "Từ chối xác thực & Xóa tài khoản ($reason)",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Đã từ chối xác thực và XÓA TÀI KHOẢN của ${data['displayName'] ?? ''} khỏi hệ thống."),
              backgroundColor: Colors.red.shade900,
            ),
          );
        }
      } else {
        await UserModerationService.rejectVerification(
          uid: uid,
          data: data,
          reason: reason,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Đã từ chối xác thực cho ${data['displayName'] ?? ''}"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isActionInProgress = false;
    }
  }

  Future<void> _handleDeleteUserAccount(String uid, Map<String, dynamic> data) async {
    if (_isActionInProgress) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa tài khoản người dùng", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text(
          "Bạn có chắc chắn muốn xóa dữ liệu tài khoản ${data['displayName'] ?? ''} (${data['email'] ?? ''}) khỏi hệ thống?\n\nHành động này sẽ giải phóng email để người dùng có thể đăng ký lại tài khoản mới.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
            child: const Text("Xóa tài khoản", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    _isActionInProgress = true;

    try {
      await UserModerationService.deleteUserAccount(
        uid: uid,
        data: data,
        reason: "Mod xóa tài khoản bị từ chối xác thực",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Đã xóa tài khoản ${data['displayName'] ?? ''} khỏi hệ thống."),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi khi xóa tài khoản: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isActionInProgress = false;
    }
  }

  void _viewMaterial(Map<String, dynamic> data) {
    if (data['fileData'] == null) return;
    if (_isActionInProgress) return;
    _isActionInProgress = true;

    final String base64str = data['fileData'];
    final String fileName = data['fileName'] ?? "tai_lieu.pdf";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(fileName, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data['isImage'] == true)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.6,
                  ),
                  child: Image.memory(
                    base64Decode(base64str),
                    fit: BoxFit.contain,
                  ),
                )
              else ...[
                const Icon(Icons.picture_as_pdf, size: 80, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text("Đây là tài liệu định dạng PDF/File.", textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Đóng"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16, color: Colors.white),
            label: const Text("Tải xuống", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              FileHelper.downloadFile(base64str, fileName);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ).then((_) {
      _isActionInProgress = false;
    });
  }

  Future<void> _showUserActivity(String uid, Map<String, dynamic> userData) async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    try {
      final activity = await UserActivityService.getUserActivity(uid);

      if (!mounted) return;

      await showDialog(
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Không thể tải hoạt động user: $e")),
        );
      }
    } finally {
      _isActionInProgress = false;
    }
  }

  Future<void> _handleSuspendUser(String uid, Map<String, dynamic> data) async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    try {
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
    } catch (e) {
      debugPrint("Error suspending user: $e");
    } finally {
      _isActionInProgress = false;
    }
  }

  Future<void> _handleRestoreUser(String uid, Map<String, dynamic> data) async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    try {
      await UserModerationService.restoreUser(
        uid: uid,
        data: data,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã khôi phục tài khoản người dùng.")),
        );
      }
    } catch (e) {
      debugPrint("Error restoring user: $e");
    } finally {
      _isActionInProgress = false;
    }
  }

  Future<void> _handleDeletePost(String docId, Map<String, dynamic> data) async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    try {
      String reason = "Vi phạm tiêu chuẩn cộng đồng.";
      bool isReported = data['isReported'] ?? false;

      if (!isReported) {
        final TextEditingController reasonController = TextEditingController();
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "Lý do xóa bài",
              style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Nunito'),
            ),
            content: SizedBox(
              width: 400,
              child: TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Nhập lý do cụ thể gửi user...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.orange),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Hủy"),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text("Xác nhận xóa"),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        reason = reasonController.text.trim().isEmpty
            ? "Nội dung không phù hợp với quy định của MyUni."
            : reasonController.text.trim();
      }

      await PostModerationService.deletePost(
        collection: _collections[_selectedCollIndex],
        docId: docId,
      );

      final reportsSnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('reportedPostId', isEqualTo: docId)
          .where('status', isEqualTo: 'pending')
          .get();

      final postReports = reportsSnapshot.docs.where((doc) {
        final rData = doc.data();
        return rData['reportedCommentId'] == null;
      }).toList();

      for (var reportDoc in postReports) {
        final rData = reportDoc.data();
        final reporterId = rData['reporterId'];
        if (reporterId != null) {
          await _sendNotification(
            userId: reporterId,
            title: "Phản hồi báo cáo",
            content: "Báo cáo của bạn đã được xử lý. Bài viết vi phạm đã bị xóa.",
            type: 'info',
            postId: docId,
          );
        }
        await reportDoc.reference.update({
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
        });
      }

      final authorId = data['authorId'] ?? data['uploaderId'];
      if (authorId != null) {
        await _sendNotification(
          userId: authorId,
          title: "Bài viết bị gỡ bỏ",
          content: isReported
              ? "Bài viết của bạn đã bị xóa do vi phạm tiêu chuẩn cộng đồng. Lý do: $reason"
              : "Bài viết của bạn đã bị gỡ bỏ bởi quản trị viên. Lý do: $reason",
          type: 'warning',
          postId: docId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã gỡ bài viết và gửi thông báo cho các bên.")),
        );
      }
    } catch (e) {
      debugPrint("Error deleting post: $e");
    } finally {
      _isActionInProgress = false;
    }
  }

  Future<void> _handleRestorePost(String docId, Map<String, dynamic> data) async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    try {
      await PostModerationService.restorePost(
        collection: _collections[_selectedCollIndex],
        docId: docId,
      );

      final authorId = data['authorId'] ?? data['uploaderId'];
      if (authorId != null) {
        _sendNotification(
          userId: authorId,
          title: "Bài viết đã được khôi phục",
          content: "Nội dung của bạn đã được duyệt.",
          type: 'info',
          postId: docId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã khôi phục bài viết")),
        );
      }
    } catch (e) {
      debugPrint("Error restoring post: $e");
    } finally {
      _isActionInProgress = false;
    }
  }

  Future<void> _handleDismissReport(String docId, Map<String, dynamic> data) async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    try {
      await PostModerationService.dismissReport(
        collection: _collections[_selectedCollIndex],
        docId: docId,
      );

      final reportsSnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('reportedPostId', isEqualTo: docId)
          .where('status', isEqualTo: 'pending')
          .get();

      final postReports = reportsSnapshot.docs.where((doc) {
        final rData = doc.data();
        return rData['reportedCommentId'] == null;
      }).toList();

      for (var reportDoc in postReports) {
        final rData = reportDoc.data();
        final reporterId = rData['reporterId'];
        if (reporterId != null) {
          await _sendNotification(
            userId: reporterId,
            title: "Phản hồi báo cáo",
            content: "Mod không phát hiện sai phạm đối với bài viết bạn đã báo cáo. Nội dung vẫn được giữ nguyên.",
            type: 'info',
            postId: docId,
          );
        }
        await reportDoc.reference.update({
          'status': 'dismissed',
          'resolvedAt': FieldValue.serverTimestamp(),
        });
      }

      final authorId = data['authorId'] ?? data['uploaderId'];
      if (authorId != null) {
        await _sendNotification(
          userId: authorId,
          title: "Báo cáo nội dung",
          content: "Mod không phát hiện sai phạm đối với bài viết của bạn. Bài viết vẫn giữ nguyên.",
          type: 'info',
          postId: docId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã hủy báo cáo và gửi thông báo cho các bên.")),
        );
      }
    } catch (e) {
      debugPrint("Error dismissing report: $e");
    } finally {
      _isActionInProgress = false;
    }
  }

  Future<void> _handleEditOfficialNews(String docId, Map<String, dynamic> data) async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    try {
      final titleController = TextEditingController(text: data['title'] ?? '');
      final summaryController = TextEditingController(text: data['summary'] ?? '');
      final departmentController = TextEditingController(text: data['department'] ?? '');
      final linkController = TextEditingController(text: data['link'] ?? '');
      final dateController = TextEditingController(text: data['publishedDateText'] ?? '');

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
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[300]!),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Lưu"),
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
        'publishedDateText': dateController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã cập nhật thông báo chính thức.")),
        );
      }
    } catch (e) {
      debugPrint("Error editing official news: $e");
    } finally {
      _isActionInProgress = false;
    }
  }

  Future<void> _handleDeleteOfficialNews(String docId) async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    try {
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
    } catch (e) {
      debugPrint("Error deleting official news: $e");
    } finally {
      _isActionInProgress = false;
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
                  if (_isActionInProgress) return;
                  _isActionInProgress = true;
                  try {
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
                  } catch (e) {
                    debugPrint("Error signing out: $e");
                  } finally {
                    _isActionInProgress = false;
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
