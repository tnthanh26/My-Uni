import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/activity_service.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

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
  final _studentIdsController = TextEditingController();

  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  bool _requiresRegistration = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _organizerController.dispose();
    _pointController.dispose();
    _studentIdsController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final fileBytes = result.files.first.bytes;

    if (fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không đọc được nội dung file.'),
        ),
      );
      return;
    }

    final content = utf8.decode(fileBytes);
    _parseAndAddIds(content);
  }

  void _parseAndAddIds(String content) {
    // Sử dụng Regex để tìm tất cả các chuỗi số có độ dài từ 7 đến 11 ký tự (định dạng MSSV phổ biến)
    // Cách này giúp nhặt MSSV ra khỏi CSV, Excel copy-paste hoặc TXT lộn xộn mà không quan tâm định dạng cột
    final matches = RegExp(r'\b\d{7,11}\b').allMatches(content);
    final ids = matches
        .map((m) => m.group(0)!)
        .toSet() // Dùng Set để loại bỏ trùng lặp ngay từ đầu
        .toList();

    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy chuỗi số nào giống MSSV (7-11 chữ số) trong file.'),
        ),
      );
      return;
    }

    setState(() {
      final currentText = _studentIdsController.text.trim();
      final currentIds = currentText.split(RegExp(r'[\n\r, ]+')).toSet();
      
      // Chỉ thêm những ID chưa có trong danh sách hiện tại
      final newIds = ids.where((id) => !currentIds.contains(id)).toList();
      
      if (newIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tất cả MSSV trong file đã có trong danh sách.')),
        );
        return;
      }

      final separator = currentText.isEmpty ? '' : '\n';
      _studentIdsController.text = '$currentText$separator${newIds.join('\n')}';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã trích xuất thêm ${ids.length} MSSV từ file.')),
    );
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

            const SizedBox(height: 22),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9EEF3)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Yêu cầu đăng ký trước',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Chỉ sinh viên trong danh sách mới được điểm danh tự động.',
                      style: TextStyle(fontFamily: 'Nunito'),
                    ),
                    value: _requiresRegistration,
                    onChanged: (val) => setState(() => _requiresRegistration = val),
                    activeColor: Colors.blueAccent,
                  ),
                  if (_requiresRegistration) ...[
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Danh sách MSSV đăng ký',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: const Text('Chọn file danh sách (.txt, .csv)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _studentIdsController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Nhập hoặc dán danh sách MSSV, mỗi mã một dòng...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE9EEF3)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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
    
    final pointText = _pointController.text.trim();
    if (pointText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập điểm rèn luyện.')),
      );
      return;
    }

    final point = int.tryParse(pointText);
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Điểm rèn luyện phải là số nguyên (không chứa dấu thập phân).')),
      );
      return;
    }

    if (point < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Điểm rèn luyện không được là số âm.')),
      );
      return;
    }

    final registeredIds = _studentIdsController.text
        .split(RegExp(r'[\n\r,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

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

    if (_requiresRegistration && registeredIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập danh sách sinh viên đăng ký.'),
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
      requiresRegistration: _requiresRegistration,
      registeredStudentIds: registeredIds,
    );

    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _organizerController.clear();
    _studentIdsController.clear();

    _pointController.text = '5';
    setState(() => _requiresRegistration = false);

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
          ? const TextInputType.numberWithOptions(decimal: false, signed: false)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
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
      initialEntryMode: TimePickerEntryMode.inputOnly,
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