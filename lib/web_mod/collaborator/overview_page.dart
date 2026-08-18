import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/activity_service.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({
    super.key,
    required this.onCreateActivity,
    required this.onOpenActivities,
    required this.onOpenAttendance,
  });

  final VoidCallback onCreateActivity;
  final VoidCallback onOpenActivities;
  final void Function(String activityId, Map<String, dynamic> data)
  onOpenAttendance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ActivityService.getMyActivities(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi tải tổng quan: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        final activeDocs = docs.where((doc) {
          return (doc.data()['status'] ?? 'active') == 'active';
        }).toList();

        final recentDocs = docs.take(3).toList();

        QueryDocumentSnapshot<Map<String, dynamic>>? mostCheckedInDoc;

        int getAttendanceCount(
          QueryDocumentSnapshot<Map<String, dynamic>> doc,
        ) {
          final value = doc.data()['attendanceCount'];
          if (value is int) return value;
          if (value is num) return value.toInt();
          return 0;
        }

        for (final doc in docs) {
          if (mostCheckedInDoc == null ||
              getAttendanceCount(doc) > getAttendanceCount(mostCheckedInDoc)) {
            mostCheckedInDoc = doc;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  _actionOverviewCard(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Tạo hoạt động mới',
                    subtitle: 'Tạo sự kiện và mở điểm danh QR',
                    color: Colors.orange,
                    onTap: onCreateActivity,
                  ),
                  _actionOverviewCard(
                    icon: Icons.fact_check_outlined,
                    title: activeDocs.isEmpty
                        ? 'Chưa có check-in đang mở'
                        : '${activeDocs.length} hoạt động đang mở',
                    subtitle: activeDocs.isEmpty
                        ? 'Tạo hoặc mở lại hoạt động để điểm danh'
                        : 'Chọn hoạt động để bắt đầu quét QR',
                    color: Colors.green,
                    onTap: onOpenActivities,
                  ),
                  _actionOverviewCard(
                    icon: Icons.download_rounded,
                    title: 'Xuất danh sách',
                    subtitle: 'Chọn hoạt động để xuất DS tham gia',
                    color: Colors.blueAccent,
                    onTap: onOpenActivities,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _overviewPanel(
                      title: 'Hoạt động gần đây',
                      child: recentDocs.isEmpty
                          ? _miniEmptyState(
                              icon: Icons.event_busy_outlined,
                              title: 'Chưa có hoạt động nào',
                              subtitle:
                                  'Hãy tạo hoạt động đầu tiên để bắt đầu quản lý điểm danh.',
                            )
                          : Column(
                              children: recentDocs.map((doc) {
                                return _recentActivityTile(doc.id, doc.data());
                              }).toList(),
                            ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 2,
                    child: _overviewPanel(
                      title: 'Nổi bật',
                      child: mostCheckedInDoc == null
                          ? _miniEmptyState(
                              icon: Icons.insights_outlined,
                              title: 'Chưa có dữ liệu',
                              subtitle:
                                  'Sau khi có sinh viên check-in, thống kê sẽ hiện ở đây.',
                            )
                          : _highlightActivity(mostCheckedInDoc.data()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionOverviewCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE9EEF3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1F37),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: Color(0xFF667085),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewPanel({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9EEF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1F37),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _miniEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1F37),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Nunito',
              color: Color(0xFF667085),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentActivityTile(String activityId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'active';
    final isActive = status == 'active';

    return InkWell(
      onTap: () => onOpenAttendance(activityId, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              isActive
                  ? Icons.play_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              color: isActive ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? 'Hoạt động không tên',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1F37),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data['attendanceCount'] ?? 0} sinh viên đã check-in',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _highlightActivity(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            color: Colors.orange,
            size: 42,
          ),
          const SizedBox(height: 14),
          const Text(
            'Hoạt động nhiều check-in nhất',
            style: TextStyle(
              fontFamily: 'Nunito',
              color: Color(0xFF9A3412),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['title'] ?? 'Hoạt động không tên',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1F37),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${data['attendanceCount'] ?? 0} sinh viên đã check-in',
            style: const TextStyle(
              fontFamily: 'Nunito',
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}
