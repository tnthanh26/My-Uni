import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_uni/features/home/create_post_page.dart';
import 'package:my_uni/features/home/create_material_page.dart';
import 'package:my_uni/features/home/post_detail_page.dart';
import 'package:timeago/timeago.dart' as timeago;

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          "Bài đăng của tôi",
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontWeight: FontWeight.bold,
            color: Color(0xFF545454),
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F6), // Nền xám nhạt
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: const Color(0xFF5893D8), // Màu xanh MyUni
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF777777),
                labelStyle: const TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: "Diễn đàn"),
                  Tab(text: "Tài liệu"),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostList('forum_posts'),
          _buildPostList('study_materials'),
        ],
      ),
    );
  }

  Widget _buildPostList(String collectionPath) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionPath)
          .where('authorId', isEqualTo: user?.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF5893D8)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(context, collectionPath);
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildDetailedItem(context, doc.id, data, collectionPath, doc.reference);
          },
        );
      },
    );
  }

  Widget _buildDetailedItem(BuildContext context, String docId, Map<String, dynamic> data, String collectionPath, DocumentReference ref) {
    String? avatarData = data['authorAvatar'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFDFE6E9), width: 1)),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(docId: docId, initialPostData: data),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22.5,
                    backgroundColor: const Color(0xFFF0F0F0),
                    backgroundImage: (avatarData != null && avatarData.isNotEmpty)
                        ? MemoryImage(base64Decode(avatarData)) : null,
                    child: (avatarData == null || avatarData.isEmpty)
                        ? const Icon(Icons.person, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collectionPath == 'forum_posts' ? "Bạn" : (data['courseName'] ?? "Tài liệu"),
                          style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF545454)),
                        ),
                        Text(
                          data['timestamp'] != null
                              ? timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'vi')
                              : 'Vừa xong',
                          style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 12, color: Color(0xFF777777)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (collectionPath == 'forum_posts' && data['hashtags'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  children: (data['hashtags'] as List).map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(16)),
                    child: Text("#$tag", style: const TextStyle(fontSize: 10, color: Color(0xFF344054), fontWeight: FontWeight.bold)),
                  )).toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                data['content'] ?? (collectionPath == 'study_materials' ? (data['fileName'] ?? 'Tài liệu không tên') : ''),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: Color(0xFF545454), height: 1.4),
              ),
            ),
            if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty)
              _buildImagePreview(data['imageUrl']),
            if (collectionPath == 'study_materials' && data['isImage'] == true && data['fileData'] != null)
              _buildImagePreview(data['fileData']),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.favorite_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text("${data['likeCount'] ?? 0}"),
                  const SizedBox(width: 15),
                  const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF777777)),
                  const SizedBox(width: 4),
                  Text("${data['commentCount'] ?? 0}"),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF5893D8), size: 24),
                    onPressed: () => _navigateToEdit(context, collectionPath, docId, data),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6C6C), size: 24),
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(String base64Str) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(base64Decode(base64Str), width: double.infinity, height: 180, fit: BoxFit.cover),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, String collection, String docId, Map<String, dynamic> data) {
    Widget targetPage;
    if (collection == 'study_materials') {
      targetPage = CreateMaterialPage(docId: docId, existingData: data);
    } else {
      targetPage = CreatePostPage(docId: docId, existingData: data);
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => targetPage));
  }

  Widget _buildEmptyState(BuildContext context, String collectionPath) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text("Bạn chưa có bài đăng nào ở mục này!", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, DocumentReference ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xóa bài viết?"),
        content: const Text("Hành động này sẽ xóa vĩnh viễn dữ liệu."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              await ref.delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}