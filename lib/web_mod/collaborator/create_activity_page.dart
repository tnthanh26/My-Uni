import 'package:flutter/material.dart';
import '../services/activity_service.dart';

class CreateActivityPage extends StatefulWidget {
  const CreateActivityPage({
    super.key,
    required this.onCreated,
  });

  final VoidCallback onCreated;

  @override
  State<CreateActivityPage> createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends State<CreateActivityPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _organizerController = TextEditingController();
  final _pointController = TextEditingController(text: '5');

  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _organizerController.dispose();
    _pointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Container(
        width: 760,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE9EEF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _input(_titleController, 'Tên hoạt động'),
            const SizedBox(height: 16),

            _input(
              _descriptionController,
              'Mô tả hoạt động',
              maxLines: 4,
            ),

            const SizedBox(height: 16),

            _input(_locationController, 'Địa điểm'),

            const SizedBox(height: 16),

            _input(_organizerController, 'Đơn vị tổ chức'),

            const SizedBox(height: 16),

            _input(
              _pointController,
              'Điểm rèn luyện dự kiến',
              isNumber: true,
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: _dateBox(
                    title: 'Bắt đầu',
                    value: _startTime,
                    onTap: () async {
                      final picked = await _pickDateTime(_startTime);

                      if (picked != null) {
                        setState(() => _startTime = picked);
                      }
                    },
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: _dateBox(
                    title: 'Kết thúc',
                    value: _endTime,
                    onTap: () async {
                      final picked = await _pickDateTime(_endTime);

                      if (picked != null) {
                        setState(() => _endTime = picked);
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _handleCreateActivity,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo hoạt động'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateActivity() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final organizer = _organizerController.text.trim();
    final point = int.tryParse(_pointController.text.trim()) ?? 0;

    if (title.isEmpty || location.isEmpty || organizer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập đủ tên, địa điểm và đơn vị tổ chức.',
          ),
        ),
      );
      return;
    }

    if (_endTime.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thời gian kết thúc phải sau thời gian bắt đầu.',
          ),
        ),
      );
      return;
    }

    await ActivityService.createActivity(
      title: title,
      description: description,
      location: location,
      organizerName: organizer,
      trainingPoint: point,
      startTime: _startTime,
      endTime: _endTime,
    );

    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _organizerController.clear();

    _pointController.text = '5';

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã tạo hoạt động thành công.'),
      ),
    );

    widget.onCreated();
  }

  Widget _input(
      TextEditingController controller,
      String label, {
        int maxLines = 1,
        bool isNumber = false,
      }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dateBox({
    required String title,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    final text =
        '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE9EEF3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              color: Colors.blueAccent,
            ),

            const SizedBox(width: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    color: Colors.grey,
                  ),
                ),

                Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null) return null;

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }
}