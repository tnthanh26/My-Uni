import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../theme/app_colors.dart';
import '../services/chat_service.dart';
import 'chat_detail_page.dart';

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

  Widget _buildUserAvatar(String photo, String name, bool isDark) {
    final cleanPhoto = photo.trim();
    ImageProvider? imageProvider;
    if (cleanPhoto.isNotEmpty) {
      if (cleanPhoto.startsWith('http://') || cleanPhoto.startsWith('https://')) {
        imageProvider = NetworkImage(cleanPhoto);
      } else {
        try {
          final bytes = base64Decode(cleanPhoto);
          imageProvider = MemoryImage(bytes);
        } catch (_) {
          imageProvider = null;
        }
      }
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.hcmusTeal.withValues(alpha: 0.15),
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.hcmusTeal,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark
                ? Colors.white
                : const Color(0xFF1D2939),
          ),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
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
              autofocus: true,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                color: isDark
                    ? Colors.white
                    : const Color(0xFF1D2939),
                fontSize: 13,
                height: 1.2,
              ),
              decoration: InputDecoration(
                isDense: true,

                // Ghi đè InputDecorationTheme toàn app
                filled: false,
                fillColor: Colors.transparent,

                hintText: 'Nhập MSSV, tên hoặc email',
                hintStyle: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  color: isDark
                      ? Colors.white38
                      : const Color(0xFF98A2B3),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            width: double.infinity,
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFEAECF0),
          ),
        ),
      ),
      body: _searchQuery.isEmpty
          ? Center(
        child: SingleChildScrollView(
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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.hcmusTeal.withValues(
                    alpha: isDark ? 0.14 : 0.09,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_search_outlined,
                  size: 34,
                  color: AppColors.hcmusTeal,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tìm sinh viên HCMUS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF1D2939),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Nhập đầy đủ MSSV, tên sinh viên hoặc email.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 12.5,
                  height: 1.5,
                  color: isDark
                      ? Colors.white60
                      : const Color(0xFF667085),
                ),
              ),
            ],
          ),
        ),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.hcmusTeal,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Đang tìm sinh viên...',
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 12,
                      color: isDark
                          ? Colors.white60
                          : const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 42,
                      color: isDark
                          ? Colors.white38
                          : const Color(0xFF98A2B3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Không thể tìm kiếm lúc này',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Vui lòng kiểm tra kết nối và thử lại.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 12,
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          final filteredUsers = docs.where((doc) {
            if (doc.id == currentUid) return false;

            final data =
                doc.data() as Map<String, dynamic>? ?? {};

            final name = (
                data['displayName'] ??
                    data['name'] ??
                    data['fullName'] ??
                    ''
            ).toString().trim().toLowerCase();

            final mssv = (
                data['studentId'] ??
                    data['mssv'] ??
                    data['code'] ??
                    ''
            ).toString().trim().toLowerCase();

            final email = (
                data['email'] ??
                    data['schoolEmail'] ??
                    data['studentEmail'] ??
                    ''
            ).toString().trim().toLowerCase();

            final emailPrefix = email.contains('@')
                ? email.split('@').first
                : email;

            final q =
            _searchQuery.trim().toLowerCase();

            final cleanQuery =
            _removeVietnameseDiacritics(q);

            final cleanName =
            _removeVietnameseDiacritics(name);

            final isMssvMatch =
                q.isNotEmpty && q == mssv;

            final isEmailMatch =
                q.isNotEmpty &&
                    (q == email || q == emailPrefix);

            final isNameMatch =
                q.isNotEmpty &&
                    (q == name || cleanQuery == cleanName);

            return isMssvMatch ||
                isEmailMatch ||
                isNameMatch;
          }).toList();

          if (filteredUsers.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(
                          alpha: 0.06,
                        )
                            : const Color(0xFFF2F4F7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.search_off_rounded,
                        size: 32,
                        color: isDark
                            ? Colors.white38
                            : const Color(0xFF98A2B3),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Không tìm thấy sinh viên',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kiểm tra lại MSSV, tên đầy đủ hoặc email trường rồi thử lại.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 12,
                        height: 1.45,
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              16,
              14,
              16,
              24,
            ),
            itemCount: filteredUsers.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = filteredUsers[index];

              final data =
                  doc.data() as Map<String, dynamic>? ?? {};

              final targetUid = doc.id;

              final name = (
                  data['displayName'] ??
                      data['name'] ??
                      'Sinh viên HCMUS'
              ).toString();

              final photo = (
                  data['photoURL'] ??
                      data['photoUrl'] ??
                      data['avatar'] ??
                      ''
              ).toString();

              final faculty = (
                  data['faculty'] ??
                      data['department'] ??
                      ''
              ).toString().trim();

              final cohort = (
                  data['cohort'] ??
                      data['academicYear'] ??
                      data['nienKhoa'] ??
                      ''
              ).toString().trim();

              final infoParts = <String>[];

              if (faculty.isNotEmpty) {
                infoParts.add(faculty);
              }

              if (cohort.isNotEmpty) {
                infoParts.add(
                  cohort.startsWith('Niên khóa') ||
                      cohort.startsWith('NK')
                      ? cohort
                      : 'Niên khóa: $cohort',
                );
              }

              final infoText = infoParts.isNotEmpty
                  ? infoParts.join(' • ')
                  : 'Sinh viên HCMUS đã xác thực';

              final Color cardColor = isDark
                  ? AppColors.surfaceDark
                  : Colors.white;

              final Color borderColor = isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE4E7EC);

              final Color primaryTextColor = isDark
                  ? Colors.white
                  : const Color(0xFF1D2939);

              final Color secondaryTextColor = isDark
                  ? Colors.white60
                  : const Color(0xFF667085);

              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    try {
                      final roomId = await _chatService
                          .getOrCreateChatRoom(
                        targetUid,
                        targetName: name,
                        targetPhoto: photo,
                      );

                      if (context.mounted &&
                          roomId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ChatDetailPage(
                                  roomId: roomId,
                                  targetUserId: targetUid,
                                  targetUserName: name,
                                  targetUserPhoto: photo,
                                ),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint(
                        'Không thể tạo phòng chat: $e',
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Không thể mở cuộc trò chuyện. Vui lòng thử lại.',
                              ),
                              behavior:
                              SnackBarBehavior.floating,
                            ),
                          );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius:
                      BorderRadius.circular(16),
                      border: Border.all(
                        color: borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildUserAvatar(
                          photo,
                          name,
                          isDark,
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
                                      maxLines: 1,
                                      overflow:
                                      TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 15,
                                        height: 1.2,
                                        fontWeight:
                                        FontWeight.w700,
                                        color:
                                        primaryTextColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Tooltip(
                                    message:
                                    'Đã xác thực sinh viên',
                                    child: Icon(
                                      Icons.verified_rounded,
                                      size: 15,
                                      color:
                                      AppColors.hcmusTeal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                infoText,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily:
                                  'Encode Sans Expanded',
                                  fontSize: 11.5,
                                  height: 1.3,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          tooltip: 'Nhắn tin',
                          style: IconButton.styleFrom(
                            backgroundColor:
                            AppColors.hcmusTeal,
                            foregroundColor: Colors.white,
                            fixedSize: const Size(40, 40),
                            shape: const CircleBorder(),
                          ),
                          onPressed: () async {
                            try {
                              final roomId = await _chatService
                                  .getOrCreateChatRoom(
                                targetUid,
                                targetName: name,
                                targetPhoto: photo,
                              );

                              if (context.mounted &&
                                  roomId.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ChatDetailPage(
                                          roomId: roomId,
                                          targetUserId:
                                          targetUid,
                                          targetUserName: name,
                                          targetUserPhoto: photo,
                                        ),
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint(
                                'Không thể tạo phòng chat: $e',
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                )
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Không thể mở cuộc trò chuyện. Vui lòng thử lại.',
                                      ),
                                      behavior:
                                      SnackBarBehavior
                                          .floating,
                                    ),
                                  );
                              }
                            }
                          },
                          icon: const Icon(
                            Icons
                                .chat_bubble_outline_rounded,
                            size: 18,
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
    );
  }
}

