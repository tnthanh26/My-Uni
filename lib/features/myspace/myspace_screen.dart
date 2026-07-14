import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './models/myspace_models.dart';
import 'create_deadlines_page.dart';
import 'create_schedule_page.dart';
import 'local_storage_helper.dart';
import 'myspace_firebase_service.dart';
import 'package:my_uni/features/notification/notification_page.dart';
import 'package:my_uni/features/services/notification_service.dart';
import 'package:my_uni/models/notification_model.dart';
import './services/myspace_weather_coordinator.dart';
import './services/weather_alert_service.dart';
import './services/weather_service.dart';
import './services/moodle_service.dart';
import './services/moodle_token_storage.dart';
import './models/weather_models.dart';
import 'weather_alert_card.dart';
import 'myspace_deadline_section.dart';
import 'package:intl/intl.dart';
import 'dart:async';

const Color hcmusBlueAccent = Color(0xFF5893D8);
const Color hcmusTeal = Color(0xFF279E95);
const Color hcmusGreyBg = Color(0xFFF2F6FF);
const Color hcmusRed = Color(0xFFFF6868);
const Color hcmusLightGrey = Color(0xFFEFEFEF);

class MySpaceScreen extends StatefulWidget {
  final bool isActive;
  const MySpaceScreen({super.key, this.isActive = false});

  @override
  State<MySpaceScreen> createState() => _MySpaceScreenState();
}

class _MySpaceScreenState extends State<MySpaceScreen> with SingleTickerProviderStateMixin {
  bool _isDetailView = false;
  late TabController _tabController;
  int selectedWeekday = DateTime.now().weekday + 1;
  bool _deadlineShowAll = false;
  // Dữ liệu mẫu
  List<Deadline> mockDeadlines = [];
  List<StudyClass> mockSchedule = [];
  AutoDeadlineConfig? _autoDeadlineConfig;
  String _userUniversity = '';
  Future<WeatherAlertResult>? _weatherFuture;
  StreamSubscription<List<StudyClass>>? _scheduleSub;
  StreamSubscription<List<Deadline>>? _deadlineSub;

  @override
  void initState() {
    super.initState();
    selectedWeekday = DateTime.now().weekday + 1;
    // Khởi tạo TabController cho phần Detail
    _tabController = TabController(length: 2, vsync: this);

    _loadInitialMetaData();

    _listenScheduleRealtime();
    _listenDeadlineRealtime();

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _deadlineSub?.cancel();
    _scheduleSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MySpaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _resetToToday();
    }
  }

  void _resetToToday() {
    setState(() {
      _focusedDate = DateTime.now();
      selectedWeekday = _focusedDate.weekday + 1;
    });
    // _prepareWeatherFuture(); // Tạm ẩn để tránh gọi API lặp lại khi chuyển tab
  }

  void _prepareWeatherFuture() {
    final now = DateTime.now();
    final todayWeekday = now.weekday + 1;

    // CHỈ hiển thị cảnh báo thời tiết nếu user đang xem ngày hôm nay thực tế
    if (selectedWeekday != todayWeekday) {
      _weatherFuture = Future.value(WeatherAlertResult.none());
      if (mounted) setState(() {});
      return;
    }

    final todayClasses =
    mockSchedule.where((c) => c.weekday == selectedWeekday).toList();

    final campusId = _mapUniversityToCampusId(_userUniversity);

    debugPrint('=== PREPARE WEATHER FUTURE ===');
    debugPrint('_userUniversity: $_userUniversity');
    debugPrint('campusId: $campusId');
    debugPrint('todayClasses length: ${todayClasses.length}');

    if (campusId == null || todayClasses.isEmpty) {
      _weatherFuture = Future.value(WeatherAlertResult.none());
      return;
    }

    final schedules = todayClasses.map((c) {
      return ScheduleItem(
        id: c.id,
        title: c.name,
        startTime: _combineDateAndTime(DateTime.now(), c.start),
        endTime: _combineDateAndTime(DateTime.now(), c.end),
        campusId: campusId,
        room: c.room,
      );
    }).toList();

    _weatherFuture = MySpaceWeatherCoordinator(
      weatherService: WeatherService(),
      alertService: WeatherAlertService(),
    ).buildWeatherAlertForToday(
      schedules: schedules,
    );
  }
  // --- LOGIC DỮ LIỆU ---
  // Thêm services vào class
  final MySpaceFirebaseService _firebaseService = MySpaceFirebaseService();

  Future<void> _loadInitialMetaData() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    final localAutoConfig = await LocalStorageHelper.getAutoDeadlineConfig(
      moodleUrl: '',
    );

    if (mounted) {
      setState(() {
        _autoDeadlineConfig = localAutoConfig;
      });
    }

    try {
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        final university = userDoc.data()?['university'] ?? '';

        if (mounted) {
          setState(() {
            _userUniversity = university;
          });
          // Hiển thị cảnh báo thời tiết sau khi đã nạp xong thông tin trường đại học
          _prepareWeatherFuture();
        }
      }

      final remoteAutoConfig = await _firebaseService.getAutoDeadlineConfig();

      if (remoteAutoConfig != null) {
        final mergedConfig = remoteAutoConfig.copyWith(
          moodleUrl: remoteAutoConfig.moodleUrl.trim(),
        );

        if (mounted) {
          setState(() {
            _autoDeadlineConfig = mergedConfig;
          });
        }

        await _maybeSyncMoodleDeadlines();

        await LocalStorageHelper.saveAutoDeadlineConfig(mergedConfig);
      }
    } catch (e) {
      debugPrint("Firebase metadata load error: $e");
    }
  }

  void _listenScheduleRealtime() {
    _scheduleSub?.cancel();

    _scheduleSub = _firebaseService.scheduleStream().listen(
          (remoteSch) async {
        if (!mounted) return;

        setState(() {
          mockSchedule = remoteSch;
        });

        await LocalStorageHelper.saveSchedule(remoteSch);

        _prepareWeatherFuture();

        if (mounted) setState(() {});
      },
      onError: (e) async {
        debugPrint("Schedule stream error: $e");

        final localSch = await LocalStorageHelper.getSchedule();
        if (!mounted) return;

        setState(() {
          mockSchedule = localSch;
        });
      },
    );
  }

  void _listenDeadlineRealtime() {
    _deadlineSub?.cancel();

    _deadlineSub = _firebaseService.deadlineStream().listen(
          (remoteDls) async {
        if (!mounted) return;
        final cleanedDeadlines = await _cleanupExpiredDeadlines(remoteDls);
        if (!mounted) return;

        setState(() {
          mockDeadlines = cleanedDeadlines;
        });

        await LocalStorageHelper.saveDeadlines(cleanedDeadlines);
      },
      onError: (e) async {
        debugPrint("Deadline stream error: $e");

        final localDls = await LocalStorageHelper.getDeadlines();
        if (!mounted) return;

        setState(() {
          mockDeadlines = localDls;
        });
      },
    );
  }

  Future<List<Deadline>> _cleanupExpiredDeadlines(List<Deadline> deadlines) async {
    final now = DateTime.now();
    final remainingDeadlines = <Deadline>[];

    for (final deadline in deadlines) {
      final deadlineDateTime = DateTime(
        deadline.dueDate.year,
        deadline.dueDate.month,
        deadline.dueDate.day,
        deadline.dueTime.hour,
        deadline.dueTime.minute,
      );

      final daysOverdue = now.difference(deadlineDateTime).inDays;

      final shouldDelete =
          (deadline.isCompleted && daysOverdue >= 1) ||
              (!deadline.isCompleted && daysOverdue >= 3);

      if (shouldDelete) {
        for (var nid in deadline.notificationIds) {
          await NotificationService.cancelNotification(nid);
        }
        await _firebaseService.deleteDeadline(deadline.id);
        debugPrint('Deleted expired deadline: ${deadline.title}');
      } else {
        remainingDeadlines.add(deadline);
      }
    }

    return remainingDeadlines;
  }

  void _toggleDeadline(String id) async {
    final index = mockDeadlines.indexWhere((d) => d.id == id);
    if (index != -1) {
      HapticFeedback.lightImpact();
      setState(() {
        mockDeadlines[index].isCompleted = !mockDeadlines[index].isCompleted;
      });

      // Lưu trạng thái mới vào máy
      await LocalStorageHelper.saveDeadlines(mockDeadlines);

      await _firebaseService.saveDeadline(mockDeadlines[index]);
    }
  }

  void _deleteDeadline(String id) async {
    final index = mockDeadlines.indexWhere((d) => d.id == id);
    if (index != -1) {
      HapticFeedback.mediumImpact();
      final deadline = mockDeadlines[index];
      for (var nid in deadline.notificationIds) {
        await NotificationService.cancelNotification(nid);
      }
      
      setState(() {
        mockDeadlines.removeAt(index);
      });
      // Lưu trạng thái mới vào máy
      await LocalStorageHelper.saveDeadlines(mockDeadlines);

      // Nếu có mạng thì xóa trên Firebase
      await _firebaseService.deleteDeadline(id);
    }
  }

  // --- ĐIỀU HƯỚNG (NAVIGATION) ---

  void _navigateToDetail(int tabIndex, {bool forceShowAll = false}) {
    setState(() {
      _isDetailView = true;
      _tabController.index = tabIndex;
      if (tabIndex == 0) {
        _deadlineShowAll = forceShowAll;
      }
    });
  }

  void _backToDashboard() {
    setState(() => _isDetailView = false);
  }

  void _showCreateOptions(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_calendar, color: hcmusBlueAccent),
              title: const Text("Tạo Deadline mới", style: TextStyle(fontFamily: 'Poppins')),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateDeadlinesPage(
                      initialDate: _focusedDate,
                    ),
                  ),
                );
                if (result == true) _loadInitialMetaData(); // QUAN TRỌNG: Load lại sau khi tạo
              },
            ),
            ListTile(
              leading: const Icon(Icons.class_, color: hcmusTeal),
              title: const Text("Tạo Môn học mới", style: TextStyle(fontFamily: 'Poppins')),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateSchedulePage(
                      initialWeekday: selectedWeekday,
                    ),
                  ),
                );
                if (result == true) _loadInitialMetaData(); // QUAN TRỌNG: Load lại sau khi tạo
              },
            ),
          ],
        ),
      ),
    );
  }

  //Auto deadline code

  Future<void> _saveAutoDeadlineConfig(AutoDeadlineConfig config) async {
    final normalized = config.copyWith(updatedAt: DateTime.now());
    await LocalStorageHelper.saveAutoDeadlineConfig(normalized);
    await _firebaseService.saveAutoDeadlineConfig(normalized);

    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _autoDeadlineConfig = normalized;
    });
  }

  Future<void> _showAutoDeadlineConfigSheet() async {
    final bool isPolicyAccepted = await LocalStorageHelper.isMoodlePolicyAccepted();
    if (!isPolicyAccepted) {
      if (!mounted) return;
      final bool? proceed = await showMoodlePolicyDialog(context);
      if (proceed != true) return;
      await LocalStorageHelper.setMoodlePolicyAccepted(true);
    }

    if (!mounted) return;
    await showAutoDeadlineConfigSheet(
      context,
      currentConfig: _autoDeadlineConfig,
      onSave: _saveAutoDeadlineConfig,
      onSyncNow: () => _maybeSyncMoodleDeadlines(force: true),
    );
  }

  Future<void> _maybeSyncMoodleDeadlines({bool force = false}) async {
    final config = _autoDeadlineConfig;

    if (config == null ||
        !config.isEnabled ||
        config.moodleUrl.trim().isEmpty) {
      debugPrint('Moodle sync skipped: config missing/disabled.');
      return;
    }

    final lastSync = config.updatedAt;

    if (!force &&
        lastSync != null &&
        DateTime.now().difference(lastSync).inHours < 12) {
      debugPrint('Moodle sync skipped: cooldown active.');
      return;
    }

    final token = await MoodleTokenStorage.getToken();

    if (token == null || token.trim().isEmpty) {
      debugPrint('Moodle sync skipped: missing token.');
      return;
    }

    try {
      debugPrint('Moodle sync started for: ${config.moodleUrl}');

      final events = await MoodleService.fetchUpcomingEvents(
        moodleUrl: config.moodleUrl,
        token: token,
      );

      if (events == null) {
        debugPrint('Moodle sync failed: events is null.');
        return;
      }

      debugPrint('Fetched Moodle events: ${events.length}');

      // Xử lý xóa các deadline đã bị xóa trên Moodle
      final fetchedMoodleIds = events.map((e) => 'moodle_${e['id']}').toSet();
      final currentDeadlines = await _firebaseService.getDeadlines();
      final localMoodleDeadlines = currentDeadlines.where((d) => d.isMoodleSynced).toList();

      for (final localD in localMoodleDeadlines) {
        if (!fetchedMoodleIds.contains(localD.id)) {
          // Nếu deadline còn trong tương lai nhưng không còn trong danh sách sắp tới của Moodle -> Xóa
          if (localD.dueDate.isAfter(DateTime.now())) {
            debugPrint('Xóa deadline Moodle vì không còn tồn tại trên Moodle: ${localD.title}');
            await _firebaseService.deleteDeadline(localD.id);
          }
        }
      }

      for (final event in events) {
        final int? timestamp = event['timestart'];

        if (timestamp == null) continue;

        final DateTime dateTime =
        DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

        final rawDescription = cleanHtml(
          (event['description'] ?? '').toString(),
        ).trim();

        final deadline = Deadline(
          id: 'moodle_${event['id']}',
          title: (event['name'] ?? 'Untitled Moodle Event').toString(),
          description: rawDescription.isNotEmpty
              ? rawDescription
              : 'Deadline được lấy từ Moodle',
          dueDate: dateTime,
          dueTime: TimeOfDay.fromDateTime(dateTime),
          isCompleted: false,
          isMoodleSynced: true,
        );

        debugPrint('CREATED DEADLINE: ${deadline.title}');

        await _firebaseService.saveDeadline(deadline);
      }

      final updatedConfig = config.copyWith(
        updatedAt: DateTime.now(),
      );

      await _saveAutoDeadlineConfig(updatedConfig);

      debugPrint('Moodle sync completed.');
    } catch (e) {
      debugPrint('Moodle sync error: $e');
    }
  }

  String cleanHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }



  String _formatTime24h(dynamic time) {
    // Trường hợp 1: Nếu đầu vào là TimeOfDay (thường dùng cho Deadline)
    if (time is TimeOfDay) {
      final hours = time.hour.toString().padLeft(2, '0');
      final minutes = time.minute.toString().padLeft(2, '0');
      return '$hours:$minutes';
    }

    // Trường hợp 2: Nếu đầu vào là String (thường dùng cho Schedule có AM/PM)
    if (time is String) {
      try {
        // Loại bỏ khoảng trắng và chuyển về viết hoa để dễ so sánh
        String input = time.toUpperCase().trim();
        bool isPM = input.contains("PM");
        bool isAM = input.contains("AM");

        // Lấy phần số (ví dụ "01:30 PM" -> "01:30")
        String numericPart = input.replaceAll("AM", "").replaceAll("PM", "").trim();
        List<String> parts = numericPart.split(":");

        int hour = int.parse(parts[0]);
        int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

        // Chuyển đổi logic 12h -> 24h
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;

        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      } catch (e) {
        // Nếu lỗi parse hoặc chuỗi đã là 24h rồi, trả về nguyên bản
        return time;
      }
    }

    return time.toString();
  }

  DateTime _focusedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _focusedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDarkMode ? ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: hcmusBlueAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1C1C1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1C1C1E),
          ) : ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: hcmusBlueAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _focusedDate) {
      setState(() {
        _focusedDate = picked;
        // Cập nhật selectedWeekday để khớp với ngày vừa chọn
        selectedWeekday = picked.weekday + 1;
      });
      _prepareWeatherFuture();
    }
  }

  // Hàm tính toán ngày trong tuần (Giữ nguyên logic cũ của bạn)
  List<Map<String, dynamic>> _getCurrentWeekDays() {
    DateTime referenceDate = _focusedDate;
    // Tìm ngày thứ 2 của tuần chứa referenceDate
    DateTime monday = referenceDate.subtract(Duration(days: referenceDate.weekday - 1));
    return List.generate(7, (index) {
      DateTime day = monday.add(Duration(days: index));
      return {
        "day": day.day.toString(),
        "label": index == 6 ? "CN" : "T${index + 2}",
        "value": index + 2,
        "fullDate": DateTime(day.year, day.month, day.day)
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: Stack(
        children: [
          // 1. Phần Header cố định (Fixed Header)
          _buildFixedHeader(context),

          // 2. Phần nội dung có thể cuộn (Scrollable Content)
          Column(
            children: [
              // Khoảng trống để lộ phần Header Logo & HCMUS (Khớp với top 102px trong Figma)
              SizedBox(height: MediaQuery.of(context).padding.top + 64.0),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600.0),
                      child: _isDetailView
                          ? _buildDetailViewContent() // Hiển thị nội dung DI
                          : _buildDashboardContent(), // Hiển thị nội dung 3.1
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      floatingActionButton: _isDetailView
          ? FloatingActionButton(
        onPressed: () => _showCreateOptions(context),
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFF5A5959),
        child: const Icon(Icons.add, size: 36, color: Colors.white),
      )
          : null,
    );
  }

  // --- DASHBOARD CONTENT (3.1) ---
  DateTime _combineDateAndTime(DateTime date, String time) {
    final input = time.trim().toUpperCase();

    DateTime parsedTime;

    try {
      if (input.contains('AM') || input.contains('PM')) {
        parsedTime = DateFormat('h:mm a').parse(input);
      } else {
        parsedTime = DateFormat('HH:mm').parse(input);
      }

      return DateTime(
        date.year,
        date.month,
        date.day,
        parsedTime.hour,
        parsedTime.minute,
      );
    } catch (e) {
      debugPrint('Cannot parse schedule time: $time, error: $e');

      return DateTime(
        date.year,
        date.month,
        date.day,
        0,
        0,
      );
    }
  }

  String? _mapUniversityToCampusId(String university) {
    switch (university.trim()) {
      case 'VNU - HCMUS (CS1)':
        return 'us_cs1';
      case 'VNU - HCMUS (CS2)':
        return 'us_cs2';
      default:
        return null;
    }
  }

  Widget _buildCompactSummaryBanner() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final todayClassesCount =
        mockSchedule.where((c) => c.weekday == selectedWeekday).length;

    final activeDeadlinesCount =
        mockDeadlines.where((d) => !d.isCompleted).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      constraints: const BoxConstraints(minHeight: 92),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF40539B).withValues(alpha: 0.9), const Color(0xFF74C98C)]
              : [const Color(0xFF042788).withValues(alpha: 0.9), const Color(0xFF439472).withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            /*
            child: SizedBox(
              width: 18,
              height: 18,
              child: Image.asset(
                'assets/images/welcome.png',
                fit: BoxFit.contain,
              ),
            ),
             */
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 13, // Giảm nhẹ font size để an toàn hơn
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  const TextSpan(text: 'Hôm nay bạn có '),
                  TextSpan(
                    text: '$todayClassesCount lớp học',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' và '),
                  TextSpan(
                    text: '$activeDeadlinesCount deadline',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' cần giải quyết.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    final todayClasses =
    mockSchedule.where((c) => c.weekday == selectedWeekday).toList();

    List<Deadline> sortedDeadlines = List.from(mockDeadlines);
    sortedDeadlines.sort((a, b) {
      final aDateTime = DateTime(
        a.dueDate.year,
        a.dueDate.month,
        a.dueDate.day,
        a.dueTime.hour,
        a.dueTime.minute,
      );
      final bDateTime = DateTime(
        b.dueDate.year,
        b.dueDate.month,
        b.dueDate.day,
        b.dueTime.hour,
        b.dueTime.minute,
      );
      return aDateTime.compareTo(bDateTime);
    });

    List<Deadline> top3Deadlines = sortedDeadlines.take(3).toList();

    final campusId = _mapUniversityToCampusId(_userUniversity);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          FutureBuilder<WeatherAlertResult>(
            future: _weatherFuture ?? Future.value(WeatherAlertResult.none()),
            builder: (context, snapshot) {
              final result = snapshot.data ?? WeatherAlertResult.none();

              if (snapshot.connectionState == ConnectionState.waiting ||
                  !result.shouldShow) {
                return _buildWelcomeBannerFigma();
              }

              return IntrinsicHeight( // Giúp 2 thẻ cao bằng nhau mượt mà
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildCompactSummaryBanner(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: WeatherAlertCard(alert: result),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 25),

          MySpaceDeadlineSection(
            autoDeadlineConfig: _autoDeadlineConfig,
            deadlines: top3Deadlines,
            totalDeadlinesCount: mockDeadlines.length,
            onOpenAutoConfig: _showAutoDeadlineConfigSheet,
            onOpenDetail: () => _navigateToDetail(0, forceShowAll: true),
            onToggleDeadline: _toggleDeadline,
            onDeleteDeadline: _deleteDeadline,
          ),

          if (top3Deadlines.isEmpty) _buildEmptyStateMeme(type: 'deadline'),

          const SizedBox(height: 20),
          _buildSectionHeaderFigma("Thời Khóa Biểu", () => _navigateToDetail(1)),
          _buildCalendarStripFigma(),
          ...todayClasses.map((c) => _buildScheduleCardFigma(c)),

          if (todayClasses.isEmpty)
            _buildEmptyStateMeme(type: 'class'),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmptyStateMeme({
    required String type,
  }) {
    final bool isDarkMode =
        Theme.of(context).brightness == Brightness.dark;

    String imagePath;
    String title;

    switch (type) {
      case 'deadline':
        imagePath = 'assets/images/no_deadline_meme.gif';
        title = 'Hết deadline rồi quẩy thôi!';
        break;

      case 'class':
        imagePath = 'assets/images/no_class_meme.png';
        title = 'Nay rảnh thì đi chơi hông người đẹp?';
        break;

      default:
        imagePath = 'assets/images/no_class_meme.png';
        title = 'Trống trơn';
    }

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Image.asset(
              imagePath,
              height: 120,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 10),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white
                    : const Color(0xFF040404),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildDetailViewContent() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        // 1. Lớp phủ mờ nội bộ (Chỉ cao 150px như Figma)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
          child: Container(
            decoration: BoxDecoration(
              color: (isDarkMode ? const Color(0xFF23242A) : const Color(0xFFEBEBF5)).withValues(alpha: 0.9),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
          ),
        ),

        // 2. Nội dung thực tế (Lịch, Toggle, List)
        Column(
          children: [
            // Header của Detail (Tháng X, Y)
             Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    onPressed: _backToDashboard,
                  ),
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _selectDate(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 2),
                            Text(
                              "Tháng ${_focusedDate.month}, ${_focusedDate.year}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: isDarkMode ? Colors.white : Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            _buildDetailCalendarStrip(),
            const SizedBox(height: 24),
            _buildSlidingToggle(),
            const SizedBox(height: 2),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  MySpaceDeadlineDetailList(
                    deadlines: mockDeadlines,
                    selectedWeekday: selectedWeekday,
                    currentWeek: _getCurrentWeekDays(),
                    onToggleDeadline: _toggleDeadline,
                    onDeleteDeadline: _deleteDeadline,
                    onEditDeadline: _editDeadline,
                    initialShowAll: _deadlineShowAll,
                  ),
                  _buildScheduleDetailList(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
  int _countDeadlinesForDate(DateTime date) {
    return mockDeadlines.where((d) =>
    d.dueDate.year == date.year &&
        d.dueDate.month == date.month &&
        d.dueDate.day == date.day
    ).length;
  }

  int _countClassesForDate(int weekday) {
    return mockSchedule.where((c) => c.weekday == weekday).length;
  }

  Widget _buildDetailCalendarStrip() {
    final currentWeek = _getCurrentWeekDays();
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: List.generate(currentWeek.length, (index) {
          final dayData = currentWeek[index];
          DateTime dayDate = dayData['fullDate'];
          int weekdayValue = dayData['value']; // T2=2, T3=3... CN=8
          bool isSelected = selectedWeekday == weekdayValue;

          // Logic thay đổi thông số thông báo
          final isScheduleTab = _tabController.index == 1;

          int count = isScheduleTab
              ? _countClassesForDate(weekdayValue)
              : _countDeadlinesForDate(dayDate);

          Color badgeColor = isScheduleTab ? hcmusTeal : hcmusRed;

          return Expanded(
            child: GestureDetector(
               onTap: () {
                setState(() {
                  selectedWeekday = weekdayValue;
                  _focusedDate = dayDate;
                });
                _prepareWeatherFuture();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? hcmusBlueAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${dayDate.day}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : (isDarkMode ? Colors.white : Colors.black),
                          ),
                        ),
                        Text(
                          dayData['label'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : (isDarkMode ? Colors.white60 : const Color(0xff94A3B8)),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Badge thông báo (Đỏ cho Deadline, Teal cho Schedule)
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: count > 0
                              ? Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: badgeColor,
                              shape: BoxShape.circle,
                            ),
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(
                                  "$count",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // Thanh trượt deadlines và schedules
  Widget _buildSlidingToggle() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _tabController.animation!,
      builder: (context, child) {
        final double animValue = _tabController.animation?.value ?? 0.0;
        final Color activeColor = Color.lerp(hcmusRed, hcmusTeal, animValue) ?? hcmusRed;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                width: 1.5,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: activeColor,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            labelColor: isDarkMode ? Colors.white : const Color(0xFF1E293B),
            unselectedLabelColor: isDarkMode ? Colors.white38 : const Color(0xFF94A3B8),
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
              fontSize: 15,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
              fontSize: 14,
            ),
            tabs: const [
              Tab(
                height: 40,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text("Deadline"),
                ),
              ),
              Tab(
                height: 40,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text("Thời Khóa Biểu"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editDeadline(Deadline deadline) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateDeadlinesPage(deadline: deadline),
      ),
    );
    if (result == true) _loadInitialMetaData(); // Load lại sau khi sửa
  }

  void _editSchedule(StudyClass schedule) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateSchedulePage(schedule: schedule),
      ),
    );
    if (result == true) _loadInitialMetaData(); // Tải lại dữ liệu sau khi sửa
  }



  Widget _buildScheduleDetailList() {
    final dayClasses = mockSchedule.where((c) => c.weekday == selectedWeekday).toList();

    if (dayClasses.isEmpty) {
      return Center(child: Text("Hôm nay không có lịch học", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: dayClasses.length,
      itemBuilder: (context, index) {
        final c = dayClasses[index];
        return _buildScheduleCardFigma(c);
      },
    );
  }

  Widget _buildFixedHeader(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        // Background Image - Cố định
        Container(
          height: statusBarHeight + 102.0,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/hcmus_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(color: Colors.black.withOpacity(0.45)),
        ),

        // Logo & HCMUS Text & Notification - Cố định
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 35),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cụm trái: Logo + Tên trường
                Row(children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Image.asset('assets/images/logoAppName.png', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text("HCMUS",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          fontFamily: 'Nunito',
                          letterSpacing: 1.2
                      )
                  ),
                ]),

                // Cụm phải: Nút thông báo UI Capsule (Đã cập nhật)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => NotificationScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xff545454),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: StreamBuilder<List<MyUniNotification>>(
                      stream: NotificationService.getNotifications(),
                      builder: (context, snapshot) {
                        // Đếm số thông báo chưa đọc thực tế
                        final unreadCount = snapshot.data?.where((n) => !n.isRead).length ?? 0;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                            if (unreadCount > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: CircleAvatar(
                                  radius: 6,
                                  backgroundColor: Colors.red,
                                  child: Text(
                                    unreadCount > 9 ? "9+" : unreadCount.toString(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ),
                              )
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeBannerFigma() {
    final int today = DateTime.now().weekday + 1;
    final int todayClassesCount = mockSchedule.where((c) => c.weekday == today).length;
    final int pendingDeadlinesCount = mockDeadlines.where((d) => !d.isCompleted).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF042788).withValues(alpha: 0.9),
            const Color(0xFF60CA6F).withValues(alpha: 1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withValues(alpha: 0.25),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              /*
              SizedBox(
                width: 20,
                height: 20,
                child: Image.asset(
                  'assets/images/welcome.png',
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 8),
              */
              Text("Chào bạn!",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins')
              ),
            ],
          ),
          SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500, // Độ đậm cơ bản cho cả câu
              ),
              children: [
                const TextSpan(text: "Hôm nay bạn có "),
                TextSpan(
                  text: "$todayClassesCount lớp học",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800, // In đậm con số lớp học
                    fontSize: 14, // Có thể tăng size nhẹ để nổi bật hơn
                  ),
                ),
                const TextSpan(text: " và "),
                TextSpan(
                  text: "$pendingDeadlinesCount deadline",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800, // In đậm con số deadline
                    fontSize: 14,
                  ),
                ),
                const TextSpan(text: " cần giải quyết."),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildSectionHeaderFigma(String title, VoidCallback onPressed) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: isDarkMode ? Colors.white : Colors.black87)),
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF2A2A2E) : hcmusLightGrey, shape: BoxShape.circle),
            child: Icon(Icons.list_rounded, size: 18, color: isDarkMode ? Colors.white70 : Colors.black87),
          ),
        )
      ],
    );
  }

  Widget _buildCalendarStripFigma() {
    final List<Map<String, dynamic>> currentWeek = _getCurrentWeekDays();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: currentWeek.map((d) => Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedWeekday = d['value'];
                _focusedDate = d['fullDate'];
              });
              _prepareWeatherFuture();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _calendarDayFigma(
                  d['day'],
                  d['label'],
                  isSelected: selectedWeekday == d['value']
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _calendarDayFigma(String day, String weekday, {bool isSelected = false}) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: isSelected ? hcmusBlueAccent : (isDarkMode ? const Color(0xFF2A2A2E) : hcmusLightGrey),
        borderRadius: BorderRadius.circular(20),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekday,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              day,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : (isDarkMode ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showScheduleActionMenu(StudyClass s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.name, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.grey)),
              Divider(color: isDarkMode ? Colors.white12 : null),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: hcmusTeal),
                title: const Text("Chỉnh sửa lịch học"),
                onTap: () {
                  Navigator.pop(context);
                  _editSchedule(s); // Gọi hàm sửa vừa tạo
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: hcmusRed),
                title: const Text("Xóa lịch học", style: TextStyle(color: hcmusRed)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteSchedule(s.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteSchedule(String id) async {
    setState(() {
      mockSchedule.removeWhere((s) => s.id == id);
    });
    await LocalStorageHelper.saveSchedule(mockSchedule);

    await _firebaseService.deleteSchedule(id);
  }

  Widget _buildScheduleCardFigma(StudyClass c) { // Thay đổi tham số truyền vào là StudyClass
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 80, // Điều chỉnh theo Figma (94px)
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        // hcmusTeal
        color: isDarkMode ? const Color(0xFF164E63) : hcmusTeal,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              // Thanh màu bên trái
              Container(
                width: 10,
                decoration: BoxDecoration(
                  color: c.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 15),

              // Giờ giấc (07:30 - 09:10)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_formatTime24h(c.start), style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Poppins', fontWeight: FontWeight.w500)),
                  const SizedBox(height: 20), // Khoảng cách giữa start và end
                  Text(_formatTime24h(c.end), style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Poppins', fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(width: 10),

              // Line 13 (Vertical Divider)
              const VerticalDivider(
                color: Colors.white,
                indent: 10,
                endIndent: 10,
                thickness: 1.5,
              ),
              const SizedBox(width: 10),

              // Thông tin môn học và phòng
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          c.room,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Khoảng trống cho nút ba chấm
              const SizedBox(width: 40),
            ],
          ),

          // NÚT BA CHẤM (More Action)
          Positioned(
            right: 8,
            top: 8,
            child: GestureDetector(
              onTap: () => _showScheduleActionMenu(c), // Gọi hàm Menu của Schedule
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.more_horiz,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}