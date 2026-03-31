import 'package:flutter/material.dart';
import 'myspace_firebase_service.dart';
import 'package:intl/intl.dart';
import 'local_storage_helper.dart';
import 'myspace_models.dart';

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
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Status bar giả lập theo Figma (40px)
      appBar: AppBar(
        backgroundColor: headerBg,
        elevation: 4, // Tương đương box-shadow trong CSS
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy',
              style: TextStyle(color: accentBlue, fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'Encode Sans Expanded')),
        ),
        title: const Text('Tạo Deadlines',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'Encode Sans Expanded')),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveDeadline, // Gọi hàm đã sửa ở trên
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
        child: Column(
          children: [
            const SizedBox(height: 16), // Padding trên cùng
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Tên Deadline (Gạch chân)
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(fontSize: 20, color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'Tên deadline',
                      hintStyle: TextStyle(color: borderGrey, fontSize: 20, fontFamily: 'Encode Sans Expanded'),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderGrey)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: headerBg)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Ô chọn Ngày và Giờ (Rectangle 470)
                  Container(
                    width: double.infinity,
                    height: 77,
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Cánh trái: Calendar
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                                  style: const TextStyle(fontSize: 18, fontFamily: 'Urbanist'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Cánh phải: Time
                        InkWell(
                          onTap: _selectTime,
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_outlined, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                _selectedTime.format(context),
                                style: const TextStyle(fontSize: 18, fontFamily: 'Urbanist'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Đặt lời nhắc (Rectangle 470)
                  Container(
                    width: double.infinity,
                    height: 77,
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Row(
                      children: [
                        Icon(Icons.alarm_outlined, size: 24),
                        SizedBox(width: 12),
                        Text('Đặt lời nhắc',
                            style: TextStyle(color: Color(0xFF787878), fontSize: 20, fontFamily: 'Encode Sans Expanded')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 4. Phần Nội dung
                  const Text('Nội dung',
                      style: TextStyle(fontSize: 15, color: Colors.black, fontFamily: 'Encode Sans Expanded')),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 214,
                    decoration: BoxDecoration(
                      border: Border.all(color: borderGrey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _descController,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: 'Chi tiết về deadlines',
                        hintStyle: TextStyle(color: borderGrey, fontSize: 15, fontFamily: 'Encode Sans Expanded'),
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
    );
  }

  // Logic chọn ngày/giờ giữ nguyên như cũ
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
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _saveDeadline() async {
    if (_titleController.text.isEmpty) {
      // Có thể thêm thông báo lỗi nếu tiêu đề trống
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên deadline')),
      );
      return;
    }

    try {
      // --- THAY THẾ FIREBASE BẰNG LOCAL STORAGE TẠM THỜI ---

      // 1. Lấy danh sách hiện có (đã bao gồm mock data nếu máy trống)
      List<Deadline> currentDeadlines = await LocalStorageHelper.getDeadlines();

      // 2. Xác định ID:
      // Nếu widget.deadline != null (đang sửa) -> lấy ID cũ.
      // Nếu widget.deadline == null (tạo mới) -> tạo ID mới bằng timestamp.
      final String targetId = widget.deadline?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      // 3. Tạo đối tượng Deadline đã cập nhật
      final updatedDeadline = Deadline(
        id: targetId,
        title: _titleController.text,
        description: _descController.text,
        dueDate: _selectedDate,
        dueTime: _selectedTime,
        isCompleted: widget.deadline?.isCompleted ?? false, // Giữ nguyên trạng thái hoàn thành cũ nếu đang sửa
      );

      // 4. KIỂM TRA: LÀ SỬA HAY THÊM MỚI?
      if (widget.deadline != null) {
        // Tìm vị trí của phần tử cũ trong danh sách dựa trên ID
        int index = currentDeadlines.indexWhere((d) => d.id == targetId);

        if (index != -1) {
          // Nếu tìm thấy, GHI ĐÈ vào vị trí cũ
          currentDeadlines[index] = updatedDeadline;
        } else {
          // Trường hợp hy hữu (id không còn tồn tại), thêm mới
          currentDeadlines.add(updatedDeadline);
        }
      } else {
        // Nếu là tạo mới hoàn toàn, THÊM vào cuối danh sách
        currentDeadlines.add(updatedDeadline);
      }

      // 5. Lưu danh sách đã sửa đổi trở lại vào LocalStorage
      await LocalStorageHelper.saveDeadlines(currentDeadlines);
      await MySpaceFirebaseService().saveDeadline(updatedDeadline);

      // 6. Quay lại màn hình trước và thông báo thành công
      if (mounted) {
        Navigator.pop(context, true); // Trả về true để MySpaceScreen biết cần refresh
      }

    } catch (e) {
      print("Lỗi lưu deadline cục bộ: $e");
    }
  }
}