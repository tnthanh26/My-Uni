import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_storage_helper.dart';
import 'myspace_models.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.schedule != null) {
      _subjectController.text = widget.schedule!.name;
      _locationController.text = widget.schedule!.room;
      // Cập nhật các biến thời gian và thứ từ widget.schedule
      // VD: _selectedWeekday = _getWeekdayString(widget.schedule!.weekday);
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: headerBg,
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
                style: const TextStyle(fontSize: 20, color: Colors.black, fontFamily: 'Encode Sans Expanded'),
                decoration: const InputDecoration(
                  hintText: 'Tên Môn học',
                  hintStyle: TextStyle(color: borderGrey, fontSize: 20),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderGrey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: headerBg)),
                ),
              ),
              const SizedBox(height: 24),

              // 2. [CẬP NHẬT] Chọn Thứ (Thay thế cho chọn Ngày)
              _buildRectangleField(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedWeekday,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, color: hintGrey),
                          style: const TextStyle(fontSize: 20, fontFamily: 'Urbanist', color: Colors.black),
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
                            const Icon(Icons.access_time, size: 24),
                            const SizedBox(width: 8),
                            Text(_startTime.format(context),
                                style: const TextStyle(fontSize: 18, fontFamily: 'Encode Sans Expanded', color: hintGrey)),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(color: borderGrey, indent: 20, endIndent: 20),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(false),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Icon(Icons.access_time, size: 24),
                            const SizedBox(width: 8),
                            Text(_endTime.format(context),
                                style: const TextStyle(fontSize: 18, fontFamily: 'Encode Sans Expanded', color: hintGrey)),
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
                    const Icon(Icons.location_on_outlined, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        style: const TextStyle(fontSize: 20, fontFamily: 'Encode Sans Expanded'),
                        decoration: const InputDecoration(
                          hintText: 'Địa điểm',
                          hintStyle: TextStyle(color: hintGrey),
                          border: InputBorder.none,
                        ),
                      ),
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

  Widget _buildRectangleField({required Widget child, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: 77,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: fieldBg, borderRadius: BorderRadius.circular(20)),
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
        color: widget.schedule?.color ?? Colors.blueAccent, // Giữ màu cũ nếu có
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