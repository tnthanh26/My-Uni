import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/post_detail_page.dart';

class CourseReviewListPage extends StatefulWidget {
  final String fullCourseName;
  final String teacherName;

  const CourseReviewListPage({
    super.key,
    required this.fullCourseName,
    required this.teacherName
  });

  @override
  State<CourseReviewListPage> createState() => _CourseReviewListPageState();
}

class _CourseReviewListPageState extends State<CourseReviewListPage> {
  bool isNewest = true;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : const Color(0xFF545454),
        elevation: 0.5,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.fullCourseName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Nunito',
                color: isDarkMode ? Colors.white : const Color(0xFF545454),
              ),
            ),
            Text(
              'Giảng viên: ${widget.teacherName}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                fontFamily: 'Nunito',
                color: Color(0xFF6797E1),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<bool>(
            icon: const Icon(Icons.sort_rounded, color: Color(0xFF6797E1)),
            onSelected: (bool value) {
              setState(() {
                isNewest = value;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<bool>>[
              PopupMenuItem<bool>(
                value: true,
                child: ListTile(
                  leading: Icon(Icons.new_releases_outlined,
                      color: isNewest ? Colors.blue : Colors.grey),
                  title: Text('Mới nhất',
                      style: TextStyle(color: isNewest ? Colors.blue : (isDarkMode ? Colors.white : Colors.black), fontSize: 14)),
                  trailing: isNewest ? const Icon(Icons.check, color: Colors.blue, size: 20) : null,
                ),
              ),
              PopupMenuItem<bool>(
                value: false,
                child: ListTile(
                  leading: Icon(Icons.history_outlined,
                      color: !isNewest ? Colors.blue : Colors.grey),
                  title: Text('Cũ nhất',
                      style: TextStyle(color: !isNewest ? Colors.blue : (isDarkMode ? Colors.white : Colors.black), fontSize: 14)),
                  trailing: !isNewest ? const Icon(Icons.check, color: Colors.blue, size: 20) : null,
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('course_reviews')
            .where('courseName', isEqualTo: widget.fullCourseName)
            .where('teacherName', isEqualTo: widget.teacherName)
            .where('status', isEqualTo: 'approved')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6797E1)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Chưa có đánh giá chi tiết nào.',
                style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
              ),
            );
          }

          var reviewDocs = snapshot.data!.docs;

          reviewDocs.sort((a, b) {
            var t1 = a['timestamp'] as Timestamp;
            var t2 = b['timestamp'] as Timestamp;
            if (isNewest) {
              return t2.compareTo(t1);
            } else {
              return t1.compareTo(t2);
            }
          });

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: reviewDocs.length,
            separatorBuilder: (context, index) => Divider(
                height: 40,
                color: isDarkMode ? Colors.white12 : const Color(0xFFEEEEEE)
            ),
            itemBuilder: (context, index) {
              final doc = reviewDocs[index];
              final reviewData = doc.data() as Map<String, dynamic>;
              final String docId = doc.id;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailPage(
                        docId: docId,
                        initialPostData: reviewData,
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  widget.fullCourseName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    fontFamily: 'Encode Sans Expanded',
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  )
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  reviewData['semester'] ?? 'Học kỳ không xác định',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Encode Sans Expanded')
                              ),
                              Text(
                                  'GV: ${reviewData['teacherName'] ?? 'N/A'}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Encode Sans Expanded')
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(5, (i) => Icon(
                        i < (reviewData['rating'] ?? 5) ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFFFCB45), size: 18,
                      )),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      reviewData['content'] ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: isDarkMode ? Colors.white70 : const Color(0xFF545454),
                          fontFamily: 'Encode Sans Expanded'
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        _buildStat(Icons.favorite_outline, Colors.grey, '${reviewData['likeCount'] ?? 0}'),
                        const SizedBox(width: 25),
                        _buildStat(Icons.chat_bubble_outline, Colors.grey, '${reviewData['commentCount'] ?? 0}'),
                        const Spacer(),
                        const Icon(Icons.bookmark_border, color: Colors.amber),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStat(IconData icon, Color color, String count) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 5),
        Text(count, style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Encode Sans Expanded')),
      ],
    );
  }
}