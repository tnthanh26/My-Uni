import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'myspace_firebase_service.dart';
import 'local_storage_helper.dart';
import 'models/myspace_models.dart';
import 'campus_data.dart';
import 'models/weather_models.dart';
import 'package:intl/intl.dart';

class CreateSchedulePage extends StatefulWidget {
  final StudyClass? schedule;
  final int? initialWeekday;
  final String? userUniversity;
  const CreateSchedulePage({super.key, this.schedule, this.initialWeekday, this.userUniversity});

  @override
  State<CreateSchedulePage> createState() => _CreateSchedulePageState();
}

class _CreateSchedulePageState extends State<CreateSchedulePage> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Thay đổi: Sử dụng String để lưu "Thứ" thay vì DateTime
  String _selectedWeekday = "Thứ 2";
  final List<String> _weekdays = ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ Nhật"];

  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 10);

  static const Color headerBg = Color(0xFF545454);
  static const Color accentBlue = Color(0xFF92B9E6);
  static const Color fieldBg = Color(0xFFEFF6FF);
  static const Color borderGrey = Color(0xFF8E8E93);
  static const Color hintGrey = Color(0xFF787878);

  late Color _selectedColor = widget.schedule?.color ?? const Color(0xFFFFC374);

  // Bảng màu Google Calendar Event Colors
  final List<Color> _colorOptions = [
    const Color(0xFF039BE5), // Peacock (Xanh dương)
    const Color(0xFFE67C73), // Flamingo (Hồng cam)
    const Color(0xFF33B679), // Sage (Xanh lá nhạt)
    const Color(0xFF8E24AA), // Grape (Tím)
    const Color(0xFFF4511E), // Tangerine (Cam)
    const Color(0xFFF6BF26), // Banana (Vàng)
    const Color(0xFF7986CB), // Lavender (Tím nhạt)
  ];

  String _userUniversity = '';
  List<CampusLocation> _availableCampuses = [];
  String? _selectedCampusId;

  @override
  void initState() {
    super.initState();
    _userUniversity = widget.userUniversity ?? '';
    _initCampuses();
    if (widget.schedule != null) {
      final schedule = widget.schedule!;

      _subjectController.text = schedule.name;
      _locationController.text = schedule.room;
      _selectedColor = schedule.color;
      _selectedWeekday = _weekdays[schedule.weekday - 2];

      _startTime = _parseScheduleTime(schedule.start);
      _endTime = _parseScheduleTime(schedule.end);
    } else if (widget.initialWeekday != null &&
        widget.initialWeekday! >= 2 &&
        widget.initialWeekday! <= 8) {
      _selectedWeekday = _weekdays[widget.initialWeekday! - 2];
    }
  }

  Future<void> _initCampuses() async {
    if (_userUniversity.isEmpty) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          if (userDoc.exists) {
            _userUniversity = userDoc.data()?['university'] ?? '';
          }
        }
      } catch (e) {
        debugPrint("Error fetching user university: $e");
      }
    }
    _availableCampuses = CampusData.getCampusesForSchoolOf(_userUniversity);

    if (widget.schedule != null && widget.schedule!.campusId != null) {
      _selectedCampusId = widget.schedule!.campusId;
    } else {
      _selectedCampusId = CampusData.mapUniversityToCampusId(_userUniversity);
    }

    // Ensure selected campus is in the available list, fallback to first if not
    if (_selectedCampusId != null && !_availableCampuses.any((c) => c.campusId == _selectedCampusId)) {
      _selectedCampusId = _availableCampuses.isNotEmpty ? _availableCampuses.first.campusId : null;
    } else if (_selectedCampusId == null && _availableCampuses.isNotEmpty) {
      _selectedCampusId = _availableCampuses.first.campusId;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _showCampusSelectionBottomSheet() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color primaryTextColor = isDarkMode ? Colors.white : Colors.black87;
    final Color secondaryTextColor = isDarkMode ? Colors.white54 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Text(
                  'Chọn cơ sở trường',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Encode Sans Expanded',
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _availableCampuses.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final campus = _availableCampuses[index];
                      final isSelected = _selectedCampusId == campus.campusId;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCampusId = campus.campusId;
                          });
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? (isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0))
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryColor.withOpacity(0.15)
                                      : (isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.school_outlined,
                                  size: 20,
                                  color: isSelected ? primaryColor : secondaryTextColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  campus.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? primaryColor : primaryTextColor,
                                    fontFamily: 'Urbanist',
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: primaryColor,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  TimeOfDay _parseScheduleTime(String time) {
    final input = time.trim().toUpperCase();

    try {
      DateTime parsed;

      if (input.contains('AM') || input.contains('PM')) {
        parsed = DateFormat('h:mm a').parse(input);
      } else {
        parsed = DateFormat('HH:mm').parse(input);
      }

      return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
    } catch (e) {
      debugPrint('Cannot parse schedule time: $time, error: $e');
      return const TimeOfDay(hour: 7, minute: 30);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBg = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color primaryText = isDarkMode ? Colors.white : Colors.black;
    final Color secondaryText = isDarkMode ? Colors.white70 : hintGrey;
    final Color borderColor = isDarkMode ? const Color(0xFF3A3A3C) : borderGrey;
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : headerBg,
        elevation: 4,
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy',
              style: TextStyle(color: accentBlue, fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'Encode Sans Expanded')),
        ),
        title: const Text('Tạo Môn học',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'Encode Sans Expanded')),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveSchedule, // Gọi hàm chúng ta vừa sửa ở trên
            child: const Text('Lưu',
                style: TextStyle(
                    color: accentBlue,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Encode Sans Expanded'
                )),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550.0),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const SizedBox(height: 24),
              // 1. Tên Môn học
              TextField(
                controller: _subjectController,
                style: TextStyle(fontSize: 20, color: primaryText, fontFamily: 'Encode Sans Expanded'),
                decoration: InputDecoration(
                  hintText: 'Tên Môn học',
                  hintStyle: TextStyle(color: secondaryText, fontSize: 20),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: headerBg)),
                ),
              ),
              const SizedBox(height: 24),

              // 2. [CẬP NHẬT] Chọn Thứ (Thay thế cho chọn Ngày)
              _buildRectangleField(
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 24, color: primaryText),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedWeekday,
                          dropdownColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down, color: secondaryText),
                          style: TextStyle(fontSize: 20, fontFamily: 'Urbanist', color: primaryText),
                          onChanged: (String? newValue) {
                            setState(() => _selectedWeekday = newValue!);
                          },
                          items: _weekdays.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. Giờ bắt đầu & Giờ kết thúc
              _buildRectangleField(
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(true),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, size: 24, color: primaryText),
                            const SizedBox(width: 8),
                            Text(_startTime.format(context),
                                style: TextStyle(fontSize: 18, fontFamily: 'Encode Sans Expanded', color: secondaryText)),
                          ],
                        ),
                      ),
                    ),
                    VerticalDivider(color: borderColor, indent: 20, endIndent: 20),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(false),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.access_time, size: 24, color: primaryText),
                            const SizedBox(width: 8),
                            Text(_endTime.format(context),
                                style: TextStyle(fontSize: 18, fontFamily: 'Encode Sans Expanded', color: secondaryText)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Cơ sở trường & Chi tiết địa điểm
              Text("Cơ sở trường",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Encode Sans Expanded', color: primaryText)),
              const SizedBox(height: 12),
              _buildRectangleField(
                onTap: _showCampusSelectionBottomSheet,
                child: Row(
                  children: [
                    Icon(Icons.school_outlined, size: 24, color: primaryText),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _availableCampuses.firstWhere(
                                (c) => c.campusId == _selectedCampusId,
                                orElse: () => _availableCampuses.isNotEmpty
                                    ? _availableCampuses.first
                                    : CampusLocation(campusId: '', name: 'Chọn cơ sở', latitude: 0, longitude: 0),
                              ).name,
                              style: TextStyle(
                                fontSize: 20,
                                fontFamily: 'Urbanist',
                                color: primaryText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down, color: secondaryText),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _locationController,
                style: TextStyle(fontSize: 20, color: primaryText, fontFamily: 'Encode Sans Expanded'),
                decoration: InputDecoration(
                  hintText: 'Chi tiết địa điểm (Tòa, phòng...)',
                  hintStyle: TextStyle(color: secondaryText, fontSize: 20),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: headerBg)),
                ),
              ),
              const SizedBox(height: 24),
              Text("Màu sắc thẻ",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Encode Sans Expanded', color: primaryText)),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colorOptions.length,
                  itemBuilder: (context, index) {
                    bool isSelected = _selectedColor == _colorOptions[index];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = _colorOptions[index]),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _colorOptions[index],
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: isDarkMode ? Colors.white : headerBg, width: 3)
                              : Border.all(color: Colors.transparent),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    )));
  }

  Widget _buildRectangleField({required Widget child, VoidCallback? onTap}) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: 77,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1C1C1E) : fieldBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode ? const Color(0xFF3A3A3C) : Colors.transparent,
          ),
        ),
        child: child,
      ),
    );
  }

  Future<void> _selectTime(bool isStart) async {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final initialTime = isStart ? _startTime : _endTime;
    
    final now = DateTime.now();
    DateTime tempDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      initialTime.hour,
      initialTime.minute,
    );

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 280,
          color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: isDarkMode ? Colors.white10 : Colors.black12,
                        width: 0.5,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          "Hủy",
                          style: TextStyle(
                            fontFamily: 'Urbanist',
                            fontSize: 16,
                            color: isDarkMode ? Colors.white54 : Colors.black54,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      Text(
                        isStart ? "Giờ bắt đầu" : "Giờ kết thúc",
                        style: TextStyle(
                          fontFamily: 'Urbanist',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            final selectedTime = TimeOfDay(
                              hour: tempDateTime.hour,
                              minute: tempDateTime.minute,
                            );
                             if (isStart) {
                               _startTime = selectedTime;
                             } else {
                               _endTime = selectedTime;
                             }
                          });
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Xong",
                          style: TextStyle(
                            fontFamily: 'Urbanist',
                            fontSize: 16,
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: isDarkMode ? Brightness.dark : Brightness.light,
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: true,
                      initialDateTime: tempDateTime,
                      onDateTimeChanged: (DateTime newDateTime) {
                        tempDateTime = newDateTime;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _getWeekdayInt(String dayName) {
    switch (dayName) {
      case "Thứ 2": return 2;
      case "Thứ 3": return 3;
      case "Thứ 4": return 4;
      case "Thứ 5": return 5;
      case "Thứ 6": return 6;
      case "Thứ 7": return 7;
      case "Chủ Nhật": return 8;
      default: return 2;
    }
  }

  Future<void> _saveSchedule() async {
    if (_subjectController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên môn học')),
      );
      return;
    }

    final int startMinutes = _startTime.hour * 60 + _startTime.minute;
    final int endMinutes = _endTime.hour * 60 + _endTime.minute;

    if (startMinutes >= endMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giờ bắt đầu phải nhỏ hơn giờ kết thúc')),
      );
      return;
    }

    final startStr = _startTime.format(context);
    final endStr = _endTime.format(context);

    try {
      // 1. Lấy danh sách lịch học hiện tại từ máy (đã bao gồm mock data nếu máy trống)
      List<StudyClass> currentSchedule = await LocalStorageHelper.getSchedule();

      // 2. Tạo đối tượng StudyClass mới từ thông tin đã nhập
      final String targetId = widget.schedule?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      final int targetWeekday = _getWeekdayInt(_selectedWeekday);

      // Kiểm tra trùng lịch học trong cùng ngày
      final overlappingSchedules = currentSchedule.where((s) {
        if (s.id == targetId) return false; // Không so sánh với chính môn đang sửa
        if (s.weekday != targetWeekday) return false;

        final sStartMins = (StudyClass.parseTimeToHourFraction(s.start) * 60).round();
        final sEndMins = (StudyClass.parseTimeToHourFraction(s.end) * 60).round();

        // Điều kiện trùng khung giờ: startA < endB && startB < endA
        return (startMinutes < sEndMins) && (sStartMins < endMinutes);
      }).toList();

      if (overlappingSchedules.isNotEmpty) {
        final conflict = overlappingSchedules.first;
        if (mounted) {
          final bool? proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28.0),
              ),
              icon: const Icon(
                Icons.schedule_rounded,
                size: 32,
                color: Color(0xFFE67C73),
              ),
              title: const Text(
                'Lịch học bị trùng khung giờ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              content: Text(
                'Môn học này trùng thời gian với "${conflict.name}" (${conflict.start} - ${conflict.end}).\n\nBạn vẫn muốn tiếp tục lưu lịch này?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black87,
                ),
              ),
              actionsAlignment: MainAxisAlignment.end,
              actionsPadding: const EdgeInsets.only(right: 16, bottom: 16, top: 8),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Chỉnh sửa'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF039BE5),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Vẫn lưu',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );

          if (proceed != true) {
            return;
          }
        }
      }

      // 3. Tạo đối tượng môn học mới từ thông tin đã nhập
      final updatedClass = StudyClass(
        id: targetId,
        name: _subjectController.text,
        start: startStr,
        end: endStr,
        room: _locationController.text,
        campusId: _selectedCampusId,
        weekday: _getWeekdayInt(_selectedWeekday),
        color: _selectedColor,
      );

      // 4. KIỂM TRA: LÀ SỬA HAY THÊM MỚI?
      if (widget.schedule != null) {
        // Chế độ Sửa: Tìm vị trí index của ID cũ và thay thế
        int index = currentSchedule.indexWhere((s) => s.id == targetId);
        if (index != -1) {
          currentSchedule[index] = updatedClass;
        } else {
          currentSchedule.add(updatedClass);
        }
      } else {
        // Chế độ Thêm mới
        currentSchedule.add(updatedClass);
      }

      // 5. Lưu danh sách đã cập nhật vào Local Storage
      await LocalStorageHelper.saveSchedule(currentSchedule);
      await MySpaceFirebaseService().saveSchedule(updatedClass);

      // 6. Quay lại màn hình trước và báo hiệu thành công (true)
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Lỗi khi lưu môn học cục bộ: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }
}