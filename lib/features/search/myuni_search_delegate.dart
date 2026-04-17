import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/post_detail_page.dart';
import 'course_review_list_page.dart';

enum SearchScope { official, forum, review, material }

class MyUniSearchDelegate extends SearchDelegate<String> {
  final SearchScope currentScope;

  final ValueNotifier<int> _refreshTrigger = ValueNotifier<int>(0);

  List<String> selectedHashtags = ['Tất cả'];
  String currentSort = 'relevance';

  final List<String> availableHashtags = [
    'Tất cả', 'Hỏi đáp', 'Quân sự', 'Học phí', 'Tìm đồ', 'Chia sẻ', 'Tìm việc'
  ];

  MyUniSearchDelegate({required this.currentScope}) : super(
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

  // Ghi đè theme cho thanh SearchBar phía trên
  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : Colors.grey),
        border: InputBorder.none,
      ),
    );
  }

  void _forceRefresh(BuildContext context) {
    _refreshTrigger.value++;
    query = query;
    showResults(context);
  }

  String _formatTimestamp(int? seconds) {
    if (seconds == null) return "Vừa xong";
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return [
      if (query.isNotEmpty)
        IconButton(onPressed: () => query = '', icon: Icon(Icons.clear, color: isDarkMode ? Colors.white70 : Colors.black54)),

      PopupMenuButton<String>(
        icon: const Icon(Icons.sort_rounded, color: Color(0xFF6797E1)),
        onSelected: (String value) {
          currentSort = value;
          _forceRefresh(context);
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'relevance',
            child: ListTile(
              leading: Icon(Icons.auto_awesome_outlined, color: currentSort == 'relevance' ? Colors.blue : Colors.grey),
              title: Text('Độ liên quan', style: TextStyle(color: currentSort == 'relevance' ? Colors.blue : (isDarkMode ? Colors.white : Colors.black))),
              trailing: currentSort == 'relevance' ? const Icon(Icons.check, color: Colors.blue) : null,
            ),
          ),
          PopupMenuItem<String>(
            value: 'desc',
            child: ListTile(
              leading: Icon(Icons.new_releases_outlined, color: currentSort == 'desc' ? Colors.blue : Colors.grey),
              title: Text('Mới nhất', style: TextStyle(color: currentSort == 'desc' ? Colors.blue : (isDarkMode ? Colors.white : Colors.black))),
              trailing: currentSort == 'desc' ? const Icon(Icons.check, color: Colors.blue) : null,
            ),
          ),
          PopupMenuItem<String>(
            value: 'asc',
            child: ListTile(
              leading: Icon(Icons.history_outlined, color: currentSort == 'asc' ? Colors.blue : Colors.grey),
              title: Text('Cũ nhất', style: TextStyle(color: currentSort == 'asc' ? Colors.blue : (isDarkMode ? Colors.white : Colors.black))),
              trailing: currentSort == 'asc' ? const Icon(Icons.check, color: Colors.blue) : null,
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, ''),
    icon: Icon(Icons.arrow_back, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
  );

  Widget _buildFilterBar(StateSetter setState, BuildContext context) {
    if (currentScope != SearchScope.forum) return const SizedBox.shrink();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: availableHashtags.map((tag) {
            bool isSelected = selectedHashtags.contains(tag);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(tag == 'Tất cả' ? tag : '# $tag'),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black54),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF6797E1),
                backgroundColor: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (selected) {
                  setState(() {
                    if (tag == 'Tất cả') {
                      selectedHashtags = ['Tất cả'];
                    } else {
                      selectedHashtags.remove('Tất cả');
                      if (selected) {
                        selectedHashtags.add(tag.trim());
                      } else {
                        selectedHashtags.remove(tag.trim());
                        if (selectedHashtags.isEmpty) selectedHashtags = ['Tất cả'];
                      }
                    }
                  });
                  _forceRefresh(context);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (query.trim().isEmpty) {
      return Container(
        color: isDarkMode ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
        child: const Center(
            child: Text('Nhập từ khóa để bắt đầu tìm kiếm',
                style: TextStyle(color: Colors.grey))
        ),
      );
    }

    return Container(
      color: isDarkMode ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
      child: ValueListenableBuilder<int>(
          valueListenable: _refreshTrigger,
          builder: (context, trigger, _) {
            return StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    if (currentScope == SearchScope.forum) _buildFilterBar(setState, context),
                    if (currentScope == SearchScope.forum) Divider(height: 1, thickness: 0.5, color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
                    Expanded(
                      child: FutureBuilder<List<dynamic>>(
                        key: ValueKey('${query}_${selectedHashtags.join()}_${currentSort}_$trigger'),
                        future: _performSemanticSearch(query, currentScope),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF6797E1)));
                          }
                          if (snapshot.hasError) return const Center(child: Text('Lỗi kết nối Server', style: TextStyle(color: Colors.red)));
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Text('Không tìm thấy kết quả', style: TextStyle(color: Colors.grey)));
                          }

                          return _buildResultList(context, snapshot.data!);
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          }
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);

  Future<List<dynamic>> _performSemanticSearch(String query, SearchScope scope) async {
    if (query.trim().isEmpty) return [];

    final String scopeString = scope.toString().split('.').last;
    final String sortOrder = currentSort;

    final cleanQuery = query.trim();
    List<String> activeTags = selectedHashtags.where((t) => t != 'Tất cả').toList();
    String tagParam = activeTags.isEmpty ? '' : activeTags.join(',');

    final uri = Uri.parse('http://10.0.2.2:8000/search').replace(queryParameters: {
      'query': cleanQuery,
      'scope': scopeString,
      'tag': tagParam,
      'sort': sortOrder,
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic>? data = jsonDecode(utf8.decode(response.bodyBytes));
        return data ?? [];
      }
    } catch (e) {
      debugPrint("Lỗi Search: $e");
    }
    return [];
  }

  Widget _buildResultList(BuildContext context, List<dynamic> results) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDarkMode ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8F9FA),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: results.length,
        separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = results[index];
          final String docId = item['id'];
          final Map<String, dynamic> data = Map<String, dynamic>.from(item['data']);

          void openDetail() {
            Map<String, dynamic> processedData = Map.from(data);

            if (processedData.containsKey('timestamp')) {
              var rawTs = processedData['timestamp'];
              if (rawTs is int) {
                processedData['timestamp'] = Timestamp.fromMillisecondsSinceEpoch(rawTs * 1000);
              } else if (rawTs is String) {
                int? parsed = int.tryParse(rawTs);
                processedData['timestamp'] = Timestamp.fromMillisecondsSinceEpoch((parsed ?? 0) * 1000);
              }
            } else {
              processedData['timestamp'] = Timestamp.now();
            }

            var rawHashtags = processedData['hashtags'];
            if (rawHashtags is String) {
              processedData['hashtags'] = rawHashtags.split(',').where((s) => s.trim().isNotEmpty).toList();
            } else if (rawHashtags == null) {
              processedData['hashtags'] = [];
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(
                    docId: docId,
                    initialPostData: processedData
                ),
              ),
            );
          }

          final String scope = data['scope'] ?? '';

          if (scope == 'forum_posts') return _buildForumItem(context, data, openDetail);
          if (scope == 'official_news') return _buildOfficialItem(context, data, openDetail);
          if (scope == 'course_reviews' || scope == 'course_reviews_group') {
            return _buildReviewItem(context, data, openDetail);
          }
          if (scope == 'study_materials') return _buildMaterialItem(context, data, openDetail);

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildForumItem(BuildContext context, Map<String, dynamic> data, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: isDarkMode ? Colors.white10 : const Color(0x0D000000))
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDarkMode ? Colors.white12 : Colors.grey[200],
                  backgroundImage: (data['authorAvatar'] != null && data['authorAvatar'] != "")
                      ? MemoryImage(base64Decode(data['authorAvatar'])) : null,
                  child: (data['authorAvatar'] == null || data['authorAvatar'] == "")
                      ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                      data['authorName'] ?? 'Sinh viên MyUni',
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)
                  ),
                  Text(_formatTimestamp(data['timestamp'] as int?), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ]),
              ]),

              const SizedBox(height: 12),

              if (data['hashtags'] != null && (data['hashtags'] as List).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Wrap(
                    spacing: 8,
                    children: (data['hashtags'] as List).map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white12 : const Color(0xFFF1F2F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "#$tag",
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6797E1)
                        ),
                      ),
                    )).toList(),
                  ),
                ),

              Text(
                  data['content'] ?? '',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, height: 1.4, color: isDarkMode ? Colors.white70 : Colors.black87)
              ),

              if (data['imageUrl'] != null && data['imageUrl'] != "")
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(base64Decode(data['imageUrl']), width: double.infinity, fit: BoxFit.cover),
                  ),
                ),

              const SizedBox(height: 12),
              _buildPostActions(data['likeCount'] ?? 0, data['commentCount'] ?? 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialItem(BuildContext context, Map<String, dynamic> data, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C3E50).withOpacity(0.3) : const Color(0xFFF0F7FF),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isDarkMode ? Colors.white12 : const Color(0xFFD0E3FF))
        ),
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFF6797E1), child: Icon(Icons.campaign, color: Colors.white)),
          title: Text(
              data['title'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87)
          ),
          subtitle: Text(
              'Từ: ${data['authorName']}\nNgày: ${data['date']}',
              style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white60 : Colors.black54)
          ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(BuildContext context, Map<String, dynamic> data, VoidCallback _) {
    final String fullCourseName = data['courseName'] ?? 'Unknown Course';

    String courseCode = fullCourseName;
    String displayName = "Đánh giá môn học";

    if (fullCourseName.contains(' - ')) {
      List<String> parts = fullCourseName.split(' - ');
      courseCode = parts[0].trim();
      displayName = parts.sublist(1).join(' - ').trim();
    }

    final int reviewCount = data['reviewCount'] ?? 0;
    final double rating = (data['rating'] ?? 5.0).toDouble();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseReviewListPage(
              fullCourseName: fullCourseName,
              teacherName: data['teacherName'] ?? 'Nhiều giảng viên',
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF6797E1),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courseCode,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 18),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating.floor() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 18,
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    // ĐÃ SỬA: Trả lại hiển thị số lượng review ở đây
                    Text(
                      '$reviewCount đánh giá',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w400
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              'Giảng viên: ${data['teacherName'] ?? 'Nhiều giảng viên'}',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialItem(BuildContext context, Map<String, dynamic> data, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: isDarkMode ? Colors.white10 : const Color(0x1A000000))
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: isDarkMode ? Colors.redAccent.withOpacity(0.1) : Colors.red.shade50,
                borderRadius: BorderRadius.circular(10)
            ),
            child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 30),
          ),
          title: Text(
              data['courseName'] ?? 'Tài liệu',
              style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)
          ),
          subtitle: Text(
              'Tệp: ${data['fileName']}',
              style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.black54)
          ),
          trailing: const Icon(Icons.download_for_offline, color: Color(0xFF6797E1)),
        ),
      ),
    );
  }

  Widget _buildPostActions(int likes, int comments) {
    return Row(
      children: [
        Row(children: [const Icon(Icons.favorite_border, size: 18, color: Colors.grey), const SizedBox(width: 5), Text('$likes', style: const TextStyle(color: Colors.grey))]),
        const SizedBox(width: 20),
        Row(children: [const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey), const SizedBox(width: 5), Text('$comments', style: const TextStyle(color: Colors.grey))]),
      ],
    );
  }
}