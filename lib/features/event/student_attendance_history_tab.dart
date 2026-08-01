import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'event_qr_scanner_dialog.dart';

class StudentAttendanceHistoryTab extends StatefulWidget {
  const StudentAttendanceHistoryTab({super.key});

  @override
  State<StudentAttendanceHistoryTab> createState() =>
      _StudentAttendanceHistoryTabState();
}

class _StudentAttendanceHistoryTabState
    extends State<StudentAttendanceHistoryTab> {
  int _selectedSegment = 0; // 0: Hoạt động trường, 1: Lịch sử điểm danh

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activitiesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _attendedSub;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _activitiesDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _attendedDocs = [];
  Set<String> _attendedActivityIds = {};

  bool _isLoadingActivities = true;
  bool _isLoadingAttended = true;

  @override
  void initState() {
    super.initState();
    _initSubscriptions();
  }

  void _initSubscriptions() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingActivities = false;
        _isLoadingAttended = false;
      });
      return;
    }

    _activitiesSub = FirebaseFirestore.instance
        .collection('student_activities')
        .snapshots()
        .listen(
          (snapshot) {
        if (mounted) {
          setState(() {
            _activitiesDocs = snapshot.docs;
            _isLoadingActivities = false;
          });
        }
      },
      onError: (e) {
        debugPrint('Lỗi stream student_activities: $e');
        if (mounted) setState(() => _isLoadingActivities = false);
      },
    );

    _attendedSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('attended_activities')
        .snapshots()
        .listen(
          (snapshot) {
        if (mounted) {
          setState(() {
            _attendedDocs = snapshot.docs;
            _attendedActivityIds = snapshot.docs.map((doc) => doc.id).toSet();
            _isLoadingAttended = false;
          });
        }
      },
      onError: (e) {
        debugPrint('Lỗi stream attended_activities: $e');
        if (mounted) setState(() => _isLoadingAttended = false);
      },
    );
  }

  @override
  void dispose() {
    _activitiesSub?.cancel();
    _attendedSub?.cancel();
    super.dispose();
  }

  Color _backgroundColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F9FC);

  Color _surfaceColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

  Color _primaryTextColor(bool isDarkMode) =>
      isDarkMode ? Colors.white : const Color(0xFF1E1E1E);

  Color _secondaryTextColor(bool isDarkMode) =>
      isDarkMode ? Colors.white70 : const Color(0xFF6B7280);

  Color _borderColor(bool isDarkMode) =>
      isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB);

  DateTime _parseDateTime(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return DateTime.fromMillisecondsSinceEpoch(parsed);
      final dateParsed = DateTime.tryParse(raw);
      if (dateParsed != null) return dateParsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return 'Chưa xác định';
    final dt = _parseDateTime(raw);
    if (dt.millisecondsSinceEpoch == 0) return raw.toString();
    return DateFormat('HH:mm - dd/MM/yyyy').format(dt);
  }

  void _showActivityDetailModal(
      BuildContext context,
      bool isDarkMode,
      Map<String, dynamic> data,
      bool isCheckedIn,
      ) {
    final title = data['title']?.toString() ?? 'Hoạt động trường';
    final description = data['description']?.toString() ?? 'Không có mô tả.';
    final location = data['location']?.toString() ?? 'Chưa cập nhật địa điểm';
    final organizer = data['organizerName']?.toString() ?? 'Đơn vị tổ chức';
    final point = (data['trainingPoint'] as num? ?? 0).toInt();
    final status = data['status']?.toString() ?? 'active';
    final isActive = status == 'active';
    final startTime = _formatDateTime(data['startTime']);
    final endTime = _formatDateTime(data['endTime']);
    final requiresRegistration = data['requiresRegistration'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: _surfaceColor(isDarkMode),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF10B981).withOpacity(0.12)
                            : Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive
                                ? Icons.sensors_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 14,
                            color: isActive
                                ? const Color(0xFF10B981)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? 'Đang mở check-in' : 'Đã đóng check-in',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? const Color(0xFF10B981)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9900), Color(0xFFFF5500)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '+$point ĐRL',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: _primaryTextColor(isDarkMode),
                  ),
                ),
                const SizedBox(height: 16),

                _buildInfoRow(
                  isDarkMode,
                  Icons.business_rounded,
                  'Đơn vị tổ chức',
                  organizer,
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  isDarkMode,
                  Icons.location_on_rounded,
                  'Địa điểm',
                  location,
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  isDarkMode,
                  Icons.access_time_filled_rounded,
                  'Thời gian bắt đầu',
                  startTime,
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  isDarkMode,
                  Icons.timer_off_rounded,
                  'Thời gian kết thúc',
                  endTime,
                ),
                if (requiresRegistration) ...[
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    isDarkMode,
                    Icons.how_to_reg_rounded,
                    'Đăng ký',
                    'Yêu cầu sinh viên thuộc danh sách đăng ký trước',
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                Text(
                  'Mô tả chi tiết',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _primaryTextColor(isDarkMode),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    height: 1.5,
                    color: _secondaryTextColor(isDarkMode),
                  ),
                ),
                const SizedBox(height: 24),

                if (isCheckedIn)
                  Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Color(0xFF10B981), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Bạn đã điểm danh hoạt động này',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isActive)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => const EventQrScannerDialog(),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Quét mã QR để điểm danh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
      bool isDarkMode,
      IconData icon,
      String label,
      String value,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6C63FF)),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: _primaryTextColor(isDarkMode),
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _secondaryTextColor(isDarkMode),
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Center(
        child: Text(
          'Vui lòng đăng nhập để xem danh sách hoạt động.',
          style: TextStyle(color: _secondaryTextColor(isDarkMode)),
        ),
      );
    }

    if (_isLoadingActivities && _isLoadingAttended) {
      return const Center(child: CircularProgressIndicator());
    }

    int totalEvents = _attendedDocs.length;
    int totalPoints = 0;
    for (final doc in _attendedDocs) {
      final data = doc.data();
      totalPoints += (data['trainingPoint'] as num? ?? 0).toInt();
    }

    return Container(
      color: _backgroundColor(isDarkMode),
      child: Column(
        children: [
          // 1. Stats Header Box
          _buildStatsHeader(
            context,
            isDarkMode,
            totalEvents,
            totalPoints,
          ),

          // 2. Segmented Switcher
          _buildSegmentedSwitcher(
            isDarkMode,
            _attendedDocs.length,
          ),

          // 3. Content List
          Expanded(
            child: IndexedStack(
              index: _selectedSegment,
              children: [
                _buildSchoolActivitiesList(
                  context,
                  isDarkMode,
                ),
                _buildAttendanceHistoryList(
                  context,
                  isDarkMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(
      BuildContext context,
      bool isDarkMode,
      int totalEvents,
      int totalPoints,
      ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                value: totalEvents.toString(),
                label: 'Đã điểm danh',
                icon: Icons.event_available_rounded,
              ),
              Container(
                width: 1,
                height: 46,
                color: Colors.white24,
              ),
              _buildStatItem(
                value: '+$totalPoints',
                label: 'Điểm rèn luyện',
                icon: Icons.offline_bolt_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const EventQrScannerDialog(),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.35)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Quét mã QR điểm danh ngay',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 26),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 12,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedSwitcher(
      bool isDarkMode,
      int historyCount,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              index: 0,
              label: '🎯 Hoạt động trường',
              isSelected: _selectedSegment == 0,
              isDarkMode: isDarkMode,
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              index: 1,
              label: '📜 Lịch sử ($historyCount)',
              isSelected: _selectedSegment == 1,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required String label,
    required bool isSelected,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedSegment = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? const Color(0xFF3A3A3A) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected && !isDarkMode
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
            color: isSelected
                ? (isDarkMode ? Colors.white : const Color(0xFF6C63FF))
                : _secondaryTextColor(isDarkMode),
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolActivitiesList(
      BuildContext context,
      bool isDarkMode,
      ) {
    final filteredDocs = _activitiesDocs.where((doc) {
      final data = doc.data();
      final status = data['status']?.toString();
      return status != 'deleted';
    }).toList();

    filteredDocs.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      final statusA = dataA['status'] == 'active' ? 0 : 1;
      final statusB = dataB['status'] == 'active' ? 0 : 1;

      if (statusA != statusB) return statusA.compareTo(statusB);

      final dtA = _parseDateTime(dataA['startTime']);
      final dtB = _parseDateTime(dataB['startTime']);

      return dtB.compareTo(dtA);
    });

    if (filteredDocs.isEmpty) {
      return _buildEmptyState(
        context,
        isDarkMode,
        title: 'Chưa có hoạt động nào',
        subtitle:
        'Hiện tại chưa có hoạt động ĐRL từ trường. Vui lòng quay lại sau!',
        icon: Icons.event_note_rounded,
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: filteredDocs.length,
      itemBuilder: (context, index) {
        final doc = filteredDocs[index];
        final data = doc.data();
        final activityId = doc.id;
        final isCheckedIn = _attendedActivityIds.contains(activityId);

        return _buildSchoolActivityCard(
          context,
          isDarkMode,
          activityId,
          data,
          isCheckedIn,
        );
      },
    );
  }

  Widget _buildSchoolActivityCard(
      BuildContext context,
      bool isDarkMode,
      String activityId,
      Map<String, dynamic> data,
      bool isCheckedIn,
      ) {
    final title = data['title']?.toString() ?? 'Hoạt động trường';
    final organizer = data['organizerName']?.toString() ?? 'Đơn vị tổ chức';
    final location = data['location']?.toString() ?? 'Địa điểm chưa cập nhật';
    final point = (data['trainingPoint'] as num? ?? 0).toInt();
    final status = data['status']?.toString() ?? 'active';
    final isActive = status == 'active';
    final startTimeStr = _formatDateTime(data['startTime']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? const Color(0xFF6C63FF).withOpacity(0.3)
              : _borderColor(isDarkMode),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isDarkMode
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () =>
              _showActivityDetailModal(context, isDarkMode, data, isCheckedIn),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF10B981).withOpacity(0.12)
                            : Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF10B981)
                                  : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isActive ? 'Đang mở check-in' : 'Đã kết thúc',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? const Color(0xFF10B981)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+$point ĐRL',
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
                const SizedBox(height: 10),

                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _primaryTextColor(isDarkMode),
                  ),
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    Icon(Icons.business_rounded,
                        size: 14, color: _secondaryTextColor(isDarkMode)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        organizer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          color: _secondaryTextColor(isDarkMode),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 14, color: _secondaryTextColor(isDarkMode)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          color: _secondaryTextColor(isDarkMode),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 14, color: _secondaryTextColor(isDarkMode)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        startTimeStr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: _secondaryTextColor(isDarkMode),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: isCheckedIn
                            ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF10B981), size: 16),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Đã điểm danh',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            : isActive
                            ? ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) =>
                              const EventQrScannerDialog(),
                            );
                          },
                          icon: const Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 16),
                          label: const Text(
                            'Quét QR điểm danh',
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        )
                            : Text(
                          'Nhấn để xem chi tiết',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: _secondaryTextColor(isDarkMode),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: _secondaryTextColor(isDarkMode),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceHistoryList(
      BuildContext context,
      bool isDarkMode,
      ) {
    if (_attendedDocs.isEmpty) {
      return _buildEmptyState(
        context,
        isDarkMode,
        title: 'Chưa có lịch sử điểm danh',
        subtitle:
        'Hãy tham gia các hoạt động trường và quét mã QR để tích lũy điểm rèn luyện nhé!',
        icon: Icons.history_rounded,
      );
    }

    return Column(
      children: [
        _buildNoticeBox(isDarkMode),
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _attendedDocs.length,
            itemBuilder: (context, index) {
              final data = _attendedDocs[index].data();
              return _buildActivityHistoryCard(context, isDarkMode, data);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityHistoryCard(
      BuildContext context,
      bool isDarkMode,
      Map<String, dynamic> data,
      ) {
    final title = data['title']?.toString() ?? 'Hoạt động';
    final point = (data['trainingPoint'] as num? ?? 0).toInt();
    final organizer = data['organizerName']?.toString() ?? 'Đơn vị tổ chức';
    final checkedInAt = data['checkedInAt'];
    final method = data['checkInMethod']?.toString() ?? 'student_qr';

    String checkedInText = 'Vừa xong';
    if (checkedInAt is Timestamp) {
      final date = checkedInAt.toDate();
      checkedInText = DateFormat('HH:mm - dd/MM/yyyy').format(date);
    }

    final isStudentQr = method == 'student_qr';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(isDarkMode)),
        boxShadow: isDarkMode
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isStudentQr
                  ? const Color(0xFF6797E1).withOpacity(0.12)
                  : const Color(0xFF00D4AA).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isStudentQr ? Icons.qr_code_2_rounded : Icons.camera_alt_rounded,
              color: isStudentQr
                  ? const Color(0xFF6797E1)
                  : const Color(0xFF00D4AA),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _primaryTextColor(isDarkMode),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  organizer,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: _secondaryTextColor(isDarkMode),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: _secondaryTextColor(isDarkMode),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      checkedInText,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: _secondaryTextColor(isDarkMode),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+$point ĐRL',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context,
      bool isDarkMode, {
        required String title,
        required String subtitle,
        required IconData icon,
      }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: _secondaryTextColor(isDarkMode).withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _primaryTextColor(isDarkMode),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              color: _secondaryTextColor(isDarkMode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBox(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.orangeAccent.withOpacity(0.08)
            : Colors.orangeAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orangeAccent.withOpacity(0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.orangeAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Lưu ý: Điểm rèn luyện tích lũy hiển thị phía trên chỉ là tổng điểm dự kiến từ các sự kiện bạn đã điểm danh. Điểm cộng thực tế tối đa cho từng nhóm nội dung sẽ được tính theo quy chế đánh giá ĐRL hiện hành của Trường.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : const Color(0xFF5C4010),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
