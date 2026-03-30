import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../home/post_detail_page.dart';

enum SearchScope { official, forum, review, material }

class MyUniSearchDelegate extends SearchDelegate<String> {
  final SearchScope currentScope;

  MyUniSearchDelegate({required this.currentScope})
      : super(
    searchFieldLabel: _getSearchLabel(currentScope),
    keyboardType: TextInputType.text,
  );

  static String _getSearchLabel(SearchScope scope) {
    switch (scope) {
      case SearchScope.official: return 'Tìm thông tin chính thức...';
      case SearchScope.forum: return 'Bạn muốn biết điều gì quanh trường?';
      case SearchScope.review: return 'Bạn muốn biết đánh giá môn học nào?';
      case SearchScope.material: return 'Tìm tài liệu tham khảo...';
    }
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, ''),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) return _buildInitialMessage(context);
    return FutureBuilder<List<dynamic>>(
      future: _performSemanticSearch(query, currentScope),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6797E1)));
        if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildNoResult(context);
        return _buildResultList(context, snapshot.data!);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);

  // ==============================
  // LOGIC GỌI API & MAPPING DATA
  // ==============================
  Future<List<dynamic>> _performSemanticSearch(String query, SearchScope scope) async {
    final String scopeString = scope.toString().split('.').last;
    final url = Uri.parse('http://10.0.2.2:8000/search?query=$query&scope=$scopeString');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      debugPrint('Search API Error: $e');
    }
    return [];
  }

  Widget _buildResultList(BuildContext context, List<dynamic> results) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: results.length,
        separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = results[index];
          final String docId = item['id'];
          final Map<String, dynamic> data = item['data'];
          final String scope = data['scope'] ?? '';

          // Hàm điều hướng
          void openDetail() {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(docId: docId, initialPostData: data),
              ),
            );
          }

          // Trả về UI dựa trên loại bài viết
          if (scope == 'forum_posts') return _buildForumItem(context, data, openDetail);
          if (scope == 'course_reviews') return _buildReviewItem(context, data, openDetail);
          if (scope == 'official_news') return _buildOfficialItem(context, data, openDetail);
          if (scope == 'study_materials') return _buildMaterialItem(context, data, openDetail);
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // --- GIAO DIỆN CHI TIẾT TỪNG LOẠI (KHÔI PHỤC BẢN CŨ) ---

  Widget _buildForumItem(BuildContext context, Map<String, dynamic> data, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.black.withOpacity(0.05))),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (data['authorAvatar'] != null && data['authorAvatar'] != "") ? MemoryImage(base64Decode(data['authorAvatar'])) : null,
                  child: (data['authorAvatar'] == null || data['authorAvatar'] == "") ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['authorName'] ?? 'Vô danh', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text("Vừa xong", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ]),
              ]),
              const SizedBox(height: 12),
              Text(data['content'] ?? '', maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.4)),
              const SizedBox(height: 12),
              _buildPostActions(data['likeCount'] ?? 0, data['commentCount'] ?? 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(BuildContext context, Map<String, dynamic> data, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.black.withOpacity(0.05))),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['courseName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF003366))),
              Text('GV: ${data['authorName']} • ${data['semester']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              _buildRatingStars((data['rating'] ?? 5).toDouble()),
              const SizedBox(height: 10),
              Text(data['content'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
              const Divider(),
              _buildPostActions(data['likeCount'] ?? 0, data['commentCount'] ?? 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialItem(BuildContext context, Map<String, dynamic> data, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFD0E3FF))),
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFF6797E1), child: Icon(Icons.campaign, color: Colors.white)),
          title: Text(data['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text('Từ: ${data['authorName']}\nNgày: ${data['date']}', style: const TextStyle(fontSize: 11)),
          isThreeLine: true,
        ),
      ),
    );
  }

  Widget _buildMaterialItem(BuildContext context, Map<String, dynamic> data, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 30),
          ),
          title: Text(data['courseName'] ?? 'Tài liệu', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Tệp: ${data['fileName']}', style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.download_for_offline, color: Color(0xFF6797E1)),
        ),
      ),
    );
  }

  // ==============================
  // HELPERS
  // ==============================
  Widget _buildPostActions(int likes, int comments) {
    return Row(
      children: [
        Row(children: [const Icon(Icons.favorite_border, size: 18, color: Colors.grey), const SizedBox(width: 5), Text('$likes', style: const TextStyle(color: Colors.grey))]),
        const SizedBox(width: 20),
        Row(children: [const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey), const SizedBox(width: 5), Text('$comments', style: const TextStyle(color: Colors.grey))]),
      ],
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(children: List.generate(5, (index) => Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 18)));
  }

  Widget _buildInitialMessage(BuildContext context) => const Center(child: Text('Tìm kiếm thông minh MyUni...'));
  Widget _buildNoResult(BuildContext context) => const Center(child: Text('Không tìm thấy kết quả.'));
}