import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'post_action_row.dart'; // Giữ nguyên import logic của bạn

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

  // --- LOGIC NHẬN DIỆN COLLECTION CỦA BẠN ---
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

  // --- LOGIC THÊM COMMENT CỦA BẠN ---
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

    await _firestore.collection(_collectionPath).doc(widget.docId).collection('comments').add({
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_getAppBarTitle(),
            style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF545454),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFDFE6E9), height: 1),
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

                  // DÙNG POSTACTIONROW CỦA BẠN ĐỂ GIỮ LOGIC LIKE/SAVE
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: PostActionRow(
                      docId: widget.docId,
                      data: widget.initialPostData,
                      onSave: (id, data) {},
                      collectionPath: _collectionPath,
                    ),
                  ),

                  Container(color: const Color(0xFFF8F9FA), height: 8),
                  _buildCommentSection(),
                  const SizedBox(height: 20),
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

  // --- UI OFFICIAL (CHÍNH THỨC) ---
  Widget _buildOfficialUI(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildAuthorRow(data['department'] ?? 'HCMUS', data['date'] ?? '', isOfficial: true),
        const SizedBox(height: 16),
        Text(data['title'] ?? '',
            style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w600, fontSize: 18, color: Color(0xFF545454))),
        const SizedBox(height: 12),
        Text(data['summary'] ?? '',
            style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: Color(0xFF545454), height: 1.5)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset('assets/images/news.png', width: double.infinity, height: 240, fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 45, child: OutlinedButton(
          onPressed: () => launchUrl(Uri.parse(data['link'] ?? ''), mode: LaunchMode.externalApplication),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF5893D8)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text("Xem chi tiết bài viết", style: TextStyle(color: Color(0xFF5893D8), fontWeight: FontWeight.bold)),
        )),
      ]),
    );
  }

  // --- UI REVIEW ---
  Widget _buildReviewUI(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data['courseName'] ?? '',
            style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w700, fontSize: 20, color: Color(0xFF545454))),
        Text("Giảng viên: ${data['teacherName']}",
            style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w400, color: Color(0xFF5893D8))),
        Text(data['semester'] ?? '', style: const TextStyle(fontFamily: 'Encode Sans Expanded', color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        Row(children: List.generate(5, (i) => Icon(
            i < (data['rating'] ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
            color: const Color(0xFFFFCB45), size: 28))),
        const SizedBox(height: 15),
        Text(data['content'] ?? '',
            style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 16, height: 1.6, color: Color(0xFF545454))),
      ]),
    );
  }

  // --- UI MATERIAL (TÀI LIỆU) ---
  Widget _buildMaterialUI(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data['courseName'] ?? 'Tài liệu',
            style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w700, fontSize: 20, color: Color(0xFF545454))),
        Text(data['semester'] ?? '', style: const TextStyle(fontFamily: 'Encode Sans Expanded', color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        Text(data['content'] ?? '',
            style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 16, color: Color(0xFF545454))),
        const SizedBox(height: 16),
        if (data['fileData'] != null)
          data['isImage'] == true
              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(data['fileData']), width: double.infinity, fit: BoxFit.contain))
              : Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDFE6E9))),
            child: Row(children: [const Icon(Icons.description_rounded, color: Color(0xFF5893D8), size: 32), const SizedBox(width: 12), Expanded(child: Text(data['fileName'] ?? 'document.pdf', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w500)))]),
          ),
      ]),
    );
  }

  // --- UI FORUM (DIỄN ĐÀN) ---
  Widget _buildForumUI(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildAuthorRow(
            data['authorName'] ?? 'Sinh viên ẩn danh',
            data['timestamp'] != null ? timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'vi') : 'Vừa xong',
            avatarBase64: data['authorAvatar']
        ),
        const SizedBox(height: 16),
        if (data['hashtags'] != null)
          Wrap(spacing: 8, children: (data['hashtags'] as List).map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(16)),
            child: Text("#$t", style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF344054))),
          )).toList()),
        const SizedBox(height: 16),
        Text(data['content'] ?? '', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 16, height: 1.5, color: Color(0xFF545454))),
        const SizedBox(height: 16),
        if (data['imageUrl'] != null && data['imageUrl'] != '')
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(data['imageUrl']), width: double.infinity, fit: BoxFit.cover)),
      ]),
    );
  }

  // --- HELPER COMPONENT GIỮ LOGIC LẤY AVATAR CỦA BẠN ---
  Widget _buildAuthorRow(String name, String sub, {String? avatarBase64, bool isOfficial = false}) {
    return Row(children: [
      CircleAvatar(
        radius: 22.5,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: (avatarBase64 != null && avatarBase64.isNotEmpty)
              ? ClipOval(child: Image.memory(base64Decode(avatarBase64), fit: BoxFit.cover, width: 45, height: 45))
              : const Icon(Icons.person, color: Colors.grey),
        ),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(name, style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w600, fontSize: 15)),
          if (isOfficial) ...[const SizedBox(width: 4), const Icon(Icons.check_circle, color: Color(0xFF66ACFE), size: 16)],
        ]),
        Text(sub, style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 12, color: Colors.grey)),
      ])
    ]);
  }

  // --- COMMENT SECTION VỚI LOGIC REPLY CỦA BẠN ---
  Widget _buildCommentSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection(_collectionPath).doc(widget.docId).collection('comments').orderBy('timestamp', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
        var allComments = snapshot.data!.docs.map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id}).toList();
        var rootComments = allComments.where((c) => c['parentCommentId'] == null).toList();

        if (rootComments.isEmpty) return const Padding(padding: EdgeInsets.all(40.0), child: Center(child: Text("Chưa có bình luận nào.", style: TextStyle(fontFamily: 'Encode Sans Expanded', color: Colors.grey))));

        return Column(children: rootComments.map((comment) => _buildCommentTree(comment, allComments)).toList());
      },
    );
  }

  Widget _buildCommentTree(Map<String, dynamic> comment, List<Map<String, dynamic>> allComments) {
    var replies = allComments.where((c) => c['parentCommentId'] == comment['id']).toList();
    return Column(children: [
      _buildSingleCommentWidget(comment),
      if (replies.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Column(children: replies.map((reply) => _buildCommentTree(reply, allComments)).toList())
        ),
    ]);
  }

  Widget _buildSingleCommentWidget(Map<String, dynamic> comment) {
    String? avt = comment['authorAvatar'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFF1F2F6),
          // Logic avatar từ URL (userData) hoặc Base64 tùy dữ liệu của bạn
          backgroundImage: (avt != null && avt.isNotEmpty && avt.startsWith('http'))
              ? NetworkImage(avt) : null,
          child: (avt == null || avt.isEmpty)
              ? const Icon(Icons.person, size: 20, color: Colors.grey)
              : (avt.startsWith('http') ? null : ClipOval(child: Image.memory(base64Decode(avt), fit: BoxFit.cover))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF1F2F6), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(comment['authorName'], style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(comment['content'], style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 14, color: Color(0xFF545454))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: GestureDetector(
              onTap: () => setState(() { _replyingToId = comment['id']; _replyingToName = comment['authorName']; }),
              child: const Text("Trả lời", style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 12, color: Color(0xFF777777), fontWeight: FontWeight.bold)),
            ),
          ),
        ]))
      ]),
    );
  }

  Widget _buildCommentInputField() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, 12, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05)))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_replyingToId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: const Color(0xFF5893D8).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Text("Đang trả lời ", style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 12)),
              Text(_replyingToName ?? "", style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5893D8))),
              const Spacer(),
              GestureDetector(onTap: () => setState(() { _replyingToId = null; _replyingToName = null; }), child: const Icon(Icons.close, size: 16, color: Colors.grey))
            ]),
          ),
        Row(children: [
          Expanded(child: TextField(
              controller: _commentController,
              style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 14),
              decoration: InputDecoration(
                  hintText: "Viết bình luận...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  filled: true, fillColor: const Color(0xFFF1F2F6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)))),
          const SizedBox(width: 8),
          CircleAvatar(radius: 22, backgroundColor: const Color(0xFF5893D8), child: IconButton(onPressed: _addComment, icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20)))
        ]),
      ]),
    );
  }
}