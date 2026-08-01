import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_uni/models/event_model.dart';
import 'package:my_uni/features/services/notification_service.dart';

class ReminderControllerGroup {
  final TextEditingController controller;
  final FocusNode focusNode;
  String unit;

  ReminderControllerGroup({
    required String value,
    required this.unit,
  })  : controller = TextEditingController(text: value),
        focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class CreatePersonalEventPage extends StatefulWidget {
  final EventModel? event;
  const CreatePersonalEventPage({super.key, this.event});

  @override
  State<CreatePersonalEventPage> createState() =>
      _CreatePersonalEventPageState();
}

class _CreatePersonalEventPageState extends State<CreatePersonalEventPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);

  final List<ReminderControllerGroup> _reminderGroups = [];
  bool _isLoading = false;

  static const Color primaryBrown = Color(0xFF545454);
  static const Color accentBlue = Color(0xFF92B9E6);
  static const Color borderGrey = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();

    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _locationController.text = widget.event!.location;
      _descController.text = widget.event!.description ?? "";
      _selectedDate = widget.event!.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.event!.dateTime);

      // Tạm thời đọc field cũ reminder để không vỡ model hiện tại.
      final oldReminder = widget.event!.reminder;

      if (oldReminder != null &&
          oldReminder.isNotEmpty &&
          oldReminder != 'Không' &&
          oldReminder != 'Đặt lời nhắc') {
        final parsed = _parseOldReminder(oldReminder);
        _reminderGroups.add(
          ReminderControllerGroup(
            value: parsed.$1,
            unit: parsed.$2,
          ),
        );
      } else {
        _reminderGroups.add(ReminderControllerGroup(value: '30', unit: 'phút'));
      }
    } else {
      _reminderGroups.add(ReminderControllerGroup(value: '30', unit: 'phút'));
    }

    for (var group in _reminderGroups) {
      group.focusNode.addListener(_onFocusChange);
    }
  }

  (String, String) _parseOldReminder(String reminder) {
    if (reminder.contains('5 phút')) return ('5', 'phút');
    if (reminder.contains('15 phút')) return ('15', 'phút');
    if (reminder.contains('1 giờ')) return ('1', 'giờ');
    if (reminder.contains('ngày')) {
      final number = RegExp(r'\d+').firstMatch(reminder)?.group(0) ?? '1';
      return (number, 'ngày');
    }
    if (reminder.contains('tuần')) {
      final number = RegExp(r'\d+').firstMatch(reminder)?.group(0) ?? '1';
      return (number, 'tuần');
    }
    return ('30', 'phút');
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descController.dispose();

    for (var group in _reminderGroups) {
      group.dispose();
    }

    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    DateTime tempDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
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
                        "Chọn giờ sự kiện",
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
                            _selectedTime = TimeOfDay(
                              hour: tempDateTime.hour,
                              minute: tempDateTime.minute,
                            );
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

  int _getMinutesBefore(int value, String unit) {
    if (unit.contains('phút')) return value;
    if (unit.contains('giờ')) return value * 60;
    if (unit.contains('ngày')) return value * 1440;
    if (unit.contains('tuần')) return value * 10080;
    return 0;
  }

  Future<bool> _confirmPastEvent(DateTime finalDateTime) async {
    if (finalDateTime.isAfter(DateTime.now())) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sự kiện đang ở quá khứ'),
        content: const Text(
          'Thời gian sự kiện bạn chọn đã trôi qua rồi. Bạn vẫn muốn lưu sự kiện này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Chỉnh lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vẫn lưu'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _saveEvent() async {
    if (_isLoading) return;

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập tên sự kiện")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final DateTime finalDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final shouldContinue = await _confirmPastEvent(finalDateTime);
    if (!shouldContinue) return;

    setState(() => _isLoading = true);

    try {
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('personal_events');

      // Hủy thông báo cũ nếu đang sửa.
      if (widget.event != null) {
        if (widget.event!.notificationId != null) {
          await NotificationService.cancelNotification(
            widget.event!.notificationId!,
          );
        }

        // Nếu sau này model có notificationIds thì nên cancel hết ở đây.
        // Hiện tại giữ tương thích với notificationId cũ.
      }

      List<String> reminderStrings = [];
      List<int> notificationIds = [];

      for (var group in _reminderGroups) {
        final rawValue = group.controller.text.trim();
        if (rawValue.isEmpty) continue;

        final int value = int.tryParse(rawValue) ?? 0;
        if (value <= 0) continue;

        final String unit = group.unit;
        final int minutesBefore = _getMinutesBefore(value, unit);

        reminderStrings.add('$value $unit');

        final DateTime notificationTime = finalDateTime.subtract(
          Duration(minutes: minutesBefore),
        );

        if (notificationTime.isAfter(DateTime.now())) {
          final int notificationId =
          (finalDateTime.millisecondsSinceEpoch + minutesBefore)
              .remainder(100000000);

          await NotificationService.scheduleNotification(
            id: notificationId,
            title: "Nhắc nhở sự kiện: ${_titleController.text.trim()}",
            body: _locationController.text.trim().isNotEmpty
                ? "Sắp đến giờ diễn ra tại ${_locationController.text.trim()}"
                : "Sự kiện sẽ diễn ra lúc ${DateFormat('HH:mm dd/MM').format(finalDateTime)}",
            scheduledDate: notificationTime,
          );

          notificationIds.add(notificationId);
        }
      }

      final eventData = {
        'title': _titleController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descController.text.trim(),
        'dateTime': Timestamp.fromDate(finalDateTime),

        // Field mới: hỗ trợ nhiều reminder.
        'reminders': reminderStrings,
        'notificationIds': notificationIds,

        // Field cũ: giữ lại để app không bị vỡ ở những chỗ đang đọc reminder/notificationId.
        'reminder': reminderStrings.isNotEmpty
            ? '${reminderStrings.first} trước'
            : 'Không',
        'notificationId':
        notificationIds.isNotEmpty ? notificationIds.first : null,

        if (widget.event?.sourceArticleUrl != null)
          'sourceArticleUrl': widget.event!.sourceArticleUrl,

        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.event != null) {
        await collection.doc(widget.event!.id).update(eventData);
      } else {
        eventData['createdAt'] = FieldValue.serverTimestamp();
        await collection.add(eventData);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Firebase Error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildReminderSection({
    required bool isDarkMode,
    required Color cardBg,
    required Color textColor,
    required Color secondaryText,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lời nhắc',
          style: TextStyle(
            fontSize: 15,
            color: textColor,
            fontFamily: 'Encode Sans Expanded',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        ..._reminderGroups.asMap().entries.map((entry) {
          final int idx = entry.key;
          final group = entry.value;
          final bool hasFocus = group.focusNode.hasFocus;

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
                  const Icon(
                    Icons.notifications_active_outlined,
                    size: 20,
                    color: accentBlue,
                  ),
                  const SizedBox(width: 16),

                  Container(
                    width: 55,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                        hasFocus ? accentBlue : borderColor.withOpacity(0.1),
                        width: hasFocus ? 1.5 : 1,
                      ),
                    ),
                    child: TextField(
                      controller: group.controller,
                      focusNode: group.focusNode,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Container(
                    width: 100,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: borderColor.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: group.unit,
                        icon: Icon(
                          Icons.expand_more_rounded,
                          color: secondaryText,
                          size: 18,
                        ),
                        alignment: Alignment.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontFamily: 'Urbanist',
                          fontWeight: FontWeight.w500,
                        ),
                        dropdownColor:
                        isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                        items: ['phút', 'giờ', 'ngày', 'tuần'].map((val) {
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
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.redAccent,
                      size: 24,
                    ),
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

        InkWell(
          onTap: () {
            setState(() {
              final newGroup = ReminderControllerGroup(
                value: '30',
                unit: 'phút',
              );
              newGroup.focusNode.addListener(_onFocusChange);
              _reminderGroups.add(newGroup);
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: accentBlue, size: 22),
                SizedBox(width: 4),
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
      ],
    );
  }

  Widget _buildInputRow(
      Color bg,
      IconData icon, {
        required Widget child,
        VoidCallback? onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryBrown.withOpacity(0.7), size: 22),
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor =
    isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color inputBg =
    isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFF0F5FF);
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color secondaryText = isDarkMode ? Colors.white70 : borderGrey;
    final Color borderColor =
    isDarkMode ? const Color(0xFF3A3A3C) : borderGrey;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryBrown,
        elevation: 0,
        leadingWidth: 70,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Hủy',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        title: Text(
          widget.event != null ? 'Sửa Sự Kiện' : 'Tạo Sự Kiện',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveEvent,
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Text(
              'Lưu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550.0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: widget.event == null,
              style: TextStyle(
                fontSize: 20,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'Tên sự kiện',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: primaryBrown),
                ),
              ),
            ),

            const SizedBox(height: 30),

            _buildInputRow(
              inputBg,
              Icons.calendar_today_outlined,
              onTap: _selectDate,
              child: Row(
                children: [
                  Text(
                    DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_selectedDate),
                    style: TextStyle(color: textColor),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _selectTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedTime.format(context),
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _buildInputRow(
              inputBg,
              Icons.location_on_outlined,
              child: TextField(
                controller: _locationController,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(
                  hintText: 'Địa điểm',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),

            const SizedBox(height: 24),

            _buildReminderSection(
              isDarkMode: isDarkMode,
              cardBg: inputBg,
              textColor: textColor,
              secondaryText: secondaryText,
              borderColor: borderColor,
            ),

            const SizedBox(height: 30),

            Text(
              'Nội dung',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: inputBg,
              ),
              child: TextField(
                controller: _descController,
                maxLines: 6,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(
                  hintText: 'Chi tiết về sự kiện',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    )));
  }
}