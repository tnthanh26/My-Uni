import 'package:flutter/material.dart';
import '../../../widgets/app_skeleton.dart';

/// Single Post Card Skeleton for Forum & Official Tabs
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar + Tên + Thời gian
            Row(
              children: [
                const SkeletonBox.circle(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 120, height: 14, borderRadius: 4),
                      SizedBox(height: 6),
                      SkeletonBox(width: 70, height: 10, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Nội dung bài viết (2 dòng text giả)
            const SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
            const SizedBox(height: 6),
            const SkeletonBox(width: 220, height: 14, borderRadius: 4),
            const SizedBox(height: 12),
            // Khối ảnh giả lập (Image placeholder)
            const SkeletonBox(
              width: double.infinity,
              height: 160,
              borderRadius: 12,
            ),
            const SizedBox(height: 12),
            // Footer: Icon thả tim/bình luận giả lập
            Row(
              children: const [
                SkeletonBox(width: 50, height: 18, borderRadius: 6),
                SizedBox(width: 20),
                SkeletonBox(width: 50, height: 18, borderRadius: 6),
                SizedBox(width: 20),
                SkeletonBox(width: 50, height: 18, borderRadius: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ListView Skeleton for Forum / Official Feed Tabs
class PostCardSkeletonListView extends StatelessWidget {
  final int itemCount;

  const PostCardSkeletonListView({
    super.key,
    this.itemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: itemCount,
      itemBuilder: (context, index) => const PostCardSkeleton(),
    );
  }
}

/// Skeleton for Material (Tài Liệu) Tab
class MaterialSkeletonListView extends StatelessWidget {
  const MaterialSkeletonListView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const SkeletonBox(width: 44, height: 44, borderRadius: 12),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 180, height: 14, borderRadius: 4),
                      SizedBox(height: 6),
                      SkeletonBox(width: 110, height: 10, borderRadius: 4),
                    ],
                  ),
                ),
                const SkeletonBox(width: 24, height: 24, borderRadius: 6),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton for Review Tab
class ReviewSkeletonListView extends StatelessWidget {
  const ReviewSkeletonListView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: SkeletonBox(
              width: double.infinity,
              height: 110,
              borderRadius: 16,
            ),
          );
        },
      ),
    );
  }
}
