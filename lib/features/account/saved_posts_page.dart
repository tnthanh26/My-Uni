import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;

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

  // --- REUSE LOGIC FROM YOUR TABS ---
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Bài đã lưu", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : Colors.grey[200],
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: const Color(0xFF6797E1).withOpacity(0.2),
              ),
              labelColor: const Color(0xFF6797E1),
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
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
          _buildSavedList("general", isDarkMode),
          _buildSavedList("course", isDarkMode),
        ],
      ),
    );
  }

  Widget _buildSavedList(String type, bool isDarkMode) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(user?.uid)
          .collection('saved_posts')
          .where('saveType', isEqualTo: type)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String docId = docs[index].id;

            // PHÂN LOẠI ĐÚNG UI THEO NGUỒN GỐC
            if (data.containsKey('department')) return _buildOfficialCard(data, docId, isDarkMode);
            if (data.containsKey('authorName')) return _buildForumCard(data, docId, isDarkMode);
            if (data.containsKey('rating')) return _buildReviewCard(data, docId, isDarkMode);
            if (data.containsKey('fileData')) return _buildMaterialCard(data, docId, isDarkMode);

            return const SizedBox();
          },
        );
      },
    );
  }

  // --- 1. OFFICIAL CARD ---
  Widget _buildOfficialCard(Map<String, dynamic> data, String docId, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFF6797E1), child: Icon(Icons.school, color: Colors.white, size: 20)),
          title: Text(data['department'] ?? 'Thông báo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(data['date'] ?? '', style: const TextStyle(fontSize: 12)),
          trailing: IconButton(icon: const Icon(Icons.bookmark, color: Colors.amber), onPressed: () => _removeSave(docId)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(data['summary'] ?? '', maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[800], height: 1.4)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/images/news.png', width: double.infinity, height: 180, fit: BoxFit.cover)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _launchURL(data['link'] ?? ''),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), side: BorderSide(color: const Color(0xFF6797E1))),
              child: const Text('Xem chi tiết bài viết', style: TextStyle(color: Color(0xFF6797E1), fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]),
    );
  }

  // --- 2. FORUM CARD ---
  Widget _buildForumCard(Map<String, dynamic> data, String docId, bool isDark) {
    String? avatarData = data['authorAvatar'];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.orangeAccent.withOpacity(0.2),
            backgroundImage: (avatarData != null && avatarData.isNotEmpty) ? MemoryImage(base64Decode(avatarData)) : null,
            child: (avatarData == null || avatarData.isEmpty) ? const Icon(Icons.person, color: Colors.orange) : null,
          ),
          title: Text(data['authorName'] ?? 'Sinh viên ẩn danh', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(data['timestamp'] != null ? timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'vi') : 'Vừa xong', style: const TextStyle(fontSize: 12)),
          trailing: IconButton(icon: const Icon(Icons.bookmark, color: Colors.amber), onPressed: () => _removeSave(docId)),
        ),
        if (data['hashtags'] != null) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(spacing: 8, runSpacing: 4, children: (data['hashtags'] as List).map((tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF6797E1).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text('#$tag', style: const TextStyle(color: Color(0xFF6797E1), fontSize: 12, fontWeight: FontWeight.w600)),
          )).toList()),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: Text(data['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5))),
        if (data['imageUrl'] != null) Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(data['imageUrl']), width: double.infinity, fit: BoxFit.cover)),
        ),
      ]),
    );
  }

  // --- 3. REVIEW CARD ---
  Widget _buildReviewCard(Map<String, dynamic> data, String docId, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['courseName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(data['semester'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text("Giảng viên: ${data['teacherName'] ?? ''}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          IconButton(icon: const Icon(Icons.bookmark, color: Colors.amber), onPressed: () => _removeSave(docId)),
        ]),
        const SizedBox(height: 8),
        Row(children: List.generate(5, (i) => Icon(i < (data['rating'] ?? 0) ? Icons.star : Icons.star_border, color: Colors.amber, size: 18))),
        const SizedBox(height: 12),
        Text(data['content'] ?? '', style: const TextStyle(height: 1.4)),
        const Divider(),
        const Row(children: [Icon(Icons.favorite_border, color: Colors.grey, size: 20), SizedBox(width: 4), Text("96", style: TextStyle(color: Colors.grey))]),
      ]),
    );
  }

  // --- 4. MATERIAL CARD ---
  Widget _buildMaterialCard(Map<String, dynamic> data, String docId, bool isDark) {
    String? fileData = data['fileData'];
    String? fileName = data['fileName'];
    bool isImage = data['isImage'] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['courseName'] ?? 'Tài liệu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(data['semester'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text("Giảng viên: ${data['teacherName'] ?? ''}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          IconButton(icon: const Icon(Icons.bookmark, color: Colors.amber), onPressed: () => _removeSave(docId)),
        ]),
        const SizedBox(height: 12),
        Text(data['content'] ?? '', style: const TextStyle(height: 1.4)),
        const SizedBox(height: 12),
        if (fileData != null) GestureDetector(
          onTap: () => _handleOpenFile(context, fileData, fileName ?? 'document'),
          child: isImage
              ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(fileData), width: double.infinity, fit: BoxFit.cover))
              : Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.withOpacity(0.2))),
            child: Row(children: [
              const Icon(Icons.insert_drive_file, color: Color(0xFF6797E1), size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(fileName ?? 'Tài liệu đính kèm', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
              const Icon(Icons.file_download_outlined, color: Colors.grey, size: 20),
            ]),
          ),
        ),
        const Divider(),
        const Row(children: [Icon(Icons.favorite_border, color: Colors.grey, size: 20), SizedBox(width: 4), Text("96", style: TextStyle(color: Colors.grey))]),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_border, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            const Text("Danh sách lưu trống!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6797E1), minimumSize: const Size(200, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
              child: const Text("Về trang chủ", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}