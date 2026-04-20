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

  String _getCollectionPath(Map<String, dynamic> data) {
    if (data.containsKey('link')) return 'official_news';
    if (data.containsKey('rating')) return 'course_reviews';
    if (data.containsKey('fileData')) return 'study_materials';
    return 'forum_posts';
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

  // --- HÀM ĐIỀU HƯỚNG ĐÃ CẬP NHẬT (CHÍNH XÁC COLLECTION & XÓA LỖI) ---
  void _navigateToDetail(Map<String, dynamic> data, String savedDocId) async {
    String originalId = data['originalDocId'] ?? savedDocId;
    // Tự động nhận diện collection dựa trên data để đi đúng đường
    String collectionPath = _getCollectionPath(data);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      DocumentSnapshot originalDoc = await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(originalId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;
      Navigator.pop(context); // Tắt loading

      if (originalDoc.exists) {
        Map<String, dynamic> currentData = originalDoc.data() as Map<String, dynamic>;

        if (currentData['status'] == 'hidden') {
          _showUnavailableMessage(savedDocId);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(docId: originalId, initialPostData: currentData),
            ),
          );
        }
      } else {
        _showUnavailableMessage(savedDocId);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showUnavailableMessage(savedDocId);
    }
  }

  void _showUnavailableMessage(String savedDocId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Thông báo", style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold)),
        content: const Text("Bài viết này không còn tồn tại hoặc đã bị gỡ bỏ. Bạn có muốn xóa bản lưu này không?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Đóng", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeSave(savedDocId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Đã gỡ bản lưu không còn khả dụng."))
                );
              }
            },
            child: const Text("Xóa bản lưu", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white70 : const Color(0xFF545454)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
            "Bài đã lưu",
            style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF545454)
            )
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F0F0),
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
              unselectedLabelColor: isDarkMode ? Colors.white38 : const Color(0xFF777777),
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

            if (data.containsKey('department')) {
              return GestureDetector(
                onTap: () => _navigateToDetail(data, docId),
                child: _buildOfficialCard(data, docId),
              );
            }
            if (data.containsKey('authorName') && !data.containsKey('rating') && !data.containsKey('fileData')) {
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : const Color(0xFFDFE6E9), width: 1))
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: Colors.white, child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['department'] ?? 'HCMUS News', style: TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w600, fontSize: 14, color: isDarkMode ? Colors.white : const Color(0xFF545454))),
            Text(data['date'] ?? '', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 12, color: Color(0xFF777777))),
          ])),
          IconButton(icon: const Icon(Icons.bookmark, color: Color(0xFFFFCB45)), onPressed: () => _removeSave(docId)),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(data['title'] ?? '', style: TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w600, fontSize: 15, color: isDarkMode ? Colors.white : const Color(0xFF545454), height: 1.3)),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String? avatarData = data['authorAvatar'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : const Color(0xFFDFE6E9), width: 1))
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20, backgroundColor: isDarkMode ? Colors.white10 : const Color(0xFFF0F0F0),
            backgroundImage: (avatarData != null && avatarData.isNotEmpty) ? MemoryImage(base64Decode(avatarData)) : null,
            child: (avatarData == null || avatarData.isEmpty) ? const Icon(Icons.person, color: Colors.grey) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['authorName'] ?? 'Sinh viên ẩn danh', style: TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w600, fontSize: 14, color: isDarkMode ? Colors.white : const Color(0xFF545454))),
            Text(data['timestamp'] != null ? timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'vi') : 'Vừa xong', style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 12, color: Color(0xFF777777))),
          ])),
          IconButton(icon: const Icon(Icons.bookmark, color: Color(0xFFFFCB45)), onPressed: () => _removeSave(docId)),
        ]),
        if (data['hashtags'] != null) Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(spacing: 8, children: (data['hashtags'] as List).map((tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: isDarkMode ? Colors.white10 : const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(16)),
            child: Text('#$tag', style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 10, color: isDarkMode ? Colors.white70 : Colors.black, fontWeight: FontWeight.bold)),
          )).toList()),
        ),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(data['content'] ?? '', style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: isDarkMode ? Colors.white70 : const Color(0xFF545454), height: 1.4))),
        if (data['imageUrl'] != null) Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(data['imageUrl']), width: double.infinity, height: 180, fit: BoxFit.cover)),
        ),
      ]),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> data, String docId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white10 : const Color(0xFFDFE6E9), width: 2))
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['courseName'] ?? '', style: TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w700, fontSize: 16, color: isDarkMode ? Colors.white : const Color(0xFF545454))),
            const SizedBox(height: 4),
            Text("Giảng viên: ${data['teacherName'] ?? ''}", style: TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w300, fontSize: 14, color: isDarkMode ? Colors.white70 : const Color(0xFF545454))),
            Text(data['semester'] ?? '', style: TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w300, fontSize: 14, color: isDarkMode ? Colors.white60 : const Color(0xFF545454))),
          ])),
          IconButton(icon: const Icon(Icons.bookmark, color: Color(0xFFFFCB45)), onPressed: () => _removeSave(docId)),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: List.generate(5, (i) => Icon(i < (data['rating'] ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFFFCB45), size: 22))),
        ),
        Text(data['content'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: isDarkMode ? Colors.white70 : const Color(0xFF545454), height: 1.33)),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> data, String docId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String? fileData = data['fileData'];
    String? fileName = data['fileName'];
    bool isImage = data['isImage'] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white10 : const Color(0xFFDFE6E9), width: 2))
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['courseName'] ?? 'Tài liệu', style: TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w700, fontSize: 16, color: isDarkMode ? Colors.white : const Color(0xFF545454))),
            const SizedBox(height: 4),
            Text("Giảng viên: ${data['teacherName'] ?? ''}", style: TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w300, fontSize: 14, color: isDarkMode ? Colors.white70 : const Color(0xFF545454))),
          ])),
          IconButton(icon: const Icon(Icons.bookmark, color: Color(0xFFFFCB45)), onPressed: () => _removeSave(docId)),
        ]),
        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(data['content'] ?? '', style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: isDarkMode ? Colors.white70 : const Color(0xFF545454), height: 1.33))),
        if (fileData != null) GestureDetector(
          onTap: () => _handleOpenFile(context, fileData, fileName ?? 'document'),
          child: isImage
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(fileData), width: double.infinity, height: 180, fit: BoxFit.cover))
              : Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDarkMode ? Colors.white12 : const Color(0xFFDFE6E9))
            ),
            child: Row(children: [
              const Icon(Icons.description_rounded, color: Color(0xFF5893D8), size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text(fileName ?? 'Tài liệu', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w500, fontSize: 14, color: isDarkMode ? Colors.white : const Color(0xFF545454)))),
              const Icon(Icons.file_download_outlined, color: Color(0xFF777777)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.bookmark_border, size: 100, color: isDarkMode ? Colors.white10 : const Color(0xFFDFE6E9)),
        const SizedBox(height: 20),
        Text("Danh sách lưu trống!", style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white38 : const Color(0xFF545454))),
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