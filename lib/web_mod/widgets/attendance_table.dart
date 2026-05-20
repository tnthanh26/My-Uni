import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AttendanceTable extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const AttendanceTable({
    super.key,
    required this.docs,
  });

  @override
  State<AttendanceTable> createState() => _AttendanceTableState();
}

class _AttendanceTableState extends State<AttendanceTable> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return 'Đang cập nhật';
    final date = value.toDate();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _textCell(String text, {double width = 120}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF344054),
        ),
      ),
    );
  }

  Widget _statusChip() {
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEAFBF0),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFB7E4C7)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 16,
            ),
            SizedBox(width: 6),
            Text(
              'Đã ghi nhận',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF15803D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.docs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 70),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_alt_outlined, size: 52, color: Color(0xFF98A2B3)),
            SizedBox(height: 18),
            Text(
              'Chưa có sinh viên check-in',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF344054),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Danh sách điểm danh sẽ hiển thị tại đây.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                color: Color(0xFF98A2B3),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 1180
            ? 1180.0
            : constraints.maxWidth;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE4E7EC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: constraints.maxWidth < 1180,
            radius: const Radius.circular(999),
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: DataTable(
                  columnSpacing: 26,
                  horizontalMargin: 26,
                  headingRowHeight: 68,
                  dataRowMinHeight: 74,
                  dataRowMaxHeight: 74,
                  dividerThickness: 1,
                  headingRowColor: MaterialStateProperty.all(
                    const Color(0xFFF8FAFC),
                  ),
                  headingTextStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475467),
                  ),
                  columns: const [
                    DataColumn(label: Text('Họ tên')),
                    DataColumn(label: Text('MSSV')),
                    DataColumn(label: Text('Khoa')),
                    DataColumn(label: Text('Niên khóa')),
                    DataColumn(label: Text('Thời gian check-in')),
                    DataColumn(label: Text('Trạng thái')),
                  ],
                  rows: widget.docs.map((doc) {
                    final data = doc.data();

                    return DataRow(
                      cells: [
                        DataCell(_textCell(data['displayName'] ?? '', width: 210)),
                        DataCell(_textCell(data['studentId'] ?? '', width: 130)),
                        DataCell(_textCell(data['faculty'] ?? 'Chưa cập nhật khoa', width: 230)),
                        DataCell(_textCell(data['cohort'] ?? '', width: 130)),
                        DataCell(_textCell(_formatTime(data['checkedInAt']), width: 190)),
                        DataCell(
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _statusChip(),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}