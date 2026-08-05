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
import '../home/home_page.dart';
import '../myspace/myspace_screen.dart';

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

    // Đồng bộ xóa trong collection interested_events để nút "Quan tâm" bên Tab Khám phá tự cập nhật lại
    final String targetInterestedId = (ev.facultyEventId != null && ev.facultyEventId!.isNotEmpty)
        ? ev.facultyEventId!
        : ev.id;

    final interestedRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('interested_events')
        .doc(targetInterestedId);

    await interestedRef.delete();

    if (ev.id != targetInterestedId) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('interested_events')
          .doc(ev.id)
          .delete();
    }
  }

  List<EventModel> _sortEvents(List<EventModel> rawEvents, String filter) {
    final now = DateTime.now();

    final List<EventModel> futureEvents = [];
    final List<EventModel> pastEvents = [];

    for (final event in rawEvents) {
      if (event.dateTime.isBefore(now)) {
        pastEvents.add(event);
      } else {
        futureEvents.add(event);
      }
    }

    if (filter == 'Gần nhất') {
      // Event sắp tới: tăng dần theo thời gian (sớm nhất xếp trước)
      futureEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      // Event đã qua: đẩy xuống cuối, mới nhất xếp trước
      pastEvents.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    } else if (filter == 'Xa nhất') {
      // Event sắp tới: giảm dần theo thời gian (xa nhất xếp trước)
      futureEvents.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      // Event đã qua: đẩy xuống cuối, mới nhất xếp trước
      pastEvents.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    }

    return [...futureEvents, ...pastEvents];
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
    final Color surfaceColor = isDarkMode
        ? const Color(0xFF1C1E21)
        : Colors.white;

    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE4E7EC);

    final Color primaryTextColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1D2939);

    final Color secondaryTextColor = isDarkMode
        ? Colors.white60
        : const Color(0xFF667085);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: isDarkMode
                          ? const Color(0xFF101214)
                          : const Color(0xFFF8FAFC),
                      appBar: AppBar(
                        title: const Text(
                          'Khám phá sự kiện',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: isDarkMode
                            ? const Color(0xFF1C1E21)
                            : Colors.white,
                        foregroundColor: isDarkMode
                            ? Colors.white
                            : const Color(0xFF1D2939),
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                      ),
                      body: const DiscoverEventTab(
                        useNestedScrollOverlap: false,
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: figmaSelectionBlue.withValues(
                          alpha: isDarkMode ? 0.16 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.explore_outlined,
                        size: 21,
                        color: figmaSelectionBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Khám phá sự kiện cộng đồng',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Tìm các hoạt động mới từ trường và các khoa.',
                            style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontSize: 11.5,
                              height: 1.35,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 21,
                      color: secondaryTextColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: InterestedEventTab(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _backgroundColor(isDarkMode),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600.0),
          child: widget.mode == EventTabMode.community
              ? const DiscoverEventTab(useNestedScrollOverlap: false)
              : StreamBuilder<List<EventModel>>(
                  stream: _getEventsStream(),
                  builder: (context, snapshot) {
                    final List<EventModel> allEvents = snapshot.data ?? [];
                    final List<EventModel> sortedListEvents =
                        _sortEvents(allEvents, _listFilter);

                    final now = DateTime.now();
                    final int countList =
                        allEvents.where((e) => !e.dateTime.isBefore(now)).length;
                    final String listText =
                        '$countList sự kiện sắp diễn ra';

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sự kiện của tôi',
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _primaryTextColor(isDarkMode),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      listText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Encode Sans Expanded',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: _secondaryTextColor(isDarkMode),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildSyncInfoButton(isDarkMode),
                              const SizedBox(width: 8),
                              _buildListFilter(isDarkMode),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _buildListView(sortedListEvents, isDarkMode),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
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

  Widget _buildListView(
      List<EventModel> events,
      bool isDarkMode,
      ) {
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 40,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: figmaSelectionBlue.withValues(
                    alpha: isDarkMode ? 0.14 : 0.09,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_available_outlined,
                  size: 34,
                  color: figmaSelectionBlue.withValues(
                    alpha: 0.85,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có sự kiện.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _primaryTextColor(isDarkMode),
                  fontFamily: 'Nunito',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _emptyQuotes[_quoteIndex],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _secondaryTextColor(isDarkMode),
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  height: 1.45,
                  fontFamily: 'Encode Sans Expanded',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24,
      ),
      itemCount: events.length,
      itemBuilder: (context, i) {
        return _buildLargeEventCard(
          events[i],
          isDarkMode,
          i,
        );
      },
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

  Widget _buildLargeEventCard(
      EventModel ev,
      bool isDarkMode,
      int index,
      ) {
    final now = DateTime.now();
    final bool isPastEvent = ev.dateTime.isBefore(now);

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

    const List<Color> googleCalendarColors = [
      Color(0xFF4285F4),
      Color(0xFF34A853),
      Color(0xFFFBBC04),
      Color(0xFFEA4335),
      Color(0xFF8E67D4),
      Color(0xFF00ACC1),
    ];

    final Color eventColor = isPastEvent
        ? const Color(0xFF9AA0A6)
        : googleCalendarColors[
    index % googleCalendarColors.length
    ];

    final Color cardColor = isDarkMode
        ? const Color(0xFF1C1E21)
        : Colors.white;

    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE4E7EC);

    final Color primaryTextColor =
    _primaryTextColor(isDarkMode);

    final Color secondaryTextColor =
    _secondaryTextColor(isDarkMode);

    final Color statusColor = isPastEvent
        ? const Color(0xFF9AA0A6)
        : diff.inDays == 0
        ? const Color(0xFFEA8600)
        : eventColor;

    final String locationText =
    ev.location.trim().isNotEmpty
        ? ev.location.trim()
        : ev.isOnline
        ? 'Online'
        : 'Chưa cập nhật';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: isDarkMode
            ? const []
            : [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            _showEventDetailsBottomSheet(
              context,
              ev,
              isDarkMode,
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  color: eventColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      14,
                      14,
                      10,
                      14,
                    ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          padding: const EdgeInsets.symmetric(
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: eventColor.withValues(
                              alpha: isDarkMode ? 0.14 : 0.09,
                            ),
                            borderRadius:
                            BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('MMM')
                                    .format(ev.dateTime)
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  color: eventColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                DateFormat('dd')
                                    .format(ev.dateTime),
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  color: primaryTextColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 23,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      ev.title,
                                      maxLines: 2,
                                      overflow:
                                      TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontFamily: 'Nunito',
                                        fontWeight:
                                        FontWeight.w700,
                                        fontSize: 16,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  _buildMoreMenu(
                                    ev,
                                    isDarkMode,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 15,
                                    color: secondaryTextColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('HH:mm')
                                        .format(ev.dateTime),
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontFamily:
                                      'Encode Sans Expanded',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    ev.isOnline
                                        ? Icons.videocam_outlined
                                        : Icons.location_on_outlined,
                                    size: 15,
                                    color: secondaryTextColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      locationText,
                                      maxLines: 1,
                                      overflow:
                                      TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: secondaryTextColor,
                                        fontFamily:
                                        'Encode Sans Expanded',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: isDarkMode
                                              ? 0.16
                                              : 0.10,
                                        ),
                                        borderRadius:
                                        BorderRadius.circular(9),
                                      ),
                                      child: Text(
                                        timeStatus,
                                        maxLines: 1,
                                        overflow:
                                        TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontFamily:
                                          'Encode Sans Expanded',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isPastEvent) ...[
                                    const SizedBox(width: 7),
                                    Container(
                                      padding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF9AA0A6)
                                            .withValues(
                                          alpha: isDarkMode
                                              ? 0.16
                                              : 0.10,
                                        ),
                                        borderRadius:
                                        BorderRadius.circular(9),
                                      ),
                                      child: const Text(
                                        'Đã diễn ra',
                                        style: TextStyle(
                                          color: Color(0xFF80868B),
                                          fontFamily:
                                          'Encode Sans Expanded',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: isPastEvent
                                        ? const Color(0xFF9AA0A6)
                                        : eventColor,
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
              ],
            ),
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

  Widget _buildSyncInfoButton(bool isDarkMode) {
    const Color hcmusLightGrey = Color(0xFFEFEFEF);

    return Tooltip(
      message: 'Thông tin đồng bộ Lịch biểu',
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: _surfaceColor(isDarkMode),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: figmaSelectionBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Đồng bộ Lịch biểu',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _primaryTextColor(isDarkMode),
                    ),
                  ),
                ],
              ),
              content: Text(
                'Các sự kiện bạn lưu hoặc tạo sẽ tự động được đồng bộ với Lịch biểu ở trang Góc nhỏ của bạn.',
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 13.5,
                  height: 1.45,
                  color: _primaryTextColor(isDarkMode),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Đã hiểu',
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontWeight: FontWeight.w700,
                      color: figmaSelectionBlue,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2A2A2E) : hcmusLightGrey,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome,
            size: 17,
            color: figmaSelectionBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildMySpaceShortcutButton(bool isDarkMode) {
    const Color hcmusLightGrey = Color(0xFFEFEFEF);
    final bool isCalendarActive = _viewTabController?.index == 1;

    return Tooltip(
      message: isCalendarActive ? 'Xem dạng Danh sách' : 'Xem dạng Lịch chia theo giờ',
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_viewTabController != null) {
              final int nextIndex = _viewTabController!.index == 0 ? 1 : 0;
              _viewTabController!.animateTo(nextIndex);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCalendarActive
                ? figmaSelectionBlue
                : (isDarkMode ? const Color(0xFF2A2A2E) : hcmusLightGrey),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.calendar_month_rounded,
            size: 18,
            color: isCalendarActive
                ? Colors.white
                : (isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyCalendarView(List<EventModel> events, bool isDarkMode) {
    final DateTime currentSelected = _selectedDay ?? DateTime.now();
    final DateTime today = DateTime.now();

    final List<EventModel> dayEvents = events.where((e) {
      return e.dateTime.year == currentSelected.year &&
          e.dateTime.month == currentSelected.month &&
          e.dateTime.day == currentSelected.day;
    }).toList();

    final List<DateTime> dateStrip = List.generate(
      21,
      (index) => today.subtract(const Duration(days: 3)).add(Duration(days: index)),
    );

    return Column(
      children: [
        Container(
          height: 66,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: dateStrip.length,
            itemBuilder: (context, index) {
              final date = dateStrip[index];
              final bool isSelected = date.year == currentSelected.year &&
                  date.month == currentSelected.month &&
                  date.day == currentSelected.day;
              final bool isTodayDate = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              final String weekdayStr = DateFormat('E', 'vi').format(date);
              final String dayStr = DateFormat('dd').format(date);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDay = date;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? figmaSelectionBlue
                        : (isDarkMode ? const Color(0xFF1C1E21) : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? figmaSelectionBlue
                          : (isTodayDate
                              ? figmaSelectionBlue.withValues(alpha: 0.6)
                              : _borderColor(isDarkMode)),
                      width: isTodayDate && !isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: figmaSelectionBlue.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : const [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        weekdayStr,
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.85)
                              : _secondaryTextColor(isDarkMode),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayStr,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
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

        const SizedBox(height: 4),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: 17,
            itemBuilder: (context, index) {
              final int hour = 6 + index;
              final String hourStr = '${hour.toString().padLeft(2, '0')}:00';

              final List<EventModel> hourEvents = dayEvents.where((e) {
                return e.dateTime.hour == hour;
              }).toList();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        hourStr,
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _secondaryTextColor(isDarkMode),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 1,
                            margin: const EdgeInsets.only(top: 8, bottom: 8),
                            color: _borderColor(isDarkMode),
                          ),
                          if (hourEvents.isEmpty)
                            const SizedBox(height: 16)
                          else
                            ...hourEvents.map((ev) => _buildHourlyEventCard(ev, isDarkMode)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyEventCard(EventModel ev, bool isDarkMode) {
    const Color primaryBlue = Color(0xFF5893D8);
    final String timeStr = DateFormat('HH:mm').format(ev.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1C1E21) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryBlue.withValues(alpha: 0.35),
        ),
        boxShadow: isDarkMode
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: InkWell(
        onTap: () => _showEventDetailsBottomSheet(context, ev, isDarkMode),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 12, color: primaryBlue),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ev.isFromFacultyEvent) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'SỰ KIỆN KHOA',
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ev.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _primaryTextColor(isDarkMode),
              ),
            ),
            if (ev.location.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    ev.isOnline ? Icons.videocam_outlined : Icons.location_on_outlined,
                    size: 14,
                    color: _secondaryTextColor(isDarkMode),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ev.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 11.5,
                        color: _secondaryTextColor(isDarkMode),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListFilter(bool isDarkMode) {
    const Color hcmusLightGrey = Color(0xFFEFEFEF);

    return PopupMenuButton<String>(
      tooltip: 'Sắp xếp & Lọc',
      color: _surfaceColor(isDarkMode),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      onSelected: (v) => setState(() => _listFilter = v),
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          value: 'Gần nhất',
          height: 42,
          child: Row(
            children: [
              Icon(
                Icons.arrow_upward_rounded,
                size: 15,
                color: _listFilter == 'Gần nhất' ? figmaSelectionBlue : _secondaryTextColor(isDarkMode),
              ),
              const SizedBox(width: 8),
              Text(
                'Gần nhất',
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 12,
                  fontWeight: _listFilter == 'Gần nhất' ? FontWeight.bold : FontWeight.w500,
                  color: _primaryTextColor(isDarkMode),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'Xa nhất',
          height: 42,
          child: Row(
            children: [
              Icon(
                Icons.arrow_downward_rounded,
                size: 15,
                color: _listFilter == 'Xa nhất' ? figmaSelectionBlue : _secondaryTextColor(isDarkMode),
              ),
              const SizedBox(width: 8),
              Text(
                'Xa nhất',
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 12,
                  fontWeight: _listFilter == 'Xa nhất' ? FontWeight.bold : FontWeight.w500,
                  color: _primaryTextColor(isDarkMode),
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2E) : hcmusLightGrey,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.filter_list_rounded,
          size: 18,
          color: isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Widget _filterChip(
      bool isDarkMode,
      String label,
      ) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _borderColor(isDarkMode),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sort_rounded,
            size: 16,
            color: _secondaryTextColor(isDarkMode),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _primaryTextColor(isDarkMode),
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 17,
            color: _secondaryTextColor(isDarkMode),
          ),
        ],
      ),
    );
  }
}