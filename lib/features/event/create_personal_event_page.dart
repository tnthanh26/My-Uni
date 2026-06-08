import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_uni/models/event_model.dart';
import 'package:my_uni/features/services/notification_service.dart';

class CreatePersonalEventPage extends StatefulWidget {
  final EventModel? event;
  const CreatePersonalEventPage({super.key, this.event});

  @override
  State<CreatePersonalEventPage> createState() => _CreatePersonalEventPageState();
}

class _CreatePersonalEventPageState extends State<CreatePersonalEventPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  String _selectedReminder = 'Đặt lời nhắc';
  bool _isLoading = false;

  static const Color primaryBrown = Color(0xFF47352E);

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _locationController.text = widget.event!.location;
      _descController.text = widget.event!.description ?? "";
      _selectedDate = widget.event!.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.event!.dateTime);
      _selectedReminder = widget.event!.reminder ?? 'Không';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _selectReminder() {
    final List<String> options = ['5 phút trước', '15 phút trước', '1 giờ trước', 'Không'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) => ListTile(
            title: Text(opt, textAlign: TextAlign.center),
            onTap: () {
              setState(() => _selectedReminder = opt);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  Future<void> _saveEvent() async {
    if (_isLoading) return;

    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tên sự kiện")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final DateTime finalDateTime = DateTime(
          _selectedDate.year, _selectedDate.month, _selectedDate.day,
          _selectedTime.hour, _selectedTime.minute,
        );

        // 1. Tính toán thời gian thông báo
        int minutesBefore = 0;
        if (_selectedReminder == '5 phút trước') minutesBefore = 5;
        else if (_selectedReminder == '15 phút trước') minutesBefore = 15;
        else if (_selectedReminder == '1 giờ trước') minutesBefore = 60;

        DateTime notificationTime = finalDateTime.subtract(Duration(minutes: minutesBefore));

        // 2. Tạo ID thông báo (Dùng remainder để đảm bảo an toàn cho Android int32)
        int notificationId = finalDateTime.millisecondsSinceEpoch.remainder(100000000);

        final eventData = {
          'title': _titleController.text,
          'location': _locationController.text,
          'description': _descController.text,
          'dateTime': Timestamp.fromDate(finalDateTime),
          'reminder': _selectedReminder,
          'notificationId': notificationId,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final collection = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('personal_events');

        // 3. Xử lý Hủy thông báo cũ nếu là chế độ Sửa
        if (widget.event != null) {
          if (widget.event!.notificationId != null) {
            await NotificationService.cancelNotification(widget.event!.notificationId!);
          }
          await collection.doc(widget.event!.id).update(eventData);
        } else {
          eventData['createdAt'] = FieldValue.serverTimestamp();
          await collection.add(eventData);
        }

        // 4. Đặt lịch thông báo mới
        if (_selectedReminder != 'Không' && notificationTime.isAfter(DateTime.now())) {
          await NotificationService.scheduleNotification(
            id: notificationId,
            title: "Nhắc nhở sự kiện: ${_titleController.text}",
            body: "Sắp đến giờ diễn ra tại ${_locationController.text}",
            scheduledDate: notificationTime,
          );
        }

        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Firebase Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    } finally {
      // Chỉ tắt loading nếu widget vẫn còn tồn tại và chưa Navigator.pop
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color inputBg = isDarkMode ? Colors.white10 : const Color(0xFFF0F5FF);
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryBrown,
        elevation: 0,
        leadingWidth: 70,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
        title: Text(
            widget.event != null ? 'Sửa Sự Kiện' : 'Tạo Sự Kiện',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveEvent,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Lưu', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: widget.event == null,
              style: TextStyle(fontSize: 20, color: textColor, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Tên sự kiện',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: primaryBrown)),
              ),
            ),
            const SizedBox(height: 30),
            _buildInputRow(isDarkMode, inputBg, Icons.calendar_today_outlined, onTap: _selectDate,
                child: Row(children: [
                  Text(DateFormat('EEE, MMM d, yyyy').format(_selectedDate), style: TextStyle(color: textColor)),
                  const Spacer(),
                  InkWell(
                    onTap: _selectTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.access_time, size: 18, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(_selectedTime.format(context), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                ])),
            const SizedBox(height: 16),
            _buildInputRow(isDarkMode, inputBg, Icons.location_on_outlined,
                child: TextField(
                  controller: _locationController,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(hintText: 'Địa điểm', border: InputBorder.none, isDense: true),
                )),
            const SizedBox(height: 16),
            _buildInputRow(isDarkMode, inputBg, Icons.notifications_none_rounded, onTap: _selectReminder,
                child: Row(
                  children: [
                    Text(_selectedReminder, style: TextStyle(color: _selectedReminder == 'Đặt lời nhắc' ? Colors.grey : textColor)),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  ],
                )),
            const SizedBox(height: 30),
            Text('Nội dung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
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
                decoration: const InputDecoration(hintText: 'Chi tiết về sự kiện', border: InputBorder.none),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(bool isDarkMode, Color bg, IconData icon, {required Widget child, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
        child: Row(children: [
          Icon(icon, color: primaryBrown.withOpacity(0.7), size: 22),
          const SizedBox(width: 12),
          Expanded(child: child),
        ]),
      ),
    );
  }
}