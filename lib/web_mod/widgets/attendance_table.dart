import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AttendanceTable extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const AttendanceTable({
    super.key,
    required this.docs,
  });

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return 'Đang cập nhật';
    final date = value.toDate();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có sinh viên check-in.',
          style: TextStyle(
            fontFamily: 'Nunito',
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EEF3)),
      ),
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(const Color(0xFFF5F7FA)),
        columns: const [
          DataColumn(label: Text('Họ tên')),
          DataColumn(label: Text('MSSV')),
          DataColumn(label: Text('Khoa')),
          DataColumn(label: Text('Niên khóa')),
          DataColumn(label: Text('Thời gian check-in')),
          DataColumn(label: Text('Trạng thái')),
        ],
        rows: docs.map((doc) {
          final data = doc.data();

          return DataRow(
            cells: [
              DataCell(Text(data['displayName'] ?? '')),
              DataCell(Text(data['studentId'] ?? '')),
              DataCell(Text(data['faculty'] ?? '')),
              DataCell(Text(data['cohort'] ?? '')),
              DataCell(Text(_formatTime(data['checkedInAt']))),
              DataCell(
                Row(
                  children: const [
                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                    SizedBox(width: 6),
                    Text('Đã ghi nhận'),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}