import 'package:flutter/material.dart';
import 'myspace_firebase_service.dart';
import 'package:intl/intl.dart';
import 'local_storage_helper.dart';
import 'models/myspace_models.dart';
import '../services/notification_service.dart';

class ReminderControllerGroup {
  final TextEditingController controller;
  final FocusNode focusNode;
  String unit;

  ReminderControllerGroup({required String value, required this.unit})
      : controller = TextEditingController(text: value),
        focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class CreateDeadlinesPage extends StatefulWidget {
  final Deadline? deadline;
  const CreateDeadlinesPage({super.key, this.deadline});

  @override
  State<CreateDeadlinesPage> createState() => _CreateDeadlinesPageState();
}

class _CreateDeadlinesPageState extends State<CreateDeadlinesPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  
  final List<ReminderControllerGroup> _reminderGroups = [];

  // --- HẰNG SỐ MÀU SẮC THEO CSS ---
  static const Color headerBg = Color(0xFF545454);
  static const Color accentBlue = Color(0xFF92B9E6); // Màu nút Hủy/Lưu
  static const Color fieldBg = Color(0xFFEFF6FF);    // Rectangle 470
  static const Color borderGrey = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    if (widget.deadline != null) {
      _titleController.text = widget.deadline!.title;
      _descController.text = widget.deadline!.description ?? '';
      _selectedDate = widget.deadline!.dueDate;
      _selectedTime = widget.deadline!.dueTime;
      
      for (String r in widget.deadline!.reminders) {
        final parts = r.split(' ');
        if (parts.length >= 2) {
          _reminderGroups.add(ReminderControllerGroup(value: parts[0], unit: parts[1]));
        }
      }
    } else {
      _reminderGroups.add(ReminderControllerGroup(value: '30', unit: 'phút'));
    }

    // Lắng nghe focus cho các ô nhập số
    for (var group in _reminderGroups) {
      group.focusNode.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    setState(() {}); // Rebuild để cập nhật màu border khi focus
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    for (var group in _reminderGroups) {
      group.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBg = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color cardBg = isDarkMode ? const Color(0xFF1C1C1E) : fieldBg;
    final Color surfaceBg = isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
    final Color primaryText = isDarkMode ? Colors.white : Colors.black;
    final Color secondaryText = isDarkMode ? Colors.white70 : borderGrey;
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
        title: const Text('Tạo Deadline',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'Encode Sans Expanded')),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveDeadline,
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550.0),
          child: SingleChildScrollView(
            child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    style: TextStyle(fontSize: 20, color: primaryText),
                    decoration: InputDecoration(
                      hintText: 'Tên deadline',
                      hintStyle: TextStyle(color: secondaryText, fontSize: 20, fontFamily: 'Encode Sans Expanded'),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: headerBg)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    height: 77,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 24, color: primaryText),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                                  style: TextStyle(fontSize: 18, fontFamily: 'Urbanist', color: primaryText),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _selectTime,
                          child: Row(
                            children: [
                              Icon(Icons.access_time_outlined, size: 24, color: primaryText),
                              const SizedBox(width: 8),
                              Text(
                                _selectedTime.format(context),
                                style: TextStyle(fontSize: 18, fontFamily: 'Urbanist', color: primaryText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('Lời nhắc',
                      style: TextStyle(fontSize: 15, color: primaryText, fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  
                  // Modern Inline Reminders - Unified Containers
                  ..._reminderGroups.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var group = entry.value;
                    bool hasFocus = group.focusNode.hasFocus;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined, size: 20, color: accentBlue),
                            const SizedBox(width: 16),
                            
                            // Unified Number Input Box
                            Container(
                              width: 55,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: hasFocus ? accentBlue : borderColor.withOpacity(0.1),
                                  width: hasFocus ? 1.5 : 1,
                                ),
                              ),
                              child: TextField(
                                controller: group.controller,
                                focusNode: group.focusNode,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: primaryText, fontSize: 16, fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide.none),
                                  contentPadding: EdgeInsets.zero,
                                  filled: false,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Unified Unit Box
                            Container(
                              width: 100,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: borderColor.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: group.unit,
                                  icon: Icon(Icons.expand_more_rounded, color: secondaryText, size: 18),
                                  alignment: Alignment.center,
                                  style: TextStyle(color: primaryText, fontSize: 16, fontFamily: 'Urbanist', fontWeight: FontWeight.w500),
                                  items: ['phút', 'giờ', 'ngày', 'tuần'].map((String val) {
                                    return DropdownMenuItem<String>(
                                      value: val,
                                      alignment: Alignment.center,
                                      child: Text(val),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) {
                                    if (newValue != null) {
                                      setState(() => group.unit = newValue);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 24),
                              onPressed: () {
                                setState(() {
                                  _reminderGroups[idx].dispose();
                                  _reminderGroups.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                  // "Thêm lời nhắc" text link
                  InkWell(
                    onTap: () {
                      setState(() {
                        final newGroup = ReminderControllerGroup(value: '30', unit: 'phút');
                        newGroup.focusNode.addListener(_onFocusChange);
                        _reminderGroups.add(newGroup);
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, color: accentBlue, size: 22),
                          const SizedBox(width: 4),
                          Text(
                            'Thêm lời nhắc',
                            style: TextStyle(
                              color: accentBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Urbanist',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  Text('Ghi chú',
                      style: TextStyle(fontSize: 15, color: primaryText, fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: surfaceBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _descController,
                      maxLines: 8,
                      style: TextStyle(color: primaryText, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Có note gì thì ghi ngắn gọn ở đây nhe...',
                        hintStyle: TextStyle(color: borderGrey, fontSize: 15, fontFamily: 'Encode Sans Expanded'),
                        contentPadding: const EdgeInsets.all(12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: headerBg),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )));
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _saveDeadline() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên deadline')),
      );
      return;
    }

    try {
      final DateTime finalDateTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      );

      // Hủy thông báo cũ
      if (widget.deadline != null) {
        for (var nid in widget.deadline!.notificationIds) {
          await NotificationService.cancelNotification(nid);
        }
      }

      List<int> newNotificationIds = [];
      List<String> reminderStrings = [];
      
      for (var group in _reminderGroups) {
        if (group.controller.text.isEmpty) continue;
        
        int val = int.tryParse(group.controller.text) ?? 0;
        String unit = group.unit;
        reminderStrings.add('$val $unit');

        int minutesBefore = 0;
        if (unit.contains('phút')) minutesBefore = val;
        else if (unit.contains('giờ')) minutesBefore = val * 60;
        else if (unit.contains('ngày')) minutesBefore = val * 1440;
        else if (unit.contains('tuần')) minutesBefore = val * 10080;

        DateTime notificationTime = finalDateTime.subtract(Duration(minutes: minutesBefore));
        if (notificationTime.isAfter(DateTime.now())) {
          int nid = (finalDateTime.millisecondsSinceEpoch + minutesBefore).remainder(100000000);
          await NotificationService.scheduleNotification(
            id: nid,
            title: "Nhắc nhở Deadline: ${_titleController.text}",
            body: "Deadline của bạn sẽ đến hạn vào lúc ${DateFormat('HH:mm dd/MM').format(finalDateTime)}",
            scheduledDate: notificationTime,
          );
          newNotificationIds.add(nid);
        }
      }

      List<Deadline> currentDeadlines = await LocalStorageHelper.getDeadlines();
      final String targetId = widget.deadline?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      final updatedDeadline = Deadline(
        id: targetId,
        title: _titleController.text,
        description: _descController.text,
        dueDate: _selectedDate,
        dueTime: _selectedTime,
        isCompleted: widget.deadline?.isCompleted ?? false,
        reminders: reminderStrings,
        notificationIds: newNotificationIds,
      );

      if (widget.deadline != null) {
        int index = currentDeadlines.indexWhere((d) => d.id == targetId);
        if (index != -1) {
          currentDeadlines[index] = updatedDeadline;
        } else {
          currentDeadlines.add(updatedDeadline);
        }
      } else {
        currentDeadlines.add(updatedDeadline);
      }

      await LocalStorageHelper.saveDeadlines(currentDeadlines);
      await MySpaceFirebaseService().saveDeadline(updatedDeadline);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Lỗi lưu deadline: $e");
    }
  }
}