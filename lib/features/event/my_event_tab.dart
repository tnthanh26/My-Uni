import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_uni/models/event_model.dart';
import 'create_personal_event_page.dart';

class MyEventTab extends StatefulWidget {
  const MyEventTab({super.key});
  @override
  State<MyEventTab> createState() => _MyEventTabState();
}

class _MyEventTabState extends State<MyEventTab> with TickerProviderStateMixin {
  TabController? _viewTabController;
  int _selectedMonth = DateTime.now().month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  String _listFilter = 'Gần nhất';

  // Màu nâu theo ảnh thiết kế của Thanh
  static const Color primaryBlue = Color(0xFF6797E1);
  static const Color primaryBrown = Color(0xFF47352E);
  Color lightUiBg(bool isDark) => isDark ? Colors.white10 : const Color(0xFFF1F1F1);

  @override
  void initState() {
    super.initState();
    _viewTabController = TabController(length: 2, vsync: this);
    _viewTabController!.addListener(() {
      if (!_viewTabController!.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _viewTabController?.dispose();
    super.dispose();
  }

  Stream<List<EventModel>> _getEventsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('personal_events')
        .orderBy('dateTime', descending: _listFilter == 'Xa nhất')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList());
  }

  // Popup Lịch Tháng
  void _showFullCalendarPopup(bool isDarkMode) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Tháng ${DateFormat('MM/yyyy').format(_focusedDay)}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                headerVisible: true,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(color: primaryBrown, shape: BoxShape.circle),
                    todayDecoration: BoxDecoration(color: primaryBrown.withOpacity(0.2), shape: BoxShape.circle),
                    defaultTextStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black)
                ),
                onDaySelected: (sel, foc) {
                  setState(() { _selectedDay = sel; _focusedDay = foc; _selectedMonth = foc.month; });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HÀM HIỂN THỊ CHI TIẾT (Details) ---
  void _showEventDetailsBottomSheet(BuildContext context, EventModel ev, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(ev.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const Divider(),
            const SizedBox(height: 10),
            _buildDetailRow(Icons.access_time_filled_rounded, "Thời gian:", DateFormat('dd/MM/yyyy HH:mm').format(ev.dateTime)),
            _buildDetailRow(Icons.location_on_rounded, "Vị trí:", ev.location),
            _buildDetailRow(Icons.description_rounded, "Mô tả:", ev.description ?? "Không có mô tả"),
            _buildDetailRow(Icons.add_alert_rounded, "Nhắc nhở:", ev.reminder ?? "Không có nhắc nhở"),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (_viewTabController == null) return const SizedBox.shrink();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: primaryBrown,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
      body: StreamBuilder<List<EventModel>>(
          stream: _getEventsStream(),
          builder: (context, snapshot) {
            final List<EventModel> allEvents = snapshot.data ?? [];

            // Logic đếm số lượng sự kiện
            int count = _viewTabController!.index == 0
                ? allEvents.length
                : allEvents.where((e) => isSameDay(e.dateTime, _selectedDay)).length;

            return CustomScrollView(
              slivers: [
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),

                // 1. THANH CÔNG CỤ
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _viewTabController!.index == 0 ? _buildListFilter(isDarkMode) : _buildMonthPicker(isDarkMode),
                        const Spacer(),
                        _buildViewSwitcher(isDarkMode),
                      ],
                    ),
                  ),
                ),

                // 2. DÒNG TEXT ĐẾM SỰ KIỆN
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: Text(
                        "Bạn đang có $count sự kiện sắp diễn ra",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ),

                // 3. NỘI DUNG
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _viewTabController,
                    children: [
                      _buildListView(allEvents, isDarkMode),
                      _buildCalendarView(allEvents, isDarkMode),
                    ],
                  ),
                ),
              ],
            );
          }
      ),
    );
  }

  Widget _buildViewSwitcher(bool isDarkMode) {
    return Container(
      height: 42,
      width: 96,
      padding: const EdgeInsets.all(4), // Padding đều 4 cạnh
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white10 : const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          // Box màu nâu chạy qua lại
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: _viewTabController!.index == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              width: 44,
              height: 34, // Chiều cao cố định để fit với padding ngoài
              decoration: BoxDecoration(
                color: primaryBrown,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // Icon đè lên trên và dùng Center để căn giữa icon vào box
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _viewTabController!.animateTo(0),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Icon(
                      Icons.list_alt_rounded,
                      size: 22,
                      color: _viewTabController!.index == 0 ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _viewTabController!.animateTo(1),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Icon(
                      Icons.calendar_month_outlined,
                      size: 22,
                      color: _viewTabController!.index == 1 ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoreMenu(EventModel ev, bool isDarkMode) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: _viewTabController!.index == 0 ? Colors.white : Colors.black54),
      onSelected: (value) {
        if (value == 'edit') {
          // 1. Chuyển sang trang tạo với dữ liệu có sẵn (Cần chỉnh lại constructor bên CreatePersonalEventPage)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePersonalEventPage(event: ev),
            ),
          );
        } else if (value == 'delete') {
          // 2. Hiện confirm xóa
          _confirmDelete(ev);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Chỉnh sửa")])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Xóa", style: TextStyle(color: Colors.red))])),
      ],
    );
  }

// Hàm xác nhận xóa
  void _confirmDelete(EventModel ev) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: Text("Bạn có chắc chắn muốn xóa sự kiện '${ev.title}' không?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          TextButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users').doc(user.uid)
                    .collection('personal_events').doc(ev.id) // ev.id lấy từ doc.id trong model
                    .delete();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa sự kiện")));
              }
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<EventModel> events, bool isDarkMode) {
    if (events.isEmpty) return const Center(child: Text("Không có sự kiện."));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: events.length,
      itemBuilder: (context, i) => _buildLargeEventCard(events[i], isDarkMode),
    );
  }

  Widget _buildCalendarView(List<EventModel> events, bool isDarkMode) {
    final dayEvents = events.where((e) => isSameDay(e.dateTime, _selectedDay)).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: CalendarFormat.week,
          headerVisible: false,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (sel, foc) => setState(() { _selectedDay = sel; _focusedDay = foc; }),
          calendarStyle: CalendarStyle(
            selectedDecoration: const BoxDecoration(color: primaryBlue, shape: BoxShape.circle),
            todayDecoration: BoxDecoration(color: primaryBrown.withOpacity(0.2), shape: BoxShape.circle),
            defaultTextStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
        ),
        IconButton(
            onPressed: () => _showFullCalendarPopup(isDarkMode),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey)),
        const Row(children: [Text("Time", style: TextStyle(color: Colors.grey)), SizedBox(width: 30), Text("Event", style: TextStyle(color: Colors.grey))]),
        const Divider(),
        ...dayEvents.asMap().entries.map((entry) => _buildTimelineRow(isDarkMode, entry.value, entry.key)).toList(),
      ],
    );
  }

  Widget _buildLargeEventCard(EventModel ev, bool isDarkMode) {
    final diff = ev.dateTime.difference(DateTime.now());
    return Container(
      height: 150, margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(
            image: NetworkImage('https://student.hcmus.edu.vn/_next/image?url=%2Fbackground.jpg&w=3840&q=75'),
            fit: BoxFit.cover,
            opacity: 0.6, // Tăng opacity lên để ảnh sáng rõ hơn
            colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken)
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(ev.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
            _buildMoreMenu(ev, isDarkMode),
          ]),
          const Spacer(),
          Text("${diff.inHours} hours left", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(DateFormat('MMM d, yyyy').format(ev.dateTime), style: const TextStyle(color: Colors.white70)),
            // Bấm vào Details này sẽ hiện BottomSheet
            InkWell(
                onTap: () => _showEventDetailsBottomSheet(context, ev, isDarkMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: const Text("Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )),
          ]),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(bool isDarkMode, EventModel ev, int index) {
    Color pastelBg = index % 2 == 0 ? const Color(0xFFC8E6C9) : const Color(0xFFFFF9C4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('HH:mm').format(ev.dateTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(width: 15),
          Expanded(
            child: InkWell(
              onTap: () => _showEventDetailsBottomSheet(context, ev, isDarkMode),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E1E1E) : pastelBg, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(ev.title, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                      _buildMoreMenu(ev, isDarkMode),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 14),
                      const SizedBox(width: 4),
                      Expanded(child: Text(ev.location, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMonthPicker(bool isDarkMode) {
    return PopupMenuButton<int>(
      onSelected: (m) => setState(() { _selectedMonth = m; _focusedDay = DateTime(2026, m, 1); }),
      itemBuilder: (ctx) => List.generate(12, (i) => PopupMenuItem(value: i + 1, child: Text("Tháng ${i + 1}"))),
      child: _filterChip(isDarkMode, "Tháng $_selectedMonth"),
    );
  }

  Widget _buildListFilter(bool isDarkMode) {
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => _listFilter = v),
      itemBuilder: (ctx) => [const PopupMenuItem(value: 'Gần nhất', child: Text('Gần nhất')), const PopupMenuItem(value: 'Xa nhất', child: Text('Xa nhất'))],
      child: _filterChip(isDarkMode, _listFilter),
    );
  }

  Widget _filterChip(bool isDarkMode, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: lightUiBg(isDarkMode), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.withOpacity(0.1))),
      child: Row(children: [Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)), const Icon(Icons.keyboard_arrow_down, size: 16)]),
    );
  }
}