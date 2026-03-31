import 'package:flutter/material.dart';
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

  static const Color primaryBlue = Color(0xFF6797E1);
  static const Color primaryBrown = Color(0xFF47352E);
  static const Color figmaBlueBg = Color(0xFFF2F6FF);
  static const Color figmaSelectionBlue = Color(0xFF5893D8);
  static const Color figmaDetailBtn = Color(0xFF1088AE);

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
    final now = DateTime.now();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('personal_events')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('dateTime', descending: _listFilter == 'Xa nhất')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList());
  }

  // CẬP NHẬT: Hàm lấy ngày giờ linh hoạt theo tháng được chọn
  List<DateTime> _getDaysInWeek() {
    // Nếu ngày đang chọn không thuộc tháng đang lọc, thì reset về ngày đầu tiên của tháng đó
    DateTime baseDay = _selectedDay!;
    if (baseDay.month != _selectedMonth) {
      baseDay = DateTime(DateTime.now().year, _selectedMonth, 1);
    }

    DateTime firstDayOfWeek = baseDay.subtract(Duration(days: baseDay.weekday % 7));
    return List.generate(7, (index) => firstDayOfWeek.add(Duration(days: index)));
  }

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
              Text(
                "Chọn ngày",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 300,
                width: 300,
                child: CalendarDatePicker(
                  initialDate: _selectedDay!,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                  onDateChanged: (date) {
                    setState(() {
                      _selectedDay = date;
                      _focusedDay = date;
                      _selectedMonth = date.month;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventDetailsBottomSheet(BuildContext context, EventModel ev, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    ev.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
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
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(EventModel ev) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: Text("Bạn có chắc chắn muốn xóa sự kiện '${ev.title}' không?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('personal_events')
                    .doc(ev.id)
                    .delete();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Đã xóa sự kiện")),
                );
              }
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (_viewTabController == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<EventModel>>(
          stream: _getEventsStream(),
          builder: (context, snapshot) {
            final List<EventModel> allEvents = snapshot.data ?? [];
            int count = _viewTabController!.index == 0
                ? allEvents.length
                : allEvents.where((e) => DateUtils.isSameDay(e.dateTime, _selectedDay)).length;

            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _viewTabController!.index == 0
                            ? _buildListFilter(isDarkMode)
                            : _buildMonthPicker(isDarkMode),
                        const Spacer(),
                        _buildViewSwitcher(isDarkMode),
                      ],
                    ),
                  ),
                ),
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
          }),
    );
  }

  Widget _buildViewSwitcher(bool isDarkMode) {
    return Container(
      height: 42,
      width: 96,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white10 : const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: _viewTabController!.index == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              width: 44,
              height: 34,
              decoration: BoxDecoration(
                color: primaryBrown,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
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

  Widget _buildListView(List<EventModel> events, bool isDarkMode) {
    if (events.isEmpty) return const Center(child: Text("Không có sự kiện sắp tới."));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: events.length,
      itemBuilder: (context, i) => _buildLargeEventCard(events[i], isDarkMode),
    );
  }

  Widget _buildCalendarView(List<EventModel> events, bool isDarkMode) {
    final dayEvents = events.where((e) => DateUtils.isSameDay(e.dateTime, _selectedDay)).toList();
    dayEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final weekDays = _getDaysInWeek();

    return Container(
      color: isDarkMode ? Colors.black26 : figmaBlueBg,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: weekDays.length,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (context, index) {
                DateTime day = weekDays[index];
                bool isSelected = DateUtils.isSameDay(day, _selectedDay);
                String label = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'][day.weekday % 7];

                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = day),
                  child: Container(
                    width: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? figmaSelectionBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black54, fontSize: 12)),
                        Text("${day.day}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                IconButton(
                  onPressed: () => _showFullCalendarPopup(isDarkMode),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  child: Row(
                    children: const [
                      Text("Time", style: TextStyle(fontFamily: 'Poppins', fontSize: 17)),
                      SizedBox(width: 45),
                      Text("Event", style: TextStyle(fontFamily: 'Poppins', fontSize: 17)),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 35),
                  child: Divider(color: Color(0xFF949494)),
                ),
                Stack(
                  children: [
                    Positioned(
                      left: 83, top: 0, bottom: 0,
                      child: Container(width: 1, color: const Color(0xFF949494)),
                    ),
                    Column(
                      children: dayEvents.isEmpty
                          ? [
                        Padding(
                          padding: const EdgeInsets.only(top: 50, left: 100),
                          child: Text("Không có sự kiện", style: TextStyle(color: Colors.black54)),
                        )
                      ]
                          : dayEvents.asMap().entries.map((entry) => _buildTimelineRow(isDarkMode, entry.value, entry.key)).toList(),
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

  Widget _buildTimelineRow(bool isDarkMode, EventModel ev, int index) {
    Color cardBg = index % 2 == 0 ? const Color(0xFFD6FBD5) : const Color(0xFFFBF5D5);
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Center(
              child: Text(
                DateFormat('HH:mm').format(ev.dateTime),
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 19),
              ),
            ),
          ),
          const SizedBox(width: 25),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(ev.title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 18))),
                      _buildMoreMenu(ev, isDarkMode),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18),
                      const SizedBox(width: 4),
                      Expanded(child: Text(ev.location, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => _showEventDetailsBottomSheet(context, ev, isDarkMode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(color: figmaDetailBtn, borderRadius: BorderRadius.circular(20)),
                        child: const Text("Details", style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
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

  Widget _buildLargeEventCard(EventModel ev, bool isDarkMode) {
    final diff = ev.dateTime.difference(DateTime.now());
    String timeText = diff.inDays > 0 ? "${diff.inDays} days left" : (diff.inHours > 0 ? "${diff.inHours} hours left" : "${diff.inMinutes} mins left");
    return Container(
      height: 150, margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(image: AssetImage('assets/images/background.jpg'), fit: BoxFit.cover, opacity: 0.6, colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(ev.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
              _buildMoreMenu(ev, isDarkMode),
            ],
          ),
          const Spacer(),
          Text(timeText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMM d, yyyy').format(ev.dateTime), style: const TextStyle(color: Colors.white70)),
              InkWell(
                onTap: () => _showEventDetailsBottomSheet(context, ev, isDarkMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: figmaDetailBtn, borderRadius: BorderRadius.circular(8)),
                  child: const Text("Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          Navigator.push(context, MaterialPageRoute(builder: (context) => CreatePersonalEventPage(event: ev)));
        } else if (value == 'delete') {
          _confirmDelete(ev);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Chỉnh sửa")])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Xóa", style: TextStyle(color: Colors.red))])),
      ],
    );
  }

  Widget _buildMonthPicker(bool isDarkMode) {
    return PopupMenuButton<int>(
      onSelected: (m) {
        setState(() {
          _selectedMonth = m;
          _selectedDay = DateTime(DateTime.now().year, m, 1);
          _focusedDay = _selectedDay!;
        });
      },
      itemBuilder: (ctx) => List.generate(
        12,
            (i) => PopupMenuItem(
          value: i + 1,
          child: Text("Tháng ${i + 1}"),
        ),
      ),
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