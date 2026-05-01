import 'package:cloud_firestore/cloud_firestore.dart';

class UserActivityData {
  const UserActivityData({
    required this.forumPosts,
    required this.reviews,
    required this.materials,
    required this.logs,
  });

  final List<QueryDocumentSnapshot> forumPosts;
  final List<QueryDocumentSnapshot> reviews;
  final List<QueryDocumentSnapshot> materials;
  final List<QueryDocumentSnapshot> logs;
}

class UserActivityService {
  static Future<UserActivityData> getUserActivity(String uid) async {
    final forumPosts = await FirebaseFirestore.instance
        .collection('forum_posts')
        .where('authorId', isEqualTo: uid)
        .limit(10)
        .get();

    final reviews = await FirebaseFirestore.instance
        .collection('course_reviews')
        .where('authorId', isEqualTo: uid)
        .limit(10)
        .get();

    final materials = await FirebaseFirestore.instance
        .collection('study_materials')
        .where('authorId', isEqualTo: uid)
        .limit(10)
        .get();

    final logs = await FirebaseFirestore.instance
        .collection('moderation_logs')
        .where('targetUserId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    return UserActivityData(
      forumPosts: forumPosts.docs,
      reviews: reviews.docs,
      materials: materials.docs,
      logs: logs.docs,
    );
  }
}