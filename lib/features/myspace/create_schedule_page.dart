import 'package:flutter/material.dart';
import 'myspace_firebase_service.dart';
import 'local_storage_helper.dart';
import 'models/myspace_models.dart';
import 'package:intl/intl.dart';

class CreateSchedulePage extends StatefulWidget {
  final StudyClass? schedule;
  const CreateSchedulePage({super.key, this.schedule});

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

  // Danh sách các màu "Pastel" phù hợp với UI hiện đại
  final List<Color> _colorOptions = [
    const Color(0xFFFFC374), // Vàng
    const Color(0xFF92B9E6), // Xanh dương hcmus
    const Color(0xFF66D46D), // Xanh lá
    const Color(0xFFFFA3A3), // Đỏ nhạt
    const Color(0xFFD492E6), // Tím
    const Color(0xFF8DE6D4), // Teal nhạt
  ];

  @override
  void initState() {
    super.initState();
    if (widget.schedule != null) {
      _subjectController.text = widget.schedule!.name;
      _locationController.text = widget.schedule!.room;
      _selectedColor = widget.schedule!.color;
      _selectedWeekday = _weekdays[widget.schedule!.weekday - 2];
      // Cập nhật các biến thời gian và thứ từ widget.schedule
      // VD: _selectedWeekday = _getWeekdayString(widget.schedule!.weekday);
    }
  }

  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBg = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color cardBg = isDarkMode ? const Color(0xFF1C1C1E) : fieldBg;
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
      body: SingleChildScrollView(
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

              // 4. Địa điểm
              _buildRectangleField(
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 24, color: primaryText),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        style: TextStyle(fontSize: 20, fontFamily: 'Encode Sans Expanded', color: primaryText),
                        decoration: InputDecoration(
                          hintText: 'Địa điểm',
                          hintStyle: TextStyle(color: secondaryText),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
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
    );
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
    final picked = await showTimePicker(context: context, initialTime: isStart ? _startTime : _endTime);
    if (picked != null) {
      setState(() {
        if (isStart) _startTime = picked;
        else _endTime = picked;
      });
    }
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

  // Cập nhật hàm _saveSchedule
  Future<void> _saveSchedule() async {
    if (_subjectController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên môn học')),
      );
      return;
    }

    try {
      // 1. Lấy danh sách lịch học hiện tại từ máy (đã bao gồm mock data nếu máy trống)
      List<StudyClass> currentSchedule = await LocalStorageHelper.getSchedule();

      // 2. Tạo đối tượng StudyClass mới từ thông tin đã nhập
      final String targetId = widget.schedule?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      // 3. Tạo đối tượng môn học mới từ thông tin đã nhập
      final updatedClass = StudyClass(
        id: targetId,
        name: _subjectController.text,
        start: _startTime.format(context),
        end: _endTime.format(context),
        room: _locationController.text,
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