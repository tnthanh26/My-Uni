import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ActivityCard extends StatelessWidget {
  final String activityId;
  final Map<String, dynamic> data;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onViewRegisteredList;

  const ActivityCard({
    super.key,
    required this.activityId,
    required this.data,
    required this.onOpen,
    required this.onClose,
    required this.onReopen,
    required this.onDelete,
    this.onEdit,
    this.onViewRegisteredList,
  });

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return 'Chưa có thời gian';

    final date = value.toDate();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'active').toString();
    final isActive = status == 'active';
    final requiresReg = data['requiresRegistration'] == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFECFDF3)
                            : const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isActive
                            ? Icons.event_available_rounded
                            : Icons.event_busy_rounded,
                        color: isActive
                            ? const Color(0xFF027A48)
                            : const Color(0xFF475467),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  data['title']?.toString() ??
                                      'Hoạt động không tên',
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF101828),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              if (requiresReg)
                                _statusBadge(
                                  'YÊU CẦU ĐĂNG KÝ',
                                  const Color(0xFFEFF8FF),
                                  const Color(0xFF175CD3),
                                ),

                              const SizedBox(width: 8),

                              _statusBadge(
                                isActive ? 'ĐANG MỞ' : 'ĐÃ ĐÓNG',
                                isActive
                                    ? const Color(0xFFECFDF3)
                                    : const Color(0xFFF2F4F7),
                                isActive
                                    ? const Color(0xFF027A48)
                                    : const Color(0xFF475467),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tổ chức bởi: ${data['organizerName']?.toString() ?? 'N/A'}',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  data['description']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF475467),
                  ),
                ),

                const SizedBox(height: 16),

                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _compactChip(
                      Icons.location_on_outlined,
                      data['location']?.toString() ?? 'Chưa cập nhật',
                    ),
                    _compactChip(
                      Icons.calendar_today_outlined,
                      _formatDate(data['startTime']),
                    ),
                    _compactChip(
                      Icons.people_outline_rounded,
                      '${data['attendanceCount']?.toString() ?? '0'} check-in',
                    ),
                    _compactChip(
                      Icons.stars_outlined,
                      '${data['trainingPoint']?.toString() ?? '0'} ĐRL',
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.end,
                children: [
                  if (requiresReg && onViewRegisteredList != null)
                    IntrinsicWidth(
                      child: OutlinedButton.icon(
                        onPressed: onViewRegisteredList,
                        icon: const Icon(Icons.how_to_reg_rounded, size: 15),
                        label: const Text('DS đăng ký'),
                        style: OutlinedButton.styleFrom(
                          fixedSize: const Size.fromHeight(36),
                          foregroundColor: const Color(0xFF344054),
                          side: const BorderSide(color: Color(0xFFD0D5DD)),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                  IntrinsicWidth(
                    child: ElevatedButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.analytics_rounded, size: 15),
                      label: const Text('Chi tiết'),
                      style: ElevatedButton.styleFrom(
                        fixedSize: const Size.fromHeight(36),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        textStyle: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  TextButton.icon(
                    onPressed: isActive ? onClose : onReopen,
                    icon: Icon(
                      isActive
                          ? Icons.lock_outline_rounded
                          : Icons.lock_open_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isActive ? 'Đóng' : 'Mở lại',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: isActive
                          ? const Color(0xFFB44431)
                          : const Color(0xFF027A48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  if (onEdit != null)
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                      tooltip: 'Sửa',
                    ),

                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFD92D20),
                      size: 20,
                    ),
                    tooltip: 'Xóa',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(
      String label,
      Color bgColor,
      Color textColor,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _compactChip(
      IconData icon,
      String label,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFEAECF0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: const Color(0xFF667085),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475467),
            ),
          ),
        ],
      ),
    );
  }
}