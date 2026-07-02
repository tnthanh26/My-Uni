import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StudentAttendanceHistoryTab extends StatelessWidget {
  const StudentAttendanceHistoryTab({super.key});

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Center(
        child: Text(
          'Vui lòng đăng nhập để xem lịch sử.',
          style: TextStyle(color: _secondaryTextColor(isDarkMode)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor(isDarkMode),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('attended_activities')
            .orderBy('checkedInAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi khi tải lịch sử: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          // Calculate stats
          int totalEvents = docs.length;
          int totalPoints = 0;
          for (final doc in docs) {
            final data = doc.data();
            totalPoints += (data['trainingPoint'] as num? ?? 0).toInt();
          }

          return Column(
            children: [
              // Stats Card
              _buildStatsHeader(context, isDarkMode, totalEvents, totalPoints),
              
              // Regulations Notice Box
              _buildNoticeBox(isDarkMode),

              // List Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sự kiện đã tham gia',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: _primaryTextColor(isDarkMode),
                    ),
                  ),
                ),
              ),

              // Events List
              Expanded(
                child: docs.isEmpty
                    ? _buildEmptyState(context, isDarkMode)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          return _buildActivityHistoryCard(context, isDarkMode, data);
                        },
                      ),
              ),
            ],
          );
        },
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
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            value: totalEvents.toString(),
            label: 'Sự kiện đã quét',
            icon: Icons.event_available_rounded,
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.white24,
          ),
          _buildStatItem(
            value: '+$totalPoints',
            label: 'Điểm rèn luyện',
            icon: Icons.offline_bolt_rounded,
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
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 6),
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
            fontWeight: FontWeight.w500,
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
    final title = data['title'] ?? 'Hoạt động';
    final point = data['trainingPoint'] ?? 0;
    final organizer = data['organizerName'] ?? 'Đơn vị tổ chức';
    final checkedInAt = data['checkedInAt'];
    final method = data['checkInMethod'] ?? 'student_qr';

    String checkedInText = 'Vừa xong';
    if (checkedInAt is Timestamp) {
      final date = checkedInAt.toDate();
      checkedInText = DateFormat('dd/MM/yyyy HH:mm').format(date);
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
          // Icon Box
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
              color: isStudentQr ? const Color(0xFF6797E1) : const Color(0xFF00D4AA),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Event Details
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+$point ĐRL',
                        style: const TextStyle(
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

  Widget _buildEmptyState(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: _secondaryTextColor(isDarkMode).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có hoạt động điểm danh',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _primaryTextColor(isDarkMode),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy tham gia sự kiện và quét mã QR để ghi nhận điểm rèn luyện nhé!',
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
