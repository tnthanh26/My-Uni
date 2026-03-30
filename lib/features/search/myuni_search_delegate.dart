import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// 1. Enum để phân loại Tab và quản lý Search Scope
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

  // == GIAO DIỆN APPBAR ACTIONS ==
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
      IconButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chức năng sắp xếp đang phát triển'))),
        icon: const Icon(Icons.swap_vert),
      ),
      const SizedBox(width: 8),
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
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('Lỗi kết nối: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return _buildNoResult(context);
        return _buildResultList(context, snapshot.data!);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) return _buildInitialMessage(context);
    return buildResults(context);
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black54),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
        border: InputBorder.none,
      ),
    );
  }

  // ==============================
  // 2. LOGIC GỌI API BACKEND (ĐÃ UPDATE ĐÚNG DATA)
  // ==============================
  Future<List<dynamic>> _performSemanticSearch(String query, SearchScope scope) async {
    final String scopeString = scope.toString().split('.').last;
    final url = Uri.parse('http://10.0.2.2:8000/search?query=$query&scope=$scopeString');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> apiData = jsonDecode(utf8.decode(response.bodyBytes));
        return apiData.map((item) {
          final meta = item['metadata'] ?? {};
          return {
            'type': scopeString,
            'id': item['id'],
            'title': item['title'] ?? '',
            'content': item['content'] ?? '',
            'author': item['author'] ?? '',
            'sub_info': item['sub_info'] ?? '',
            'likes': meta['likes'] ?? 0,
            'comments': meta['comments'] ?? 0,
            'rating': (meta['rating'] ?? 5).toDouble(),
          };
        }).toList();
      }
    } catch (e) {
      print('Lỗi gọi API: $e');
    }
    return [];
  }

  // ==============================
  // 3. XÂY DỰNG DANH SÁCH UI
  // ==============================
  Widget _buildResultList(BuildContext context, List<dynamic> results) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: results.length,
        separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = results[index];
          final type = item['type'];

          if (type == 'forum') return _buildPostItem(context, item);
          if (type == 'review') return _buildCourseReviewItem(context, item);
          if (type == 'official') return _buildOfficialItem(context, item);
          if (type == 'material') return _buildMaterialItem(context, item);
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // --- A. GIAO DIỆN FORUM ---
  Widget _buildPostItem(BuildContext context, Map<String, dynamic> data) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.black.withOpacity(0.05))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(
                  backgroundColor: Color(0xFFE0E0E0),
                  radius: 18,
                  child: Icon(Icons.person, color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['author'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(data['sub_info'], style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ]),
              const Spacer(),
              const Icon(Icons.more_horiz, color: Colors.grey),
            ]),
            const SizedBox(height: 12),
            const Wrap(spacing: 8, children: [
              _TagWidget(label: '#HỏiĐáp', color: Color(0xFFEDF2F9)),
              _TagWidget(label: '#AI', color: Color(0xFFEDF2F9)),
            ]),
            const SizedBox(height: 10),
            Text(data['content'],
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
            const SizedBox(height: 16),
            // UPDATE: Truyền likes/comments thật từ Firebase
            _buildPostActions(data['likes'], data['comments'], false),
          ],
        ),
      ),
    );
  }

  // --- B. GIAO DIỆN REVIEW (LẤY DATA THẬT) ---
  Widget _buildCourseReviewItem(BuildContext context, Map<String, dynamic> data) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.black.withOpacity(0.05))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Text(data['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF003366))),
              ),
              const Icon(Icons.more_vert, color: Colors.grey, size: 20),
            ]),
            Text('${data['sub_info']} • GV: ${data['author']}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            _buildRatingStars(data['rating']),
            const SizedBox(height: 12),
            Text(data['content'],
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: () {},
                  child: const Text('Xem thêm', style: TextStyle(color: Color(0xFF6797E1)))),
            ),
            const Divider(),
            // UPDATE: Truyền likes/comments thật
            _buildPostActions(data['likes'], data['comments'], false),
          ],
        ),
      ),
    );
  }

  // --- C. GIAO DIỆN OFFICIAL (LẤY DATA THẬT) ---
  Widget _buildOfficialItem(BuildContext context, Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD0E3FF)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
            backgroundColor: Color(0xFF6797E1),
            child: Icon(Icons.campaign, color: Colors.white)),
        title: Text(data['title'],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF003366))),
        subtitle: Text('Từ: ${data['author']}\nNgày: ${data['sub_info']}',
            style: const TextStyle(fontSize: 12, height: 1.5)),
        isThreeLine: true,
      ),
    );
  }

  // --- D. GIAO DIỆN MATERIAL (LẤY DATA THẬT) ---
  Widget _buildMaterialItem(BuildContext context, Map<String, dynamic> data) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 30),
        ),
        title: Text(data['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('GV hướng dẫn: ${data['author']}\n${data['content']}',
            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.download_for_offline, color: Color(0xFF6797E1), size: 28),
        onTap: () {},
      ),
    );
  }

  // ==============================
  // 4. CÁC HELPER WIDGETS
  // ==============================
  Widget _buildPostActions(int likes, int comments, bool saved) {
    return Row(
      children: [
        _ActionBtn(icon: Icons.favorite_border, label: '$likes', color: Colors.redAccent),
        const SizedBox(width: 20),
        _ActionBtn(icon: Icons.chat_bubble_outline, label: '$comments', color: Colors.blueAccent),
        const Spacer(),
        Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: Colors.grey, size: 20),
      ],
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
        children: List.generate(5, (index) => Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber, size: 18)));
  }

  Widget _buildInitialMessage(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_rounded, size: 80, color: Colors.grey.shade200),
      const SizedBox(height: 16),
      const Text('MyUni Semantic Search', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      const Text('Tìm kiếm thông minh theo ý nghĩa bài viết', style: TextStyle(color: Colors.grey, fontSize: 12)),
    ]),
  );

  Widget _buildNoResult(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.sentiment_dissatisfied, size: 80, color: Colors.orangeAccent),
      const SizedBox(height: 16),
      Text('Không tìm thấy kết quả cho "$query"', style: const TextStyle(fontWeight: FontWeight.bold)),
      const Text('Hãy thử diễn đạt theo cách khác nhé!', style: TextStyle(color: Colors.grey)),
    ]),
  );
}

// Sub-widgets hỗ trợ để code gọn hơn
class _TagWidget extends StatelessWidget {
  final String label;
  final Color color;
  const _TagWidget({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(color: Color(0xFF6797E1), fontSize: 11, fontWeight: FontWeight.bold)),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ActionBtn({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: Colors.grey, size: 18),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
  ]);
}