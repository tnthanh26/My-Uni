import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../file_helper_stub.dart'
if (dart.library.html) '../file_helper_web.dart';
import '../services/activity_service.dart';
import '../student_qr_scanner_dialog.dart';
import '../widgets/attendance_table.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({
    super.key,
    required this.selectedActivityId,
    required this.selectedActivityData,
    required this.onBackToActivities,
    required this.onChooseActivity,
  });

  final String? selectedActivityId;
  final Map<String, dynamic>? selectedActivityData;
  final VoidCallback onBackToActivities;
  final VoidCallback onChooseActivity;

  @override
  Widget build(BuildContext context) {
    if (selectedActivityId == null) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE9EEF3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.orangeAccent,
                  size: 38,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Chưa chọn hoạt động',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1F37),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Hãy chọn một hoạt động để bắt đầu điểm danh sinh viên bằng mã QR.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  color: Color(0xFF667085),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: onChooseActivity,
                icon: const Icon(Icons.event_note_outlined),
                label: const Text('Đi đến hoạt động của tôi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('student_activities')
          .doc(selectedActivityId!)
          .snapshots(),
      builder: (context, activitySnapshot) {
        if (activitySnapshot.hasError) {
          return Center(
            child: Text('Lỗi tải hoạt động: ${activitySnapshot.error}'),
          );
        }

        if (!activitySnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!activitySnapshot.data!.exists) {
          return const Center(child: Text('Hoạt động không còn tồn tại.'));
        }

        final activityData = activitySnapshot.data!.data() ?? {};
        final status = activityData['status'] ?? 'active';
        final isActive = status == 'active';

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onBackToActivities,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Quay lại hoạt động'),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isActive ? 'Đang mở check-in' : 'Đã đóng check-in',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                activityData['title'] ?? 'Hoạt động',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1F37),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isActive
                    ? 'Danh sách sinh viên đã check-in sẽ hiển thị realtime tại đây.'
                    : 'Hoạt động này đã đóng check-in. Bạn vẫn có thể xem và xuất danh sách.',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: isActive
                          ? () => _openStudentQrScanner(context, selectedActivityId!)
                          : null,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: Text(
                        isActive ? 'Quét QR sinh viên' : 'Check-in đã đóng',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _exportAttendanceCsv(
                        context,
                        selectedActivityId!,
                        activityData,
                      ),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Xuất danh sách'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ActivityService.getAttendance(selectedActivityId!),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Lỗi tải danh sách: ${snapshot.error}'),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];

                    return SingleChildScrollView(
                      child: AttendanceTable(docs: docs),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openStudentQrScanner(
      BuildContext context,
      String activityId,
      ) async {
    final activitySnapshot = await FirebaseFirestore.instance
        .collection('student_activities')
        .doc(activityId)
        .get();

    final activityData = activitySnapshot.data();

    if (activityData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hoạt động không còn tồn tại.')),
      );
      return;
    }

    final status = activityData['status'] ?? 'active';

    if (status != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hoạt động này đã đóng check-in.')),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const StudentQrScannerDialog(),
    );

    if (result == null) return;

    try {
      final isNewCheckIn = await ActivityService.addAttendanceFromQr(
        activityId: activityId,
        studentData: result,
      );

      if (!context.mounted) return;

      if (isNewCheckIn) {
        _showCheckInResultDialog(
          context: context,
          title: 'Điểm danh thành công',
          icon: Icons.check_circle_rounded,
          iconColor: Colors.green,
          activityId: activityId,
          studentData: result,
        );
      } else {
        _showCheckInResultDialog(
          context: context,
          title: 'Sinh viên đã điểm danh trước đó',
          icon: Icons.info_rounded,
          iconColor: Colors.orange,
          activityId: activityId,
          studentData: result,
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể ghi nhận điểm danh: $e')),
      );
    }
  }

  void _showCheckInResultDialog({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required String activityId,
    required Map<String, dynamic> studentData,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Họ tên: ${studentData['displayName'] ?? ''}'),
            Text('MSSV: ${studentData['studentId'] ?? ''}'),
            Text('Khoa: ${studentData['faculty'] ?? ''}'),
            Text('Niên khóa: ${studentData['cohort'] ?? ''}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openStudentQrScanner(context, activityId);
            },
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('Quét tiếp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAttendanceCsv(
      BuildContext context,
      String activityId,
      Map<String, dynamic> activityData,
      ) async {
    try {
      final snapshot = await ActivityService.attendanceRef(activityId)
          .orderBy('checkedInAt', descending: false)
          .get();

      final docs = snapshot.docs;

      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa có sinh viên nào để xuất danh sách.'),
          ),
        );
        return;
      }

      final activityTitle = (activityData['title'] ?? 'hoat_dong').toString();

      final safeTitle = activityTitle
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');

      final buffer = StringBuffer();

      buffer.write('\uFEFF');

      buffer.writeln(
        'STT,Họ tên,MSSV,Khoa,Niên khóa,Thời gian check-in,Điểm rèn luyện',
      );

      for (int i = 0; i < docs.length; i++) {
        final data = docs[i].data();

        final checkedInAt = data['checkedInAt'];
        String checkedInText = '';

        if (checkedInAt is Timestamp) {
          final date = checkedInAt.toDate();

          checkedInText =
          '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/'
              '${date.year} '
              '${date.hour.toString().padLeft(2, '0')}:'
              '${date.minute.toString().padLeft(2, '0')}';
        }

        final trainingPoint = activityData['trainingPoint'] ?? 0;

        buffer.writeln([
          i + 1,
          _csvCell(data['displayName'] ?? ''),
          _csvCell(data['studentId'] ?? ''),
          _csvCell(data['faculty'] ?? ''),
          _csvCell(data['cohort'] ?? ''),
          _csvCell(checkedInText),
          trainingPoint,
        ].join(','));
      }

      final csvContent = buffer.toString();
      final base64Data = base64Encode(utf8.encode(csvContent));

      FileHelper.downloadFile(
        base64Data,
        'Danh_sach_diem_danh_$safeTitle.csv',
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xuất danh sách điểm danh.')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xuất danh sách: $e')),
      );
    }
  }

  String _csvCell(dynamic value) {
    final text = value.toString().replaceAll('"', '""');
    return '"$text"';
  }
}