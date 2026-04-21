import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_uni/models/event_model.dart';

import 'create_personal_event_page.dart';
import 'interested_event_tab.dart';

class MyEventTab extends StatefulWidget {
  const MyEventTab({super.key});

  @override
  State<MyEventTab> createState() => _MyEventTabState();
}

class _MyEventTabState extends State<MyEventTab>
    with TickerProviderStateMixin {
  TabController? _viewTabController;

  int _selectedMonth = DateTime.now().month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  String _listFilter = 'Gần nhất';
  String _activeSubTab = 'Cá nhân';

  Timer? _refreshTimer;

  static const Color primaryBlue = Color(0xFF6797E1);
  static const Color primaryBrown = Color(0xFF47352E);
  static const Color figmaBlueBg = Color(0xFFF2F6FF);
  static const Color figmaSelectionBlue = Color(0xFF5893D8);
  static const Color figmaDetailBtn = Color(0xFF1088AE);

  @override
  void initState() {
    super.initState();
    _viewTabController = TabController(length: 2, vsync: this);
    _viewTabController!.addListener(() {
      if (!_viewTabController!.indexIsChanging) {
        setState(() {});
      }
    });

    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _viewTabController?.dispose();
    super.dispose();
  }

  bool get isListView => _viewTabController?.index == 0;

  Color _backgroundColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F9FC);

  Color _surfaceColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

  Color _secondarySurfaceColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF1F4F8);

  Color _primaryTextColor(bool isDarkMode) =>
      isDarkMode ? Colors.white : const Color(0xFF1E1E1E);

  Color _secondaryTextColor(bool isDarkMode) =>
      isDarkMode ? Colors.white70 : const Color(0xFF6B7280);

  Color _borderColor(bool isDarkMode) =>
      isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB);

  List<BoxShadow> _cardShadow(bool isDarkMode) => isDarkMode
      ? []
      : [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];

  Stream<List<EventModel>> _getEventsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    final now = DateTime.now();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('personal_events')
        .where(
      'dateTime',
      isGreaterThanOrEqualTo: Timestamp.fromDate(now),
    )
        .orderBy('dateTime', descending: _listFilter == 'Xa nhất')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList(),
    );
  }

  List<DateTime> _getDaysInWeek() {
    DateTime baseDay = _selectedDay!;
    if (baseDay.month != _selectedMonth) {
      baseDay = DateTime(DateTime.now().year, _selectedMonth, 1);
    }

    final firstDayOfWeek =
    baseDay.subtract(Duration(days: baseDay.weekday % 7));

    return List.generate(
      7,
          (index) => firstDayOfWeek.add(Duration(days: index)),
    );
  }

  void _showFullCalendarPopup(bool isDarkMode) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: _surfaceColor(isDarkMode),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chọn ngày',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _primaryTextColor(isDarkMode),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                width: 300,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: figmaSelectionBlue,
                      onPrimary: Colors.white,
                      surface: _surfaceColor(isDarkMode),
                      onSurface: _primaryTextColor(isDarkMode),
                    ),
                  ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventDetailsBottomSheet(
      BuildContext context,
      EventModel ev,
      bool isDarkMode,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor(isDarkMode),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ev.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _primaryTextColor(isDarkMode),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: _secondaryTextColor(isDarkMode),
                  ),
                ),
              ],
            ),
            Divider(color: _borderColor(isDarkMode)),
            const SizedBox(height: 10),
            _buildDetailRow(
              Icons.access_time_filled_rounded,
              'Thời gian',
              DateFormat('dd/MM/yyyy HH:mm').format(ev.dateTime),
              isDarkMode,
            ),
            _buildDetailRow(
              Icons.location_on_rounded,
              'Vị trí',
              ev.location,
              isDarkMode,
            ),
            _buildDetailRow(
              Icons.description_rounded,
              'Mô tả',
              ev.description?.trim().isNotEmpty == true
                  ? ev.description!
                  : 'Không có mô tả',
              isDarkMode,
            ),
            _buildDetailRow(
              Icons.add_alert_rounded,
              'Nhắc nhở',
              ev.reminder?.trim().isNotEmpty == true
                  ? ev.reminder!
                  : 'Không có nhắc nhở',
              isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon,
      String label,
      String value,
      bool isDarkMode,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _secondarySurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(isDarkMode)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: figmaSelectionBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _secondaryTextColor(isDarkMode),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _primaryTextColor(isDarkMode),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(EventModel ev, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor(isDarkMode),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Xác nhận xóa',
          style: TextStyle(color: _primaryTextColor(isDarkMode)),
        ),
        content: Text(
          "Bạn có chắc chắn muốn xóa sự kiện '${ev.title}' không?",
          style: TextStyle(color: _secondaryTextColor(isDarkMode)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
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

                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa sự kiện')),
                );
              }
            },
            child: const Text(
              'Xóa',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabToggle(bool isDarkMode) {
    return Container(
      width: 190,
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _secondarySurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor(isDarkMode)),
      ),
      child: Row(
        children: [
          _buildToggleItem('Cá nhân', isDarkMode),
          _buildToggleItem('Quan tâm', isDarkMode),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, bool isDarkMode) {
    final isSelected = _activeSubTab == label;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSubTab = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDarkMode ? const Color(0xFF323232) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? _cardShadow(isDarkMode) : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? figmaSelectionBlue
                  : _secondaryTextColor(isDarkMode),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_viewTabController == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: _backgroundColor(isDarkMode),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 100),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(child: _buildSubTabToggle(isDarkMode)),
          ),
          Expanded(
            child: _activeSubTab == 'Quan tâm'
                ? const InterestedEventTab()
                : StreamBuilder<List<EventModel>>(
              stream: _getEventsStream(),
              builder: (context, snapshot) {
                final List<EventModel> allEvents = snapshot.data ?? [];

                final int count = isListView
                    ? allEvents.length
                    : allEvents
                    .where(
                      (e) => DateUtils.isSameDay(
                    e.dateTime,
                    _selectedDay,
                  ),
                )
                    .length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                      child: Row(
                        children: [
                          isListView
                              ? _buildListFilter(isDarkMode)
                              : _buildMonthPicker(isDarkMode),
                          const Spacer(),
                          _buildViewSwitcher(isDarkMode),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        'Bạn đang có $count sự kiện sắp diễn ra',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _primaryTextColor(isDarkMode),
                        ),
                      ),
                    ),
                    Expanded(
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitcher(bool isDarkMode) {
    return Container(
      height: 44,
      width: 98,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _secondarySurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor(isDarkMode)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment:
            isListView ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: 43,
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
                      size: 21,
                      color: isListView
                          ? Colors.white
                          : _secondaryTextColor(isDarkMode),
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
                      size: 21,
                      color: !isListView
                          ? Colors.white
                          : _secondaryTextColor(isDarkMode),
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
    if (events.isEmpty) {
      return Center(
        child: Text(
          'Không có sự kiện sắp tới.',
          style: TextStyle(
            color: _secondaryTextColor(isDarkMode),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: events.length,
      itemBuilder: (context, i) => _buildLargeEventCard(events[i], isDarkMode),
    );
  }

  Widget _buildCalendarView(List<EventModel> events, bool isDarkMode) {
    final dayEvents = events
        .where((e) => DateUtils.isSameDay(e.dateTime, _selectedDay))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final weekDays = _getDaysInWeek();

    return Container(
      color: _backgroundColor(isDarkMode),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _surfaceColor(isDarkMode),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _borderColor(isDarkMode)),
              boxShadow: _cardShadow(isDarkMode),
            ),
            height: 94,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: weekDays.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                final DateTime day = weekDays[index];
                final bool isSelected = DateUtils.isSameDay(day, _selectedDay);
                final String label = [
                  'CN',
                  'T2',
                  'T3',
                  'T4',
                  'T5',
                  'T6',
                  'T7'
                ][day.weekday % 7];

                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 50,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? figmaSelectionBlue
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : _secondaryTextColor(isDarkMode),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : _primaryTextColor(isDarkMode),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                IconButton(
                  onPressed: () => _showFullCalendarPopup(isDarkMode),
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: _secondaryTextColor(isDarkMode),
                  ),
                ),
                Padding(
                  padding:
                  const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Center(
                          child: Text(
                            'Thời gian',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _secondaryTextColor(isDarkMode),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        'Sự kiện',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _secondaryTextColor(isDarkMode),
                        ),
                      ),
                    ],
                  ),
                ),
                Stack(
                  children: [
                    Positioned(
                      left: 126,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1.2,
                        color: _borderColor(isDarkMode),
                      ),
                    ),
                    Column(
                      children: dayEvents.isEmpty
                          ? [
                        Padding(
                          padding:
                          const EdgeInsets.only(top: 50, left: 100),
                          child: Text(
                            'Không có sự kiện',
                            style: TextStyle(
                              color: _secondaryTextColor(isDarkMode),
                            ),
                          ),
                        ),
                      ]
                          : dayEvents
                          .asMap()
                          .entries
                          .map(
                            (entry) => _buildTimelineRow(
                          isDarkMode,
                          entry.value,
                          entry.key,
                        ),
                      )
                          .toList(),
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
    final Color cardBg = isDarkMode
        ? (index.isEven
        ? const Color(0xFF243127)
        : const Color(0xFF353225))
        : (index.isEven
        ? const Color(0xFFE9F7EA)
        : const Color(0xFFFFF7D6));

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Text(
                  DateFormat('HH:mm').format(ev.dateTime),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _primaryTextColor(isDarkMode),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _cardShadow(isDarkMode),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ev.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _primaryTextColor(isDarkMode),
                          ),
                        ),
                      ),
                      _buildMoreMenu(ev, isDarkMode),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: _secondaryTextColor(isDarkMode),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ev.location,
                          style: TextStyle(
                            fontSize: 14,
                            color: _secondaryTextColor(isDarkMode),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () =>
                          _showEventDetailsBottomSheet(context, ev, isDarkMode),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: figmaDetailBtn,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(82, 34),
                      ),
                      child: const Text(
                        'Chi tiết',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildLargeEventCard(EventModel ev, bool isDarkMode) {
    final diff = ev.dateTime.difference(DateTime.now());

    final String timeText = diff.isNegative
        ? 'Đang diễn ra'
        : (diff.inDays > 0
        ? 'Còn ${diff.inDays} ngày nữa'
        : (diff.inHours > 0
        ? 'Còn ${diff.inHours} giờ nữa'
        : 'Còn ${diff.inMinutes} phút nữa'));

    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        image: const DecorationImage(
          image: AssetImage('assets/images/background.jpg'),
          fit: BoxFit.cover,
          opacity: 0.65,
          colorFilter: ColorFilter.mode(
            Colors.black45,
            BlendMode.darken,
          ),
        ),
        boxShadow: _cardShadow(isDarkMode),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withOpacity(0.08)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ev.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                _buildMoreMenu(ev, isDarkMode),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                timeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  DateFormat('MMM d, yyyy').format(ev.dateTime),
                  style: const TextStyle(color: Colors.white70),
                ),
                const Spacer(),
                InkWell(
                  onTap: () =>
                      _showEventDetailsBottomSheet(context, ev, isDarkMode),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: figmaDetailBtn,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Chi tiết',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreMenu(EventModel ev, bool isDarkMode) {
    final bool whiteIcon = isListView;

    return PopupMenuButton<String>(
      color: _surfaceColor(isDarkMode),
      icon: Icon(
        Icons.more_vert,
        color: whiteIcon ? Colors.white : _secondaryTextColor(isDarkMode),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePersonalEventPage(event: ev),
            ),
          );
        } else if (value == 'delete') {
          _confirmDelete(ev, isDarkMode);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(
                Icons.edit,
                size: 18,
                color: _primaryTextColor(isDarkMode),
              ),
              const SizedBox(width: 8),
              Text(
                'Chỉnh sửa',
                style: TextStyle(color: _primaryTextColor(isDarkMode)),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Xóa',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthPicker(bool isDarkMode) {
    return PopupMenuButton<int>(
      color: _surfaceColor(isDarkMode),
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
          child: Text(
            'Tháng ${i + 1}',
            style: TextStyle(color: _primaryTextColor(isDarkMode)),
          ),
        ),
      ),
      child: _filterChip(isDarkMode, 'Tháng $_selectedMonth'),
    );
  }

  Widget _buildListFilter(bool isDarkMode) {
    return PopupMenuButton<String>(
      color: _surfaceColor(isDarkMode),
      onSelected: (v) => setState(() => _listFilter = v),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'Gần nhất',
          child: Text(
            'Gần nhất',
            style: TextStyle(color: _primaryTextColor(isDarkMode)),
          ),
        ),
        PopupMenuItem(
          value: 'Xa nhất',
          child: Text(
            'Xa nhất',
            style: TextStyle(color: _primaryTextColor(isDarkMode)),
          ),
        ),
      ],
      child: _filterChip(isDarkMode, _listFilter),
    );
  }

  Widget _filterChip(bool isDarkMode, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _secondarySurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(isDarkMode)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _primaryTextColor(isDarkMode),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: _secondaryTextColor(isDarkMode),
          ),
        ],
      ),
    );
  }
}