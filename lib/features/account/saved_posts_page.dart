import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:my_uni/features/home/post_detail_page.dart';

class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    timeago.setLocaleMessages('vi', timeago.ViMessages());
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  }

  Future<void> _handleOpenFile(BuildContext context, String base64Data, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(base64Decode(base64Data));
      await OpenFilex.open(filePath);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    }
  }

  Future<void> _removeSave(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('saved_posts').doc(docId).delete();
  }

  void _navigateToDetail(Map<String, dynamic> data, String docId) {
    String originalId = data['originalDocId'] ?? docId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(docId: originalId, initialPostData: data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF545454)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
            "Bài đã lưu",
            style: TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.bold, color: Color(0xFF545454))
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: const Color(0xFF5893D8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF777777),
              labelStyle: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: "Diễn đàn chung"),
                Tab(text: "Khóa học"),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSavedList("general"),
          _buildSavedList("course"),
        ],
      ),
    );
  }

  Widget _buildSavedList(String type) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(user?.uid)
          .collection('saved_posts')
          .where('saveType', isEqualTo: type)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF5893D8)));
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String docId = docs[index].id;

            // FIX: Bọc GestureDetector cho từng loại Card để điều hướng
            if (data.containsKey('department')) {
              return GestureDetector(
                onTap: () => _navigateToDetail(data, docId),
                child: _buildOfficialCard(data, docId),
              );
            }
            if (data.containsKey('authorName')) {
              return GestureDetector(
                onTap: () => _navigateToDetail(data, docId),
                child: _buildForumCard(data, docId),
              );
            }
            if (data.containsKey('rating')) {
              return GestureDetector(
                onTap: () => _navigateToDetail(data, docId),
                child: _buildReviewCard(data, docId),
              );
            }
            if (data.containsKey('fileData')) {
              return GestureDetector(
                onTap: () => _navigateToDetail(data, docId),
                child: _buildMaterialCard(data, docId),
              );
            }

            return const SizedBox();
          },
        );
      },
    );
  }

  Widget _buildOfficialCard(Map<String, dynamic> data, String docId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDFE6E9), width: 1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: Colors.white, child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['department'] ?? 'HCMUS News', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF545454))),
            Text(data['date'] ?? '', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 12, color: Color(0xFF777777))),
          ])),
          IconButton(icon: const Icon(Icons.bookmark, color: Color(0xFFFFCB45)), onPressed: () => _removeSave(docId)),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(data['title'] ?? '', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF545454), height: 1.3)),
        ),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/images/news.png', width: double.infinity, height: 180, fit: BoxFit.cover)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SizedBox(
            width: double.infinity, height: 40,
            child: OutlinedButton(
              onPressed: () => _launchURL(data['link'] ?? ''),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF5893D8)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Xem chi tiết bài viết', style: TextStyle(color: Color(0xFF5893D8), fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildForumCard(Map<String, dynamic> data, String docId) {
    String? avatarData = data['authorAvatar'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDFE6E9), width: 1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20, backgroundColor: const Color(0xFFF0F0F0),
            backgroundImage: (avatarData != null && avatarData.isNotEmpty) ? MemoryImage(base64Decode(avatarData)) : null,
            child: (avatarData == null || avatarData.isEmpty) ? const Icon(Icons.person, color: Colors.grey) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['authorName'] ?? 'Sinh viên ẩn danh', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF545454))),
            Text(data['timestamp'] != null ? timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'vi') : 'Vừa xong', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 12, color: Color(0xFF777777))),
          ])),
          IconButton(icon: const Icon(Icons.bookmark, color: Color(0xFFFFCB45)), onPressed: () => _removeSave(docId)),
        ]),
        if (data['hashtags'] != null) Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(spacing: 8, children: (data['hashtags'] as List).map((tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(16)),
            child: Text('#$tag', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 10, color: Colors.black)),
          )).toList()),
        ),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(data['content'] ?? '', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: Color(0xFF545454), height: 1.4))),
        if (data['imageUrl'] != null) Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(data['imageUrl']), width: double.infinity, height: 180, fit: BoxFit.cover)),
        ),
      ]),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> data, String docId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDFE6E9), width: 2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['courseName'] ?? '', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF545454))),
            const SizedBox(height: 4),
            Text("Giảng viên: ${data['teacherName'] ?? ''}", style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w300, fontSize: 14, color: Color(0xFF545454))),
            Text(data['semester'] ?? '', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w300, fontSize: 14, color: Color(0xFF545454))),
          ])),
          IconButton(icon: const Icon(Icons.bookmark, color: Color(0xFFFFCB45)), onPressed: () => _removeSave(docId)),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: List.generate(5, (i) => Icon(i < (data['rating'] ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFFFCB45), size: 22))),
        ),
        Text(data['content'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: Color(0xFF545454), height: 1.33)),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> data, String docId) {
    String? fileData = data['fileData'];
    String? fileName = data['fileName'];
    bool isImage = data['isImage'] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDFE6E9), width: 2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['courseName'] ?? 'Tài liệu', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF545454))),
            const SizedBox(height: 4),
            Text("Giảng viên: ${data['teacherName'] ?? ''}", style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w300, fontSize: 14, color: Color(0xFF545454))),
          ])),
          IconButton(icon: const Icon(Icons.bookmark, color: Color(0xFFFFCB45)), onPressed: () => _removeSave(docId)),
        ]),
        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(data['content'] ?? '', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: Color(0xFF545454), height: 1.33))),
        if (fileData != null) GestureDetector(
          onTap: () => _handleOpenFile(context, fileData, fileName ?? 'document'),
          child: isImage
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(fileData), width: double.infinity, height: 180, fit: BoxFit.cover))
              : Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDFE6E9))),
            child: Row(children: [
              const Icon(Icons.description_rounded, color: Color(0xFF5893D8), size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text(fileName ?? 'Tài liệu', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF545454)))),
              const Icon(Icons.file_download_outlined, color: Color(0xFF777777)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.bookmark_border, size: 100, color: Color(0xFFDFE6E9)),
        const SizedBox(height: 20),
        const Text("Danh sách lưu trống!", style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF545454))),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5893D8), minimumSize: const Size(200, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), elevation: 0),
          child: const Text("Về trang chủ", style: TextStyle(fontFamily: 'Encode Sans Expanded', color: Colors.white, fontWeight: FontWeight.bold)),
        )
      ]),
    );
  }
}