import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:my_uni/utils/custom_timeago_messages.dart';
import 'package:my_uni/utils/base64_image_cache.dart';
import 'package:url_launcher/url_launcher.dart';
import 'post_action_row.dart';
import 'official_content_helper.dart';
import 'poll_widget.dart';
import 'create_post_page.dart';
import 'create_material_page.dart';
import 'create_review_page.dart';
import '../services/content_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../theme/app_colors.dart';
import '../chat/services/chat_service.dart';
import '../chat/pages/chat_detail_page.dart';
import '../chat/widgets/student_identity_card.dart';
import '../../utils/anonymous_utils.dart';
import '../search/myuni_search_delegate.dart';

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

  // State to track expanded comment threads
  final Set<String> _expandedComments = {};

  late Map<String, dynamic> _postData;
  StreamSubscription<DocumentSnapshot>? _postSub;

  File? _commentImageFile;
  bool _isSubmittingComment = false;
  bool _isCommentAnonymous = false;
  String _commentSortMode = 'newest'; // 'newest' hoặc 'top'

  Future<void> _pickCommentImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _commentImageFile = File(pickedFile.path));
    }
  }
  
  Future<String?> _processImageToBase64(File file) async {
    final bytes = await file.readAsBytes();
    var compressedBytes = await FlutterImageCompress.compressWithList(
      bytes, quality: 20, minWidth: 500, minHeight: 500,
    );
    return base64Encode(compressedBytes);
  }

  void _showFullScreenImage(BuildContext context, String base64Image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.memory(
                Base64ImageCache.decode(base64Image),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _collectionPath {
    if (widget.initialPostData.containsKey('link')) return 'official_news';
    if (widget.initialPostData.containsKey('rating')) return 'course_reviews';
    if (widget.initialPostData.containsKey('fileData')) return 'study_materials';
    return 'forum_posts';
  }

  @override
  void initState() {
    super.initState();
    _postData = Map<String, dynamic>.from(widget.initialPostData);
    timeago.setLocaleMessages('vi', CustomViMessages());
    _subscribePostRealtime();
  }

  void _subscribePostRealtime() {
    _postSub?.cancel();
    _postSub = _firestore
        .collection(_collectionPath)
        .doc(widget.docId)
        .snapshots()
        .listen(
      (doc) {
        if (doc.exists && doc.data() != null && mounted) {
          setState(() {
            _postData = doc.data() as Map<String, dynamic>;
          });
        }
      },
      onError: (error) {
        debugPrint("Post realtime stream error (handled): $error");
      },
    );
  }

  @override
  void dispose() {
    _postSub?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleOpenFile(
      BuildContext context,
      String base64Data,
      String fileName,
      ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Đang chuẩn bị tài liệu..."),
          duration: Duration(seconds: 1),
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(base64Decode(base64Data));
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Không có ứng dụng để mở loại file này: ${result.message}",
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $e")),
        );
      }
    }
  }

  Future<void> _showReportOptions() async {


    final List<String> reportReasons = [
      "Ngôn từ gây hấn/Xúc phạm",
      "Thông tin sai lệch",
      "Spam/Quảng cáo trái phép",
      "Nội dung không phù hợp với sinh viên",
      "Khác"
    ];

    bool isOtherSelected = false;
    TextEditingController customReasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: SingleChildScrollView(
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
                            fontWeight: (reason == "Khác" && isOtherSelected) ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          if (reason == "Khác") {
                            setModalState(() {
                              isOtherSelected = true;
                            });
                          } else {
                            Navigator.pop(context);
                            _submitReport(reason);
                          }
                        },
                      ),
                    ),
                    if (isOtherSelected) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: customReasonController,
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: "Vui lòng nhập lý do cụ thể...",
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.white38 : Colors.grey,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDarkMode ? Colors.white10 : const Color(0xFFEAEFF5),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDarkMode ? Colors.white10 : const Color(0xFFEAEFF5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF5893D8)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            String customReason = customReasonController.text.trim();
                            if (customReason.isNotEmpty) {
                              Navigator.pop(context);
                              _submitReport("Khác: $customReason");
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Vui lòng nhập lý do báo cáo")),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5893D8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Gửi báo cáo",
                            style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                ),
              ),
            );
          },
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
          _postData['authorId'] ?? _postData['uploaderId'];
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

  Future<void> _showReportCommentOptions(Map<String, dynamic> comment) async {


    final List<String> reportReasons = [
      "Nội dung thô tục, nhạy cảm",
      "Spam, quảng cáo không phép",
      "Quấy rối, công kích cá nhân",
      "Thông tin sai sự thật",
      "Vi phạm quy chuẩn cộng đồng",
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Báo cáo bình luận này",
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
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
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _submitCommentReport(comment, reason);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.blueAccent),
                title: Text(
                  "Lý do khác...",
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomReportCommentDialog(comment);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomReportCommentDialog(Map<String, dynamic> comment) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          "Lý do báo cáo khác",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          minLines: 1,
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: "Nhập lý do chi tiết...",
            hintStyle: TextStyle(
              color: isDarkMode ? Colors.white38 : Colors.grey,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF5893D8)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              String customReason = reasonController.text.trim();
              if (customReason.isNotEmpty) {
                Navigator.pop(context);
                _submitCommentReport(comment, "Khác: $customReason");
              }
            },
            child: const Text(
              "Gửi báo cáo",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCommentReport(
      Map<String, dynamic> comment,
      String reason,
      ) async {
    if (_user == null) return;

    final commentId = comment['id'];

    try {
      // Đánh dấu comment bị báo cáo
      await _firestore
          .collection(_collectionPath)
          .doc(widget.docId)
          .collection('comments')
          .doc(commentId)
          .update({
        'isReported': true,
        'reportCount': FieldValue.increment(1),
      });

      // Đánh dấu bài viết có comment bị báo cáo
      await _firestore
          .collection(_collectionPath)
          .doc(widget.docId)
          .update({
        'hasReportedComments': true,
        'reportedCommentCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Lưu report
      await _firestore.collection('reports').add({
        'reporterId': _user!.uid,
        'reportedCommentId': commentId,
        'reportedPostId': widget.docId,
        'postCollection': _collectionPath,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'type': 'comment',
      });

      // Gửi thông báo cho tác giả comment
      final commentAuthorId = comment['authorId'];
      if (commentAuthorId != null) {
        String shortCommentText = comment['content'] ?? "";

        if (shortCommentText.isEmpty && comment['imageUrl'] != null) {
          shortCommentText = "[Hình ảnh]";
        }

        if (shortCommentText.length > 30) {
          shortCommentText =
          "${shortCommentText.substring(0, 30)}...";
        }

        await _firestore.collection('notifications').add({
          'userId': commentAuthorId,
          'type': 'warning',
          'title': 'Cảnh báo bình luận',
          'content':
          'Bình luận "$shortCommentText" bị báo cáo: $reason.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'relatedPostId': widget.docId,
          'collectionPath': _collectionPath,
          'reportedCommentId': commentId,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Cảm ơn bạn! Báo cáo bình luận đã được gửi tới điều hành viên.",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Lỗi báo cáo bình luận: $e");
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      List<DocumentReference> descendantRefs = [];

      Future<void> findDescendants(String id) async {
        final replies = await _firestore
            .collection(_collectionPath)
            .doc(widget.docId)
            .collection('comments')
            .where('parentCommentId', isEqualTo: id)
            .get();
        for (var doc in replies.docs) {
          descendantRefs.add(doc.reference);
          await findDescendants(doc.id);
        }
      }

      await findDescendants(commentId);

      WriteBatch batch = _firestore.batch();

      DocumentReference mainCommentRef = _firestore
          .collection(_collectionPath)
          .doc(widget.docId)
          .collection('comments')
          .doc(commentId);
      batch.delete(mainCommentRef);

      for (var ref in descendantRefs) {
        batch.delete(ref);
      }

      int totalToDelete = 1 + descendantRefs.length;

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
              "Đã xóa bình luận",
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

  void _showEditCommentDialog(Map<String, dynamic> comment) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController editController = TextEditingController(text: comment['content']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          "Sửa bình luận",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: TextField(
          controller: editController,
          maxLines: 3,
          minLines: 1,
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: "Nhập nội dung mới...",
            hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF5893D8)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              String newContent = editController.text.trim();
              if (newContent.isEmpty) return;

              // Check for violated words (Blacklist & Sensitive)
              List<String> blacklistViolations = ContentService.getBlacklistedWords(newContent);
              if (blacklistViolations.isNotEmpty) {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: const Text("Yêu cầu sửa nội dung"),
                    content: Text("Bình luận chứa từ ngữ không phù hợp: (${blacklistViolations.join(', ')}). Vui lòng xóa hoặc sửa lại để tiếp tục."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Quay lại sửa"),
                      ),
                    ],
                  ),
                );
                return;
              }

              bool isSensitive = false;
              List<String> sensitiveViolations = ContentService.getSensitiveWords(newContent);
              if (sensitiveViolations.isNotEmpty) {
                bool shouldSubmit = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: const Text("Cảnh báo từ ngữ nhạy cảm"),
                    content: Text("Bình luận chứa từ ngữ nhạy cảm: (${sensitiveViolations.join(', ')}). Nếu tiếp tục sửa, bình luận sẽ ở trạng thái chờ duyệt bởi Quản trị viên. Bạn có muốn tiếp tục?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Quay lại sửa"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Vẫn đăng"),
                      ),
                    ],
                  ),
                ) ?? false;

                if (!shouldSubmit) {
                  return;
                }
                isSensitive = true;
              }

              try {
                await _firestore
                    .collection(_collectionPath)
                    .doc(widget.docId)
                    .collection('comments')
                    .doc(comment['id'])
                    .update({
                  'content': newContent,
                  'status': isSensitive ? 'pending' : 'approved',
                });
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Đã cập nhật bình luận")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Lỗi: $e")),
                  );
                }
              }
            },
            child: const Text(
              "Lưu",
              style: TextStyle(color: Color(0xFF5893D8), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCommentNotification(String content, String senderName) async {
    if (_collectionPath == 'official_news') return;
    final authorId =
        _postData['authorId'] ?? _postData['uploaderId'];
    if (_user == null || authorId == null || _user!.uid == authorId) return;

    await _firestore.collection('notifications').add({
      'userId': authorId,
      'type': 'comment',
      'title': 'Bình luận mới',
      'content': '$senderName đã bình luận bài viết của bạn',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'relatedPostId': widget.docId,
      'collectionPath': _collectionPath,
    });
  }

  Future<void> _sendLikeNotification() async {
    if (_collectionPath == 'official_news') return;
    final authorId =
        _postData['authorId'] ?? _postData['uploaderId'];
    if (_user == null || authorId == null || _user!.uid == authorId) return;

    final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
    final userData = userDoc.data();
    final rawName = userData?['displayName']?.toString().trim();
    final senderName = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : (_user!.displayName != null && _user!.displayName!.trim().isNotEmpty
            ? _user!.displayName!.trim()
            : "Ai đó");

    await _firestore.collection('notifications').add({
      'userId': authorId,
      'type': 'like',
      'title': 'Yêu thích',
      'content': '$senderName đã thích bài viết của bạn',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'relatedPostId': widget.docId,
      'collectionPath': _collectionPath,
    });
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (_user == null || (content.isEmpty && _commentImageFile == null)) return;
    if (_isSubmittingComment) return;



    // 1. Kiểm tra từ cấm
    if (content.isNotEmpty) {
      List<String> blacklistViolations = ContentService.getBlacklistedWords(content);
      if (blacklistViolations.isNotEmpty) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Yêu cầu sửa nội dung"),
            content: Text("Bình luận chứa từ ngữ không phù hợp: (${blacklistViolations.join(', ')}). Vui lòng xóa hoặc sửa lại để tiếp tục."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Quay lại sửa"),
              ),
            ],
          ),
        );
        return;
      }
    }

    // 2. Kiểm tra từ nhạy cảm
    bool isSensitive = false;
    if (content.isNotEmpty) {
      List<String> sensitiveViolations = ContentService.getSensitiveWords(content);
      if (sensitiveViolations.isNotEmpty) {
        bool shouldSubmit = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Cảnh báo từ ngữ nhạy cảm"),
            content: Text("Bình luận chứa từ ngữ nhạy cảm: (${sensitiveViolations.join(', ')}). Nếu tiếp tục đăng, bình luận sẽ ở trạng thái chờ duyệt bởi Quản trị viên. Bạn có muốn tiếp tục?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Quay lại sửa"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Vẫn đăng"),
              ),
            ],
          ),
        ) ?? false;

        if (!shouldSubmit) {
          return;
        }
        isSensitive = true;
      }
    }

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      FocusScope.of(context).unfocus();
      String? parentId = _replyingToId;
      String? commentImageUrl;

      if (_commentImageFile != null) {
        commentImageUrl = await _processImageToBase64(_commentImageFile!);
      }

      _commentController.clear();
      setState(() {
        _replyingToId = null;
        _replyingToName = null;
        _commentImageFile = null;
      });

      final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
      final userData = userDoc.data();
      final rawName = userData?['displayName']?.toString().trim();
      final senderName = (rawName != null && rawName.isNotEmpty)
          ? rawName
          : (_user!.displayName != null && _user!.displayName!.trim().isNotEmpty
              ? _user!.displayName!.trim()
              : "Ai đó");

      final String commentSenderName = _isCommentAnonymous
          ? 'Sinh viên ẩn danh'
          : senderName;

      String? rootCommentId;
      String rootAuthorId = _user!.uid;

      if (parentId != null) {
        final parentDoc = await _firestore
            .collection(_collectionPath)
            .doc(widget.docId)
            .collection('comments')
            .doc(parentId)
            .get();

        if (parentDoc.exists) {
          final parentData = parentDoc.data()!;

          rootCommentId =
              parentData['rootCommentId']?.toString() ?? parentDoc.id;

          rootAuthorId =
              parentData['rootAuthorId']?.toString() ??
                  parentData['authorId']?.toString() ??
                  _user!.uid;
        }
      }

      Map<String, dynamic> commentData = {
        'authorId': _user!.uid,
        'authorName': commentSenderName,
        'authorAvatar': _isCommentAnonymous ? '' : (userData?['photoUrl'] ?? ''),
        'isAnonymous': _isCommentAnonymous,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'parentCommentId': parentId,

        // Comment gốc sẽ để null.
        // Tất cả reply lưu cùng rootCommentId và rootAuthorId.
        'rootCommentId': rootCommentId,
        'rootAuthorId': rootAuthorId,

        'likes': [],
        'status': isSensitive ? 'pending' : 'approved',
      };

      if (commentImageUrl != null) {
        commentData['imageUrl'] = commentImageUrl;
      }

      // 1. Ghi bình luận vào subcollection (Bắt buộc thành công)
      try {
        await _firestore
            .collection(_collectionPath)
            .doc(widget.docId)
            .collection('comments')
            .add(commentData);
      } catch (e) {
        throw "Tạo tài liệu bình luận thất bại (Lỗi quyền truy cập): $e";
      }

      // 2. Cập nhật số lượng bình luận bài viết (Bọc riêng để không chặn luồng chính nếu lỗi phân quyền bài viết)
      try {
        await _firestore.collection(_collectionPath).doc(widget.docId).update({
          'commentCount': FieldValue.increment(1)
        });
      } catch (e) {
        debugPrint("Lỗi cập nhật commentCount của bài viết: $e");
      }

      // 3. Gửi thông báo đến tác giả bài đăng (Bọc riêng để tránh lỗi phân quyền ghi notifications của người khác)
      String notificationContent = content.isNotEmpty ? content : "[Hình ảnh]";
      try {
        await _sendCommentNotification(notificationContent, commentSenderName);
      } catch (e) {
        debugPrint("Lỗi ghi thông báo bình luận: $e");
      }

      // If it's a reply, also notify the parent comment author
      if (parentId != null) {
        try {
          final parentDoc = await _firestore
              .collection(_collectionPath)
              .doc(widget.docId)
              .collection('comments')
              .doc(parentId)
              .get();
          
          if (parentDoc.exists) {
            final parentData = parentDoc.data();
            final parentAuthorId = parentData?['authorId'];
            
            if (parentAuthorId != null && parentAuthorId != _user!.uid) {
              await _firestore.collection('notifications').add({
                'userId': parentAuthorId,
                'type': 'comment',
                'title': 'Phản hồi mới',
                'content': '$commentSenderName đã phản hồi bình luận của bạn: "$notificationContent"',
                'timestamp': FieldValue.serverTimestamp(),
                'isRead': false,
                'relatedPostId': widget.docId,
                'collectionPath': _collectionPath,
              });
            }
          }
        } catch (e) {
          debugPrint("Lỗi gửi thông báo reply: $e");
        }
      }
    } catch (e) {
      debugPrint("Lỗi thêm bình luận: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi khi thêm bình luận: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  Future<void> _toggleCommentLike(Map<String, dynamic> comment) async {
    if (_user == null) return;
    final uid = _user!.uid;
    final commentId = comment['id'];
    final List<dynamic> likes = comment['likes'] ?? [];
    
    final docRef = _firestore
        .collection(_collectionPath)
        .doc(widget.docId)
        .collection('comments')
        .doc(commentId);

    if (likes.contains(uid)) {
      await docRef.update({
        'likes': FieldValue.arrayRemove([uid])
      });
    } else {
      await docRef.update({
        'likes': FieldValue.arrayUnion([uid])
      });

      // Send notification to comment author
      final commentAuthorId = comment['authorId'];
      if (commentAuthorId != null && commentAuthorId != uid) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final userData = userDoc.data();
        final rawLikeName = userData?['displayName']?.toString().trim();
        final senderLikeName = (rawLikeName != null && rawLikeName.isNotEmpty)
            ? rawLikeName
            : (_user!.displayName != null && _user!.displayName!.trim().isNotEmpty
                ? _user!.displayName!.trim()
                : "Ai đó");

        await _firestore.collection('notifications').add({
          'userId': commentAuthorId,
          'type': 'like',
          'title': 'Lượt thích mới',
          'content': '$senderLikeName đã thích bình luận của bạn: "${comment['content']}"',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'relatedPostId': widget.docId,
          'collectionPath': _collectionPath,
        });
      }
    }
  }

  Future<void> _toggleInterest() async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng đăng nhập để lưu sự kiện")),
      );
      return;
    }

    final docRef = _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('interested_events')
        .doc(widget.docId);

    final docSnapshot = await docRef.get();
    final data = widget.initialPostData;

    if (docSnapshot.exists) {
      await docRef.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã bỏ quan tâm")),
      );
    } else {
      await docRef.set({
        'title': data['title'] ?? 'Sự kiện sinh viên',
        'date': data['date'] ?? 'Xem chi tiết',
        'department': data['department'] ?? 'Cơ sở HCMUS',
        'summary': data['summary'] ?? '',
        'link': data['link'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã thêm vào mục Đã quan tâm")),
      );
    }
  }

  Widget _buildInterestButton({
    required BuildContext context,
    required bool isDarkMode,
    required bool isInterested,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isInterested
                ? (isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFF1F5F9))
                : const Color(0xFF5893D8),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isInterested || isDarkMode
                ? []
                : [
              BoxShadow(
                color: const Color(0xFF5893D8).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isInterested ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                size: 16,
                color: isInterested
                    ? (isDarkMode ? Colors.white70 : const Color(0xFF64748B))
                    : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                isInterested ? 'Đã quan tâm' : 'Quan tâm',
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isInterested
                      ? (isDarkMode ? Colors.white70 : const Color(0xFF64748B))
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSavePost({
    required BuildContext context,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng đăng nhập để lưu bài viết")),
      );
      return;
    }
    final docRef = _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('saved_posts')
        .doc(docId);
    try {
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        await docRef.delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Đã bỏ lưu bài viết")));
        }
      } else {
        final Map<String, dynamic> saveData = Map.from(data);

        String saveType = 'general';
        if (_collectionPath == 'course_reviews' ||
            _collectionPath == 'study_materials') {
          saveType = 'course';
        }

        saveData['saveType'] = saveType;
        saveData['savedAt'] = FieldValue.serverTimestamp();
        saveData['originalDocId'] = docId;
        await docRef.set(saveData);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Đã lưu vào mục Bài đã lưu")));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Lỗi: ${e.toString()}")));
      }
    }
  }

  void _navigateToEdit() async {
    Widget targetPage;
    final data = _postData;
    if (_collectionPath == 'study_materials') {
      targetPage = CreateMaterialPage(docId: widget.docId, existingData: data);
    } else if (_collectionPath == 'course_reviews') {
      targetPage = CreateReviewPage(docId: widget.docId, existingData: data);
    } else {
      targetPage = CreatePostPage(docId: widget.docId, existingData: data);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetPage),
    );
    _refreshPostData();
  }

  Future<void> _refreshPostData() async {
    try {
      final doc = await _firestore.collection(_collectionPath).doc(widget.docId).get();
      if (doc.exists && doc.data() != null && mounted) {
        setState(() {
          _postData = doc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      debugPrint("Error refreshing post data: $e");
    }
  }

  void _confirmDeletePost() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          "Xóa bài viết?",
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          "Hành động này sẽ xóa vĩnh viễn bài viết của bạn.",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost();
            },
            child: const Text(
              "Xóa",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    try {
      await _firestore.collection(_collectionPath).doc(widget.docId).delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã xóa bài viết thành công")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi khi xóa: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isOwner = _user?.uid ==
        (_postData['authorId'] ??
            _postData['uploaderId']);

    bool canEditPost = isOwner;
    if (canEditPost && _postData['timestamp'] != null) {
      try {
        final Timestamp ts = _postData['timestamp'] as Timestamp;
        final DateTime postTime = ts.toDate();
        if (DateTime.now().difference(postTime).inHours >= 12) {
          canEditPost = false;
        }
      } catch (e) {
        debugPrint("Error checking post edit timeframe: $e");
      }
    }

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
          if (isOwner && _collectionPath != 'official_news')
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') _navigateToEdit();
                if (val == 'delete') _confirmDeletePost();
              },
              icon: const Icon(Icons.more_vert_rounded),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              itemBuilder: (context) => [
                if (canEditPost)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                        SizedBox(width: 10),
                        Text("Chỉnh sửa",
                            style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 13)),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text("Xóa bài",
                          style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontSize: 13,
                              color: Colors.red)),
                    ],
                  ),
                ),
              ],
            )
          else if (_collectionPath != 'official_news')
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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: PostActionRow(
                      docId: widget.docId,
                      data: _postData,
                      onSave: (id, data) => _toggleSavePost(
                        context: context,
                        docId: id,
                        data: data,
                      ),
                      collectionPath: _collectionPath,
                      onLike: _sendLikeNotification,
                      isInDetail: true,
                    ),
                  ),
                  Divider(
                    height: 24,
                    thickness: 1,
                    color: isDarkMode ? Colors.white10 : const Color(0xFFEDF2F7),
                  ),
                  _buildCommentSection(),
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
    if (_collectionPath == 'official_news') return "Chi tiết bài viết";
    if (_collectionPath == 'course_reviews') return "Review môn học";
    if (_collectionPath == 'study_materials') return "Tài liệu học tập";
    return "Chi tiết bài đăng";
  }

  Widget _buildDynamicHeader() {
    final data = _postData;
    if (_collectionPath == 'official_news') return _buildOfficialUI(data);
    if (_collectionPath == 'course_reviews') return _buildReviewUI(data);
    if (_collectionPath == 'study_materials') return _buildMaterialUI(data);
    return _buildForumUI(data);
  }

  Widget _buildOfficialUI(Map<String, dynamic> data) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isEvent = OfficialContentHelper.isOfficialEvent(
      data['title'],
      data['summary'],
    );

    final String imagePath = OfficialContentHelper.getOfficialImageByContent(
      data['title'],
      data['summary'],
    );

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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: _buildAuthorRow(
              data['department'] ?? 'HCMUS',
              data['date'] ?? '',
              isOfficial: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopChip(
                  label: OfficialContentHelper.getOfficialCategoryTag(
                    data['title'],
                    data['summary'],
                    data['hashtags'],
                  ),
                  icon: isEvent ? Icons.event : Icons.campaign_outlined,
                  isDarkMode: isDarkMode,
                  highlighted: isEvent,
                  onTap: () {
                    final tag = OfficialContentHelper.getOfficialCategoryTag(
                      data['title'],
                      data['summary'],
                      data['hashtags'],
                    );
                    showSearch(
                      context: context,
                      delegate: MyUniSearchDelegate(
                        currentScope: SearchScope.official,
                        initialHashtag: tag,
                      ),
                    );
                  },
                ),
                if (isEvent)
                  StreamBuilder<DocumentSnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(_user?.uid ?? 'guest')
                        .collection('interested_events')
                        .doc(widget.docId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final bool isInterested =
                          snapshot.hasData && snapshot.data!.exists;

                      return _buildInterestButton(
                        context: context,
                        isDarkMode: isDarkMode,
                        isInterested: isInterested,
                        onTap: _toggleInterest,
                      );
                    },
                  ),
              ],
            ),
          ),
          if (data['hashtags'] != null) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (data['hashtags'] as List)
                    .map(
                      (t) => GestureDetector(
                        onTap: () {
                          final cleanTag = t.toString().replaceAll('#', '').trim();
                          if (cleanTag.isNotEmpty) {
                            showSearch(
                              context: context,
                              delegate: MyUniSearchDelegate(
                                currentScope: SearchScope.forum,
                                initialHashtag: cleanTag,
                              ),
                            );
                          }
                        },
                        child: Container(
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.tag_rounded,
                                size: 14,
                                color: Color(0xFF306CFE),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                t.toString(),
                                style: TextStyle(
                                  fontFamily: 'Encode Sans Expanded',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : const Color(0xFF344054),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
    final int rating = (data['rating'] is num)
        ? (data['rating'] as num).toInt()
        : int.tryParse(data['rating']?.toString() ?? '0') ?? 0;

    final String contentStr = (data['content'] ?? '').toString().trim();
    final bool hasContent = contentStr.isNotEmpty;

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
        padding: EdgeInsets.fromLTRB(16, 18, 16, hasContent ? 18 : 12),
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
            if (hasContent) ...[
              const SizedBox(height: 16),
              Text(
                contentStr,
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
              GestureDetector(
                onTap: () => _handleOpenFile(
                  context,
                  data['fileData'],
                  data['fileName'] ?? (data['isImage'] == true ? 'image.png' : 'document.pdf'),
                ),
                child: data['isImage'] == true
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(
                    Base64ImageCache.decode(data['fileData']),
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
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildForumUI(Map<String, dynamic> data) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isOwner = _user?.uid == data['authorId'];
    final bool isAnonymous =
        (data['isAnonymous'] == true) ||
            (data['authorName']?.toString().toLowerCase().contains('vô danh') ?? false) ||
            (data['authorName']?.toString().toLowerCase().contains('ẩn danh') ?? false);
    final bool showOwnAnonymousBadge = isOwner && isAnonymous;
    final String timeText = data['timestamp'] != null
        ? timeago.format(
      (data['timestamp'] as Timestamp).toDate(),
      locale: 'vi',
    )
        : 'Vừa xong';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildAuthorRow(
                  isAnonymous
                      ? AnonymousUtils.getAnonymousName(data['authorId'] ?? data['uploaderId'] ?? data['userId'] ?? data['uid'], widget.docId)
                      : (data['authorName'] ?? data['uploaderName'] ?? data['userName'] ?? 'Sinh viên'),
                  timeText,
                  avatarBase64: isAnonymous ? null : (data['authorAvatar'] ?? data['uploaderAvatar'] ?? data['userAvatar']),
                  authorId: isAnonymous ? null : (data['authorId'] ?? data['uploaderId'] ?? data['userId'] ?? data['uid']),
                ),
              ),

              if (showOwnAnonymousBadge)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5893D8).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    "Của bạn",
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5893D8),
                    ),
                  ),
                ),
            ],
          ),
          if (data['hashtags'] != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (data['hashtags'] as List)
                  .map(
                    (t) => GestureDetector(
                      onTap: () {
                        final cleanTag = t.toString().replaceAll('#', '').trim();
                        if (cleanTag.isNotEmpty) {
                          showSearch(
                            context: context,
                            delegate: MyUniSearchDelegate(
                              currentScope: SearchScope.forum,
                              initialHashtag: cleanTag,
                            ),
                          );
                        }
                      },
                      child: Container(
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.tag_rounded,
                              size: 14,
                              color: Color(0xFF306CFE),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              t.toString(),
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white70
                                    : const Color(0xFF344054),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            data['content'] ?? '',
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 15,
              height: 1.7,
              color: isDarkMode
                  ? Colors.white
                  : const Color(0xFF1F2937),
            ),
          ),
          if (data['imageUrl'] != null && data['imageUrl'] != '') ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => _showFullScreenImage(context, data['imageUrl']),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(
                  Base64ImageCache.decode(data['imageUrl']),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          if (data['poll'] != null) ...[
            const SizedBox(height: 14),
            PollWidget(docId: widget.docId, pollData: data['poll']),
          ],
        ],
      ),
    );
  }

  Widget _buildTopChip({
    required String label,
    required IconData icon,
    required bool isDarkMode,
    bool highlighted = false,
    VoidCallback? onTap,
  }) {
    final chip = Container(
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
          const Icon(
            Icons.tag_rounded,
            size: 14,
            color: Color(0xFF306CFE),
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

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: chip);
    }
    return chip;
  }

  Widget _buildAuthorRow(
      String name,
      String sub, {
        String? avatarBase64,
        String? authorId,
        bool isOfficial = false,
      }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    void handleAuthorTap() async {
      if (authorId != null && authorId.isNotEmpty && !isOfficial && !name.contains('ẩn danh')) {
        final info = await ChatService().getStudentVerificationInfo(authorId);
        if (mounted) {
          StudentIdentitySheet.show(
            context,
            info ?? {
              'uid': authorId,
              'displayName': name,
              'photoURL': avatarBase64 ?? '',
            },
          );
        }
      }
    }



    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: handleAuthorTap,
          child: CircleAvatar(
            radius: 23,
            backgroundColor:
            isDarkMode ? Colors.white10 : const Color(0xFFF0F0F0),
            child: avatarBase64 != null && avatarBase64.isNotEmpty && !isOfficial
                ? CircleAvatar(
              radius: 21,
              backgroundImage: MemoryImage(Base64ImageCache.decode(avatarBase64)),
            )
                : Padding(
              padding: const EdgeInsets.all(2.0),
              child: isOfficial
                  ? Image.asset('assets/images/logo.png', width: 46, height: 46)
                  : Icon(Icons.person, color: isDarkMode ? Colors.white38 : Colors.grey, size: 28),
            ),
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
                    child: GestureDetector(
                      onTap: handleAuthorTap,
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
            .where((c) {
              final status = c['status'];
              final authorId = c['authorId'];
              if (status == 'pending' && authorId != _user?.uid) {
                return false;
              }
              if (status == 'hidden') {
                return false;
              }
              return true;
            })
            .toList();
        var rootComments =
        allComments.where((c) => c['parentCommentId'] == null).toList();

        if (_commentSortMode == 'top') {
          rootComments.sort((a, b) {
            final List<dynamic> aLikes = a['likes'] ?? [];
            final List<dynamic> bLikes = b['likes'] ?? [];
            final cmp = bLikes.length.compareTo(aLikes.length);
            if (cmp != 0) return cmp;
            final Timestamp? aTime = a['timestamp'] as Timestamp?;
            final Timestamp? bTime = b['timestamp'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return -1;
            if (bTime == null) return 1;
            return bTime.compareTo(aTime);
          });
        } else if (_commentSortMode == 'newest') {
          rootComments.sort((a, b) {
            final Timestamp? aTime = a['timestamp'] as Timestamp?;
            final Timestamp? bTime = b['timestamp'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return -1; // Bình luận mới tạo (đang chờ serverTimestamp) nằm ngay ĐẦU
            if (bTime == null) return 1;
            return bTime.compareTo(aTime); // Mới nhất lên đầu
          });
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  PopupMenuButton<String>(
                    tooltip: "Sắp xếp bình luận",
                    offset: const Offset(0, 24),
                    color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _commentSortMode == 'newest' ? "Mới nhất" : "Nổi bật nhất",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white70 : const Color(0xFF344054),
                              fontFamily: 'Encode Sans Expanded',
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.sort_rounded,
                            size: 18,
                            color: isDarkMode ? Colors.white60 : Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _commentSortMode = val;
                      });
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'newest',
                        height: 36,
                        child: Text(
                          "Mới nhất",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _commentSortMode == 'newest' ? FontWeight.w700 : FontWeight.w500,
                            color: isDarkMode ? Colors.white70 : const Color(0xFF344054),
                            fontFamily: 'Encode Sans Expanded',
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'top',
                        height: 36,
                        child: Text(
                          "Nổi bật nhất",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _commentSortMode == 'top' ? FontWeight.w700 : FontWeight.w500,
                            color: isDarkMode ? Colors.white70 : const Color(0xFF344054),
                            fontFamily: 'Encode Sans Expanded',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (rootComments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/lonelycat.png',
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Ở đây thật... lạnh lẽo!",
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white30 : Color(0xFF545454),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: rootComments
                      .map((comment) => _buildCommentTree(comment, allComments, 0, false))
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
      int depth,
      bool isLast,
      ) {
    var replies =
    allComments.where((c) => c['parentCommentId'] == comment['id']).toList();
    bool isExpanded = _expandedComments.contains(comment['id']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSingleCommentWidget(comment, depth, replies.isNotEmpty, isLast, allComments),
        if (replies.isNotEmpty) ...[
          if (depth == 0) ...[
            // Root level: Handle expansion toggle
            if (!isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: GestureDetector(
                  onTap: () => setState(() => _expandedComments.add(comment['id'])),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      "Xem ${replies.length} phản hồi",
                      style: const TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 12,
                        color: Color(0xFF5893D8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Column(
                  children: replies.asMap().entries.map((entry) {
                    return _buildCommentTree(
                        entry.value,
                        allComments,
                        depth + 1,
                        entry.key == replies.length - 1
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: GestureDetector(
                  onTap: () => setState(() => _expandedComments.remove(comment['id'])),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      "Ẩn bớt",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ]
          ] else ...[
            // Depth > 0: Always show sub-replies directly to avoid button clutter
            Padding(
              padding: EdgeInsets.only(left: depth < 3 ? 36 : 0),
              child: Column(
                children: replies.asMap().entries.map((entry) {
                  return _buildCommentTree(
                      entry.value,
                      allComments,
                      depth + 1,
                      entry.key == replies.length - 1
                  );
                }).toList(),
              ),
            ),
          ]
        ],
      ],
    );
  }

  String _getParentAuthorName(
      String? parentId, List<Map<String, dynamic>> allComments) {
    if (parentId == null) return "";
    try {
      final parent = allComments.firstWhere((c) => c['id'] == parentId);
      return parent['authorName'] ?? "Người dùng";
    } catch (e) {
      return "Người dùng";
    }
  }

  Widget _buildSingleCommentWidget(Map<String, dynamic> comment, int depth,
      bool hasReplies, bool isLast, List<Map<String, dynamic>> allComments) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String? commentAuthorId = comment['authorId'];

    final bool isCommentOwner = _user?.uid == comment['authorId'];
    final bool isPostOwner = _user?.uid ==
        (_postData['authorId'] ??
            _postData['uploaderId']);
    final bool canDelete = isCommentOwner || isPostOwner;
    bool canEdit = isCommentOwner;

    if (canEdit && comment['timestamp'] != null) {
      try {
        final Timestamp ts = comment['timestamp'] as Timestamp;
        final DateTime commentTime = ts.toDate();
        if (DateTime.now().difference(commentTime).inHours >= 12) {
          canEdit = false;
        }
      } catch (e) {
        debugPrint("Error checking comment edit timeframe: $e");
      }
    }

    final bool isPostAnonymous =
        (_postData['isAnonymous'] == true) ||
        (_postData['authorName']?.toString().toLowerCase().contains('vô danh') ?? false) ||
        (_postData['authorName']?.toString().toLowerCase().contains('ẩn danh') ?? false);

    final bool isCommentAnonymous = (comment['isAnonymous'] == true);

    final bool isAuthor = !isPostAnonymous &&
        !isCommentAnonymous &&
        comment['authorId'] ==
            (_postData['authorId'] ??
                _postData['uploaderId']);

    final List<dynamic> likes = comment['likes'] ?? [];
    final bool isLiked = _user != null && likes.contains(_user!.uid);
    final String timeStr = comment['timestamp'] != null
        ? timeago.format(
      (comment['timestamp'] as Timestamp).toDate(),
      locale: 'vi',
    )
        : 'Vừa xong';

    final String contentText = comment['content']?.toString().trim() ?? '';
    final bool hasContent = contentText.isNotEmpty;
    final bool hasImage = comment['imageUrl'] != null && comment['imageUrl'].toString().isNotEmpty;

    return StreamBuilder<DocumentSnapshot>(
      stream: (commentAuthorId == null || isCommentAnonymous)
          ? null
          : _firestore.collection('users').doc(commentAuthorId).snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;

        final String liveName = isCommentAnonymous
            ? AnonymousUtils.getAnonymousName(commentAuthorId, widget.docId)
            : (userData?['displayName'] ?? comment['authorName'] ?? 'Người dùng');

        final String? liveAvatar = isCommentAnonymous
            ? null
            : (userData?['photoUrl'] ?? comment['authorAvatar']);

        void handleCommentUserTap() async {
          if (commentAuthorId != null && commentAuthorId.isNotEmpty && !isCommentAnonymous) {
            final info = await ChatService().getStudentVerificationInfo(commentAuthorId);
            if (mounted) {
              StudentIdentitySheet.show(
                context,
                info ?? {
                  'uid': commentAuthorId,
                  'displayName': liveName,
                  'photoURL': liveAvatar ?? '',
                },
              );
            }
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (depth > 0 && depth <= 3)
              Positioned(
                left: -18,
                top: -12,
                height: 38,
                child: Container(
                  width: 18,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.06),
                        width: 1.5,
                      ),
                      bottom: BorderSide(
                        color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.06),
                        width: 1.5,
                      ),
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: handleCommentUserTap,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor:
                      isDarkMode ? Colors.white10 : const Color(0xFFF1F2F6),
                      child: (liveAvatar == null || liveAvatar.isEmpty)
                          ? Icon(
                        Icons.person,
                        size: 20,
                        color: isDarkMode ? Colors.white38 : Colors.grey,
                      )
                          : ClipOval(
                        child: Image.memory(
                          Base64ImageCache.decode(liveAvatar),
                          fit: BoxFit.cover,
                          width: 36,
                          height: 36,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row (Name + Time + More menu)
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: GestureDetector(
                                      onTap: handleCommentUserTap,
                                      child: Text(
                                        liveName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Encode Sans Expanded',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isCommentAnonymous && isCommentOwner) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5893D8).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "Bạn",
                                        style: TextStyle(
                                          fontFamily: 'Encode Sans Expanded',
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF5893D8),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (isAuthor) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5893D8).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "Tác giả",
                                        style: TextStyle(
                                          fontFamily: 'Encode Sans Expanded',
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF5893D8),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  Text(
                                    "•",
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white30 : Colors.black26,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontSize: 11,
                                      color: isDarkMode ? Colors.white38 : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_user != null)
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.more_horiz,
                                    size: 16,
                                    color: isDarkMode ? Colors.white38 : const Color(0xFF777777),
                                  ),
                                  onSelected: (val) async {
                                    if (val == 'delete') _showDeleteConfirmation(comment['id']);
                                    if (val == 'edit') _showEditCommentDialog(comment);
                                    if (val == 'report') _showReportCommentOptions(comment);
                                  },
                                  itemBuilder: (context) => [
                                    if (canEdit) const PopupMenuItem(value: 'edit', child: Text("Sửa bình luận")),
                                    if (canDelete) const PopupMenuItem(value: 'delete', child: Text("Xóa", style: TextStyle(color: Colors.red))),
                                    if (!isCommentOwner) const PopupMenuItem(value: 'report', child: Text("Báo cáo bình luận", style: TextStyle(color: Colors.redAccent))),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (hasContent) ...[
                          const SizedBox(height: 3),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 14,
                                height: 1.4,
                                color: isDarkMode ? Colors.white70 : const Color(0xFF333333),
                              ),
                              children: [
                                if (depth > 1)
                                  TextSpan(
                                    text: "@${_getParentAuthorName(comment['parentCommentId'], allComments)} ",
                                    style: const TextStyle(
                                      color: Color(0xFF5893D8),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                TextSpan(text: contentText),
                              ],
                            ),
                          ),
                        ],
                        if (hasImage) ...[
                          SizedBox(height: hasContent ? 8 : 6),
                          GestureDetector(
                            onTap: () => _showFullScreenImage(context, comment['imageUrl']),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                Base64ImageCache.decode(comment['imageUrl']),
                                width: MediaQuery.of(context).size.width * 0.55,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Bottom Actions (Like & Reply & Chat)
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleCommentLike(comment),
                              child: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: isLiked ? Colors.redAccent : (isDarkMode ? Colors.white38 : Colors.grey[500]),
                              ),
                            ),
                            if (likes.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                likes.length.toString(),
                                style: TextStyle(
                                  fontFamily: 'Encode Sans Expanded',
                                  fontSize: 11,
                                  color: isDarkMode ? Colors.white38 : Colors.grey[600],
                                ),
                              ),
                            ],
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => setState(() {
                                _replyingToId = comment['id'];
                                _replyingToName = liveName;
                              }),
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 15,
                                color: isDarkMode ? Colors.white38 : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCommentIdentitySelector() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final uid = _user?.uid;
    if (uid == null) return;

    String realName = _user?.displayName ?? 'Sinh viên';
    String? userPhotoBase64;
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final rawName = data?['displayName']?.toString().trim();
        if (rawName != null && rawName.isNotEmpty) {
          realName = rawName;
        }
        userPhotoBase64 = data?['photoUrl'];
      }
    } catch (_) {}

    final anonName = AnonymousUtils.getAnonymousName(uid, widget.docId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        "Bình luận dưới tên",
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Chọn danh tính bạn muốn hiển thị khi bình luận vào bài viết này",
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 12,
                      color: isDarkMode ? Colors.white60 : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Option 1: Profile thật
                  InkWell(
                    onTap: () {
                      setState(() => _isCommentAnonymous = false);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isCommentAnonymous
                            ? (isDarkMode ? const Color(0xFF5893D8).withValues(alpha: 0.15) : const Color(0xFFEBF5FF))
                            : (isDarkMode ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: !_isCommentAnonymous
                              ? const Color(0xFF5893D8)
                              : (isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0)),
                          width: !_isCommentAnonymous ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isDarkMode ? Colors.white10 : Colors.grey[200],
                            backgroundImage: (userPhotoBase64 != null && userPhotoBase64.isNotEmpty)
                                ? MemoryImage(Base64ImageCache.decode(userPhotoBase64))
                                : null,
                            child: (userPhotoBase64 == null || userPhotoBase64.isEmpty)
                                ? Icon(Icons.person, color: isDarkMode ? Colors.white54 : Colors.grey[600])
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  realName,
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Trang cá nhân của bạn",
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.white54 : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Radio<bool>(
                            value: false,
                            groupValue: _isCommentAnonymous,
                            activeColor: const Color(0xFF5893D8),
                            onChanged: (val) {
                              setState(() => _isCommentAnonymous = false);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Option 2: Thành viên ẩn danh
                  InkWell(
                    onTap: () {
                      setState(() => _isCommentAnonymous = true);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isCommentAnonymous
                            ? (isDarkMode ? const Color(0xFF5893D8).withValues(alpha: 0.15) : const Color(0xFFEBF5FF))
                            : (isDarkMode ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isCommentAnonymous
                              ? const Color(0xFF5893D8)
                              : (isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0)),
                          width: _isCommentAnonymous ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isDarkMode ? const Color(0xFF334155) : const Color(0xFF475569),
                            child: const Icon(Icons.person_outline, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  anonName,
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Tên và ảnh đại diện của bạn sẽ được ẩn",
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.white54 : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Radio<bool>(
                            value: true,
                            groupValue: _isCommentAnonymous,
                            activeColor: const Color(0xFF5893D8),
                            onChanged: (val) {
                              setState(() => _isCommentAnonymous = true);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCommentInputField() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return _buildActualCommentInputField(isDarkMode);
  }

  Widget _buildActualCommentInputField(bool isDarkMode) {
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
          if (_commentImageFile != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 90,
              alignment: Alignment.centerLeft,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _commentImageFile!,
                      height: 90,
                      width: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _commentImageFile = null),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isCommentAnonymous)
            GestureDetector(
              onTap: _showCommentIdentitySelector,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF5893D8).withValues(alpha: 0.15)
                      : const Color(0xFF5893D8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF5893D8).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 15,
                      color: Color(0xFF5893D8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Đang ẩn danh: ${AnonymousUtils.getAnonymousName(_user?.uid, widget.docId)}',
                      style: const TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5893D8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: Color(0xFF5893D8),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              GestureDetector(
                onTap: _showCommentIdentitySelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: _isCommentAnonymous
                            ? (isDarkMode ? const Color(0xFF334155) : const Color(0xFF475569))
                            : (isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0)),
                        child: Icon(
                          _isCommentAnonymous ? Icons.person_outline : Icons.person,
                          size: 18,
                          color: _isCommentAnonymous ? Colors.white : (isDarkMode ? Colors.white70 : const Color(0xFF5893D8)),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF111315) : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF5893D8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.sync_alt_rounded,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _pickCommentImage,
                icon: Icon(
                  Icons.image_outlined,
                  color: isDarkMode ? Colors.white70 : const Color(0xFF5893D8),
                  size: 22,
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
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
                      hintText: _isCommentAnonymous
                          ? "Viết bình luận ẩn danh..."
                          : "Viết bình luận...",
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.white38 : Colors.grey,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
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
                    icon: Padding(
                      padding: EdgeInsets.only(left: _isSubmittingComment ? 0 : 3),
                      child: _isSubmittingComment
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
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
