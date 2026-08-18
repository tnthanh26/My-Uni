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
                _attendedActivityIds = snapshot.docs
                    .map((doc) => doc.id)
                    .toSet();
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
    const Color primaryColor = Color(0xFF5893D8);
    const Color successColor = Color(0xFF2E9D65);
    const Color pointColor = Color(0xFFD99518);

    final Color sheetColor = isDarkMode
        ? const Color(0xFF1C1E21)
        : Colors.white;

    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE4E7EC);

    final Color primaryTextColor = _primaryTextColor(isDarkMode);

    final Color secondaryTextColor = _secondaryTextColor(isDarkMode);

    final String title = data['title']?.toString() ?? 'Hoạt động trường';

    final String description =
        data['description']?.toString() ?? 'Không có mô tả.';

    final String location =
        data['location']?.toString() ?? 'Chưa cập nhật địa điểm';

    final String organizer =
        data['organizerName']?.toString() ?? 'Đơn vị tổ chức';

    final int point = (data['trainingPoint'] as num? ?? 0).toInt();

    final String status = data['status']?.toString() ?? 'active';

    final bool isActive = status == 'active';

    final String startTime = _formatDateTime(data['startTime']);

    final String endTime = _formatDateTime(data['endTime']);

    final bool requiresRegistration = data['requiresRegistration'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.44),
      builder: (bottomContext) {
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(bottomContext).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white24
                        : const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? successColor.withValues(alpha: 0.11)
                                    : secondaryTextColor.withValues(
                                        alpha: 0.10,
                                      ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? successColor
                                          : secondaryTextColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isActive
                                        ? 'Đang mở điểm danh'
                                        : 'Đã đóng điểm danh',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isActive
                                          ? successColor
                                          : secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: pointColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+$point ĐRL',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: pointColor,
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
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            height: 1.3,
                            color: primaryTextColor,
                          ),
                        ),

                        const SizedBox(height: 18),

                        _buildActivityInfoRow(
                          isDarkMode: isDarkMode,
                          icon: Icons.business_outlined,
                          label: 'Đơn vị tổ chức',
                          value: organizer,
                        ),

                        const SizedBox(height: 12),

                        _buildActivityInfoRow(
                          isDarkMode: isDarkMode,
                          icon: Icons.location_on_outlined,
                          label: 'Địa điểm',
                          value: location,
                        ),

                        const SizedBox(height: 12),

                        _buildActivityInfoRow(
                          isDarkMode: isDarkMode,
                          icon: Icons.access_time_rounded,
                          label: 'Bắt đầu',
                          value: startTime,
                        ),

                        const SizedBox(height: 12),

                        _buildActivityInfoRow(
                          isDarkMode: isDarkMode,
                          icon: Icons.timelapse_rounded,
                          label: 'Kết thúc',
                          value: endTime,
                        ),

                        if (requiresRegistration) ...[
                          const SizedBox(height: 12),
                          _buildActivityInfoRow(
                            isDarkMode: isDarkMode,
                            icon: Icons.how_to_reg_outlined,
                            label: 'Điều kiện',
                            value:
                                'Yêu cầu sinh viên thuộc danh sách đăng ký trước',
                          ),
                        ],

                        const SizedBox(height: 20),

                        Divider(height: 1, color: borderColor),

                        const SizedBox(height: 18),

                        Text(
                          'Thông tin chi tiết',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: primaryTextColor,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          description,
                          style: TextStyle(
                            fontFamily: 'Encode Sans Expanded',
                            fontSize: 12.5,
                            height: 1.55,
                            color: secondaryTextColor,
                          ),
                        ),

                        const SizedBox(height: 22),

                        if (isCheckedIn)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: successColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: successColor.withValues(alpha: 0.28),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: successColor,
                                  size: 19,
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Bạn đã điểm danh hoạt động này',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Encode Sans Expanded',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: successColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isActive)
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(bottomContext);

                                showDialog(
                                  context: context,
                                  builder: (_) => const EventQrScannerDialog(),
                                );
                              },
                              icon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Quét mã QR để điểm danh',
                                style: TextStyle(
                                  fontFamily: 'Encode Sans Expanded',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                      ],
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

  Widget _buildActivityInfoRow({
    required bool isDarkMode,
    required IconData icon,
    required String label,
    required String value,
  }) {
    const Color primaryColor = Color(0xFF5893D8);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: isDarkMode ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: primaryColor),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: _secondaryTextColor(isDarkMode),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: _primaryTextColor(isDarkMode),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Vui lòng đăng nhập để xem danh sách hoạt động.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 12.5,
              color: _secondaryTextColor(isDarkMode),
            ),
          ),
        ),
      );
    }

    if (_isLoadingActivities && _isLoadingAttended) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5893D8)),
      );
    }

    final int totalEvents = _attendedDocs.length;

    int totalPoints = 0;

    for (final doc in _attendedDocs) {
      final data = doc.data();

      totalPoints += (data['trainingPoint'] as num? ?? 0).toInt();
    }

    return Container(
      color: _backgroundColor(isDarkMode),
      child: Column(
        children: [
          _buildStatsHeader(context, isDarkMode, totalEvents, totalPoints),

          _buildSegmentedSwitcher(isDarkMode, _attendedDocs.length),

          const SizedBox(height: 6),

          Expanded(
            child: IndexedStack(
              index: _selectedSegment,
              children: [
                _buildSchoolActivitiesList(context, isDarkMode),
                _buildAttendanceHistoryList(context, isDarkMode),
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
    const Color primaryColor = Color(0xFF5893D8);

    const Color pointColor = Color(0xFFD99518);

    final Color cardColor = isDarkMode ? const Color(0xFF1C1E21) : Colors.white;

    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE4E7EC);

    final Color secondaryTextColor = _secondaryTextColor(isDarkMode);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: isDarkMode
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tổng quan điểm danh',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _primaryTextColor(isDarkMode),
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  value: totalEvents.toString(),
                  label: 'Đã điểm danh',
                  valueColor: primaryColor,
                  textColor: secondaryTextColor,
                ),
              ),

              Container(width: 1, height: 46, color: borderColor),

              Expanded(
                child: _buildStatItem(
                  value: '+$totalPoints',
                  label: 'Điểm dự kiến',
                  valueColor: pointColor,
                  textColor: secondaryTextColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const EventQrScannerDialog(),
                );
              },
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text(
                'Quét mã QR điểm danh',
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
    IconData? icon,
    required Color valueColor,
    required Color textColor,
  }) {
    return Column(
      children: [
        if (icon != null) ...[
          Icon(icon, color: valueColor, size: 22),
          const SizedBox(height: 5),
        ],
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 11.5,
            fontFamily: 'Encode Sans Expanded',
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedSwitcher(bool isDarkMode, int historyCount) {
    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE4E7EC);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF24272B) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              index: 0,
              label: 'Hoạt động',
              isSelected: _selectedSegment == 0,
              isDarkMode: isDarkMode,
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              index: 1,
              label: 'Lịch sử ($historyCount)',
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
    const Color primaryColor = Color(0xFF5893D8);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSegment = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? const Color(0xFF34373C) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected && !isDarkMode
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12,
            color: isSelected ? primaryColor : _secondaryTextColor(isDarkMode),
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolActivitiesList(BuildContext context, bool isDarkMode) {
    final filteredDocs = _activitiesDocs.where((doc) {
      final data = doc.data();
      final status = data['status']?.toString();

      return status != 'deleted';
    }).toList();

    filteredDocs.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      final int statusA = dataA['status'] == 'active' ? 0 : 1;

      final int statusB = dataB['status'] == 'active' ? 0 : 1;

      if (statusA != statusB) {
        return statusA.compareTo(statusB);
      }

      final DateTime dtA = _parseDateTime(dataA['startTime']);

      final DateTime dtB = _parseDateTime(dataB['startTime']);

      return dtB.compareTo(dtA);
    });

    if (filteredDocs.isEmpty) {
      return _buildEmptyState(
        context,
        isDarkMode,
        title: 'Chưa có hoạt động nào',
        subtitle:
            'Hiện tại chưa có hoạt động điểm rèn luyện từ trường. Vui lòng quay lại sau.',
        icon: Icons.event_note_outlined,
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      itemCount: filteredDocs.length,
      itemBuilder: (context, index) {
        final doc = filteredDocs[index];
        final data = doc.data();
        final String activityId = doc.id;

        final bool isCheckedIn = _attendedActivityIds.contains(activityId);

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
    const Color primaryColor = Color(0xFF5893D8);

    const Color successColor = Color(0xFF2E9D65);

    const Color pointColor = Color(0xFFD99518);

    final String title = data['title']?.toString() ?? 'Hoạt động trường';

    final String organizer =
        data['organizerName']?.toString() ?? 'Đơn vị tổ chức';

    final String location =
        data['location']?.toString() ?? 'Địa điểm chưa cập nhật';

    final int point = (data['trainingPoint'] as num? ?? 0).toInt();

    final String status = data['status']?.toString() ?? 'active';

    final bool isActive = status == 'active';

    final String startTimeStr = _formatDateTime(data['startTime']);

    final Color borderColor = _borderColor(isDarkMode);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDarkMode
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showActivityDetailModal(context, isDarkMode, data, isCheckedIn);
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? successColor.withValues(alpha: 0.11)
                            : _secondaryTextColor(
                                isDarkMode,
                              ).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? successColor
                                  : _secondaryTextColor(isDarkMode),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isActive ? 'Đang mở điểm danh' : 'Đã kết thúc',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? successColor
                                  : _secondaryTextColor(isDarkMode),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pointColor.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+$point ĐRL',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: pointColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 11),

                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.3,
                    color: _primaryTextColor(isDarkMode),
                  ),
                ),

                const SizedBox(height: 8),

                _buildCompactActivityRow(
                  isDarkMode: isDarkMode,
                  icon: Icons.business_outlined,
                  text: organizer,
                ),

                const SizedBox(height: 6),

                _buildCompactActivityRow(
                  isDarkMode: isDarkMode,
                  icon: Icons.location_on_outlined,
                  text: location,
                ),

                const SizedBox(height: 6),

                _buildCompactActivityRow(
                  isDarkMode: isDarkMode,
                  icon: Icons.schedule_rounded,
                  text: startTimeStr,
                  maxLines: 2,
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: isCheckedIn
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: successColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: successColor,
                                      size: 16,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Đã điểm danh',
                                      style: TextStyle(
                                        fontFamily: 'Encode Sans Expanded',
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: successColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : isActive
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) =>
                                        const EventQrScannerDialog(),
                                  );
                                },
                                icon: const Icon(
                                  Icons.qr_code_scanner_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Quét QR',
                                  style: TextStyle(
                                    fontFamily: 'Encode Sans Expanded',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  minimumSize: const Size(0, 38),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              'Nhấn để xem chi tiết',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 11.5,
                                color: _secondaryTextColor(isDarkMode),
                              ),
                            ),
                    ),

                    const SizedBox(width: 8),

                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
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

  Widget _buildCompactActivityRow({
    required bool isDarkMode,
    required IconData icon,
    required String text,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: _secondaryTextColor(isDarkMode)),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 11.5,
              height: 1.4,
              color: _secondaryTextColor(isDarkMode),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceHistoryList(BuildContext context, bool isDarkMode) {
    if (_attendedDocs.isEmpty) {
      return _buildEmptyState(
        context,
        isDarkMode,
        title: 'Chưa có lịch sử điểm danh',
        subtitle:
            'Hãy tham gia hoạt động trường và quét mã QR để tích lũy điểm rèn luyện.',
        icon: Icons.history_rounded,
      );
    }

    return Column(
      children: [
        _buildNoticeBox(isDarkMode),

        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
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
    const Color primaryColor = Color(0xFF5893D8);

    const Color successColor = Color(0xFF2E9D65);

    const Color pointColor = Color(0xFFD99518);

    final String title = data['title']?.toString() ?? 'Hoạt động';

    final int point = (data['trainingPoint'] as num? ?? 0).toInt();

    final String organizer =
        data['organizerName']?.toString() ?? 'Đơn vị tổ chức';

    final checkedInAt = data['checkedInAt'];

    final String method = data['checkInMethod']?.toString() ?? 'student_qr';

    String checkedInText = 'Vừa xong';

    if (checkedInAt is Timestamp) {
      final date = checkedInAt.toDate();

      checkedInText = DateFormat('HH:mm - dd/MM/yyyy').format(date);
    }

    final bool isStudentQr = method == 'student_qr';

    final Color accentColor = isStudentQr ? primaryColor : successColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(isDarkMode)),
        boxShadow: isDarkMode
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isStudentQr ? Icons.qr_code_2_rounded : Icons.camera_alt_outlined,
              color: accentColor,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    height: 1.3,
                    color: _primaryTextColor(isDarkMode),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  organizer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 11.5,
                    color: _secondaryTextColor(isDarkMode),
                  ),
                ),

                const SizedBox(height: 9),

                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: _secondaryTextColor(isDarkMode),
                    ),

                    const SizedBox(width: 5),

                    Expanded(
                      child: Text(
                        checkedInText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 11,
                          color: _secondaryTextColor(isDarkMode),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pointColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '+$point ĐRL',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: pointColor,
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
    const Color primaryColor = Color(0xFF5893D8);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: isDarkMode ? 0.14 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 31, color: primaryColor),
            ),

            const SizedBox(height: 15),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _primaryTextColor(isDarkMode),
              ),
            ),

            const SizedBox(height: 7),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 12,
                height: 1.5,
                color: _secondaryTextColor(isDarkMode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeBox(bool isDarkMode) {
    const Color pointColor = Color(0xFFD99518);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pointColor.withValues(alpha: isDarkMode ? 0.09 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pointColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              color: pointColor,
              size: 18,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              'Điểm hiển thị là tổng điểm dự kiến từ các hoạt động bạn đã điểm danh. Điểm chính thức vẫn được tính theo quy chế đánh giá điểm rèn luyện hiện hành của Trường.',
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 11.5,
                height: 1.48,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white70 : const Color(0xFF6B4C16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
