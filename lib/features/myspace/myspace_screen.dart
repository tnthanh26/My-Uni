import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './models/myspace_models.dart';
import 'campus_data.dart';
import 'create_deadlines_page.dart';
import 'create_schedule_page.dart';
import 'package:my_uni/features/event/create_personal_event_page.dart';
import 'package:my_uni/features/event/event_detail_sheet.dart';
import 'local_storage_helper.dart';
import 'myspace_firebase_service.dart';
import 'package:my_uni/features/notification/notification_page.dart';
import 'package:my_uni/features/notification/message_notification_page.dart';
import 'package:my_uni/features/services/notification_service.dart';
import 'package:my_uni/models/notification_model.dart';
import 'package:my_uni/models/event_model.dart';
import './services/myspace_weather_coordinator.dart';
import './services/weather_alert_service.dart';
import './services/weather_service.dart';
import './services/moodle_service.dart';
import './services/moodle_token_storage.dart';
import './models/weather_models.dart';
import './services/welcome_banner_service.dart';
import 'weather_alert_card.dart';
import 'myspace_deadline_section.dart';
import 'widgets/myspace_skeleton.dart';
import 'widgets/schedule_calendar_grid.dart';
import 'package:my_uni/widgets/app_action_dialogs.dart';
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
  List<EventModel> mockPersonalEvents = [];
  AutoDeadlineConfig? _autoDeadlineConfig;
  String _userUniversity = '';
  Future<WeatherAlertResult>? _weatherFuture;
  bool _isLoadingData = true;
  StreamSubscription<List<StudyClass>>? _scheduleSub;
  StreamSubscription<List<Deadline>>? _deadlineSub;
  StreamSubscription<QuerySnapshot>? _personalEventsSub;
  final ScrollController _timetableScrollController = ScrollController();
  final ScrollController _dashboardScrollController = ScrollController();
  late final PageController _dayPageController;
  late final PageController _weekPageController;
  static final DateTime _anchorDate = DateTime(2020, 1, 1);
  static final DateTime _weekAnchorMonday = DateTime(2020, 1, 6);

  int _getPageIndexFromDate(DateTime date) {
    return date.difference(_anchorDate).inDays;
  }

  DateTime _getDateFromPageIndex(int pageIndex) {
    return _anchorDate.add(Duration(days: pageIndex));
  }

  int _weekPageIndexFromDate(DateTime date) {
    final normalizedDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final monday = normalizedDate.subtract(
      Duration(days: normalizedDate.weekday - 1),
    );

    return monday.difference(_weekAnchorMonday).inDays ~/ 7;
  }

  DateTime _mondayFromWeekPage(int pageIndex) {
    return _weekAnchorMonday.add(
      Duration(days: pageIndex * 7),
    );
  }

  void _updateFocusedDate(
    DateTime targetDate, {
    bool jumpPage = true,
    bool animate = true,
    bool updateWeekPage = true,
  }) {
    final DateTime normalized = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    final int oldWeekPage = _weekPageIndexFromDate(_focusedDate);
    final int newWeekPage = _weekPageIndexFromDate(normalized);

    setState(() {
      _focusedDate = normalized;
      selectedWeekday = normalized.weekday + 1;
    });

    if (updateWeekPage && _weekPageController.hasClients) {
      final int currentWeekPage = _weekPageController.page?.round() ?? oldWeekPage;
      if (currentWeekPage != newWeekPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_weekPageController.hasClients) return;
          if (animate && (newWeekPage - currentWeekPage).abs() <= 4) {
            _weekPageController.animateToPage(
              newWeekPage,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            );
          } else {
            _weekPageController.jumpToPage(newWeekPage);
          }
        });
      }
    }

    if (!jumpPage || !_dayPageController.hasClients) {
      return;
    }

    final int targetPage = _getPageIndexFromDate(normalized);
    final int currentPage = _dayPageController.page?.round() ?? targetPage;

    if (currentPage == targetPage) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_dayPageController.hasClients) return;
      if (animate && (targetPage - currentPage).abs() == 1) {
        _dayPageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _dayPageController.jumpToPage(targetPage);
      }
    });
  }

  void _onDayPageChanged(int index) {
    final targetDate = _getDateFromPageIndex(index);

    if (DateUtils.isSameDay(targetDate, _focusedDate)) {
      return;
    }

    final int oldWeekPage = _weekPageIndexFromDate(_focusedDate);
    final int newWeekPage = _weekPageIndexFromDate(targetDate);

    setState(() {
      _focusedDate = targetDate;
      selectedWeekday = targetDate.weekday + 1;
    });

    if (oldWeekPage != newWeekPage && _weekPageController.hasClients) {
      final int currentWeekPage = _weekPageController.page?.round() ?? oldWeekPage;
      if (currentWeekPage != newWeekPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_weekPageController.hasClients) return;
          _weekPageController.animateToPage(
            newWeekPage,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    selectedWeekday = DateTime.now().weekday + 1;
    _dayPageController = PageController(
      initialPage: _getPageIndexFromDate(_focusedDate),
    );
    _weekPageController = PageController(
      initialPage: _weekPageIndexFromDate(_focusedDate),
    );
    // Khởi tạo TabController cho phần Detail
    _tabController = TabController(length: 2, vsync: this);

    _loadInitialMetaData();

    _listenScheduleRealtime();
    _listenDeadlineRealtime();
    _listenPersonalEventsRealtime();

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    _dayPageController.dispose();
    _dashboardScrollController.dispose();
    _timetableScrollController.dispose();
    _personalEventsSub?.cancel();
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
    _updateFocusedDate(DateTime.now(), jumpPage: true);
  }

  void _prepareWeatherFuture() {
    final now = DateTime.now();
    final realTodayWeekday = now.weekday + 1;

    // Luôn luôn lấy lịch học của ngày HÔM NAY thực tế (DateTime.now())
    final todayClasses = mockSchedule.where((c) => c.weekday == realTodayWeekday).toList()
      ..sort((a, b) => a.startHourFraction.compareTo(b.startHourFraction));

    final defaultCampusId = CampusData.mapUniversityToCampusId(_userUniversity);

    debugPrint('=== PREPARE WEATHER FUTURE FOR TODAY ===');
    debugPrint('_userUniversity: $_userUniversity');
    debugPrint('defaultCampusId: $defaultCampusId');
    debugPrint('realTodayWeekday: $realTodayWeekday, todayClasses length: ${todayClasses.length}');

    if (todayClasses.isEmpty) {
      _weatherFuture = Future.value(WeatherAlertResult.none());
      return;
    }

    final schedules = todayClasses.map((c) {
      final classCampusId = c.campusId ?? defaultCampusId ?? '';
      return ScheduleItem(
        id: c.id,
        title: c.name,
        startTime: _combineDateAndTime(now, c.start),
        endTime: _combineDateAndTime(now, c.end),
        campusId: classCampusId,
        room: c.room,
      );
    }).where((item) => item.campusId.isNotEmpty).toList();

    if (schedules.isEmpty) {
      _weatherFuture = Future.value(WeatherAlertResult.none());
      return;
    }

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

    final localDeadlines = await LocalStorageHelper.getDeadlines();
    final localSchedule = await LocalStorageHelper.getSchedule();
    final localAutoConfig = await LocalStorageHelper.getAutoDeadlineConfig(
      moodleUrl: '',
    );

    if (mounted) {
      setState(() {
        if (localDeadlines.isNotEmpty) mockDeadlines = localDeadlines;
        if (localSchedule.isNotEmpty) mockSchedule = localSchedule;
        _autoDeadlineConfig = localAutoConfig;
        if (localDeadlines.isNotEmpty || localSchedule.isNotEmpty) {
          _isLoadingData = false;
        }
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
          _isLoadingData = false;
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
          _isLoadingData = false;
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
          _isLoadingData = false;
        });

        await LocalStorageHelper.saveDeadlines(cleanedDeadlines);
      },
      onError: (e) async {
        debugPrint("Deadline stream error: $e");

        final localDls = await LocalStorageHelper.getDeadlines();
        if (!mounted) return;

        setState(() {
          mockDeadlines = localDls;
          _isLoadingData = false;
        });
      },
    );
  }

  void _listenPersonalEventsRealtime() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _personalEventsSub?.cancel();

    _personalEventsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('personal_events')
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        final events = snapshot.docs
            .map((doc) => EventModel.fromFirestore(doc))
            .toList();
        setState(() {
          mockPersonalEvents = events;
        });
      },
      onError: (e) {
        debugPrint("Personal events stream error: $e");
      },
    );
  }

  Future<List<Deadline>> _cleanupExpiredDeadlines(List<Deadline> deadlines) async {
    // Không tự động xóa deadline quá hạn khi user stick hoặc hết hạn. 
    // Người dùng sẽ chủ động xóa bằng nút Delete (Trash icon).
    return deadlines;
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
    _resetToToday();
    if (_dashboardScrollController.hasClients) {
      _dashboardScrollController.jumpTo(0.0);
    }
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
                      userUniversity: _userUniversity,
                    ),
                  ),
                );
                if (result == true) _loadInitialMetaData(); // QUAN TRỌNG: Load lại sau khi tạo
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_available_rounded, color: Color(0xFF5893D8)),
              title: const Text("Tạo Sự kiện cá nhân", style: TextStyle(fontFamily: 'Poppins')),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreatePersonalEventPage(),
                  ),
                );
                if (result == true || result != null) _loadInitialMetaData();
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
      locale: const Locale('vi', 'VN'),
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
      _updateFocusedDate(picked, jumpPage: true);
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
    return PopScope(
      canPop: !_isDetailView,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isDetailView) {
          _backToDashboard();
        }
      },
      child: Scaffold(
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
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.topCenter,
                              children: <Widget>[
                                ...previousChildren,
                                ?currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          child: _isDetailView
                              ? KeyedSubtree(
                                  key: const ValueKey('detailView'),
                                  child: _buildDetailViewContent(),
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('dashboardView'),
                                  child: _buildDashboardContent(),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        floatingActionButton: FloatingActionButton(
          heroTag: 'fab_myspace_tab',
          tooltip: 'Thêm nội dung',
          onPressed: () {
            _showCreateOptions(context);
          },
          backgroundColor: const Color(0xFF5893D8),
          foregroundColor: Colors.white,
          elevation: 3,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.add_rounded,
            size: 27,
          ),
        ),
      ),
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



  Widget _buildCompactSummaryBanner({
    required int classesCount,
    required int deadlinesCount,
    required int eventsCount,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<WelcomeBannerData>(
      future: WelcomeBannerService.generateBannerData(
        todayClasses: classesCount,
        todayDeadlines: deadlinesCount,
        todayEvents: eventsCount,
        now: DateTime.now(),
      ),
      builder: (context, snapshot) {
        final data = snapshot.data ??
            WelcomeBannerData(
              greeting: WelcomeBannerService.getGreeting(DateTime.now()),
              text: "Hôm nay bạn có $classesCount lớp học.",
              spans: [
                const TextSpan(text: "Hôm nay bạn có "),
                TextSpan(
                  text: "$classesCount lớp học",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: "."),
              ],
            );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          constraints: const BoxConstraints(minHeight: 92),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [
                      const Color(0xFF40539B).withValues(alpha: 0.9),
                      const Color(0xFF74C98C)
                    ]
                  : [
                      const Color(0xFF042788).withValues(alpha: 0.9),
                      const Color(0xFF439472).withValues(alpha: 0.7)
                    ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                data.greeting,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                  children: data.spans,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardContent() {
    final todayClasses = mockSchedule.where((c) => c.weekday == selectedWeekday).toList()
      ..sort((a, b) => a.startHourFraction.compareTo(b.startHourFraction));

    final weekDays = _getCurrentWeekDays();
    final selectedDayMap = weekDays.firstWhere(
      (w) => w['value'] == selectedWeekday,
      orElse: () => weekDays.first,
    );
    final DateTime selectedFullDate = selectedDayMap['fullDate'] as DateTime;

    final todayEvents = mockPersonalEvents
        .where((e) => DateUtils.isSameDay(e.dateTime, selectedFullDate))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

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

    if (_isLoadingData && mockDeadlines.isEmpty && mockSchedule.isEmpty) {
      return const MySpaceDashboardSkeleton();
    }
    return SingleChildScrollView(
      controller: _dashboardScrollController,
      physics: const ClampingScrollPhysics(),
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
                return _buildWelcomeBannerFigma(
                  classesCount: todayClasses.length,
                  deadlinesCount: mockDeadlines.where((d) => !d.isCompleted).length,
                  eventsCount: todayEvents.length,
                );
              }

              return IntrinsicHeight( // Giúp 2 thẻ cao bằng nhau mượt mà
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildCompactSummaryBanner(
                        classesCount: todayClasses.length,
                        deadlinesCount: mockDeadlines.where((d) => !d.isCompleted).length,
                        eventsCount: todayEvents.length,
                      ),
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
            onOpenDetail: () => _navigateToDetail(0, forceShowAll: false),
            onToggleDeadline: _toggleDeadline,
            onDeleteDeadline: _deleteDeadline,
          ),

          if (top3Deadlines.isEmpty) _buildEmptyStateMeme(type: 'deadline'),

          const SizedBox(height: 20),
          _buildSectionHeaderFigma("Lịch học & Sự kiện", () => _navigateToDetail(1), isSchedule: true),
          _buildCalendarStripFigma(),

          if (todayClasses.isNotEmpty) ...[
            _buildMiniSectionLabel('Lịch học', count: todayClasses.length, icon: Icons.school_outlined),
            ...todayClasses.map((c) => _buildScheduleCardFigma(c)),
          ],

          if (todayClasses.isNotEmpty && todayEvents.isNotEmpty)
            const SizedBox(height: 12),

          if (todayEvents.isNotEmpty) ...[
            _buildMiniSectionLabel('Sự kiện', count: todayEvents.length, icon: Icons.event_note_outlined),
            ...todayEvents.map((ev) => _buildPersonalEventCardFigma(ev)),
          ],

          if (todayClasses.isEmpty && todayEvents.isEmpty)
            _buildEmptyStateMeme(type: 'class'),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildMiniSectionLabel(String title, {int? count, IconData? icon}) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            count != null ? '$title ($count)' : title,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
            ),
          ),
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
          height: 150,
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
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildDeadlinePageView(),
                  _buildScheduleCalendarGridPageView(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScheduleCalendarGridPageView() {
    return PageView.builder(
      controller: _dayPageController,
      onPageChanged: _onDayPageChanged,
      itemBuilder: (context, index) {
        final pageDate = _getDateFromPageIndex(index);
        final pageWeekday = pageDate.weekday + 1;

        final dayClasses = mockSchedule.where((c) => c.weekday == pageWeekday).toList();
        final dayEvents = mockPersonalEvents
            .where((e) => DateUtils.isSameDay(e.dateTime, pageDate))
            .toList();

        return ScheduleCalendarGrid(
          key: ValueKey('schedule_grid_${pageDate.year}_${pageDate.month}_${pageDate.day}'),
          focusedDate: pageDate,
          selectedWeekday: pageWeekday,
          dayClasses: dayClasses,
          dayEvents: dayEvents,
          onScheduleTap: _showScheduleActionMenu,
          onEventTap: _showPersonalEventActionMenu,
          scrollController: null,
        );
      },
    );
  }

  Widget _buildDeadlinePageView() {
    return PageView.builder(
      controller: _dayPageController,
      onPageChanged: _onDayPageChanged,
      itemBuilder: (context, index) {
        final pageDate = _getDateFromPageIndex(index);
        final pageWeekday = pageDate.weekday + 1;

        DateTime monday = pageDate.subtract(Duration(days: pageDate.weekday - 1));
        final pageWeek = List.generate(7, (i) {
          DateTime day = monday.add(Duration(days: i));
          return {
            "day": day.day.toString(),
            "label": i == 6 ? "CN" : "T${i + 2}",
            "value": i + 2,
            "fullDate": DateTime(day.year, day.month, day.day)
          };
        });

        return MySpaceDeadlineDetailList(
          key: ValueKey('deadline_list_${pageDate.year}_${pageDate.month}_${pageDate.day}'),
          deadlines: mockDeadlines,
          selectedWeekday: pageWeekday,
          currentWeek: pageWeek,
          onToggleDeadline: _toggleDeadline,
          onDeleteDeadline: _deleteDeadline,
          onEditDeadline: _editDeadline,
          initialShowAll: _deadlineShowAll,
        );
      },
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

  int _countEventsForDate(DateTime date) {
    return mockPersonalEvents
        .where((e) => DateUtils.isSameDay(e.dateTime, date))
        .length;
  }

  Widget _buildDetailCalendarStrip() {
    return SizedBox(
      height: 70,
      child: PageView.builder(
        controller: _weekPageController,
        onPageChanged: (pageIndex) {
          final DateTime newMonday = _mondayFromWeekPage(pageIndex);
          final int selectedDayOffset = _focusedDate.weekday - 1;
          final DateTime targetDate = newMonday.add(
            Duration(days: selectedDayOffset),
          );

          if (!DateUtils.isSameDay(targetDate, _focusedDate)) {
            _updateFocusedDate(
              targetDate,
              jumpPage: true,
              animate: false,
              updateWeekPage: false,
            );
          }
        },
        itemBuilder: (context, pageIndex) {
          final DateTime monday = _mondayFromWeekPage(pageIndex);
          final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
          final isScheduleTab = _tabController.index == 1;
          final Color badgeColor = isScheduleTab ? hcmusTeal : hcmusRed;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: List.generate(7, (index) {
                final DateTime dayDate = monday.add(Duration(days: index));
                final int weekdayValue = dayDate.weekday + 1; // T2=2... CN=8
                final bool isSelected = DateUtils.isSameDay(dayDate, _focusedDate);

                final int count = isScheduleTab
                    ? (_countClassesForDate(weekdayValue) + _countEventsForDate(dayDate))
                    : _countDeadlinesForDate(dayDate);

                final String label = index == 6 ? "CN" : "T${index + 2}";

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _updateFocusedDate(
                        dayDate,
                        jumpPage: true,
                        animate: true,
                      );
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
                                label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : (isDarkMode ? Colors.white60 : const Color(0xff94A3B8)),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 3),
                              // Badge thông báo hiển thị số lượng cụ thể
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
        },
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
                  child: Text("Lịch của tôi"),
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
        builder: (context) => CreateSchedulePage(
          schedule: schedule,
          userUniversity: _userUniversity,
        ),
      ),
    );
    if (result == true) _loadInitialMetaData(); // Tải lại dữ liệu sau khi sửa
  }




  void _showPersonalEventActionMenu(EventModel ev) {
    AppActionDialogs.showActionBottomSheet(
      context: context,
      title: ev.title,
      actions: [
        AppActionItem(
          title: 'Chỉnh sửa sự kiện',
          icon: Icons.edit_outlined,
          onTap: () => _editPersonalEvent(ev),
        ),
        AppActionItem(
          title: 'Xóa sự kiện',
          icon: Icons.delete_outline_rounded,
          isDanger: true,
          onTap: () async {
            final confirm = await AppActionDialogs.showConfirmDialog(
              context: context,
              title: 'Xóa sự kiện?',
              message: 'Bạn có chắc chắn muốn xóa sự kiện "${ev.title}" khỏi lịch cá nhân không?',
              confirmText: 'Xóa',
            );
            if (confirm == true) {
              _deletePersonalEvent(ev.id);
            }
          },
        ),
      ],
    );
  }

  void _editPersonalEvent(EventModel ev) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePersonalEventPage(event: ev),
      ),
    );
  }

  void _deletePersonalEvent(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      HapticFeedback.mediumImpact();
      setState(() {
        mockPersonalEvents.removeWhere((e) => e.id == id);
      });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('personal_events')
          .doc(id)
          .delete();
    } catch (e) {
      debugPrint("Error deleting personal event: $e");
    }
  }

  Widget _buildPersonalEventCardFigma(EventModel ev) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isInterested = ev.isFromFacultyEvent;

    final Color eventBgColor = isInterested
        ? (isDarkMode
        ? const Color(0xFF426C93)
        : const Color(0xFF5F8FB8))
        : (isDarkMode
        ? const Color(0xFF55508A)
        : const Color(0xFF7D74B2));

    final String eventTagText = isInterested ? 'QUAN TÂM' : 'SỰ KIỆN';

    final timeStr = ev.endDateTime != null
        ? "${DateFormat('HH:mm').format(ev.dateTime)} - ${DateFormat('HH:mm').format(ev.endDateTime!)}"
        : DateFormat('HH:mm').format(ev.dateTime);

    return GestureDetector(
      onTap: () => EventDetailSheet.show(
        context,
        ev,
        onRefresh: () {
          if (mounted) setState(() {});
        },
      ),
      child: Container(
        height: 80,
        margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: eventBgColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              const SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      eventTagText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              const VerticalDivider(
                color: Colors.white,
                indent: 10,
                endIndent: 10,
                thickness: 1.5,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ev.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ev.location.isNotEmpty ? ev.location : 'Sự kiện cá nhân / Quan tâm',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          Positioned(
            right: 8,
            top: 0,
            child: GestureDetector(
              onTap: () => _showPersonalEventActionMenu(ev),
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
    ),
  );
  }

  Widget _buildHeaderNotificationButton({
    required String tooltip,
    required IconData icon,
    required int unreadCount,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 30,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 1,
                    top: 0,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF04438),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF303030),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        unreadCount > 9
                            ? '9+'
                            : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
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
                          fontSize: 22,
                          fontFamily: 'Nunito',
                          letterSpacing: 1.2
                      )
                  ),
                ]),

                // Cụm phải: Notification pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.32),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreamBuilder<List<MyUniNotification>>(
                        stream: NotificationService.getMessageNotifications(),
                        builder: (context, snapshot) {
                          final int unreadChatCount = snapshot.data
                              ?.where((noti) => !noti.isRead)
                              .length ??
                              0;

                          return _buildHeaderNotificationButton(
                            tooltip: 'Thông báo tin nhắn',
                            icon: Icons.chat_bubble_rounded,
                            unreadCount: unreadChatCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const MessageNotificationScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: Colors.white.withOpacity(0.20),
                      ),
                      StreamBuilder<List<MyUniNotification>>(
                        stream: NotificationService.getNotifications(),
                        builder: (context, snapshot) {
                          final int unreadCount = snapshot.data
                              ?.where((noti) => !noti.isRead)
                              .length ??
                              0;

                          return _buildHeaderNotificationButton(
                            tooltip: 'Thông báo hoạt động',
                            icon: Icons.notifications_rounded,
                            unreadCount: unreadCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const NotificationScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeBannerFigma({
    required int classesCount,
    required int deadlinesCount,
    required int eventsCount,
  }) {
    return FutureBuilder<WelcomeBannerData>(
      future: WelcomeBannerService.generateBannerData(
        todayClasses: classesCount,
        todayDeadlines: deadlinesCount,
        todayEvents: eventsCount,
        now: DateTime.now(),
      ),
      builder: (context, snapshot) {
        final data = snapshot.data ??
            WelcomeBannerData(
              greeting: WelcomeBannerService.getGreeting(DateTime.now()),
              text: "Hôm nay bạn có $classesCount lớp học.",
              spans: [
                const TextSpan(text: "Hôm nay bạn có "),
                TextSpan(
                  text: "$classesCount lớp học",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: "."),
              ],
            );

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
                color: const Color(0xFF000000).withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    data.greeting,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                  children: data.spans,
                ),
              ),
            ],
          ),
        );
      },
    );
  }



  void _showWeatherScheduleTipDialog() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDarkMode
                          ? [
                              const Color(0xFF1E293B).withOpacity(0.82),
                              const Color(0xFF0F172A).withOpacity(0.92),
                            ]
                          : [
                              Colors.white.withOpacity(0.9),
                              Colors.white.withOpacity(0.96),
                            ],
                    ),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : hcmusBlueAccent.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: hcmusBlueAccent.withOpacity(isDarkMode ? 0.18 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/images/weather-icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Thời Tiết Lên Lớp",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Việc duy trì thời khóa biểu chính xác sẽ giúp My-Uni tự động phân tích và dự báo khả năng có mưa trong suốt khung giờ học tập của bạn, giúp hành trình lên lớp luôn chủ động và an toàn.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          height: 1.45,
                          color: isDarkMode ? Colors.white70 : Colors.black87.withOpacity(0.75),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hcmusBlueAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Đã hiểu",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeaderFigma(String title, VoidCallback onPressed, {bool isSchedule = false}) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: isDarkMode ? Colors.white : Colors.black87)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSchedule) ...[
              GestureDetector(
                onTap: _showWeatherScheduleTipDialog,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF545454) : hcmusLightGrey,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wb_sunny_rounded,
                    size: 18,
                    color: Colors.amber,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onTap: onPressed,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF2A2A2E) : hcmusLightGrey, shape: BoxShape.circle),
                child: Icon(Icons.calendar_month_rounded, size: 18, color: isDarkMode ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
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
    AppActionDialogs.showActionBottomSheet(
      context: context,
      title: s.name,
      actions: [
        AppActionItem(
          title: 'Chỉnh sửa lịch học',
          icon: Icons.edit_outlined,
          onTap: () => _editSchedule(s),
        ),
        AppActionItem(
          title: 'Xóa lịch học',
          icon: Icons.delete_outline_rounded,
          isDanger: true,
          onTap: () async {
            final confirm = await AppActionDialogs.showConfirmDialog(
              context: context,
              title: 'Xóa lịch học?',
              message: 'Bạn có chắc chắn muốn xóa môn học "${s.name}" khỏi thời khóa biểu không?',
              confirmText: 'Xóa',
            );
            if (confirm == true) {
              _deleteSchedule(s.id);
            }
          },
        ),
      ],
    );
  }

  void _deleteSchedule(String id) async {
    setState(() {
      mockSchedule.removeWhere((s) => s.id == id);
    });
    await LocalStorageHelper.saveSchedule(mockSchedule);

    await _firebaseService.deleteSchedule(id);
  }

  Color getMySpaceColor(Color color) {
    const mapping = {
      0xFF039BE5: Color(0xFF5FAFD8),
      0xFFE67C73: Color(0xFFD99A93),
      0xFF33B679: Color(0xFF73C29A),
      0xFF8E24AA: Color(0xFF9C78BC),
      0xFFF4511E: Color(0xFFD98A68),
      0xFFF6BF26: Color(0xFFD9C36B),
      0xFF7986CB: Color(0xFF97A3D6),
    };

    return mapping[color.toARGB32()] ?? color;
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
                  color: getMySpaceColor(c.color),
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
                        Expanded(
                          child: Text(
                            '${c.campusId == 'us_cs1' ? 'CS1' : c.campusId == 'us_cs2' ? 'CS2' : (c.campusId ?? '')}${c.campusId != null && c.room.isNotEmpty ? ' - ' : ''}${c.room}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
            top: 0,
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