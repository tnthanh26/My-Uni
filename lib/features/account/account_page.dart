import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';
import 'utilities_page.dart';
import 'setting_page.dart';
import 'my_post_page.dart';
import 'my_review_page.dart';
import 'saved_posts_page.dart';
import 'social_contacts_page.dart';
import '../home/onboarding_dialog.dart';
import '../../theme/app_colors.dart';
import '../chat/pages/chat_list_page.dart';
import '../chat/pages/search_user_page.dart';
import '../chat/services/chat_service.dart';
import '../chat/models/chat_models.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  void _navigateIfAllowed(BuildContext context, String? verificationStatus, Widget page) {
    if ((verificationStatus == 'pending' || verificationStatus == 'rejected') && page is! EditProfilePage) {
      final isRejected = verificationStatus == 'rejected';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isRejected
              ? 'Tài khoản của bạn đã bị từ chối xác thực nên chưa thể truy cập tính năng này.'
              : 'Tài khoản của bạn đang chờ kiểm duyệt viên xác thực nên chưa thể truy cập tính năng này.'),
          backgroundColor: isRejected ? Colors.red.shade900 : Colors.amber.shade900,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  void _showLogoutDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
        isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          "Đăng xuất",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          "Bạn có chắc chắn muốn đăng xuất không?",
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
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: const Text(
              "Đăng xuất",
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

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Encode Sans Expanded',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({
    required bool isDarkMode,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
        ),
        boxShadow: isDarkMode
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Divider(
        height: 1,
        color: isDarkMode ? Colors.white10 : const Color(0xFFEAEFF5),
      ),
    );
  }

  Widget _buildAccountItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
        Color iconColor = const Color(0xFF6797E1),
        Widget? trailing,
      }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.95)
                        : Colors.black87,
                  ),
                ),
              ),
              trailing ?? Icon(
                Icons.chevron_right_rounded,
                color: isDarkMode ? Colors.white24 : Colors.black26,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required BuildContext context,
    required bool isDarkMode,
    required String name,
    required String faculty,
    required String? photoBase64,
    required bool isVerified,
    required String? verificationStatus,
  }) {
    ImageProvider? avatarProvider;
    Widget? avatarChild;

    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        avatarProvider = MemoryImage(base64Decode(photoBase64));
      } catch (_) {
        avatarChild = Icon(
          Icons.person,
          size: 52,
          color: isDarkMode ? Colors.white54 : Colors.grey,
        );
      }
    } else {
      avatarChild = Icon(
        Icons.person,
        size: 52,
        color: isDarkMode ? Colors.white54 : Colors.grey,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
        ),
        boxShadow: isDarkMode
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor:
                isDarkMode ? Colors.white10 : const Color(0xFFF3F4F6),
                backgroundImage: avatarProvider,
                child: avatarChild,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => _navigateIfAllowed(context, verificationStatus, const EditProfilePage()),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6797E1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            faculty,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 14,
              color: isDarkMode ? Colors.white60 : const Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 14),
          if (isVerified)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6797E1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Color(0xFF6797E1),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Đã xác thực',
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          color: Color(0xFF6797E1),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showStudentQrDialog(
      BuildContext context, {
        required bool isDarkMode,
        required String qrData,
        required String name,
        required String studentId,
        required String faculty,
        required String cohort,
        required String university,
      }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor:
        isDarkMode ? const Color(0xFF15171A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF6797E1).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: Color(0xFF6797E1),
                  size: 28,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Thẻ sinh viên MyUni',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color:
                  isDarkMode ? Colors.white : const Color(0xFF1F2937),
                ),
              ),

              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 22),

              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color:
                  isDarkMode ? Colors.white : const Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'MSSV: $studentId',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6797E1),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                faculty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? Colors.white60
                      : const Color(0xFF667085),
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '$cohort • $university',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 12,
                  color: isDarkMode
                      ? Colors.white38
                      : const Color(0xFF98A2B3),
                ),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6797E1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDarkMode ? const Color(0xFF0F1113) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Tài khoản',
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            color: isDarkMode ? Colors.white : const Color(0xFF545454),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF111315) : Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            String name = "Người dùng MyUni";
            String faculty = "Chưa cập nhật khoa";
            String studentId = "Chưa cập nhật MSSV";
            String university = "Chưa cập nhật trường";
            String cohort = "Chưa cập nhật niên khóa";
            String? photoBase64;
            bool isVerified = false;
            String? verificationStatus;

            if (snapshot.hasData && snapshot.data!.exists) {
              var data = snapshot.data!.data() as Map<String, dynamic>;
              name = data['displayName'] ?? "Người dùng";
              faculty = data['faculty'] ?? "Chưa cập nhật khoa";
              studentId = data['studentId'] ?? "Chưa cập nhật MSSV";
              university = data['university'] ?? "Chưa cập nhật trường";
              cohort = data['cohort'] ?? "Chưa cập nhật niên khóa";
              photoBase64 = data['photoUrl'];
              isVerified = data['isVerified'] ?? false;
              verificationStatus = data['verificationStatus'] ?? (isVerified ? 'approved' : 'pending');
            }

            final qrData = jsonEncode({
              'type': 'myuni_student_qr',
              'version': 1,
              'uid': user?.uid,
              'displayName': name,
              'studentId': studentId,
              'faculty': faculty,
              'cohort': cohort,
              'university': university,
              'isVerified': isVerified,
              'generatedAt': DateTime.now().toIso8601String(),
            });

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600.0),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (verificationStatus == 'pending' || verificationStatus == 'rejected') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (verificationStatus == 'rejected' ? Colors.red.shade900 : Colors.amber.shade900).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: (verificationStatus == 'rejected' ? Colors.red.shade800 : Colors.amber.shade800).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                verificationStatus == 'rejected' ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                                color: verificationStatus == 'rejected' ? Colors.red.shade800 : Colors.amber.shade800,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  verificationStatus == 'rejected'
                                      ? 'Tài khoản của bạn đã bị kiểm duyệt viên từ chối xác thực. Vui lòng sửa lại thông tin chính xác để gửi lại yêu cầu.'
                                      : 'Tài khoản của bạn đang chờ kiểm duyệt viên xác thực. Các tính năng tương tác, nhắn tin và chỉnh sửa hồ sơ tạm thời bị giới hạn.',
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 12.5,
                                    color: verificationStatus == 'rejected'
                                        ? (isDarkMode ? Colors.red.shade200 : Colors.red.shade900)
                                        : (isDarkMode ? Colors.amber.shade200 : Colors.amber.shade900),
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (verificationStatus == 'rejected') ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const EditProfilePage(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit_note, size: 18, color: Colors.white),
                                label: const Text(
                                  'Sửa thông tin & Gửi lại xác thực',
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade900,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  _buildProfileHeader(
                    context: context,
                    isDarkMode: isDarkMode,
                    name: name,
                    faculty: faculty,
                    photoBase64: photoBase64,
                    isVerified: isVerified,
                    verificationStatus: verificationStatus,
                  ),
                  const SizedBox(height: 22),

                  _buildSectionTitle('Tin nhắn & Kết nối', isDarkMode),
                  _buildSettingsGroup(
                    isDarkMode: isDarkMode,
                    children: [
                      _buildAccountItem(
                        context,
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Đoạn chat',
                        trailing: StreamBuilder<List<ChatRoom>>(
                          stream: ChatService().getUserChatRoomsStream(),
                          builder: (context, snapshot) {
                            final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                            final rooms = snapshot.data ?? [];
                            final unreadCount = rooms.fold<int>(
                              0, (sum, room) => sum + room.getUnreadCount(myUid),
                            );

                            if (unreadCount > 0) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.hcmusTeal,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$unreadCount mới',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }
                            return const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey);
                          },
                        ),
                        onTap: () => _navigateIfAllowed(context, verificationStatus, const ChatListPage()),
                      ),
                      _buildDivider(isDarkMode),
                      _buildAccountItem(
                        context,
                        icon: Icons.person_search_rounded,
                        title: 'Tìm kiếm người dùng',
                        onTap: () => _navigateIfAllowed(context, verificationStatus, const SearchUserPage()),
                      ),
                      _buildDivider(isDarkMode),
                      _buildAccountItem(
                        context,
                        icon: Icons.contact_phone_outlined,
                        title: 'Thông tin liên hệ của tôi',
                        onTap: () => _navigateIfAllowed(context, verificationStatus, const SocialContactsPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  _buildSectionTitle('Tài khoản', isDarkMode),
                  _buildSettingsGroup(
                    isDarkMode: isDarkMode,
                    children: [
                      _buildAccountItem(
                        context,
                        icon: Icons.qr_code_2_rounded,
                        title: 'Thẻ sinh viên MyUni',
                        onTap: () {
                          _showStudentQrDialog(
                            context,
                            isDarkMode: isDarkMode,
                            qrData: qrData,
                            name: name,
                            studentId: studentId,
                            faculty: faculty,
                            cohort: cohort,
                            university: university,
                          );
                        },
                      ),
                      _buildDivider(isDarkMode),
                      _buildAccountItem(
                        context,
                        icon: Icons.key_outlined,
                        title: 'Đổi mật khẩu',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const ChangePasswordPage(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(isDarkMode),
                      _buildAccountItem(
                        context,
                        icon: Icons.settings_outlined,
                        title: 'Cài đặt',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _buildSectionTitle('Nội dung của bạn', isDarkMode),
                  _buildSettingsGroup(
                    isDarkMode: isDarkMode,
                    children: [
                      _buildAccountItem(
                        context,
                        icon: Icons.article_outlined,
                        title: 'Bài đăng của tôi',
                        onTap: () => _navigateIfAllowed(context, verificationStatus, const MyPostsPage()),
                      ),
                      _buildDivider(isDarkMode),
                      _buildAccountItem(
                        context,
                        icon: Icons.rate_review_outlined,
                        title: 'Đánh giá của tôi',
                        onTap: () => _navigateIfAllowed(context, verificationStatus, const MyReviewsPage()),
                      ),
                      _buildDivider(isDarkMode),
                      _buildAccountItem(
                        context,
                        icon: Icons.bookmark_outline_rounded,
                        title: 'Bài đã lưu',
                        onTap: () => _navigateIfAllowed(context, verificationStatus, const SavedPostsPage()),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _buildSectionTitle('Khác', isDarkMode),
                  _buildSettingsGroup(
                    isDarkMode: isDarkMode,
                    children: [
                      _buildAccountItem(
                        context,
                        icon: Icons.grid_view_outlined,
                        title: 'Tiện ích',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UtilitiesPage(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(isDarkMode),
                      _buildAccountItem(
                        context,
                        icon: Icons.explore_outlined,
                        title: 'Hướng dẫn sử dụng',
                        onTap: () {
                          showOnboardingDialog(context);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE57373),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text(
                        'Đăng xuất',
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            )));
          },
        ),
      ),
    );
  }
}