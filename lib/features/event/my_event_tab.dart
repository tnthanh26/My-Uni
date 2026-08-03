import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_uni/models/event_model.dart';
import 'package:my_uni/features/services/notification_service.dart';
import 'create_personal_event_page.dart';
import 'interested_event_tab.dart';
import 'discover_event_tab.dart';

enum EventTabMode {
  personal,
  community,
}

class EventPageNotifier {
  static final ValueNotifier<bool> isActive = ValueNotifier<bool>(false);
}

class MyEventTab extends StatefulWidget {
  final EventTabMode mode;

  const MyEventTab({
    super.key,
    this.mode = EventTabMode.personal,
  });

  @override
  State<MyEventTab> createState() => _MyEventTabState();
}

class _MyEventTabState extends State<MyEventTab>
    with TickerProviderStateMixin {
  final List<String> _emptyQuotes = [
    "Thanh xuân như 1 tách trà, tham gia sự kiện, đậm đà thanh xuân.",
    "Hôm nay bạn bận... bận không làm gì cả.",
    "Thôi thì nghỉ ngơi một hôm cũng tốt.",
    "Nghe nói cách có người yêu nhanh nhất là tham gia thật nhiều sự kiện đấy!",
  ];
  late int _quoteIndex = Random().nextInt(_emptyQuotes.length);

  TabController? _viewTabController;

  int _selectedMonth = DateTime.now().month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  String _listFilter = 'Gần nhất';

  Timer? _refreshTimer;
  bool _isCleaningExpiredEvents = false;

  static const Color primaryBlue = Color(0xFF6797E1);
  static const Color primaryBrown = Color(0xFF545454);
  static const Color figmaBlueBg = Color(0xFFF2F6FF);
  static const Color figmaSelectionBlue = Color(0xFF5893D8);
  static const Color figmaDetailBtn = Color(0xFF1088AE);

  @override
  void initState() {
    super.initState();
    EventPageNotifier.isActive.addListener(_onActiveStateChanged);

    _viewTabController = TabController(length: 2, vsync: this);
    _viewTabController!.addListener(() {
      if (!_viewTabController!.indexIsChanging) {
        setState(() {
          _selectedDay = DateTime.now();
          _focusedDay = DateTime.now();
          _selectedMonth = DateTime.now().month;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanupExpiredPersonalEvents();
    });

    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _cleanupExpiredPersonalEvents();
        setState(() {});
      }
    });
  }

  void _onActiveStateChanged() {
    if (mounted && EventPageNotifier.isActive.value) {
      setState(() {
        _selectedDay = DateTime.now();
        _focusedDay = DateTime.now();
        _selectedMonth = DateTime.now().month;
      });
    }
  }

  @override
  void dispose() {
    EventPageNotifier.isActive.removeListener(_onActiveStateChanged);
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

  Future<void> _cancelNotificationIdsFromData(Map<String, dynamic> data) async {
    final dynamic oldSingleId = data['notificationId'];
    if (oldSingleId is int) {
      await NotificationService.cancelNotification(oldSingleId);
    }

    final dynamic ids = data['notificationIds'];
    if (ids is List) {
      for (final id in ids) {
        if (id is int && id != oldSingleId) {
          await NotificationService.cancelNotification(id);
        }
      }
    }
  }

  Future<void> _cleanupExpiredPersonalEvents() async {
    if (_isCleaningExpiredEvents) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isCleaningExpiredEvents = true;

    try {
      final deleteBefore = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 7)),
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('personal_events')
          .where('dateTime', isLessThan: deleteBefore)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        await _cancelNotificationIdsFromData(doc.data());
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Cleanup expired personal events error: $e');
    } finally {
      _isCleaningExpiredEvents = false;
    }
  }

  Future<void> _deletePersonalEvent(EventModel ev) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('personal_events')
        .doc(ev.id);

    final doc = await ref.get();

    if (doc.exists && doc.data() != null) {
      await _cancelNotificationIdsFromData(doc.data()!);
    } else if (ev.notificationId != null) {
      await NotificationService.cancelNotification(ev.notificationId!);
    }

    await ref.delete();
  }

  Stream<List<EventModel>> _getEventsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    final sevenDaysAgo = DateTime.now().subtract(
      const Duration(days: 7),
    );

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('personal_events')
        .where(
      'dateTime',
      isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
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

  Future<void> _selectDate(BuildContext context, bool isDarkMode) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
      builder: (context, child) {
        return Theme(
          data: isDarkMode
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: figmaSelectionBlue,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  ),
                  dialogBackgroundColor: const Color(0xFF1E1E1E),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: figmaSelectionBlue,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDay = picked;
        _focusedDay = picked;
        _selectedMonth = picked.month;
      });
    }
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
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: SingleChildScrollView(
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
              FutureBuilder<bool>(
                future: _checkOriginalEventExists(ev.facultyEventId),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data == false) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Sự kiện gốc này đã bị hủy hoặc xóa khỏi hệ thống bởi Ban tổ chức.',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              _buildDetailRow(
                Icons.access_time_filled_rounded,
                'Thời gian',
                DateFormat('dd/MM/yyyy HH:mm').format(ev.dateTime),
                isDarkMode,
              ),
              _buildDetailRow(
                ev.isOnline ? Icons.videocam_rounded : Icons.location_on_rounded,
                'Vị trí',
                ev.location.trim().isNotEmpty ? ev.location : (ev.isOnline ? 'Online' : 'Chưa cập nhật'),
                isDarkMode,
              ),
              if (ev.description.trim().isNotEmpty)
                _buildDetailRow(
                  Icons.description_rounded,
                  'Mô tả',
                  ev.description,
                  isDarkMode,
                ),
              if (ev.contact != null && ev.contact!.trim().isNotEmpty)
                _buildDetailRow(
                  Icons.contact_phone_rounded,
                  'Liên hệ',
                  ev.contact!,
                  isDarkMode,
                ),
              if (ev.reminder != 'Không' &&
                  ev.reminder != 'Đặt lời nhắc' &&
                  ev.reminder.trim().isNotEmpty)
                _buildDetailRow(
                  Icons.add_alert_rounded,
                  'Nhắc nhở',
                  ev.reminder,
                  isDarkMode,
                ),
              if (ev.onlineUrl != null && ev.onlineUrl!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchURL(ev.onlineUrl!),
                    icon: const Icon(Icons.videocam_rounded, size: 18),
                    label: const Text(
                      'Tham gia Online',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
              if (ev.sourceArticleUrl != null &&
                  ev.sourceArticleUrl!.trim().isNotEmpty &&
                  ev.sourceArticleUrl!.trim() != ev.onlineUrl?.trim()) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchURL(ev.sourceArticleUrl!),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text(
                      'Xem bài viết gốc',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: figmaSelectionBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _checkOriginalEventExists(String? facultyEventId) async {
    if (facultyEventId == null || facultyEventId.trim().isEmpty) return true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('faculty_events')
          .doc(facultyEventId.trim())
          .get();
      return doc.exists;
    } catch (_) {
      return true;
    }
  }

  Future<void> _launchURL(String urlString) async {
    final cleanUrl = urlString.trim();
    if (cleanUrl.isEmpty) return;
    final Uri url = Uri.parse(cleanUrl);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
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
          "Bạn có chắc muốn xóa sự kiện '${ev.title}' không?",
          style: TextStyle(color: _secondaryTextColor(isDarkMode)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _deletePersonalEvent(ev);

                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa sự kiện')),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi xóa sự kiện: $e')),
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

  Widget _buildCommunityTab(bool isDarkMode) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text(
                          "Sự kiện cộng đồng mới",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: const Color(0xFF6797E1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      body: const DiscoverEventTab(
                        useNestedScrollOverlap: false,
                      ),
                    ),
                  ),
                );
              },

              icon: const Icon(Icons.explore_rounded, size: 20),
              label: const Text(
                'Khám phá sự kiện cộng đồng',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: figmaSelectionBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const Expanded(
          child: InterestedEventTab(),
        ),
      ],
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600.0),
          child: widget.mode == EventTabMode.community
              ? _buildCommunityTab(isDarkMode)
              : StreamBuilder<List<EventModel>>(
        stream: _getEventsStream(),
        builder: (context, snapshot) {
          final List<EventModel> allEvents = snapshot.data ?? [];

          final now = DateTime.now();
          final bool isToday = DateUtils.isSameDay(
            _selectedDay,
            DateTime.now(),
          );

          final bool isPastSelectedDay =
          _selectedDay!.isBefore(DateUtils.dateOnly(DateTime.now()));

          final int countList = allEvents.where((e) => !e.dateTime.isBefore(now)).length;
          final int countCalendar = allEvents
              .where(
                (e) =>
            DateUtils.isSameDay(e.dateTime, _selectedDay) &&
                !e.dateTime.isBefore(now),
          )
              .length;

          final String listText = 'Bạn đang có $countList sự kiện sắp diễn ra';
          final String calendarText = isToday
              ? 'Hôm nay có $countCalendar sự kiện đang chờ bạn'
              : isPastSelectedDay
              ? 'Các sự kiện của ngày đã chọn'
              : 'Ngày này có $countCalendar sự kiện đang chờ bạn';

          final Widget tabBarView = Expanded(
            child: TabBarView(
              controller: _viewTabController,
              children: [
                _buildListView(allEvents, isDarkMode),
                _buildCalendarView(allEvents, isDarkMode),
              ],
            ),
          );

          return AnimatedBuilder(
            animation: _viewTabController!.animation!,
            child: tabBarView,
            builder: (context, child) {
              final double value = _viewTabController!.animation!.value;
              final double listOpacity = (1.0 - value).clamp(0.0, 1.0);
              final double calendarOpacity = value.clamp(0.0, 1.0);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Opacity(
                              opacity: listOpacity,
                              child: IgnorePointer(
                                ignoring: value >= 0.5,
                                child: _buildListFilter(isDarkMode),
                              ),
                            ),
                            Opacity(
                              opacity: calendarOpacity,
                              child: IgnorePointer(
                                ignoring: value < 0.5,
                                child: _buildMonthPicker(isDarkMode),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _buildViewSwitcher(isDarkMode),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: listOpacity,
                          child: Text(
                            listText,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _primaryTextColor(isDarkMode),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: calendarOpacity,
                          child: Text(
                            calendarText,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _primaryTextColor(isDarkMode),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  child!,
                ],
              );
            },
          );
        },
      ),

    )));
  }

  Widget _buildViewSwitcher(bool isDarkMode) {
    if (_viewTabController == null || _viewTabController!.animation == null) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 44,
      width: 98,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _secondarySurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor(isDarkMode)),
      ),
      child: AnimatedBuilder(
        animation: _viewTabController!.animation!,
        builder: (context, child) {
          final double value = _viewTabController!.animation!.value;
          final double x = -1.0 + 2.0 * value;

          final Color listIconColor = Color.lerp(
            Colors.white,
            _secondaryTextColor(isDarkMode),
            value,
          ) ?? Colors.white;

          final Color calendarIconColor = Color.lerp(
            _secondaryTextColor(isDarkMode),
            Colors.white,
            value,
          ) ?? Colors.white;

          return Stack(
            children: [
              Align(
                alignment: Alignment(x, 0.0),
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
                          color: listIconColor,
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
                          color: calendarIconColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListView(List<EventModel> events, bool isDarkMode) {
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 40,
                color: figmaSelectionBlue.withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                _emptyQuotes[_quoteIndex],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _primaryTextColor(isDarkMode).withOpacity(0.85),
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  fontFamily: 'Urbanist',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: events.length,
      itemBuilder: (context, i) =>
          _buildLargeEventCard(events[i], isDarkMode, i),
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _surfaceColor(isDarkMode),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _borderColor(isDarkMode)),
              boxShadow: _cardShadow(isDarkMode),
            ),
            height: 94,
            child: Row(
              children: List.generate(weekDays.length, (index) {
                final DateTime day = weekDays[index];
                final bool isSelected = DateUtils.isSameDay(day, _selectedDay);
                final bool isToday = DateUtils.isSameDay(day, DateTime.now());
                final String label = [
                  'CN',
                  'T2',
                  'T3',
                  'T4',
                  'T5',
                  'T6',
                  'T7'
                ][day.weekday % 7];

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDay = day;
                        _focusedDay = day;
                        _selectedMonth = day.month;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                        isSelected ? figmaSelectionBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: !isSelected && isToday
                              ? figmaSelectionBlue.withOpacity(0.5)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isToday
                                      ? figmaSelectionBlue
                                      : _secondaryTextColor(isDarkMode)),
                              fontSize: 12,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
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
                                  : (isToday
                                      ? figmaSelectionBlue
                                      : _primaryTextColor(isDarkMode)),
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(height: 2),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : figmaSelectionBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 7),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF2F6FF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
              ),
              width: double.infinity,
              child: ListView(
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                children: [
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
                            const EdgeInsets.only(top: 110, left: 146),
                            child: Text(
                              'Không có sự kiện',
                              style: TextStyle(
                                color: _secondaryTextColor(isDarkMode),
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
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
          ),
        ],
      ),
    );
  }

  Color _getVintageColor(int index, bool isDarkMode) {
    final List<Color> lightVintage = [
      const Color(0xFFFDF1E6),
      const Color(0xFFEBF2E8),
      const Color(0xFFE8EEF1),
      const Color(0xFFF5E9F2),
      const Color(0xFFFAF3DD),
    ];

    final List<Color> darkVintage = [
      const Color(0xFF2D2A26),
      const Color(0xFF262D27),
      const Color(0xFF262A2D),
      const Color(0xFF2D262B),
      const Color(0xFF2D2C26),
    ];

    return isDarkMode
        ? darkVintage[index % darkVintage.length]
        : lightVintage[index % lightVintage.length];
  }

  Widget _buildTimelineRow(bool isDarkMode, EventModel ev, int index) {
    final bool isPastEvent = ev.dateTime.isBefore(DateTime.now());

    final Color vintageBg = isPastEvent
        ? (isDarkMode ? const Color(0xFF242424) : const Color(0xFFF1F1F1))
        : _getVintageColor(index, isDarkMode);

    final List<Color> accentColors = [
      Colors.brown,
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.blueGrey,
    ];

    final Color accentColor =
    isPastEvent ? Colors.grey : accentColors[index % accentColors.length];

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Column(
              children: [
                Text(
                  DateFormat('HH:mm').format(ev.dateTime),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: isPastEvent
                        ? _secondaryTextColor(isDarkMode)
                        : _primaryTextColor(isDarkMode),
                  ),
                ),
                Text(
                  ev.dateTime.hour < 12 ? 'SÁNG' : 'CHIỀU',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: _secondaryTextColor(isDarkMode),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: vintageBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPastEvent
                      ? Colors.grey.withOpacity(0.18)
                      : (isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : accentColor.withOpacity(0.1)),
                ),
                boxShadow: isPastEvent ? [] : _cardShadow(isDarkMode),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        color: accentColor.withOpacity(
                          isPastEvent ? 0.28 : 0.4,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
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
                                        color: isPastEvent
                                            ? _secondaryTextColor(isDarkMode)
                                            : _primaryTextColor(isDarkMode),
                                      ),
                                    ),
                                  ),
                                  _buildMoreMenu(ev, isDarkMode),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 16,
                                    color: _secondaryTextColor(isDarkMode),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      ev.location,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _secondaryTextColor(isDarkMode),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (isPastEvent) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Đã diễn ra',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => _showEventDetailsBottomSheet(
                                  context,
                                  ev,
                                  isDarkMode,
                                ),
                                child: Text(
                                  'Xem chi tiết',
                                  style: TextStyle(
                                    color: isPastEvent ? Colors.grey : accentColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeEventCard(EventModel ev, bool isDarkMode, int index) {
    final now = DateTime.now();
    final bool isPastEvent = ev.dateTime.isBefore(now);

    final Color vintageBg = isPastEvent
        ? (isDarkMode ? const Color(0xFF242424) : const Color(0xFFF1F1F1))
        : _getVintageColor(index, isDarkMode);

    final diff = ev.dateTime.difference(now);

    String timeStatus;

    if (diff.isNegative) {
      if (diff.inDays.abs() >= 1) {
        timeStatus = '${diff.inDays.abs()} ngày trước';
      } else if (diff.inHours.abs() >= 1) {
        timeStatus = '${diff.inHours.abs()} giờ trước';
      } else {
        timeStatus = '${diff.inMinutes.abs()} phút trước';
      }
    } else {
      if (diff.inDays > 0) {
        timeStatus = 'Trong ${diff.inDays} ngày';
      } else if (diff.inHours > 0) {
        timeStatus = 'Trong ${diff.inHours} giờ';
      } else {
        timeStatus = 'Trong ${diff.inMinutes} phút';
      }
    }

    final Color statusColor = diff.isNegative
        ? Colors.grey
        : (diff.inDays == 0
        ? Colors.orangeAccent
        : figmaSelectionBlue);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: vintageBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: _cardShadow(isDarkMode),
      ),
      child: InkWell(
        onTap: () => _showEventDetailsBottomSheet(context, ev, isDarkMode),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMM').format(ev.dateTime).toUpperCase(),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.brown,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      DateFormat('dd').format(ev.dateTime),
                      style: TextStyle(
                        color: _primaryTextColor(isDarkMode),
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
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
                            ev.title,
                            style: TextStyle(
                              color: _primaryTextColor(isDarkMode),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: _secondaryTextColor(isDarkMode),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('HH:mm').format(ev.dateTime),
                          style: TextStyle(
                            color: _secondaryTextColor(isDarkMode),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          ev.isOnline ? Icons.videocam_rounded : Icons.location_on_outlined,
                          size: 14,
                          color: ev.isOnline ? const Color(0xFF8B5CF6) : _secondaryTextColor(isDarkMode),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ev.location.trim().isNotEmpty ? ev.location : (ev.isOnline ? 'Online' : 'Chưa cập nhật'),
                            style: TextStyle(
                              color: _secondaryTextColor(isDarkMode),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  timeStatus,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isPastEvent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Đã diễn ra',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Chi tiết',
                          style: TextStyle(
                            color: isPastEvent ? Colors.grey : figmaDetailBtn,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenu(EventModel ev, bool isDarkMode) {
    return PopupMenuButton<String>(
      color: _surfaceColor(isDarkMode),
      icon: Icon(
        Icons.more_vert,
        color: _secondaryTextColor(isDarkMode),
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
    return GestureDetector(
      onTap: () => _selectDate(context, isDarkMode),
      child: _filterChip(
        isDarkMode,
        'Tháng $_selectedMonth, ${_selectedDay?.year ?? DateTime.now().year}',
      ),
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