import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

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

  // --- QUẢN LÝ REPLY ---
  String? _replyingToId;
  String? _replyingToName;

  // Tự động nhận diện collection dựa trên dữ liệu truyền vào
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

  // --- LOGIC FUNCTIONS ---

  Future<void> _handleLike() async {
    if (_user == null) return;
    final postRef = _firestore.collection(_collectionPath).doc(widget.docId);
    final userLikeRef = postRef.collection('likes').doc(_user!.uid);
    final doc = await userLikeRef.get();

    if (doc.exists) {
      await userLikeRef.delete();
      await postRef.update({'likeCount': FieldValue.increment(-1)});
    } else {
      await userLikeRef.set({'timestamp': FieldValue.serverTimestamp()});
      await postRef.update({'likeCount': FieldValue.increment(1)});
    }
  }

  Future<void> _addComment() async {
    if (_user == null || _commentController.text.trim().isEmpty) return;

    String content = _commentController.text.trim();
    String? parentId = _replyingToId;

    // Reset trạng thái nhập liệu ngay
    _commentController.clear();
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });
    FocusScope.of(context).unfocus();

    final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
    final userData = userDoc.data();

    await _firestore.collection(_collectionPath).doc(widget.docId).collection('comments').add({
      'authorId': _user!.uid,
      'authorName': userData?['displayName'] ?? 'Sinh viên MyUni',
      'authorAvatar': userData?['photoUrl'] ?? '',
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'parentCommentId': parentId, // null nếu là comment gốc
    });

    await _firestore.collection(_collectionPath).doc(widget.docId).update({
      'commentCount': FieldValue.increment(1)
    });
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_getAppBarTitle(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: const Color(0xFF6797E1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildDynamicHeader(isDarkMode),
                  const Divider(thickness: 1, height: 1),
                  _buildInternalActionRow(isDarkMode),
                  const Divider(thickness: 8, color: Colors.black12, height: 8),

                  // DANH SÁCH COMMENT ĐA CẤP
                  _buildCommentSection(isDarkMode),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildCommentInputField(isDarkMode),
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

  Widget _buildDynamicHeader(bool isDarkMode) {
    final data = widget.initialPostData;
    if (_collectionPath == 'official_news') return _buildOfficialUI(data, isDarkMode);
    if (_collectionPath == 'course_reviews') return _buildReviewUI(data, isDarkMode);
    if (_collectionPath == 'study_materials') return _buildMaterialUI(data, isDarkMode);
    return _buildForumUI(data, isDarkMode);
  }

  // --- 4 GIAO DIỆN HEADER ĐẶC TRƯNG ---

  Widget _buildOfficialUI(Map<String, dynamic> data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(backgroundColor: Color(0xFF6797E1), child: Icon(Icons.school, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['department'] ?? 'HCMUS', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(data['date'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])
        ]),
        const SizedBox(height: 15),
        Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 10),
        Text(data['summary'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, height: 1.5)),
        const SizedBox(height: 15),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/images/news.png', width: double.infinity, height: 200, fit: BoxFit.cover),
        ),
        const SizedBox(height: 15),
        SizedBox(width: double.infinity, child: OutlinedButton(
          onPressed: () => launchUrl(Uri.parse(data['link'] ?? ''), mode: LaunchMode.externalApplication),
          child: const Text("Xem chi tiết tại Website Trường"),
        )),
      ]),
    );
  }

  Widget _buildReviewUI(Map<String, dynamic> data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data['courseName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        Text("Giảng viên: ${data['teacherName']}", style: const TextStyle(color: Color(0xFF6797E1), fontWeight: FontWeight.w500)),
        Text("Học kỳ: ${data['semester']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: List.generate(5, (i) => Icon(i < (data['rating'] ?? 0) ? Icons.star : Icons.star_border, color: Colors.amber, size: 24))),
        const SizedBox(height: 15),
        Text(data['content'] ?? '', style: TextStyle(fontSize: 15, height: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
      ]),
    );
  }

  Widget _buildMaterialUI(Map<String, dynamic> data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data['courseName'] ?? 'Tài liệu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        Text("Học kỳ: ${data['semester']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 15),
        Text(data['content'] ?? '', style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 15),
        if (data['fileData'] != null)
          data['isImage'] == true
              ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(data['fileData']), width: double.infinity, fit: BoxFit.contain))
              : Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: const Color(0xFF6797E1).withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF6797E1).withOpacity(0.2))),
            child: Row(children: [const Icon(Icons.description, color: Color(0xFF6797E1), size: 30), const SizedBox(width: 12), Expanded(child: Text(data['fileName'] ?? 'document.pdf', style: const TextStyle(fontWeight: FontWeight.w500)))]),
          ),
      ]),
    );
  }

  Widget _buildForumUI(Map<String, dynamic> data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: Colors.grey[300],
            backgroundImage: data['authorAvatar'] != null && data['authorAvatar'] != '' ? MemoryImage(base64Decode(data['authorAvatar'])) : null,
            child: (data['authorAvatar'] == null || data['authorAvatar'] == '') ? const Icon(Icons.person, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['authorName'] ?? 'Ẩn danh', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(data['timestamp'] != null ? timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'vi') : 'Vừa xong', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])
        ]),
        const SizedBox(height: 15),
        if (data['hashtags'] != null) Wrap(spacing: 8, children: (data['hashtags'] as List).map((t) => Text("#$t", style: const TextStyle(color: Color(0xFF6797E1), fontWeight: FontWeight.bold))).toList()),
        const SizedBox(height: 12),
        Text(data['content'] ?? '', style: TextStyle(fontSize: 16, height: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
        const SizedBox(height: 15),
        if (data['imageUrl'] != null && data['imageUrl'] != '') ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(data['imageUrl']), width: double.infinity, fit: BoxFit.cover)),
      ]),
    );
  }

  // --- ACTION ROW ---

  Widget _buildInternalActionRow(bool isDark) {
    return StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection(_collectionPath).doc(widget.docId).snapshots(),
        builder: (context, snapshot) {
          var currentData = snapshot.data?.data() as Map<String, dynamic>? ?? widget.initialPostData;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(Icons.favorite_border, '${currentData['likeCount'] ?? 0} Thích', isDark, onTap: _handleLike),
                _buildActionButton(Icons.chat_bubble_outline, '${currentData['commentCount'] ?? 0} Bình luận', isDark),
                _buildActionButton(Icons.bookmark_border, 'Lưu', isDark),
              ],
            ),
          );
        }
    );
  }

  Widget _buildActionButton(IconData icon, String label, bool isDark, {VoidCallback? onTap}) {
    return GestureDetector(onTap: onTap, child: Row(children: [Icon(icon, size: 20, color: Colors.grey), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))]));
  }

  // --- COMMENT SECTION (REPLY SUPPORT) ---

  Widget _buildCommentSection(bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection(_collectionPath).doc(widget.docId).collection('comments').orderBy('timestamp', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));

        var allComments = snapshot.data!.docs.map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id}).toList();
        var rootComments = allComments.where((c) => c['parentCommentId'] == null).toList();

        if (rootComments.isEmpty) return const Padding(padding: EdgeInsets.all(40.0), child: Center(child: Text("Chưa có bình luận nào.", style: TextStyle(color: Colors.grey))));

        return Column(
          children: rootComments.map((comment) => _buildCommentTree(comment, allComments, isDarkMode)).toList(),
        );
      },
    );
  }

  Widget _buildCommentTree(Map<String, dynamic> comment, List<Map<String, dynamic>> allComments, bool isDark) {
    var replies = allComments.where((c) => c['parentCommentId'] == comment['id']).toList();
    return Column(
      children: [
        _buildSingleCommentWidget(comment, isDark),
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Column(children: replies.map((reply) => _buildCommentTree(reply, allComments, isDark)).toList()),
          ),
      ],
    );
  }

  Widget _buildSingleCommentWidget(Map<String, dynamic> comment, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: comment['authorAvatar'] != null && comment['authorAvatar'] != '' ? MemoryImage(base64Decode(comment['authorAvatar'])) : null,
          child: (comment['authorAvatar'] == null || comment['authorAvatar'] == '') ? const Icon(Icons.person, size: 18) : null,
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isDark ? Colors.white10 : const Color(0xFFF1F2F6), borderRadius: BorderRadius.circular(15)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(comment['authorName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(comment['content'], style: const TextStyle(fontSize: 14)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: GestureDetector(
                onTap: () => setState(() { _replyingToId = comment['id']; _replyingToName = comment['authorName']; }),
                child: const Text("Trả lời", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ))
      ]),
    );
  }

  Widget _buildCommentInputField(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? Colors.black : Colors.white, border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2)))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: const Color(0xFF6797E1).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Text("Đang trả lời ", style: const TextStyle(fontSize: 12)),
                Text(_replyingToName ?? "", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6797E1))),
                const Spacer(),
                GestureDetector(onTap: () => setState(() { _replyingToId = null; _replyingToName = null; }), child: const Icon(Icons.close, size: 16, color: Colors.grey))
              ]),
            ),
          Row(children: [
            Expanded(child: TextField(controller: _commentController, decoration: InputDecoration(hintText: "Viết bình luận...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none), filled: true, fillColor: isDark ? Colors.white10 : Colors.grey[100], contentPadding: const EdgeInsets.symmetric(horizontal: 16)))),
            const SizedBox(width: 8),
            CircleAvatar(backgroundColor: const Color(0xFF6797E1), child: IconButton(onPressed: _addComment, icon: const Icon(Icons.send, color: Colors.white, size: 18)))
          ]),
        ],
      ),
    );
  }
}