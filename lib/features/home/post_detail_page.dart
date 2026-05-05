import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'post_action_row.dart';

class PostDetailPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initialPostData;

  const PostDetailPage({
    super.key,
    required this.docId,
    required this.initialPostData,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  String? _replyingToId;
  String? _replyingToName;

  String get _collectionPath {
    if (widget.initialPostData.containsKey('link')) return 'official_news';
    if (widget.initialPostData.containsKey('rating')) return 'course_reviews';
    if (widget.initialPostData.containsKey('fileData')) return 'study_materials';
    return 'forum_posts';
  }

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('vi', timeago.ViMessages());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showReportOptions() {
    final List<String> reportReasons = [
      "Ngôn từ gây hấn/Xúc phạm",
      "Thông tin sai lệch",
      "Spam/Quảng cáo trái phép",
      "Nội dung không phù hợp với sinh viên",
      "Khác"
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Text(
                "Báo cáo bài viết",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Nunito',
                  color: isDarkMode ? Colors.white : const Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 10),
              ...reportReasons.map(
                    (reason) => ListTile(
                  leading: const Icon(
                    Icons.report_problem_outlined,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    reason,
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _submitReport(reason);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitReport(String reason) async {
    if (_user == null) return;

    try {
      await _firestore.collection(_collectionPath).doc(widget.docId).update({
        'isReported': true,
        'reportCount': FieldValue.increment(1),
      });

      await _firestore.collection('reports').add({
        'reporterId': _user!.uid,
        'reportedPostId': widget.docId,
        'postCollection': _collectionPath,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      final authorId =
          widget.initialPostData['authorId'] ?? widget.initialPostData['uploaderId'];
      if (authorId != null) {
        await _firestore.collection('notifications').add({
          'userId': authorId,
          'type': 'warning',
          'title': 'Cảnh báo nội dung',
          'content':
          'Bài viết của bạn đang bị cộng đồng báo cáo vì lý do: $reason. Mod sẽ tiến hành kiểm tra.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'relatedPostId': widget.docId,
          'collectionPath': _collectionPath,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cảm ơn bạn! Báo cáo đã được gửi tới điều hành viên."),
          ),
        );
      }
    } catch (e) {
      debugPrint("Lỗi báo cáo: $e");
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final repliesSnapshot = await _firestore
          .collection(_collectionPath)
          .doc(widget.docId)
          .collection('comments')
          .where('parentCommentId', isEqualTo: commentId)
          .get();

      WriteBatch batch = _firestore.batch();

      DocumentReference mainCommentRef = _firestore
          .collection(_collectionPath)
          .doc(widget.docId)
          .collection('comments')
          .doc(commentId);
      batch.delete(mainCommentRef);

      for (var doc in repliesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      int totalToDelete = 1 + repliesSnapshot.docs.length;

      DocumentReference postRef =
      _firestore.collection(_collectionPath).doc(widget.docId);
      batch.update(postRef, {
        'commentCount': FieldValue.increment(-totalToDelete)
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Đã xóa bình luận và ${repliesSnapshot.docs.length} phản hồi",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Lỗi khi xóa bình luận: $e");
    }
  }

  void _showDeleteConfirmation(String commentId) {
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
          "Xóa bình luận",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          "Bạn có chắc chắn muốn xóa bình luận này không?",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteComment(commentId);
            },
            child: const Text(
              "Xóa",
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

  Future<void> _sendCommentNotification(String content) async {
    if (_collectionPath == 'official_news') return;
    final authorId =
        widget.initialPostData['authorId'] ?? widget.initialPostData['uploaderId'];
    if (_user == null || authorId == null || _user!.uid == authorId) return;

    await _firestore.collection('notifications').add({
      'userId': authorId,
      'type': 'comment',
      'title': 'Bình luận mới',
      'content': '${_user!.displayName ?? "Ai đó"} đã bình luận bài viết của bạn',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'relatedPostId': widget.docId,
      'collectionPath': _collectionPath,
    });
  }

  Future<void> _sendLikeNotification() async {
    if (_collectionPath == 'official_news') return;
    final authorId =
        widget.initialPostData['authorId'] ?? widget.initialPostData['uploaderId'];
    if (_user == null || authorId == null || _user!.uid == authorId) return;

    await _firestore.collection('notifications').add({
      'userId': authorId,
      'type': 'like',
      'title': 'Yêu thích',
      'content': '${_user!.displayName ?? "Ai đó"} đã thích bài viết của bạn',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'relatedPostId': widget.docId,
      'collectionPath': _collectionPath,
    });
  }

  Future<void> _addComment() async {
    if (_user == null || _commentController.text.trim().isEmpty) return;

    String content = _commentController.text.trim();
    String? parentId = _replyingToId;

    _commentController.clear();
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });
    FocusScope.of(context).unfocus();

    final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
    final userData = userDoc.data();

    await _firestore
        .collection(_collectionPath)
        .doc(widget.docId)
        .collection('comments')
        .add({
      'authorId': _user!.uid,
      'authorName': userData?['displayName'] ?? 'Sinh viên MyUni',
      'authorAvatar': userData?['photoUrl'] ?? '',
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'parentCommentId': parentId,
    });

    await _firestore.collection(_collectionPath).doc(widget.docId).update({
      'commentCount': FieldValue.increment(1)
    });

    await _sendCommentNotification(content);
  }

  String _getOfficialImageByContent(Map<String, dynamic> data) {
    String title = data['title']?.toString().toLowerCase() ?? "";
    String summary = data['summary']?.toString().toLowerCase() ?? "";
    String text = "$title $summary";

    if (text.contains('học bổng') || text.contains('scholarship')) {
      return 'assets/images/scholarship.png';
    }
    if (text.contains('tuyển dụng') ||
        text.contains('việc làm') ||
        text.contains('intern') ||
        text.contains('thực tập')) {
      return 'assets/images/job.jpg';
    }
    if (text.contains('hội thảo') ||
        text.contains('seminar') ||
        text.contains('workshop') ||
        text.contains('talkshow')) {
      return 'assets/images/seminar.jpg';
    }
    if (text.contains('thể thao') ||
        text.contains('bóng đá') ||
        text.contains('giải đấu')) {
      return 'assets/images/sport.jpg';
    }
    if (text.contains('công nghệ') ||
        text.contains('tech') ||
        text.contains('lập trình')) {
      return 'assets/images/tech.jpg';
    }
    if (text.contains('nghệ thuật') ||
        text.contains('văn nghệ') ||
        text.contains('âm nhạc')) {
      return 'assets/images/art.jpg';
    }
    if (text.contains('lễ tốt nghiệp') || text.contains('graduation')) {
      return 'assets/images/graduation.jpg';
    }
    if (text.contains('cuộc thi') ||
        text.contains('contest') ||
        text.contains('giải thưởng')) {
      return 'assets/images/contest.jpg';
    }
    if (text.contains('thông báo') || text.contains('quy định')) {
      return 'assets/images/announcement.jpg';
    }
    if (text.contains('y tế') || text.contains('khám chữa bệnh')) {
      return 'assets/images/health.png';
    }

    return 'assets/images/news.png';
  }

  bool _isOfficialEvent(Map<String, dynamic> data) {
    String title = data['title']?.toString().toLowerCase() ?? "";
    String summary = data['summary']?.toString().toLowerCase() ?? "";
    List<String> keywords = [
      'seminar',
      'talkshow',
      'hội thảo',
      'cuộc thi',
      'chào tân sinh viên',
      'ngày hội',
      'lễ tốt nghiệp',
      'workshop',
      'sự kiện',
      'mời tham gia',
      'đăng ký tham gia'
    ];
    String content = "$title $summary";
    return keywords.any((k) => content.contains(k));
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDarkMode ? Colors.white : const Color(0xFF545454),
          ),
        ),
        centerTitle: true,
        backgroundColor: isDarkMode ? const Color(0xFF111315) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : const Color(0xFF545454),
        elevation: 0,
        actions: [
          if (_collectionPath != 'official_news')
            IconButton(
              icon: const Icon(
                Icons.report_gmailerrorred_outlined,
                color: Colors.redAccent,
              ),
              onPressed: _showReportOptions,
              tooltip: "Báo cáo bài viết vi phạm",
            )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDarkMode ? Colors.white10 : const Color(0xFFEDF2F7),
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDynamicHeader(),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF15171A)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white10
                              : const Color(0xFFE9EEF3),
                        ),
                        boxShadow: isDarkMode
                            ? []
                            : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.035),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: PostActionRow(
                          docId: widget.docId,
                          data: widget.initialPostData,
                          onSave: (id, data) {},
                          collectionPath: _collectionPath,
                          onLike: _sendLikeNotification,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color:
                      isDarkMode ? const Color(0xFF15171A) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white10
                            : const Color(0xFFE9EEF3),
                      ),
                      boxShadow: isDarkMode
                          ? []
                          : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _buildCommentSection(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildCommentInputField(),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    if (_collectionPath == 'official_news') return "Thông báo";
    if (_collectionPath == 'course_reviews') return "Review môn học";
    if (_collectionPath == 'study_materials') return "Tài liệu học tập";
    return "Chi tiết bài đăng";
  }

  Widget _buildDynamicHeader() {
    final data = widget.initialPostData;
    if (_collectionPath == 'official_news') return _buildOfficialUI(data);
    if (_collectionPath == 'course_reviews') return _buildReviewUI(data);
    if (_collectionPath == 'study_materials') return _buildMaterialUI(data);
    return _buildForumUI(data);
  }

  Widget _buildOfficialUI(Map<String, dynamic> data) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isEvent = _isOfficialEvent(data);
    final String imagePath = _getOfficialImageByContent(data);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isEvent
              ? const Color(0xFF66ACFE).withOpacity(isDarkMode ? 0.25 : 0.22)
              : (isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3)),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isEvent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF66ACFE).withOpacity(
                  isDarkMode ? 0.18 : 0.10,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Color(0xFF5893D8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Thông báo nổi bật",
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.white70
                          : const Color(0xFF356DA8),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: _buildAuthorRow(
              data['department'] ?? 'HCMUS',
              data['date'] ?? '',
              isOfficial: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTopChip(
                  label: isEvent ? "Sự kiện" : "Tin chính thức",
                  icon: isEvent ? Icons.event : Icons.campaign_outlined,
                  isDarkMode: isDarkMode,
                  highlighted: isEvent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              data['title'] ?? '',
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                height: 1.35,
                color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ),
          if ((data['summary'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                data['summary'] ?? '',
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 15,
                  height: 1.65,
                  color: isDarkMode
                      ? Colors.white70
                      : const Color(0xFF5B6472),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Image.asset(
                    imagePath,
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/images/news.png',
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.03),
                            Colors.black.withOpacity(0.32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final link = data['link']?.toString() ?? '';
                  if (link.trim().isEmpty) return;
                  await launchUrl(
                    Uri.parse(link),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF5893D8)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: isDarkMode
                      ? Colors.white.withOpacity(0.02)
                      : const Color(0xFFF8FBFF),
                ),
                label: const Text(
                  "Xem chi tiết bài viết",
                  style: TextStyle(
                    color: Color(0xFF5893D8),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Encode Sans Expanded',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewUI(Map<String, dynamic> data) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final int rating = (data['rating'] ?? 0) is int
        ? data['rating'] ?? 0
        : ((data['rating'] ?? 0) as num).toInt();

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 12, 10, 10),
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopChip(
              label: "Review môn học",
              icon: Icons.rate_review_outlined,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 14),
            Text(
              data['courseName'] ?? '',
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                height: 1.3,
                color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Giảng viên: ${data['teacherName'] ?? 'Chưa cập nhật'}",
              style: const TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontWeight: FontWeight.w500,
                color: Color(0xFF5893D8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data['semester'] ?? '',
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                color: isDarkMode ? Colors.white54 : Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.04)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode ? Colors.white10 : const Color(0xFFEAEFF5),
                ),
              ),
              child: Row(
                children: [
                  ...List.generate(
                    5,
                        (i) => Icon(
                      i < rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFFFCB45),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "$rating/5",
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color:
                      isDarkMode ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              data['content'] ?? '',
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 15,
                height: 1.7,
                color: isDarkMode
                    ? Colors.white70
                    : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialUI(Map<String, dynamic> data) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 12, 10, 10),
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopChip(
              label: "Tài liệu học tập",
              icon: Icons.menu_book_rounded,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 14),
            Text(
              data['courseName'] ?? 'Tài liệu',
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              data['semester'] ?? '',
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                color: isDarkMode ? Colors.white54 : Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            if ((data['content'] ?? '').toString().trim().isNotEmpty)
              Text(
                data['content'] ?? '',
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 15,
                  height: 1.7,
                  color: isDarkMode
                      ? Colors.white70
                      : const Color(0xFF4B5563),
                ),
              ),
            if ((data['content'] ?? '').toString().trim().isNotEmpty)
              const SizedBox(height: 18),
            if (data['fileData'] != null)
              data['isImage'] == true
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(
                  base64Decode(data['fileData']),
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              )
                  : Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.04)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white10
                        : const Color(0xFFEAEFF5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_rounded,
                      color: Color(0xFF5893D8),
                      size: 34,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data['fileName'] ?? 'document.pdf',
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildForumUI(Map<String, dynamic> data) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String timeText = data['timestamp'] != null
        ? timeago.format(
      (data['timestamp'] as Timestamp).toDate(),
      locale: 'vi',
    )
        : 'Vừa xong';

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 12, 10, 10),
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAuthorRow(
              data['authorName'] ?? 'Sinh viên ẩn danh',
              timeText,
              avatarBase64: data['authorAvatar'],
            ),
            if (data['hashtags'] != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (data['hashtags'] as List)
                    .map(
                      (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white10
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      "#$t",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.white70
                            : const Color(0xFF344054),
                      ),
                    ),
                  ),
                )
                    .toList(),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              data['content'] ?? '',
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 15,
                height: 1.7,
                color: isDarkMode
                    ? Colors.white70
                    : const Color(0xFF4B5563),
              ),
            ),
            if (data['imageUrl'] != null && data['imageUrl'] != '') ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(
                  base64Decode(data['imageUrl']),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopChip({
    required String label,
    required IconData icon,
    required bool isDarkMode,
    bool highlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFF66ACFE).withOpacity(isDarkMode ? 0.20 : 0.14)
            : (isDarkMode ? Colors.white10 : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF66ACFE).withOpacity(0.35)
              : (isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDarkMode ? Colors.white70 : const Color(0xFF344054),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white70 : const Color(0xFF344054),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorRow(
      String name,
      String sub, {
        String? avatarBase64,
        bool isOfficial = false,
      }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Widget avatarWidget;
    if (isOfficial) {
      avatarWidget = Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        width: 46,
        height: 46,
      );
    } else {
      if (avatarBase64 != null && avatarBase64.isNotEmpty) {
        avatarWidget = ClipOval(
          child: Image.memory(
            base64Decode(avatarBase64),
            fit: BoxFit.cover,
            width: 46,
            height: 46,
          ),
        );
      } else {
        avatarWidget = Icon(
          Icons.person,
          color: isDarkMode ? Colors.white38 : Colors.grey,
          size: 28,
        );
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: isDarkMode ? Colors.white10 : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: avatarWidget,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : const Color(0xFF2C2C2C),
                      ),
                    ),
                  ),
                  if (isOfficial) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF66ACFE),
                      size: 16,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 12,
                  color: isDarkMode ? Colors.white54 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(_collectionPath)
          .doc(widget.docId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        var allComments = snapshot.data!.docs
            .map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id})
            .toList();
        var rootComments =
        allComments.where((c) => c['parentCommentId'] == null).toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Bình luận",
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 14),
              if (rootComments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      "Chưa có bình luận nào.",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: rootComments
                      .map((comment) => _buildCommentTree(comment, allComments))
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentTree(
      Map<String, dynamic> comment,
      List<Map<String, dynamic>> allComments,
      ) {
    var replies =
    allComments.where((c) => c['parentCommentId'] == comment['id']).toList();

    return Column(
      children: [
        _buildSingleCommentWidget(comment),
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(
              children: replies
                  .map((reply) => _buildCommentTree(reply, allComments))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildSingleCommentWidget(Map<String, dynamic> comment) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String? avt = comment['authorAvatar'];
    final bool isCommentOwner = _user?.uid == comment['authorId'];
    final bool isPostOwner =
        _user?.uid == (widget.initialPostData['authorId'] ?? widget.initialPostData['uploaderId']);
    final bool canDelete = isCommentOwner || isPostOwner;
    final bool isAuthor = comment['authorId'] ==
        (widget.initialPostData['authorId'] ?? widget.initialPostData['uploaderId']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
            isDarkMode ? Colors.white10 : const Color(0xFFF1F2F6),
            child: (avt == null || avt.isEmpty)
                ? Icon(
              Icons.person,
              size: 20,
              color: isDarkMode ? Colors.white38 : Colors.grey,
            )
                : ClipOval(
              child: Image.memory(
                base64Decode(avt),
                fit: BoxFit.cover,
                width: 36,
                height: 36,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.04)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode ? Colors.white10 : const Color(0xFFEAEFF5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Text(
                              comment['authorName'] ?? 'Người dùng',
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                            if (isAuthor)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5893D8)
                                      .withOpacity(isDarkMode ? 0.22 : 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  "Tác giả",
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: Color(0xFF5893D8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (canDelete)
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.more_horiz,
                              size: 18,
                              color: isDarkMode
                                  ? Colors.white38
                                  : const Color(0xFF777777),
                            ),
                            onSelected: (val) =>
                                _showDeleteConfirmation(comment['id']),
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  "Xóa",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comment['content'] ?? '',
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 14,
                      height: 1.5,
                      color: isDarkMode
                          ? Colors.white70
                          : const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      _replyingToId = comment['id'];
                      _replyingToName = comment['authorName'];
                    }),
                    child: const Text(
                      "Reply",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 12,
                        color: Color(0xFF5893D8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputField() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF111315) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
        ),
        boxShadow: isDarkMode
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF5893D8).withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 12,
                          color:
                          isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                        children: [
                          const TextSpan(text: "Đang trả lời "),
                          TextSpan(
                            text: _replyingToName ?? "",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5893D8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _replyingToId = null;
                      _replyingToName = null;
                    }),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFF1F2F6),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white10
                          : Colors.transparent,
                    ),
                  ),
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Viết bình luận...",
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.white38 : Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF66ACFE), Color(0xFF5893D8)],
                  ),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.transparent,
                  child: IconButton(
                    onPressed: _addComment,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}