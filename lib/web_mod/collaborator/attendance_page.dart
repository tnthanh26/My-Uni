import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
                spacing: 14,
                runSpacing: 12,
                children: [
                  SizedBox(
                    height: 46,
                    width: 220,
                    child: ElevatedButton.icon(
                      onPressed: isActive
                          ? () => _openStudentQrScanner(
                        context,
                        selectedActivityId!,
                      )
                          : null,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: Text(
                        isActive ? 'Quét QR sinh viên' : 'Check-in đã đóng',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  if (isActive)
                    SizedBox(
                      height: 46,
                      width: 220,
                      child: ElevatedButton.icon(
                        onPressed: () => _showEventQrDialog(
                          context,
                          selectedActivityId!,
                          activityData,
                        ),
                        icon: const Icon(Icons.qr_code_rounded, size: 20),
                        label: const Text('Xem QR hoạt động'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                  SizedBox(
                    height: 46,
                    width: 200,
                    child: OutlinedButton.icon(
                      onPressed: () => _exportAttendanceCsv(
                        context,
                        selectedActivityId!,
                        activityData,
                      ),
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text('Xuất danh sách'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: BorderSide(
                          color: Colors.blueAccent.withOpacity(0.35),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _buildRequestsSection(context, selectedActivityId!),
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

                    final docs = (snapshot.data?.docs ?? [])
                        .where((doc) => doc.data()['isApproved'] != false)
                        .toList();

                    return SingleChildScrollView(
                      child: AttendanceTable(
                        activityId: selectedActivityId!,
                        docs: docs,
                      ),
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

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StudentQrScannerDialog(
        activityId: activityId,
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

  void _showEventQrDialog(
      BuildContext context,
      String activityId,
      Map<String, dynamic> activityData,
      ) {
    final title = activityData['title'] ?? 'Hoạt động';
    final point = activityData['trainingPoint'] ?? 0;

    final eventQrData = jsonEncode({
      'type': 'myuni_event_qr',
      'version': 1,
      'activityId': activityId,
      'title': title,
      'trainingPoint': point,
      'organizerName': activityData['organizerName'] ?? '',
      'generatedAt': DateTime.now().toIso8601String(),
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mã QR hoạt động',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1F37),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: eventQrData,
                          version: QrVersions.auto,
                          size: 240,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '+$point Điểm rèn luyện',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      const Text(
                        'Sinh viên quét mã này bằng ứng dụng My Uni để tự ghi nhận điểm danh.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          color: Color(0xFF667085),
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 22),
                      _buildRequestsSection(context, activityId),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsSection(BuildContext context, String activityId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ActivityService.getAttendance(activityId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final requestDocs = snapshot.data!.docs
            .where((doc) => doc.data()['isApproved'] == false)
            .toList();

        if (requestDocs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.pending_actions_rounded,
                  color: Colors.orangeAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Yêu cầu xét duyệt vãng lai',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1F37),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${requestDocs.length} chờ duyệt',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: requestDocs.map((doc) {
                final data = doc.data();
                final studentUid = doc.id;
                final displayName = data['displayName'] ?? 'Sinh viên';
                final studentId = data['studentId'] ?? '';
                final faculty = data['faculty'] ?? '';
                final cohort = data['cohort'] ?? '';

                return Container(
                  width: 280,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1F37),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'MSSV: $studentId',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475467),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$faculty - $cohort',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                try {
                                  await ActivityService.rejectAttendanceRequest(
                                    activityId: activityId,
                                    studentUid: studentUid,
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Lỗi từ chối: $e')),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: const Text('Từ chối'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                try {
                                  await ActivityService.approveAttendanceRequest(
                                    activityId: activityId,
                                    studentUid: studentUid,
                                    studentData: data,
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Lỗi duyệt: $e')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: const Text('Duyệt'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }
}