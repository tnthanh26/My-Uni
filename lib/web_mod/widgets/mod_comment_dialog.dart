import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/post_moderation_service.dart';
import '../services/mod_notification_service.dart';

class ModCommentDialog extends StatefulWidget {
  final String collection;
  final String postId;

  const ModCommentDialog({
    super.key,
    required this.collection,
    required this.postId,
  });

  @override
  State<ModCommentDialog> createState() => _ModCommentDialogState();
}

class _ModCommentDialogState extends State<ModCommentDialog> {
  bool _isActionInProgress = false;
  ImageProvider? _getAvatarImage(String? avatar) {
    if (avatar == null || avatar.trim().isEmpty) return null;
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return NetworkImage(avatar);
    }
    try {
      return MemoryImage(base64Decode(avatar));
    } catch (e) {
      debugPrint("Error decoding avatar: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Row(
        children: [
          Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
          SizedBox(width: 12),
          Text(
            "Danh sách bình luận",
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Nunito'),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        height: 500,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(widget.collection)
              .doc(widget.postId)
              .collection('comments')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  "Chưa có bình luận nào.",
                  style: TextStyle(color: Colors.grey, fontFamily: 'Nunito'),
                ),
              );
            }

            final allDocs = snapshot.data!.docs;
            final List<QueryDocumentSnapshot> orderedComments = [];

            void addRepliesRecursively(
              String parentId,
              List<QueryDocumentSnapshot> source,
              List<QueryDocumentSnapshot> target,
            ) {
              final directReplies = source.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return d['parentCommentId'] == parentId;
              }).toList();

              directReplies.sort((a, b) {
                final aT =
                    (a.data() as Map<String, dynamic>)['timestamp']
                        as Timestamp?;
                final bT =
                    (b.data() as Map<String, dynamic>)['timestamp']
                        as Timestamp?;
                if (aT == null || bT == null) return 0;
                return aT.compareTo(bT);
              });

              for (var reply in directReplies) {
                target.add(reply);
                addRepliesRecursively(reply.id, source, target);
              }
            }

            // 1. Lấy các comment gốc (không có parentCommentId)
            final rootComments = allDocs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return d['parentCommentId'] == null;
            }).toList();

            // 2. Với mỗi comment gốc, tìm các reply đệ quy
            for (var root in rootComments) {
              orderedComments.add(root);
              addRepliesRecursively(root.id, allDocs, orderedComments);
            }

            return ListView.builder(
              itemCount: orderedComments.length,
              itemBuilder: (context, index) {
                final comment = orderedComments[index];
                final data = comment.data() as Map<String, dynamic>;
                final avatarImage = _getAvatarImage(data['authorAvatar']);
                final int reportCount = data['reportCount'] ?? 0;
                final bool isReported =
                    data['isReported'] == true && reportCount > 0;

                int depth = 0;
                String? currParent = data['parentCommentId'];
                while (currParent != null) {
                  depth++;
                  final matches = allDocs
                      .where((d) => d.id == currParent)
                      .toList();
                  if (matches.isNotEmpty) {
                    final pData = matches.first.data() as Map<String, dynamic>;
                    currParent = pData['parentCommentId'];
                  } else {
                    currParent = null;
                  }
                }
                final double leftMargin = depth > 0
                    ? (depth * 24.0).clamp(0.0, 72.0)
                    : 0.0;
                final bool isReply = depth > 0;

                return Column(
                  children: [
                    Container(
                      margin: EdgeInsets.only(
                        left: leftMargin,
                        top: 6,
                        bottom: 6,
                      ),
                      padding: (isReply || isReported)
                          ? const EdgeInsets.all(12)
                          : const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
                            ),
                      decoration: (isReply || isReported)
                          ? BoxDecoration(
                              color: isReported
                                  ? const Color(0xFFFFF1F2)
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isReported
                                    ? const Color(0xFFFECDD3)
                                    : Colors.grey[200]!,
                              ),
                            )
                          : null,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isReply)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, right: 8),
                              child: Icon(
                                Icons.subdirectory_arrow_right,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ),
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? const Icon(Icons.person, size: 18)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          data['authorName'] ?? "Người dùng",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            fontFamily: 'Nunito',
                                          ),
                                        ),
                                        if (isReply)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              "Phản hồi",
                                              style: TextStyle(
                                                color: Colors.blueAccent,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        if (isReported)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.report_problem,
                                                  size: 10,
                                                  color: Colors.redAccent,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "Bị báo cáo ($reportCount)",
                                                  style: const TextStyle(
                                                    color: Colors.redAccent,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isReported) ...[
                                          IconButton(
                                            icon: const Icon(
                                              Icons.check_circle_outline,
                                              color: Colors.green,
                                              size: 18,
                                            ),
                                            onPressed: () =>
                                                _dismissCommentReport(
                                                  comment.id,
                                                ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: "Bỏ qua báo cáo",
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _confirmDeleteComment(
                                                comment.id,
                                                isReply,
                                              ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: "Xóa bình luận",
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  data['content'] ?? "",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                                if (data['imageUrl'] != null &&
                                    data['imageUrl'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      base64Decode(data['imageUrl']),
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  data['timestamp']
                                          ?.toDate()
                                          .toString()
                                          .substring(0, 16) ??
                                      "",
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isReply &&
                        index < orderedComments.length - 1 &&
                        (orderedComments[index + 1].data()
                                as Map)['parentCommentId'] ==
                            null)
                      const Divider(height: 1),
                  ],
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Đóng"),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteComment(String commentId, bool isReply) async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Xác nhận xóa"),
          content: Text(
            isReply
                ? "Bạn có chắc chắn muốn xóa phản hồi này?"
                : "Bạn có chắc chắn muốn xóa bình luận này và tất cả phản hồi liên quan?",
          ),
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

      if (confirm == true) {
        // Fetch comment details before deletion to get author info
        final commentDoc = await FirebaseFirestore.instance
            .collection(widget.collection)
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId)
            .get();

        await PostModerationService.deleteComment(
          collection: widget.collection,
          postId: widget.postId,
          commentId: commentId,
        );

        if (commentDoc.exists) {
          final commentData = commentDoc.data();
          final commentAuthorId = commentData?['authorId'];

          // Query reports for this comment to notify reporters and resolve reports
          final reportsSnapshot = await FirebaseFirestore.instance
              .collection('reports')
              .where('reportedCommentId', isEqualTo: commentId)
              .where('status', isEqualTo: 'pending')
              .get();

          for (var reportDoc in reportsSnapshot.docs) {
            final rData = reportDoc.data();
            final reporterId = rData['reporterId'];
            if (reporterId != null) {
              await ModNotificationService.sendPostNotification(
                userId: reporterId,
                title: "Phản hồi báo cáo",
                content:
                    "Báo cáo của bạn đã được xử lý. Bình luận vi phạm đã bị xóa.",
                type: 'info',
                postId: widget.postId,
                collectionPath: widget.collection,
                reportedCommentId: commentId,
              );
            }
            await reportDoc.reference.update({
              'status': 'resolved',
              'resolvedAt': FieldValue.serverTimestamp(),
            });
          }

          if (commentAuthorId != null) {
            await ModNotificationService.sendPostNotification(
              userId: commentAuthorId,
              title: "Bình luận bị gỡ bỏ",
              content:
                  "Bình luận của bạn đã bị xóa do vi phạm tiêu chuẩn cộng đồng.",
              type: 'warning',
              postId: widget.postId,
              collectionPath: widget.collection,
              reportedCommentId: commentId,
            );
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Đã xóa bình luận thành công và gửi thông báo."),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi khi xóa bình luận: $e")));
      }
    } finally {
      _isActionInProgress = false;
    }
  }

  Future<void> _dismissCommentReport(String commentId) async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    try {
      // Fetch comment details to get author info
      final commentDoc = await FirebaseFirestore.instance
          .collection(widget.collection)
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .get();

      await PostModerationService.dismissCommentReport(
        collection: widget.collection,
        postId: widget.postId,
        commentId: commentId,
      );

      if (commentDoc.exists) {
        final commentData = commentDoc.data();
        final commentAuthorId = commentData?['authorId'];

        // Query reports for this comment to notify reporters and resolve reports
        final reportsSnapshot = await FirebaseFirestore.instance
            .collection('reports')
            .where('reportedCommentId', isEqualTo: commentId)
            .where('status', isEqualTo: 'pending')
            .get();

        for (var reportDoc in reportsSnapshot.docs) {
          final rData = reportDoc.data();
          final reporterId = rData['reporterId'];
          if (reporterId != null) {
            await ModNotificationService.sendPostNotification(
              userId: reporterId,
              title: "Phản hồi báo cáo",
              content:
                  "Mod không phát hiện sai phạm đối với bình luận bạn đã báo cáo. Nội dung vẫn được giữ nguyên.",
              type: 'info',
              postId: widget.postId,
              collectionPath: widget.collection,
              reportedCommentId: commentId,
            );
          }
          await reportDoc.reference.update({
            'status': 'dismissed',
            'resolvedAt': FieldValue.serverTimestamp(),
          });
        }

        if (commentAuthorId != null) {
          await ModNotificationService.sendPostNotification(
            userId: commentAuthorId,
            title: "Báo cáo bình luận",
            content:
                "Mod không phát hiện sai phạm đối với bình luận của bạn. Bình luận vẫn giữ nguyên.",
            type: 'info',
            postId: widget.postId,
            collectionPath: widget.collection,
            reportedCommentId: commentId,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Đã bỏ qua báo cáo bình luận và gửi thông báo."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi khi bỏ báo cáo: $e")));
      }
    } finally {
      _isActionInProgress = false;
    }
  }
}
