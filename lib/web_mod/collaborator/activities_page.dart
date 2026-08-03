import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../services/image_upload_helper.dart';
import '../widgets/activity_card.dart';

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({
    super.key,
    required this.onOpenAttendance,
  });

  final void Function(String activityId, Map<String, dynamic> data) onOpenAttendance;

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  final TextEditingController _activitySearchController = TextEditingController();
  Timer? _activitySearchDebounce;
  String _activitySearchText = '';

  @override
  void dispose() {
    _activitySearchDebounce?.cancel();
    _activitySearchController.dispose();
    super.dispose();
  }

  Future<void> _showDeleteActivityConfirmation(
      BuildContext context,
      String activityId,
      String title,
      ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text(
              'Xóa hoạt động',
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text.rich(
          TextSpan(
            text: 'Bạn có chắc chắn muốn xóa hoạt động ',
            children: [
              TextSpan(
                text: '"$title"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                '? \n\nHoạt động sẽ bị xóa vĩnh viển khỏi hệ thống và không thể khôi phục.',
              ),
            ],
          ),
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 36),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Xác nhận xóa',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await ActivityService.deleteActivity(activityId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa hoạt động.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi xóa hoạt động: $e')),
          );
        }
      }
    }
  }

  Future<DateTime?> _pickDateTimeInDialog(BuildContext context, DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      locale: const Locale('vi', 'VN'),
    );

    if (date == null) return null;
    if (!context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
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

    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: Color(0xFF1E293B),
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

  Future<void> _showEditActivityDialog(
      BuildContext context,
      String activityId,
      Map<String, dynamic> data,
      ) async {
    final titleController = TextEditingController(text: data['title'] ?? '');
    final descriptionController =
    TextEditingController(text: data['description'] ?? '');
    final locationController =
    TextEditingController(text: data['location'] ?? '');
    final organizerController =
    TextEditingController(text: data['organizerName'] ?? '');
    final contactController =
    TextEditingController(text: data['contact'] ?? '');
    final trainingPointController = TextEditingController(
      text: (data['trainingPoint'] ?? 0).toString(),
    );
    final imageUrlController =
    TextEditingController(text: data['imageUrl'] ?? '');

    bool requiresRegistration = data['requiresRegistration'] == true;
    bool isOnline = data['isOnline'] == true;
    final onlineUrlController =
    TextEditingController(text: data['onlineUrl'] ?? '');
    final registrationUrlController =
    TextEditingController(text: data['registrationUrl'] ?? '');

    DateTime startTime = (data['startTime'] is Timestamp)
        ? (data['startTime'] as Timestamp).toDate()
        : DateTime.now();
    DateTime endTime = (data['endTime'] is Timestamp)
        ? (data['endTime'] as Timestamp).toDate()
        : DateTime.now().add(const Duration(hours: 2));

    bool isUploading = false;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenSize = MediaQuery.sizeOf(context);
            final dialogWidth = math.min(650.0, screenSize.width - 48.0);
            final dialogHeight = math.min(720.0, screenSize.height - 48.0);

            return Theme(
              data: Theme.of(context).copyWith(
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 47),
                  ),
                ),
              ),
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SizedBox(
                  width: dialogWidth,
                  height: dialogHeight,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 16, 16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_calendar_rounded,
                              color: Colors.blueAccent,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Chỉnh sửa hoạt động',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(dialogCtx),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Đóng',
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: titleController,
                                decoration: InputDecoration(
                                  labelText: 'Tên hoạt động',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: organizerController,
                                decoration: InputDecoration(
                                  labelText: 'Đơn vị tổ chức',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _dateBox(
                                      title: 'Thời gian bắt đầu *',
                                      value: startTime,
                                      onTap: () async {
                                        final picked = await _pickDateTimeInDialog(context, startTime);
                                        if (picked != null) {
                                          setDialogState(() => startTime = picked);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _dateBox(
                                      title: 'Thời gian kết thúc *',
                                      value: endTime,
                                      onTap: () async {
                                        final picked = await _pickDateTimeInDialog(context, endTime);
                                        if (picked != null) {
                                          setDialogState(() => endTime = picked);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: contactController,
                                decoration: InputDecoration(
                                  labelText: 'Thông tin liên hệ (SĐT, Email BTC)',
                                  hintText: 'Ví dụ: SĐT 0901234567, email btc@gmail.com',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: locationController,
                                      decoration: InputDecoration(
                                        labelText: 'Địa điểm / Phòng học',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: trainingPointController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Điểm rèn luyện',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: descriptionController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  labelText: 'Mô tả chi tiết',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: registrationUrlController,
                                decoration: InputDecoration(
                                  labelText: 'Link bài viết gốc / Form đăng ký',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: imageUrlController,
                                      decoration: InputDecoration(
                                        labelText: 'URL Hình ảnh',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 120,
                                    height: 47,
                                    child: ElevatedButton.icon(
                                      onPressed: isUploading
                                          ? null
                                          : () async {
                                        setDialogState(
                                              () => isUploading = true,
                                        );
                                        try {
                                          final url = await ImageUploadHelper
                                              .pickAndUploadImage(
                                            folder: 'activity_images',
                                          );
                                          if (url != null) {
                                            imageUrlController.text = url;
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Lỗi tải ảnh: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        } finally {
                                          setDialogState(
                                                () => isUploading = false,
                                          );
                                        }
                                      },
                                      icon: isUploading
                                          ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                          : const Icon(
                                        Icons.upload_file_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Tải ảnh'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: Size.zero,
                                        maximumSize: const Size(120, 47),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              CheckboxListTile(
                                value: isOnline,
                                onChanged: (val) {
                                  setDialogState(
                                        () => isOnline = val ?? false,
                                  );
                                },
                                title: const Text(
                                  'Sự kiện diễn ra Trực tuyến (Online)',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              if (isOnline) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: onlineUrlController,
                                  decoration: InputDecoration(
                                    labelText: 'Đường dẫn tham gia Online (Google Meet, Zoom...)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              CheckboxListTile(
                                value: requiresRegistration,
                                onChanged: (val) {
                                  setDialogState(
                                        () => requiresRegistration = val ?? false,
                                  );
                                },
                                title: const Text(
                                  'Yêu cầu sinh viên đăng ký trước khi điểm danh',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 14,
                                  ),
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(dialogCtx),
                              child: const Text(
                                'Hủy',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 170,
                              height: 47,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                  setDialogState(() => isSaving = true);
                                  try {
                                    await ActivityService.updateActivity(
                                      activityId: activityId,
                                      title: titleController.text.trim(),
                                      description:
                                      descriptionController.text.trim(),
                                      location:
                                      locationController.text.trim(),
                                      organizerName:
                                      organizerController.text.trim(),
                                        trainingPoint: int.tryParse(
                                        trainingPointController.text
                                            .trim(),
                                      ) ??
                                          0,
                                       startTime: startTime,
                                       endTime: endTime,
                                      requiresRegistration:
                                      requiresRegistration,
                                      imageUrl:
                                      imageUrlController.text.trim(),
                                      contact: contactController.text.trim(),
                                      isOnline: isOnline,
                                      onlineUrl:
                                      onlineUrlController.text.trim(),
                                      registrationUrl:
                                      registrationUrlController.text
                                          .trim(),
                                    );
                                    if (mounted) {
                                      Navigator.pop(dialogCtx);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Đã cập nhật hoạt động thành công!',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSaving = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('Lỗi cập nhật: $e'),
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size.zero,
                                  maximumSize: const Size(170, 47),
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text('Lưu thay đổi'),
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
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    organizerController.dispose();
    trainingPointController.dispose();
    imageUrlController.dispose();
    onlineUrlController.dispose();
    registrationUrlController.dispose();
  }

  Future<void> _showRegisteredList(
      BuildContext context,
      String title,
      List<String> ids,
      ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Danh sách đăng ký',
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people_outline_rounded, size: 18, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Tổng cộng: ${ids.length} sinh viên',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 400),
                child: ids.isEmpty
                    ? const Center(child: Text('Danh sách trống'))
                    : ListView.builder(
                  shrinkWrap: true,
                  itemCount: ids.length,
                  itemBuilder: (context, index) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFF1F4F9)),
                      ),
                    ),
                    child: Text(
                      '${index + 1}. ${ids[index]}',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ActivityService.getMyActivities(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Firestore Error: ${snapshot.error}');

          return Center(
            child: Container(
              width: 700,
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Firestore cần tạo composite index.',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    snapshot.error.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        final keyword = _activitySearchText.trim().toLowerCase();

        final filteredDocs = keyword.isEmpty
            ? docs
            : docs.where((doc) {
          final data = doc.data();
          final title = (data['title'] ?? '').toString().toLowerCase();
          final location = (data['location'] ?? '').toString().toLowerCase();
          final organizer =
          (data['organizerName'] ?? '').toString().toLowerCase();

          return title.contains(keyword) ||
              location.contains(keyword) ||
              organizer.contains(keyword);
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Bạn chưa tạo hoạt động nào.',
              style: TextStyle(fontFamily: 'Nunito', color: Colors.grey),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
              child: TextField(
                controller: _activitySearchController,
                onChanged: (value) {
                  _activitySearchDebounce?.cancel();

                  _activitySearchDebounce = Timer(
                    const Duration(milliseconds: 450),
                        () {
                      if (!mounted) return;
                      setState(() {
                        _activitySearchText = value;
                      });
                    },
                  );
                },
                decoration: InputDecoration(
                  hintText:
                  'Tìm theo tên hoạt động, địa điểm hoặc đơn vị tổ chức...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _activitySearchController.text.isEmpty
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _activitySearchDebounce?.cancel();
                      _activitySearchController.clear();
                      setState(() {
                        _activitySearchText = '';
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (filteredDocs.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Không tìm thấy hoạt động phù hợp.',
                    style: TextStyle(fontFamily: 'Nunito', color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(32),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data();

                    return ActivityCard(
                      activityId: doc.id,
                      data: data,
                      onOpen: () {
                        widget.onOpenAttendance(doc.id, data);
                      },
                      onClose: () async {
                        await ActivityService.closeActivity(doc.id);
                      },
                      onReopen: () async {
                        await ActivityService.reopenActivity(doc.id);
                      },
                      onEdit: () => _showEditActivityDialog(context, doc.id, data),
                      onDelete: () => _showDeleteActivityConfirmation(
                        context,
                        doc.id,
                        data['title'] ?? 'Hoạt động',
                      ),
                      onViewRegisteredList: data['requiresRegistration'] == true
                          ? () => _showRegisteredList(
                        context,
                        data['title'] ?? 'Hoạt động',
                        (data['registeredStudentIds'] as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ??
                            [],
                      )
                          : null,
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}