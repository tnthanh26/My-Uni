import 'package:flutter/material.dart';
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
import './models/weather_models.dart';
import 'weather_alert_card.dart';
import 'package:intl/intl.dart';

// Màu sắc và thông số chuẩn từ thiết kế Figma
const Color hcmusBlueAccent = Color(0xFF5893D8);
const Color hcmusTeal = Color(0xFF279E95);
const Color hcmusGreyBg = Color(0xFFF2F6FF);
const Color hcmusRed = Color(0xFFFF6868);
const Color hcmusLightGrey = Color(0xFFEFEFEF);

class MySpaceScreen extends StatefulWidget {
  const MySpaceScreen({super.key});

  @override
  State<MySpaceScreen> createState() => _MySpaceScreenState();
}

class _MySpaceScreenState extends State<MySpaceScreen> with SingleTickerProviderStateMixin {
  bool _isDetailView = false;
  late TabController _tabController;
  int selectedWeekday = DateTime.now().weekday + 1;
  // Dữ liệu mẫu
  List<Deadline> mockDeadlines = [];
  List<StudyClass> mockSchedule = [];
  AutoDeadlineConfig? _autoDeadlineConfig;
  String _userUniversity = '';
  Future<WeatherAlertResult>? _weatherFuture;

  @override
  void initState() {
    super.initState();
    selectedWeekday = DateTime.now().weekday + 1;
    // Khởi tạo TabController cho phần Detail
    _tabController = TabController(length: 2, vsync: this);

    _loadData();

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  void _prepareWeatherFuture() {
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
        startTime: _combineTodayAndTime(c.start),
        endTime: _combineTodayAndTime(c.end),
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

  Future<void> _loadData() async {
    // 1. Lấy dữ liệu từ Local Storage trước để UI hiện ra ngay lập tức
    final localDls = await LocalStorageHelper.getDeadlines();
    final localSch = await LocalStorageHelper.getSchedule();
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final localAutoConfig = await LocalStorageHelper.getAutoDeadlineConfig(
      emailAddress: currentUserEmail,
    );
    final currentUser = FirebaseAuth.instance.currentUser;

    setState(() {
      mockDeadlines = localDls;
      mockSchedule = localSch;
      _autoDeadlineConfig = localAutoConfig;
    });

    // 2. Sau đó đồng bộ từ Firebase (Nếu có mạng)
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
        }
      }

      _prepareWeatherFuture();

      final remoteDls = await _firebaseService.getDeadlines();

      if (remoteDls.isEmpty && localDls.isNotEmpty) {
        // TRƯỜNG HỢP CỦA BẠN: Firebase trống nhưng máy có dữ liệu mẫu
        // => Đẩy ngược dữ liệu mẫu lên Firebase
        await _firebaseService.syncAllDeadlines(localDls);
      } else if (remoteDls.isNotEmpty) {
        // Nếu Firebase đã có dữ liệu, cập nhật lại UI
        setState(() {
          mockDeadlines = remoteDls;
        });
        await LocalStorageHelper.saveDeadlines(remoteDls);
      }

      final remoteSch = await _firebaseService.getSchedule();

      if (remoteSch.isEmpty && localSch.isNotEmpty) {
        // TRƯỜNG HỢP CỦA BẠN: Firebase trống nhưng máy có dữ liệu mẫu
        // => Đẩy ngược dữ liệu mẫu lên Firebase
        await _firebaseService.syncAllSchedule(localSch);
      } else if (remoteSch.isNotEmpty) {
        // Nếu Firebase đã có dữ liệu, cập nhật lại UI
        setState(() {
          mockSchedule = remoteSch;
        });
        await LocalStorageHelper.saveSchedule(remoteSch);
      }

      final remoteAutoConfig = await _firebaseService.getAutoDeadlineConfig();
      if (remoteAutoConfig != null) {
        final mergedConfig = remoteAutoConfig.copyWith(
          emailAddress: remoteAutoConfig.emailAddress.trim().isEmpty
              ? currentUserEmail
              : remoteAutoConfig.emailAddress,
        );
        setState(() {
          _autoDeadlineConfig = mergedConfig;
        });
        await LocalStorageHelper.saveAutoDeadlineConfig(mergedConfig);
      } else if ((localAutoConfig.emailAddress.isNotEmpty ||
          localAutoConfig.allowedSenders.isNotEmpty ||
          localAutoConfig.subjectKeywords.isNotEmpty ||
          localAutoConfig.permissionRequested) &&
          _firebaseService.userId != null) {
        await _firebaseService.saveAutoDeadlineConfig(localAutoConfig);
      }
    } catch (e) {
      debugPrint("Firebase Sync Error: $e");
    }
  }



  void _toggleDeadline(String id) async {
    final index = mockDeadlines.indexWhere((d) => d.id == id);
    if (index != -1) {
      setState(() {
        mockDeadlines[index].isCompleted = !mockDeadlines[index].isCompleted;
      });
      if (mockDeadlines[index].isCompleted) _showSuccessSnackBar(mockDeadlines[index].title);

      // Lưu trạng thái mới vào máy
      await LocalStorageHelper.saveDeadlines(mockDeadlines);

      await _firebaseService.saveDeadline(mockDeadlines[index]);
    }
  }

  void _deleteDeadline(String id) async {
    setState(() {
      mockDeadlines.removeWhere((d) => d.id == id);
    });
    // Lưu trạng thái mới vào máy
    await LocalStorageHelper.saveDeadlines(mockDeadlines);

    // Nếu có mạng thì xóa trên Firebase
    await _firebaseService.deleteDeadline(id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã xóa deadline thành công!")),
      );
    }
  }

  // --- ĐIỀU HƯỚNG (NAVIGATION) ---

  void _navigateToDetail(int tabIndex) {
    setState(() {
      _isDetailView = true;
      _tabController.index = tabIndex;
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
      builder: (context) => Container(
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
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateDeadlinesPage()),
                );
                if (result == true) _loadData(); // QUAN TRỌNG: Load lại sau khi tạo
              },
            ),
            ListTile(
              leading: const Icon(Icons.class_, color: hcmusTeal),
              title: const Text("Tạo Môn học mới", style: TextStyle(fontFamily: 'Poppins')),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateSchedulePage()),
                );
                if (result == true) _loadData(); // QUAN TRỌNG: Load lại sau khi tạo
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- UI HELPER ---

  List<String> _splitCommaSeparated(String input) {
    return input
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _saveAutoDeadlineConfig(AutoDeadlineConfig config) async {
    final normalized = config.copyWith(updatedAt: DateTime.now());
    await LocalStorageHelper.saveAutoDeadlineConfig(normalized);
    await _firebaseService.saveAutoDeadlineConfig(normalized);

    if (!mounted) return;
    setState(() {
      _autoDeadlineConfig = normalized;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã lưu cấu hình auto-update deadline.'),
      ),
    );
  }

  Future<void> _showAutoDeadlineConfigSheet() async {
    final baseConfig = _autoDeadlineConfig ?? AutoDeadlineConfig.empty(
      emailAddress: FirebaseAuth.instance.currentUser?.email ?? '',
    );

    final emailController = TextEditingController(text: baseConfig.emailAddress);
    final senderController = TextEditingController(
      text: baseConfig.allowedSenders.join(', '),
    );
    final keywordController = TextEditingController(
      text: baseConfig.subjectKeywords.join(', '),
    );

    bool isEnabled = baseConfig.isEnabled;
    String provider = baseConfig.provider;
    bool onlyUnread = baseConfig.onlyUnread;
    bool includeAttachments = baseConfig.includeAttachments;
    bool permissionRequested = baseConfig.permissionRequested;
    bool permissionGranted = baseConfig.permissionGranted;
    bool _showAdvancedOptions = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Auto-update deadline',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mới là phần UI + lưu cấu hình. Chưa đọc mail thật cho tới khi mình nối email_listener/OAuth backend.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SwitchListTile.adaptive(
                        value: isEnabled,
                        contentPadding: EdgeInsets.zero,
                        activeColor: hcmusBlueAccent,
                        title: const Text(
                          'Bật tự động cập nhật deadline',
                          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Sau này hệ thống sẽ quét email hợp lệ và gợi ý/tạo deadline tự động.',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12),
                        ),
                        onChanged: (value) => setModalState(() => isEnabled = value),
                      ),
                      const SizedBox(height: 14),
                      _buildConfigLabel('Loại email cần đọc'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: provider,
                        decoration: _configInputDecoration('Chọn nhà cung cấp email'),
                        items: const [
                          DropdownMenuItem(value: 'gmail', child: Text('Gmail')),
                          DropdownMenuItem(value: 'outlook', child: Text('Outlook / Microsoft')),
                          DropdownMenuItem(value: 'other', child: Text('Khác')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => provider = value);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildConfigLabel('Email sẽ dùng để đồng bộ'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _configInputDecoration('vd: hoshi@student.edu.vn'),
                      ),
                      const SizedBox(height: 14),
                      _buildConfigLabel('Tự đọc mail từ ai'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: senderController,
                        maxLines: 2,
                        decoration: _configInputDecoration(
                          'vd: daotao@school.edu.vn, lecturer@hcmus.edu.vn',
                        ),
                      ),
                      /*
                      const SizedBox(height: 14),
                      _buildConfigLabel('Từ khóa tiêu đề / nội dung ưu tiên'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: keywordController,
                        maxLines: 2,
                        decoration: _configInputDecoration(
                          'vd: deadline, assignment, quiz, submission, exam',
                        ),
                      ),
                      */
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setModalState(() => _showAdvancedOptions = !_showAdvancedOptions),
                        child: Text(
                          _showAdvancedOptions ? 'Ẩn tùy chọn nâng cao' : 'Tùy chọn nâng cao',
                          style: TextStyle(
                            color: hcmusBlueAccent,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      /*
                      if (_showAdvancedOptions) ...[
                        CheckboxListTile(
                          value: onlyUnread,
                          contentPadding: EdgeInsets.zero,
                          activeColor: hcmusBlueAccent,
                          title: const Text('Ưu tiên chỉ đọc email chưa đọc', style: TextStyle(fontFamily: 'Poppins')),
                          onChanged: (value) => setModalState(() => onlyUnread = value ?? true),
                        ),
                        CheckboxListTile(
                          value: includeAttachments,
                          contentPadding: EdgeInsets.zero,
                          activeColor: hcmusBlueAccent,
                          title: const Text('Cho phép xét cả email có file đính kèm', style: TextStyle(fontFamily: 'Poppins')),
                          onChanged: (value) => setModalState(() => includeAttachments = value ?? false),
                        ),
                      ],
                       */
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF23262B) : const Color(0xFFF5F8FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDarkMode ? const Color(0xFF3A3F47) : const Color(0xFFDCE7FF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  permissionGranted ? Icons.verified_rounded : Icons.lock_outline_rounded,
                                  size: 18,
                                  color: permissionGranted ? hcmusTeal : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  permissionGranted ? 'Quyền truy cập: đã cấp' : 'Quyền truy cập: chưa cấp',
                                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Nút này mới là bước xin phép/gợi ý UX. OAuth thật sẽ nối ở bước sau.',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  permissionRequested = true;
                                  permissionGranted = false;
                                });
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã ghi nhận yêu cầu cấp quyền. Bước OAuth thật sẽ nối sau.'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.mark_email_read_outlined),
                              label: Text(
                                permissionRequested ? 'Yêu cầu cấp quyền lại' : 'Yêu cầu cấp quyền',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hcmusBlueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () async {
                            final email = emailController.text.trim();
                            if (email.isEmpty) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Điền email trước đã.')),
                              );
                              return;
                            }

                            final config = AutoDeadlineConfig(
                              isEnabled: isEnabled,
                              provider: provider,
                              emailAddress: email,
                              allowedSenders: _splitCommaSeparated(senderController.text),
                              subjectKeywords: _splitCommaSeparated(keywordController.text),
                              onlyUnread: onlyUnread,
                              includeAttachments: includeAttachments,
                              permissionRequested: permissionRequested,
                              permissionGranted: permissionGranted,
                              updatedAt: DateTime.now(),
                            );

                            await _saveAutoDeadlineConfig(config);
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          },
                          child: const Text(
                            'Lưu cấu hình',
                            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConfigLabel(String text) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontFamily: 'Poppins',
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
    );
  }

  InputDecoration _configInputDecoration(String hintText) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        color: isDarkMode ? Colors.white54 : null,
      ),
      filled: true,
      fillColor: isDarkMode ? const Color(0xFF23262B) : const Color(0xFFF8FAFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDarkMode ? const Color(0xFF3A3F47) : const Color(0xFFD7E1F3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDarkMode ? const Color(0xFF3A3F47) : const Color(0xFFD7E1F3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: hcmusBlueAccent, width: 1.4),
      ),
    );
  }

  void _showSuccessSnackBar(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🎉 Chúc mừng Hoshi đã xong: $title"),
        backgroundColor: hcmusTeal,
        duration: const Duration(seconds: 2),
      ),
    );
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

  // Hàm tính toán ngày trong tuần (Giữ nguyên logic cũ của bạn)
  List<Map<String, dynamic>> _getCurrentWeekDays() {
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
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
              const SizedBox(height: 102),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: _isDetailView
                      ? _buildDetailViewContent() // Hiển thị nội dung DI
                      : _buildDashboardContent(), // Hiển thị nội dung 3.1
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
        child: const Icon(Icons.add, size: 35, color: Colors.white),
      )
          : null,
    );
  }

  // --- DASHBOARD CONTENT (3.1) ---
  DateTime _combineTodayAndTime(String time) {
    final now = DateTime.now();

    final parsedTime = DateFormat('h:mm a').parse(time.trim());

    return DateTime(
      now.year,
      now.month,
      now.day,
      parsedTime.hour,
      parsedTime.minute,
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF40539B), const Color(0xFF74C98C)]
              : [const Color(0xFF4C63D2), const Color(0xFF83E28D)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              '🎉',
              style: TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  const TextSpan(text: 'Hôm nay bạn có '),
                  TextSpan(
                    text: '$todayClassesCount lớp học',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: ' và\n'),
                  TextSpan(
                    text: '$activeDeadlinesCount deadline',
                    style: const TextStyle(fontWeight: FontWeight.w800),
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

    debugPrint('=== TOP BANNER DEBUG ===');
    debugPrint('_userUniversity: $_userUniversity');
    debugPrint('campusId: $campusId');
    debugPrint('todayClasses length: ${todayClasses.length}');
    for (final c in todayClasses) {
      debugPrint('class: ${c.name} ${c.start} - ${c.end}');
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          FutureBuilder<WeatherAlertResult>(
            future: _weatherFuture ?? Future.value(WeatherAlertResult.none()),
            builder: (context, snapshot) {
              debugPrint('snapshot.connectionState: ${snapshot.connectionState}');
              debugPrint('snapshot.hasError: ${snapshot.hasError}');
              debugPrint('snapshot.error: ${snapshot.error}');

              final result = snapshot.data ?? WeatherAlertResult.none();
              debugPrint('result.shouldShow: ${result.shouldShow}');
              debugPrint('result.title: ${result.title}');

              if (snapshot.connectionState == ConnectionState.waiting ||
                  !result.shouldShow) {
                return _buildWelcomeBannerFigma();
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildCompactSummaryBanner(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: WeatherAlertCard(alert: result),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 25),
          _buildDeadlineSectionHeader(),
          ...top3Deadlines.map((d) => _buildDeadlineCardFigma(d)),

          const SizedBox(height: 25),
          _buildSectionHeaderFigma("Thời Khóa Biểu", () => _navigateToDetail(1)),
          _buildCalendarStripFigma(),
          ...todayClasses.map((c) => _buildScheduleCardFigma(c)),

          const SizedBox(height: 80),
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
            // Header của Detail (Tháng 2, 2026)
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
                      child: Text(
                        "Tháng 2, 2026",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            _buildDetailCalendarStrip(),
            const SizedBox(height: 36),
            _buildSlidingToggle(),
            const SizedBox(height: 12),

            // Phần danh sách bên dưới (Nằm ngoài lớp phủ 150px nên sẽ hiện trên nền trắng sạch sẽ)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDeadlineDetailList(),
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

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: currentWeek.length,
        itemBuilder: (context, index) {
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

          return GestureDetector(
            onTap: () => setState(() => selectedWeekday = weekdayValue),
            child: Container(
              width: 48,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? hcmusBlueAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("${dayDate.day}",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : (isDarkMode ? Colors.white : Colors.black))),
                  Text(dayData['label'],
                      style: TextStyle(color: isSelected ? Colors.white : (isDarkMode ? Colors.white60 : const Color(0xff94A3B8)), fontSize: 12)),
                  const SizedBox(height: 4),
                  // Badge thông báo (Đỏ cho Deadline, Teal cho Schedule)
                  SizedBox(
                    height: 18,
                    child: count > 0
                        ? Container(
                      width: 18, // Đảm bảo width = height để tạo hình tròn chuẩn
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        "$count",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                        : const SizedBox.shrink(), // Vẫn giữ vùng 18px nhưng bên trong trống
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Thanh trượt deadlines và schedules
  Widget _buildSlidingToggle() {
    final bool isDeadlineTab = _tabController.index == 0;
    final Color activeColor = isDeadlineTab ? hcmusRed : hcmusTeal;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF2A2A2E) : hcmusLightGrey, borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(4), // Tạo khoảng trống để Indicator nhỏ hơn thanh chứa
        child: TabBar(
          controller: _tabController,
          onTap: (index) {
            setState(() {
              // Trigger build lại để cập nhật activeColor
            });
          },
          indicator: BoxDecoration(
            color: activeColor, // Đỏ cho Deadline, Teal cho Schedule
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: activeColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: isDarkMode ? Colors.white60 : const Color(0xFF94A3B8), // Màu xám (Slate 400)
          dividerColor: Colors.transparent, // Xóa gạch chân mặc định
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: "Deadlines"),
            Tab(text: "Thời Khóa Biểu"),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineDetailList() {
    final currentWeek = _getCurrentWeekDays();
    final selectedDate = currentWeek.firstWhere((d) => d['value'] == selectedWeekday)['fullDate'] as DateTime;

    // Lọc list dùng chung
    final filteredDeadlines = mockDeadlines.where((d) =>
    d.dueDate.year == selectedDate.year &&
        d.dueDate.month == selectedDate.month &&
        d.dueDate.day == selectedDate.day
    ).toList();

    if (filteredDeadlines.isEmpty) {
      return Center(child: Text("Không có deadline cho ngày này!", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: filteredDeadlines.length,
      itemBuilder: (context, index) => _buildDeadlineDetailCard(filteredDeadlines[index]),
    );
  }

  Widget _buildDeadlineDetailCard(Deadline d) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 15, left: 20, right: 20), // Thêm margin để card nằm giữa màn hình
      height: 94,
      child: Stack(
        children: [
          // 1. Rectangle 1044 (Background)
          Container(
            width: double.infinity,
            height: 94,
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E242B) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 32,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),

          // 2. Nộp file pdf trên moodle (Sub-text)
          Positioned(
            left: 14, // Tính toán lại: 61px (Figma) - 47px (Card left) = 14px
            top: 16,  // 359px - 343px = 16px
            child: Text(
              "Nộp file pdf trên moodle",
              style: TextStyle(
                fontFamily: 'Lexend Deca',
                fontSize: 11,
                color: isDarkMode ? Colors.white60 : const Color(0xFF6E6A7C),
              ),
            ),
          ),

          // 3. Bài tập CS101 (Title)
          Positioned(
            left: 14, // 61px - 47px = 14px
            top: 38,  // 381px - 343px = 38px
            child: Text(
              d.title,
              style: TextStyle(
                fontFamily: 'Lexend Deca',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: isDarkMode ? Colors.white : const Color(0xFF24252C),
                decoration: d.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),

          // 4. Icon Time Circle & Time Text (10:00 AM)
          Positioned(
            left: 14,
            top: 64, // 407px - 343px = 64px
            child: Row(
              children: [
                const Icon(Icons.access_time_filled, size: 14, color: hcmusBlueAccent),
                const SizedBox(width: 6),
                Text(
                  "${d.dueTime.hour}:${d.dueTime.minute.toString().padLeft(2, '0')}",
                  style: const TextStyle(
                    fontFamily: 'Lexend Deca',
                    fontSize: 11,
                    color: hcmusBlueAccent,
                  ),
                ),
              ],
            ),
          ),

          // 5. Ba chấm (Icons.more_horiz)
          Positioned(
            right: 18, // Ước lượng vị trí gần checkbox
            top: 12,
            child: GestureDetector(
              onTap: () => _showDeadlineActionMenu(d),
              child: Icon(Icons.more_horiz, color: isDarkMode ? Colors.white60 : const Color(0xFF6E6A7C), size: 20),
            ),
          ),

          // 6. Ellipse 132 (Checkbox)
          Positioned(
            right: 15, // 343px là left tuyệt đối, nên để right cho linh hoạt
            top: 55,   // 402px - 343px = 59px (điều chỉnh nhẹ cho cân đối)
            child: GestureDetector(
              onTap: () => _toggleDeadline(d.id),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: d.isCompleted ? hcmusBlueAccent : (isDarkMode ? const Color(0xFF2C2C2E) : Colors.white),
                  shape: BoxShape.circle,
                  border: Border.all(color: isDarkMode ? Colors.white54 : Colors.black, width: 1),
                ),
                child: d.isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editDeadline(Deadline deadline) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateDeadlinesPage(deadline: deadline),
      ),
    );
    if (result == true) _loadData(); // Load lại sau khi sửa
  }

  void _editSchedule(StudyClass schedule) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateSchedulePage(schedule: schedule),
      ),
    );
    if (result == true) _loadData(); // Tải lại dữ liệu sau khi sửa
  }

  void _showDeadlineActionMenu(Deadline d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tiêu đề để biết đang thao tác với deadline nào
              Text(
                  d.title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white70 : Colors.grey,
                      fontFamily: 'Lexend Deca'
                  )
              ),
              Divider(color: isDarkMode ? Colors.white12 : null),

              // Lựa chọn CHỈNH SỬA - Đã được cập nhật logic
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: hcmusBlueAccent),
                title: const Text("Chỉnh sửa deadline",
                    style: TextStyle(fontFamily: 'Lexend Deca')),
                onTap: () {
                  Navigator.pop(context); // Đóng Menu trước
                  _editDeadline(d);       // Gọi hàm điều hướng sang trang Create (kèm dữ liệu)
                },
              ),

              // Lựa chọn XÓA - Màu đỏ khẩn cấp
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                title: const Text(
                  "Xóa deadline",
                  style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Lexend Deca'
                  ),
                ),
                onTap: () {
                  Navigator.pop(context); // Đóng Menu trước
                  _deleteDeadline(d.id);  // Gọi hàm xóa
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
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
    return Stack(
      children: [
        // Background Image - Cố định
        Container(
          height: 150,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/hcmus_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(color: Colors.black38),
        ),

        // Logo & HCMUS Text & Notification - Cố định
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 35),
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
                      child: Image.asset('assets/images/logoApp1.png', fit: BoxFit.contain),
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: hcmusBlueAccent.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.celebration, color: Colors.orangeAccent, size: 20),
              SizedBox(width: 8),
              Text("Chào bạn tui!",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w400, // Độ đậm cơ bản cho cả câu
              ),
              children: [
                const TextSpan(text: "Hôm nay bạn có "),
                TextSpan(
                  text: "$todayClassesCount lớp học",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600, // In đậm con số lớp học
                    fontSize: 14, // Có thể tăng size nhẹ để nổi bật hơn
                  ),
                ),
                const TextSpan(text: " và "),
                TextSpan(
                  text: "$pendingDeadlinesCount deadline",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600, // In đậm con số deadline
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

  Widget _buildDeadlineSectionHeader() {
    final config = _autoDeadlineConfig;
    final bool isEnabled = config?.isEnabled ?? false;
    final bool permissionRequested = config?.permissionRequested ?? false;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Deadlines',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Poppins', color: isDarkMode ? Colors.white : Colors.black87),
          ),
        ),
        GestureDetector(
          onTap: _showAutoDeadlineConfigSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isEnabled ? (isDarkMode ? const Color(0xFF1D3557) : const Color(0xFFE7F1FF)) : (isDarkMode ? const Color(0xFF2A2A2E) : hcmusLightGrey),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isEnabled ? hcmusBlueAccent : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 15,
                  color: isEnabled ? hcmusBlueAccent : (isDarkMode ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(width: 6),
                Text(
                  isEnabled ? 'Auto-update ON' : 'Auto-update',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    color: isEnabled ? hcmusBlueAccent : (isDarkMode ? Colors.white : Colors.black87),
                  ),
                ),
                if (permissionRequested && !isEnabled) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.orange),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _navigateToDetail(0),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF2A2A2E) : hcmusLightGrey, shape: BoxShape.circle),
            child: Icon(Icons.list_rounded, size: 18, color: isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeaderFigma(String title, VoidCallback onPressed) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Poppins', color: isDarkMode ? Colors.white : Colors.black87)),
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

  Map<String, dynamic> _getTimeLeft(Deadline deadline) {
    final now = DateTime.now();
    final deadlineDateTime = DateTime(
      deadline.dueDate.year,
      deadline.dueDate.month,
      deadline.dueDate.day,
      deadline.dueTime.hour,
      deadline.dueTime.minute,
    );

    final difference = deadlineDateTime.difference(now);

    if (difference.isNegative) {
      return {"text": "Quá trễ rùi", "color": const Color(0xFFDC2626)};
    }

    int days = difference.inDays;
    int hours = difference.inHours % 24;
    int minutes = difference.inMinutes % 60;

    String timeText = "";
    if (days > 0) {
      timeText += "$days ngày $hours giờ";
    } else if (hours > 0) {
      timeText += "$hours giờ $minutes phút";
    } else {
      timeText += "$minutes phút";
    }

    // LOGIC MÀU SẮC THEO YÊU CẦU:
    // Đỏ: < 1 ngày (DC2626)
    // Cam: < 3 ngày (EA580C)
    // Xanh: Còn lại (448E58)
    Color textColor;
    if (difference.inDays < 1) {
      textColor = const Color(0xFFDC2626);
    } else if (difference.inDays < 3) {
      textColor = const Color(0xFFEA580C);
    } else {
      textColor = const Color(0xFF448E58);
    }

    return {"text": timeText, "color": textColor};
  }

  Widget _buildDeadlineCardFigma(Deadline deadline) {
    final timeLeftData = _getTimeLeft(deadline);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E242B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 3, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleDeadline(deadline.id),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: deadline.isCompleted ? hcmusBlueAccent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isDarkMode ? Colors.white54 : Colors.black, width: 1),
              ),
              child: deadline.isCompleted ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
            ),
          ),
          const SizedBox(width: 12),
          // 1. Title (Bài tập CS101)
          Expanded(
            child: Text(
                deadline.title,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Poppins',
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  // Thêm gạch ngang nếu xong
                  decoration: deadline.isCompleted ? TextDecoration.lineThrough : null,
                )
            ),
          ),

          SizedBox(
            width: 100, // Độ rộng cố định đủ cho chuỗi "Còn 2 ngày 16 giờ"
            child: RichText(
              textAlign: TextAlign.left,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Poppins',
                  color: isDarkMode ? Colors.white70 : const Color(0xFF0F172A),
                ),
                children: [
                  if (timeLeftData["color"] != const Color(0xFFDC2626))
                    const TextSpan(text: "Còn "),
                  TextSpan(
                    text: timeLeftData["text"].replaceAll("còn ", ""),
                    style: TextStyle(
                      color: timeLeftData["color"],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(
            width: 18, // Cố định chiều rộng vùng này
            child: Align(
              alignment: Alignment.centerRight, // Căn icon về bên phải trong vùng 32px
              child: deadline.isCompleted
                  ? IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFDC2626), size: 18),
                onPressed: () => _deleteDeadline(deadline.id),
              )
                  : const SizedBox.shrink(), // Khi chưa xong, vùng 32px vẫn tồn tại nhưng trống
            ), // Nếu chưa xong thì để trống nhưng SizedBox cha vẫn giữ 32px
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarStripFigma() {
    final List<Map<String, dynamic>> currentWeek = _getCurrentWeekDays();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: currentWeek.map((d) => GestureDetector(
          onTap: () {
            setState(() {
              selectedWeekday = d['value'];
            });
          },
          child: _calendarDayFigma(
              d['day'],
              d['label'],
              isSelected: selectedWeekday == d['value']
          ),
        )).toList(),
      ),
    );
  }

  Widget _calendarDayFigma(String day, String weekday, {bool isSelected = false}) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 36,
      height: 54,
      decoration: BoxDecoration(
        color: isSelected ? hcmusBlueAccent : (isDarkMode ? const Color(0xFF2A2A2E) : hcmusLightGrey),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(weekday, style: TextStyle(color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black), fontSize: 12, height: 0.75)),
          const SizedBox(height: 4),
          Text(day, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : (isDarkMode ? Colors.white : Colors.black))),
        ],
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
