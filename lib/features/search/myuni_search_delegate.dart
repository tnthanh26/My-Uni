import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../home/post_detail_page.dart';
import 'course_review_list_page.dart';

enum SearchScope { official, forum, review, material }

class MyUniSearchDelegate extends SearchDelegate<String> {
  final SearchScope currentScope;

  final ValueNotifier<int> _refreshTrigger = ValueNotifier<int>(0);

  List<String> selectedHashtags = ['Tất cả'];
  String currentSort = 'relevance';

  final List<String> availableHashtags = [
    'Tất cả',
    'Hỏi đáp',
    'Quân sự',
    'Học phí',
    'Tìm đồ',
    'Chia sẻ',
    'Tìm việc',
  ];

  MyUniSearchDelegate({required this.currentScope})
      : super(
    searchFieldLabel: _getSearchLabel(currentScope),
    keyboardType: TextInputType.text,
  );

  static String _getSearchLabel(SearchScope scope) {
    switch (scope) {
      case SearchScope.official:
        return 'Tìm thông tin chính thức...';
      case SearchScope.forum:
        return 'Bạn muốn biết điều gì quanh trường?';
      case SearchScope.review:
        return 'Bạn muốn biết đánh giá môn học nào?';
      case SearchScope.material:
        return 'Tìm tài liệu tham khảo...';
    }
  }

  Color _backgroundColor(bool isDark) =>
      isDark ? const Color(0xFF121212) : const Color(0xFFF7F9FC);

  Color _surfaceColor(bool isDark) =>
      isDark ? const Color(0xFF1E1E1E) : Colors.white;

  Color _secondarySurface(bool isDark) =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F4F8);

  Color _primaryText(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF1E1E1E);

  Color _secondaryText(bool isDark) =>
      isDark ? Colors.white70 : const Color(0xFF6B7280);

  Color _borderColor(bool isDark) =>
      isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB);

  List<BoxShadow> _cardShadow(bool isDark) => isDark
      ? []
      : [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];

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
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return theme.copyWith(
      scaffoldBackgroundColor: _backgroundColor(isDarkMode),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: _surfaceColor(isDarkMode),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.white38 : Colors.grey,
          fontSize: 15,
        ),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(
          color: _primaryText(isDarkMode),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: Icon(
            Icons.clear_rounded,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      PopupMenuButton<String>(
        color: _surfaceColor(isDarkMode),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(Icons.sort_rounded, color: Color(0xFF6797E1)),
        onSelected: (String value) {
          currentSort = value;
          _forceRefresh(context);
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'relevance',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.auto_awesome_outlined,
                color:
                currentSort == 'relevance' ? Colors.blue : Colors.grey,
              ),
              title: Text(
                'Độ liên quan',
                style: TextStyle(
                  color: currentSort == 'relevance'
                      ? Colors.blue
                      : _primaryText(isDarkMode),
                ),
              ),
              trailing: currentSort == 'relevance'
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
            ),
          ),
          PopupMenuItem<String>(
            value: 'desc',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.new_releases_outlined,
                color: currentSort == 'desc' ? Colors.blue : Colors.grey,
              ),
              title: Text(
                'Mới nhất',
                style: TextStyle(
                  color: currentSort == 'desc'
                      ? Colors.blue
                      : _primaryText(isDarkMode),
                ),
              ),
              trailing: currentSort == 'desc'
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
            ),
          ),
          PopupMenuItem<String>(
            value: 'asc',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.history_outlined,
                color: currentSort == 'asc' ? Colors.blue : Colors.grey,
              ),
              title: Text(
                'Cũ nhất',
                style: TextStyle(
                  color: currentSort == 'asc'
                      ? Colors.blue
                      : _primaryText(isDarkMode),
                ),
              ),
              trailing: currentSort == 'asc'
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, ''),
    icon: Icon(
      Icons.arrow_back_rounded,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black,
    ),
  );

  Widget _buildFilterBar(StateSetter setState, BuildContext context) {
    if (currentScope != SearchScope.forum) return const SizedBox.shrink();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      color: _surfaceColor(isDarkMode),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: availableHashtags.map((tag) {
            final bool isSelected = selectedHashtags.contains(tag);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(tag == 'Tất cả' ? tag : '# $tag'),
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : _secondaryText(isDarkMode),
                  fontSize: 13,
                  fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF6797E1),
                backgroundColor: _secondarySurface(isDarkMode),
                checkmarkColor: Colors.white,
                side: BorderSide(color: _borderColor(isDarkMode)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
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
                        if (selectedHashtags.isEmpty) {
                          selectedHashtags = ['Tất cả'];
                        }
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
        color: _backgroundColor(isDarkMode),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            decoration: BoxDecoration(
              color: _surfaceColor(isDarkMode),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _borderColor(isDarkMode)),
              boxShadow: _cardShadow(isDarkMode),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 36,
                  color: _secondaryText(isDarkMode),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nhập từ khóa để bắt đầu tìm kiếm',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _primaryText(isDarkMode),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kết quả phù hợp sẽ hiện ra ở đây.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _secondaryText(isDarkMode),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: _backgroundColor(isDarkMode),
      child: ValueListenableBuilder<int>(
        valueListenable: _refreshTrigger,
        builder: (context, trigger, _) {
          return StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  if (currentScope == SearchScope.forum)
                    _buildFilterBar(setState, context),
                  if (currentScope == SearchScope.forum)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDarkMode
                          ? Colors.white12
                          : Colors.grey.shade300,
                    ),
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      key: ValueKey(
                        '${query}_${selectedHashtags.join()}_${currentSort}_$trigger',
                      ),
                      future: _performSemanticSearch(query, currentScope),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF6797E1),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return const Center(
                            child: Text(
                              'Lỗi kết nối Server',
                              style: TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Text(
                              'Không tìm thấy kết quả',
                              style: TextStyle(
                                color: _secondaryText(isDarkMode),
                              ),
                            ),
                          );
                        }

                        return _buildResultList(context, snapshot.data!);
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);

  Future<List<dynamic>> _performSemanticSearch(
      String query,
      SearchScope scope,
      ) async {
    if (query.trim().isEmpty) return [];

    final String scopeString = scope.toString().split('.').last;
    final String sortOrder = currentSort;

    final cleanQuery = query.trim();
    final List<String> activeTags =
    selectedHashtags.where((t) => t != 'Tất cả').toList();
    final String tagParam = activeTags.isEmpty ? '' : activeTags.join(',');

    final uri = Uri.parse('https://34-142-139-17.sslip.io/search').replace(
      queryParameters: {
        'query': cleanQuery,
        'scope': scopeString,
        'tag': tagParam,
        'sort': sortOrder,
      },
    );

    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final List<dynamic>? data =
        jsonDecode(utf8.decode(response.bodyBytes));
        return data ?? [];
      } else {
        throw Exception('Search API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Lỗi Search: $e");
      rethrow;
    }
  }

  Widget _buildResultList(BuildContext context, List<dynamic> results) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: _backgroundColor(isDarkMode),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: results.length,
        separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = results[index];
          final String docId = item['id'];
          final Map<String, dynamic> data =
          Map<String, dynamic>.from(item['data']);

          void openDetail() {
            final Map<String, dynamic> processedData = Map.from(data);

            if (processedData.containsKey('timestamp')) {
              final rawTs = processedData['timestamp'];
              if (rawTs is int) {
                processedData['timestamp'] =
                    Timestamp.fromMillisecondsSinceEpoch(rawTs * 1000);
              } else if (rawTs is String) {
                final int? parsed = int.tryParse(rawTs);
                processedData['timestamp'] =
                    Timestamp.fromMillisecondsSinceEpoch(
                      (parsed ?? 0) * 1000,
                    );
              }
            } else {
              processedData['timestamp'] = Timestamp.now();
            }

            final rawHashtags = processedData['hashtags'];
            if (rawHashtags is String) {
              processedData['hashtags'] = rawHashtags
                  .split(',')
                  .where((s) => s.trim().isNotEmpty)
                  .toList();
            } else if (rawHashtags == null) {
              processedData['hashtags'] = [];
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(
                  docId: docId,
                  initialPostData: processedData,
                ),
              ),
            );
          }

          final String scope = data['scope'] ?? '';

          if (scope == 'forum_posts') {
            return _buildForumItem(context, data, openDetail);
          }
          if (scope == 'official_news') {
            return _buildOfficialItem(context, data, openDetail);
          }
          if (scope == 'course_reviews' ||
              scope == 'course_reviews_group') {
            return _buildReviewItem(context, data, openDetail);
          }
          if (scope == 'study_materials') {
            return _buildMaterialItem(context, data, openDetail);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildForumItem(
      BuildContext context,
      Map<String, dynamic> data,
      VoidCallback onTap,
      ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceColor(isDarkMode),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _borderColor(isDarkMode)),
          boxShadow: _cardShadow(isDarkMode),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: isDarkMode
                        ? Colors.white12
                        : Colors.grey[200],
                    backgroundImage:
                    (data['authorAvatar'] != null &&
                        data['authorAvatar'] != "")
                        ? MemoryImage(
                      base64Decode(data['authorAvatar']),
                    )
                        : null,
                    child: (data['authorAvatar'] == null ||
                        data['authorAvatar'] == "")
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['authorName'] ?? 'Sinh viên MyUni',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _primaryText(isDarkMode),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTimestamp(data['timestamp'] as int?),
                          style: TextStyle(
                            color: _secondaryText(isDarkMode),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (data['hashtags'] != null &&
                  (data['hashtags'] as List).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (data['hashtags'] as List)
                        .map(
                          (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _secondarySurface(isDarkMode),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _borderColor(isDarkMode),
                          ),
                        ),
                        child: Text(
                          "#$tag",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6797E1),
                          ),
                        ),
                      ),
                    )
                        .toList(),
                  ),
                ),
              Text(
                data['content'] ?? '',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              if (data['imageUrl'] != null && data['imageUrl'] != "")
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      base64Decode(data['imageUrl']),
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              _buildPostActions(
                data['likeCount'] ?? 0,
                data['commentCount'] ?? 0,
                isDarkMode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialItem(
      BuildContext context,
      Map<String, dynamic> data,
      VoidCallback onTap,
      ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceColor(isDarkMode),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _borderColor(isDarkMode)),
          boxShadow: _cardShadow(isDarkMode),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFF6797E1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _primaryText(isDarkMode),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _secondarySurface(isDarkMode),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _borderColor(isDarkMode)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Từ: ${data['authorName'] ?? 'MyUni'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _secondaryText(isDarkMode),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ngày: ${data['date'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _secondaryText(isDarkMode),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(
      BuildContext context,
      Map<String, dynamic> data,
      VoidCallback _,
      ) {
    final String fullCourseName = data['courseName'] ?? 'Unknown Course';

    String courseCode = fullCourseName;
    String displayName = "Đánh giá môn học";

    if (fullCourseName.contains(' - ')) {
      final List<String> parts = fullCourseName.split(' - ');
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF6797E1),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courseCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating.floor()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 18,
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '$reviewCount đánh giá',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Giảng viên: ${data['teacherName'] ?? 'Nhiều giảng viên'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialItem(
      BuildContext context,
      Map<String, dynamic> data,
      VoidCallback onTap,
      ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceColor(isDarkMode),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _borderColor(isDarkMode)),
          boxShadow: _cardShadow(isDarkMode),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.redAccent.withOpacity(0.12)
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['courseName'] ?? 'Tài liệu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryText(isDarkMode),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tệp: ${data['fileName']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _secondaryText(isDarkMode),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.download_for_offline_rounded,
                color: Color(0xFF6797E1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostActions(int likes, int comments, bool isDarkMode) {
    return Row(
      children: [
        Row(
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 18,
              color: _secondaryText(isDarkMode),
            ),
            const SizedBox(width: 5),
            Text(
              '$likes',
              style: TextStyle(color: _secondaryText(isDarkMode)),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 18,
              color: _secondaryText(isDarkMode),
            ),
            const SizedBox(width: 5),
            Text(
              '$comments',
              style: TextStyle(color: _secondaryText(isDarkMode)),
            ),
          ],
        ),
      ],
    );
  }
}