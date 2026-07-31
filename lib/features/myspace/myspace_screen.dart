import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './models/myspace_models.dart';
import 'campus_data.dart';
import 'create_deadlines_page.dart';
import 'create_schedule_page.dart';
import 'local_storage_helper.dart';
import 'myspace_firebase_service.dart';
import 'package:my_uni/features/notification/notification_page.dart';
import 'package:my_uni/features/notification/message_notification_page.dart';
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
import 'widgets/myspace_skeleton.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;

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
  bool _isLoadingData = true;
  StreamSubscription<List<StudyClass>>? _scheduleSub;
  StreamSubscription<List<Deadline>>? _deadlineSub;
  final ScrollController _timetableScrollController = ScrollController();
  final ScrollController _dashboardScrollController = ScrollController();

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
    _dashboardScrollController.dispose();
    _timetableScrollController.dispose();
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

    final todayClasses = mockSchedule.where((c) => c.weekday == selectedWeekday).toList()
      ..sort((a, b) => a.startHourFraction.compareTo(b.startHourFraction));

    final defaultCampusId = CampusData.mapUniversityToCampusId(_userUniversity);

    debugPrint('=== PREPARE WEATHER FUTURE ===');
    debugPrint('_userUniversity: $_userUniversity');
    debugPrint('defaultCampusId: $defaultCampusId');
    debugPrint('todayClasses length: ${todayClasses.length}');

    if (todayClasses.isEmpty) {
      _weatherFuture = Future.value(WeatherAlertResult.none());
      return;
    }

    final schedules = todayClasses.map((c) {
      final classCampusId = c.campusId ?? defaultCampusId ?? '';
      return ScheduleItem(
        id: c.id,
        title: c.name,
        startTime: _combineDateAndTime(DateTime.now(), c.start),
        endTime: _combineDateAndTime(DateTime.now(), c.end),
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
    final todayClasses = mockSchedule.where((c) => c.weekday == selectedWeekday).toList()
      ..sort((a, b) => a.startHourFraction.compareTo(b.startHourFraction));

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
          _buildSectionHeaderFigma("Thời Khóa Biểu", () => _navigateToDetail(1), isSchedule: true),
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
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // Vuốt từ trái sang phải (swipe right) để trở về trang chính MySpace
        if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
          _backToDashboard();
        }
      },
      child: Stack(
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
                    _buildScheduleCalendarGridBody(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _parseTimeToHourFraction(String timeStr) {
    return StudyClass.parseTimeToHourFraction(timeStr);
  }

  void _scrollToCurrentFocusHour() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_timetableScrollController.hasClients) return;

      final dayClasses = mockSchedule.where((c) => c.weekday == selectedWeekday).toList()
        ..sort((a, b) => a.startHourFraction.compareTo(b.startHourFraction));

      double targetHour = 7.0; // Mặc định cuộn đến 7:00 sáng
      if (dayClasses.isNotEmpty) {
        // Tự động focus vào tiết học đầu tiên trong ngày (trừ bớt 0.5 giờ để lề đẹp)
        targetHour = math.max(0.0, dayClasses.first.startHourFraction - 0.5);
      }

      const double hourHeight = 64.0;
      final double targetOffset = targetHour * hourHeight;
      final maxExtent = _timetableScrollController.position.maxScrollExtent;
      final finalOffset = targetOffset.clamp(0.0, maxExtent);

      if ((_timetableScrollController.offset - finalOffset).abs() > 10.0) {
        _timetableScrollController.animateTo(
          finalOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Widget _buildScheduleCalendarGridBody() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dayClasses = mockSchedule.where((c) => c.weekday == selectedWeekday).toList()
      ..sort((a, b) => a.startHourFraction.compareTo(b.startHourFraction));
    const double hourHeight = 64.0;
    const int startHourGrid = 0; // Từ 00:00 sáng
    const int totalHours = 24;   // 00:00 đến 23:00 (đủ 24 tiếng)

    _scrollToCurrentFocusHour();

    return SingleChildScrollView(
      controller: _timetableScrollController,
      physics: const BouncingScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.only(top: 12, bottom: 24, left: 12, right: 16),
        child: Stack(
          children: [
            // Background Hour Grid Lines
            Column(
              children: List.generate(totalHours, (index) {
                final hour = startHourGrid + index;
                final timeText = "${hour.toString().padLeft(2, '0')}:00";
                return SizedBox(
                  height: hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white38 : Colors.black45,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          height: 1,
                          color: isDarkMode ? Colors.white12 : Colors.black12,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),

            // Empty State Watermark
            if (dayClasses.isEmpty) const SizedBox.shrink(),

            // Class Blocks Positioned by Start & End Time (Google Calendar Solid Fill Style)
            ...dayClasses.map((c) {
              final startH = _parseTimeToHourFraction(c.start);
              var endH = _parseTimeToHourFraction(c.end);
              if (endH <= startH) endH = startH + 1.5;

              final topPos = (startH - startHourGrid) * hourHeight + 8;
              final blockHeight = math.max(48.0, (endH - startH) * hourHeight - 4);

              // Solid fill color matching Google Calendar theme
              final Color cardColor = isDarkMode
                  ? Color.alphaBlend(Colors.black.withValues(alpha: 0.15), c.color)
                  : c.color;

              return Positioned(
                top: topPos,
                left: 56.0,
                right: 0.0,
                height: blockHeight,
                child: GestureDetector(
                  onTap: () => _editSchedule(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Class Name - Bold White Text (Top-Left aligned)
                        Text(
                          c.name,
                          maxLines: blockHeight < 55 ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Time & Room - White Text
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${c.start} - ${c.end}",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            if (c.room.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                "• ${c.room.startsWith('Phòng') ? c.room : 'Phòng ${c.room}'}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),


          ],
        ),
      ),
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
        builder: (context) => CreateSchedulePage(
          schedule: schedule,
          userUniversity: _userUniversity,
        ),
      ),
    );
    if (result == true) _loadInitialMetaData(); // Tải lại dữ liệu sau khi sửa
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
                child: Icon(Icons.list_rounded, size: 18, color: isDarkMode ? Colors.white70 : Colors.black87),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.name, 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: isDarkMode ? Colors.white70 : Colors.grey,
                  fontFamily: 'Poppins',
                )
              ),
              Divider(color: isDarkMode ? Colors.white12 : null),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: hcmusTeal),
                title: Text(
                  "Chỉnh sửa lịch học",
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontFamily: 'Poppins',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _editSchedule(s); // Gọi hàm sửa vừa tạo
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: hcmusRed),
                title: Text(
                  "Xóa lịch học", 
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontFamily: 'Poppins',
                  ),
                ),
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