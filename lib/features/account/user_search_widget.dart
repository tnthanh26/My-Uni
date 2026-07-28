import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utility to remove Vietnamese diacritics for flexible text search
String removeVietnameseDiacritics(String str) {
  const vietnameseMap = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'A': 'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ',
    'd': 'đ',
    'D': 'Đ',
    'e': 'èéẹẻẽêềếệểễ',
    'E': 'ÈÉẸẺẼÊỀẾỆỂỄ',
    'i': 'ìíịỉĩ',
    'I': 'ÌÍỊỈĨ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'O': 'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ',
    'u': 'ùúụủũưừứựửữ',
    'U': 'ÙÚỤỦŨƯỪỨỰỬỮ',
    'y': 'ỳýỵỷỹ',
    'Y': 'ỲÝỴỶỸ',
  };

  String result = str;
  vietnameseMap.forEach((nonDiacritics, diacritics) {
    for (int i = 0; i < diacritics.length; i++) {
      result = result.replaceAll(diacritics[i], nonDiacritics);
    }
  });
  return result.toLowerCase();
}

/// Helper to render User Avatar safely (Base64, Network URL, or Fallback icon)
Widget buildUserAvatar(
  String? photoUrl, {
  double radius = 22,
  required bool isDarkMode,
}) {
  if (photoUrl != null && photoUrl.trim().isNotEmpty) {
    final cleanUrl = photoUrl.trim();
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor:
            isDarkMode ? Colors.white10 : const Color(0xFFF3F4F6),
        backgroundImage: NetworkImage(cleanUrl),
      );
    }
    try {
      final bytes = base64Decode(cleanUrl);
      return CircleAvatar(
        radius: radius,
        backgroundColor:
            isDarkMode ? Colors.white10 : const Color(0xFFF3F4F6),
        backgroundImage: MemoryImage(bytes),
      );
    } catch (_) {
      // Fallback below
    }
  }

  return CircleAvatar(
    radius: radius,
    backgroundColor:
        isDarkMode ? const Color(0xFF2A2E33) : const Color(0xFFEBF2FA),
    child: Icon(
      Icons.person_rounded,
      size: radius * 1.1,
      color: isDarkMode ? Colors.white60 : const Color(0xFF6797E1),
    ),
  );
}

/// Unified User Search Bar Widget (Single Card Container)
class UserSearchWidget extends StatefulWidget {
  const UserSearchWidget({super.key});

  @override
  State<UserSearchWidget> createState() => _UserSearchWidgetState();
}

class _UserSearchWidgetState extends State<UserSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showUserDetailModal(
      BuildContext context, Map<String, dynamic> userData, String docId) {
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = docId == currentUid;

    final String name = userData['displayName'] ?? 'Người dùng MyUni';
    final String studentId = userData['studentId'] ?? 'Chưa cập nhật MSSV';
    final String faculty = userData['faculty'] ?? 'Chưa cập nhật khoa';
    final String university = userData['university'] ?? 'Chưa cập nhật trường';
    final String cohort = userData['cohort'] ?? 'Chưa cập nhật niên khóa';
    final String? photoUrl = userData['photoUrl'];
    final bool isVerified = userData['isVerified'] ?? false;
    final String email = userData['email'] ?? '';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor:
            isDarkMode ? const Color(0xFF15171A) : Colors.white,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Avatar
              Stack(
                alignment: Alignment.center,
                children: [
                  buildUserAvatar(photoUrl, radius: 46, isDarkMode: isDarkMode),
                  if (isCurrentUser)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6797E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Bạn',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Name & Verified Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: Color(0xFF6797E1),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),

              // Faculty subtitle
              Text(
                faculty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 13,
                  color: isDarkMode ? Colors.white60 : const Color(0xFF667085),
                ),
              ),

              const SizedBox(height: 20),
              Divider(
                color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
                height: 1,
              ),
              const SizedBox(height: 16),

              // Info Items
              _buildModalInfoRow(
                context: context,
                isDarkMode: isDarkMode,
                icon: Icons.badge_outlined,
                label: 'MSSV',
                value: studentId,
                canCopy: studentId.isNotEmpty &&
                    studentId != 'Chưa cập nhật MSSV',
              ),
              const SizedBox(height: 12),
              _buildModalInfoRow(
                context: context,
                isDarkMode: isDarkMode,
                icon: Icons.school_outlined,
                label: 'Trường',
                value: university,
              ),
              const SizedBox(height: 12),
              _buildModalInfoRow(
                context: context,
                isDarkMode: isDarkMode,
                icon: Icons.calendar_today_outlined,
                label: 'Niên khóa',
                value: cohort,
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildModalInfoRow(
                  context: context,
                  isDarkMode: isDarkMode,
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: email,
                ),
              ],

              const SizedBox(height: 22),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF6797E1).withValues(alpha: 0.12),
                    foregroundColor: const Color(0xFF6797E1),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
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

  Widget _buildModalInfoRow({
    required BuildContext context,
    required bool isDarkMode,
    required IconData icon,
    required String label,
    required String value,
    bool canCopy = false,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF6797E1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF6797E1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 11,
                  color: isDarkMode ? Colors.white38 : const Color(0xFF98A2B3),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (canCopy)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: const Color(0xFF6797E1),
            tooltip: 'Sao chép $label',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã sao chép $label: $value'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bool hasResults = _query.isNotEmpty || _isExpanded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _focusNode.hasFocus
              ? const Color(0xFF6797E1)
              : (isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3)),
          width: _focusNode.hasFocus ? 1.5 : 1.0,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single Search Row (Directly inside the single unified card container)
          SizedBox(
            height: 52,
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF6797E1),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: (val) {
                      if (!_isExpanded) {
                        setState(() => _isExpanded = true);
                      }
                    },
                    onTap: () {
                      if (!_isExpanded) {
                        setState(() => _isExpanded = true);
                      }
                    },
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 14.5,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm tên user, MSSV, khoa...',
                      hintStyle: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 13.5,
                        color: isDarkMode
                            ? Colors.white38
                            : const Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: isDarkMode
                          ? Colors.white38
                          : const Color(0xFF94A3B8),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                      });
                    },
                  )
                else if (_isExpanded)
                  IconButton(
                    icon: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 22,
                      color: isDarkMode
                          ? Colors.white38
                          : const Color(0xFF94A3B8),
                    ),
                    onPressed: () {
                      _focusNode.unfocus();
                      setState(() {
                        _isExpanded = false;
                      });
                    },
                  ),
              ],
            ),
          ),

          // Divider and Results (When active or text typed)
          if (hasResults) ...[
            Divider(
              height: 1,
              color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Đã xảy ra lỗi khi tải dữ liệu người dùng.',
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 13,
                        color: Colors.red.shade400,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF6797E1),
                        ),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final cleanQuery = removeVietnameseDiacritics(_query);

                // Filter matching users
                final matchingDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final displayName = data['displayName']?.toString() ?? '';
                  final studentId = data['studentId']?.toString() ?? '';
                  final faculty = data['faculty']?.toString() ?? '';
                  final university = data['university']?.toString() ?? '';
                  final email = data['email']?.toString() ?? '';

                  if (cleanQuery.isEmpty) return true;

                  final normName = removeVietnameseDiacritics(displayName);
                  final normStudentId =
                      removeVietnameseDiacritics(studentId);
                  final normFaculty = removeVietnameseDiacritics(faculty);
                  final normUniv = removeVietnameseDiacritics(university);
                  final normEmail = removeVietnameseDiacritics(email);

                  return normName.contains(cleanQuery) ||
                      normStudentId.contains(cleanQuery) ||
                      normFaculty.contains(cleanQuery) ||
                      normUniv.contains(cleanQuery) ||
                      normEmail.contains(cleanQuery);
                }).toList();

                if (_query.isEmpty && matchingDocs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Nhập tên người dùng hoặc MSSV để bắt đầu tìm kiếm.',
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 13,
                        color: isDarkMode
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                    ),
                  );
                }

                if (_query.isNotEmpty && matchingDocs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_search_outlined,
                          size: 40,
                          color: isDarkMode
                              ? Colors.white24
                              : const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Không tìm thấy người dùng nào phù hợp',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white70
                                : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Thử tìm kiếm với từ khóa khác như tên, MSSV hoặc khoa.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.white38
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Text(
                        _query.isEmpty
                            ? 'Danh sách người dùng (${matchingDocs.length})'
                            : 'Kết quả tìm kiếm (${matchingDocs.length})',
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? Colors.white54
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: matchingDocs.length > 10
                            ? 10
                            : matchingDocs.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: isDarkMode
                              ? Colors.white10
                              : const Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (context, index) {
                          final doc = matchingDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final String docId = doc.id;
                          final bool isCurrentUser = docId == currentUid;

                          final String name =
                              data['displayName'] ?? 'Người dùng MyUni';
                          final String studentId =
                              data['studentId'] ?? '';
                          final String faculty = data['faculty'] ?? '';
                          final String? photoUrl = data['photoUrl'];
                          final bool isVerified = data['isVerified'] ?? false;

                          final String subtitleText = [
                            if (studentId.isNotEmpty) 'MSSV: $studentId',
                            if (faculty.isNotEmpty) faculty,
                          ].join(' • ');

                          return InkWell(
                            onTap: () {
                              _focusNode.unfocus();
                              FocusManager.instance.primaryFocus?.unfocus();
                              _showUserDetailModal(context, data, docId);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 6),
                              child: Row(
                                children: [
                                  buildUserAvatar(
                                    photoUrl,
                                    radius: 20,
                                    isDarkMode: isDarkMode,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name,
                                                style: TextStyle(
                                                  fontFamily:
                                                      'Encode Sans Expanded',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDarkMode
                                                      ? Colors.white
                                                      : const Color(0xFF1E293B),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isVerified) ...[
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.verified_rounded,
                                                size: 15,
                                                color: Color(0xFF6797E1),
                                              ),
                                            ],
                                            if (isCurrentUser) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 1.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF6797E1)
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Bạn',
                                                  style: TextStyle(
                                                    fontFamily:
                                                        'Encode Sans Expanded',
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF6797E1),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (subtitleText.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            subtitleText,
                                            style: TextStyle(
                                              fontFamily:
                                                  'Encode Sans Expanded',
                                              fontSize: 12,
                                              color: isDarkMode
                                                  ? Colors.white54
                                                  : const Color(0xFF64748B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: isDarkMode
                                        ? Colors.white38
                                        : const Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
