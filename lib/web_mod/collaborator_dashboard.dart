import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'services/activity_service.dart';
import 'widgets/activity_card.dart';
import 'widgets/attendance_table.dart';

class CollaboratorDashboard extends StatefulWidget {
  const CollaboratorDashboard({super.key});

  @override
  State<CollaboratorDashboard> createState() => _CollaboratorDashboardState();
}

class _CollaboratorDashboardState extends State<CollaboratorDashboard> {
  int _selectedIndex = 0;
  String? _selectedActivityId;
  Map<String, dynamic>? _selectedActivityData;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _organizerController = TextEditingController();
  final _pointController = TextEditingController(text: '5');

  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _organizerController.dispose();
    _pointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          Container(
            width: 270,
            color: const Color(0xFF1A1F37),
            child: Column(
              children: [
                const SizedBox(height: 38),
                const Icon(
                  Icons.groups_2_outlined,
                  color: Colors.orangeAccent,
                  size: 52,
                ),
                const SizedBox(height: 10),
                const Text(
                  'MYUNI CTV',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                    fontSize: 21,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 34),
                _sectionTitle('QUẢN LÝ HOẠT ĐỘNG'),
                _menuItem(0, Icons.dashboard_outlined, 'Tổng quan'),
                _menuItem(1, Icons.event_note_outlined, 'Hoạt động của tôi'),
                _menuItem(2, Icons.add_circle_outline_rounded, 'Tạo hoạt động'),
                _menuItem(3, Icons.fact_check_outlined, 'Điểm danh'),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.orangeAccent,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'Collaborator',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                user?.email ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 22),
                  color: Colors.white,
                  child: Text(
                    _pageTitle(),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1F37),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _pageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Tổng quan hoạt động';
      case 1:
        return 'Hoạt động của tôi';
      case 2:
        return 'Tạo hoạt động mới';
      case 3:
        return 'Điểm danh sinh viên';
      default:
        return 'MYUNI CTV';
    }
  }

  Widget _buildContent() {
    if (_selectedIndex == 0) return _buildOverview();
    if (_selectedIndex == 1) return _buildActivities();
    if (_selectedIndex == 2) return _buildCreateActivity();
    return _buildAttendancePage();
  }

  Widget _buildOverview() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ActivityService.getMyActivities(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        final activeCount = docs.where((doc) {
          return (doc.data()['status'] ?? 'active') == 'active';
        }).length;

        final totalAttendance = docs.fold<int>(0, (sum, doc) {
          return sum + ((doc.data()['attendanceCount'] ?? 0) as int);
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              _overviewCard(
                icon: Icons.event_note_outlined,
                title: 'Hoạt động đã tạo',
                value: '${docs.length}',
                color: Colors.blueAccent,
              ),
              _overviewCard(
                icon: Icons.play_circle_outline_rounded,
                title: 'Đang mở check-in',
                value: '$activeCount',
                color: Colors.green,
              ),
              _overviewCard(
                icon: Icons.people_alt_outlined,
                title: 'Lượt check-in',
                value: '$totalAttendance',
                color: Colors.orange,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivities() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ActivityService.getMyActivities(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Firestore Error: ${snapshot.error}');

          return Center(
            child: Container(
              width: 700,
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Firestore cần tạo composite index.',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    snapshot.error.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Bạn chưa tạo hoạt động nào.',
              style: TextStyle(fontFamily: 'Nunito', color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(32),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            return ActivityCard(
              activityId: doc.id,
              data: data,
              onOpen: () {
                setState(() {
                  _selectedActivityId = doc.id;
                  _selectedActivityData = data;
                  _selectedIndex = 3;
                });
              },
              onClose: () async {
                await ActivityService.closeActivity(doc.id);
              },
              onReopen: () async {
                await ActivityService.reopenActivity(doc.id);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCreateActivity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Container(
        width: 760,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE9EEF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _input(_titleController, 'Tên hoạt động'),
            const SizedBox(height: 16),
            _input(_descriptionController, 'Mô tả hoạt động', maxLines: 4),
            const SizedBox(height: 16),
            _input(_locationController, 'Địa điểm'),
            const SizedBox(height: 16),
            _input(_organizerController, 'Đơn vị tổ chức'),
            const SizedBox(height: 16),
            _input(_pointController, 'Điểm rèn luyện dự kiến', isNumber: true),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _dateBox(
                    title: 'Bắt đầu',
                    value: _startTime,
                    onTap: () async {
                      final picked = await _pickDateTime(_startTime);
                      if (picked != null) {
                        setState(() => _startTime = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _dateBox(
                    title: 'Kết thúc',
                    value: _endTime,
                    onTap: () async {
                      final picked = await _pickDateTime(_endTime);
                      if (picked != null) {
                        setState(() => _endTime = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _handleCreateActivity,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo hoạt động'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendancePage() {
    if (_selectedActivityId == null) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE9EEF3),
            ),
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
                onPressed: () => setState(() => _selectedIndex = 1),
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

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedActivityData?['title'] ?? 'Hoạt động',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1F37),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Danh sách sinh viên đã check-in sẽ hiển thị realtime tại đây.',
            style: TextStyle(fontFamily: 'Nunito', color: Colors.grey),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Scanner QR sẽ gắn vào nút này ở bước sau.'),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Quét QR sinh viên'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Export CSV/Excel sẽ làm ở bước sau.'),
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Xuất danh sách'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ActivityService.getAttendance(_selectedActivityId!),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi tải danh sách: ${snapshot.error}'));
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
  }

  Future<void> _handleCreateActivity() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final organizer = _organizerController.text.trim();
    final point = int.tryParse(_pointController.text.trim()) ?? 0;

    if (title.isEmpty || location.isEmpty || organizer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ tên, địa điểm và đơn vị tổ chức.')),
      );
      return;
    }

    if (_endTime.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thời gian kết thúc phải sau thời gian bắt đầu.')),
      );
      return;
    }

    await ActivityService.createActivity(
      title: title,
      description: description,
      location: location,
      organizerName: organizer,
      trainingPoint: point,
      startTime: _startTime,
      endTime: _endTime,
    );

    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _organizerController.clear();
    _pointController.text = '5';

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã tạo hoạt động thành công.')),
    );

    setState(() => _selectedIndex = 1);
  }

  Widget _menuItem(int index, IconData icon, String title) {
    final selected = _selectedIndex == index;

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.orangeAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.orangeAccent : Colors.grey),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Nunito',
                color: selected ? Colors.white : Colors.grey,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontFamily: 'Nunito',
          ),
        ),
      ),
    );
  }

  Widget _overviewCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return SizedBox(
      width: 280,
      height: 130,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE9EEF3)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1F37),
                    ),
                  ),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      color: Color(0xFF667085),
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

  Widget _input(
      TextEditingController controller,
      String label, {
        int maxLines = 1,
        bool isNumber = false,
      }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dateBox({
    required String title,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    final text =
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9EEF3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Nunito', color: Colors.grey)),
                Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}