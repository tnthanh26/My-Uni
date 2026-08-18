import 'package:flutter/material.dart';
import '../../../widgets/app_skeleton.dart';

/// Skeleton Screen placeholder for MySpace Welcome / Summary Banner
class MySpaceWelcomeBannerSkeleton extends StatelessWidget {
  const MySpaceWelcomeBannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: SkeletonBox(width: double.infinity, height: 72, borderRadius: 20),
    );
  }
}

class MySpaceDeadlineSectionSkeleton extends StatelessWidget {
  const MySpaceDeadlineSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              SkeletonBox(width: 140, height: 22, borderRadius: 6),
              SkeletonBox(width: 80, height: 18, borderRadius: 6),
            ],
          ),
          const SizedBox(height: 12),
          // 3 Deadline Item Skeletons
          ...List.generate(
            3,
            (index) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: SkeletonBox(
                width: double.infinity,
                height: 50,
                borderRadius: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MySpaceScheduleSectionSkeleton extends StatelessWidget {
  const MySpaceScheduleSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Skeleton
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 150, height: 22, borderRadius: 6),
              SkeletonBox(width: 70, height: 18, borderRadius: 6),
            ],
          ),
          const SizedBox(height: 14),
          // Calendar Strip Skeleton (7 days)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              7,
              (index) =>
                  const SkeletonBox(width: 42, height: 58, borderRadius: 14),
            ),
          ),
          const SizedBox(height: 16),
          // 2 Schedule Card Skeletons
          ...List.generate(
            2,
            (index) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SkeletonBox(
                width: double.infinity,
                height: 74,
                borderRadius: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full Dashboard Skeleton Screen for MySpace
class MySpaceDashboardSkeleton extends StatelessWidget {
  const MySpaceDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          MySpaceWelcomeBannerSkeleton(),
          SizedBox(height: 25),
          MySpaceDeadlineSectionSkeleton(),
          SizedBox(height: 25),
          MySpaceScheduleSectionSkeleton(),
        ],
      ),
    );
  }
}
