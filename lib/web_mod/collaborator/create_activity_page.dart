import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/home/faculty_helper.dart';
import '../services/activity_service.dart';
import '../services/image_upload_helper.dart';

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
  static const Color _pageBackground = Color(0xFFF6F8FB);
  static const Color _cardBorder = Color(0xFFE7ECF2);
  static const Color _fieldBackground = Color(0xFFF8FAFC);
  static const Color _titleColor = Color(0xFF1A1F37);
  static const Color _secondaryText = Color(0xFF667085);
  static const Color _primaryOrange = Color(0xFFFFA726);
  static const Color _primaryBlue = Color(0xFF3B82F6);

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _organizerController = TextEditingController();
  final _contactController = TextEditingController();
  final _pointController = TextEditingController(text: '5');
  final _studentIdsController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _onlineUrlController = TextEditingController();
  final _registrationUrlController = TextEditingController();

  String _selectedFacultyId = 'fit';
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  DateTime? _registrationDeadline;

  bool _isOnline = false;
  bool _requiresRegistration = false;
  bool _isUploadingImage = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _organizerController.dispose();
    _contactController.dispose();
    _pointController.dispose();
    _studentIdsController.dispose();
    _imageUrlController.dispose();
    _onlineUrlController.dispose();
    _registrationUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleUploadImage() async {
    try {
      final url = await ImageUploadHelper.pickAndUploadImage(
        folder: 'event_images',
        onUploadingStateChanged: (uploading) {
          if (mounted) {
            setState(() => _isUploadingImage = uploading);
          }
        },
      );

      if (url != null && mounted) {
        _imageUrlController.text = url;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tải hình ảnh lên thành công!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tải ảnh thất bại: $e'),
          ),
        );
      }
    }
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
    final matches = RegExp(r'\b\d{7,11}\b').allMatches(content);
    final ids = matches.map((match) => match.group(0)!).toSet().toList();

    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không tìm thấy chuỗi số nào giống MSSV (7-11 chữ số) trong file.',
          ),
        ),
      );
      return;
    }

    setState(() {
      final currentText = _studentIdsController.text.trim();
      final currentIds = currentText
          .split(RegExp(r'[\n\r, ]+'))
          .where((id) => id.isNotEmpty)
          .toSet();

      final newIds = ids.where((id) => !currentIds.contains(id)).toList();

      if (newIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tất cả MSSV trong file đã có trong danh sách.',
            ),
          ),
        );
        return;
      }

      final separator = currentText.isEmpty ? '' : '\n';
      _studentIdsController.text =
      '$currentText$separator${newIds.join('\n')}';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã trích xuất thêm ${ids.length} MSSV từ file.',
        ),
      ),
    );
  }

  Future<void> _handleCreateActivity() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final organizer = _organizerController.text.trim();
    final contact = _contactController.text.trim();
    final pointText = _pointController.text.trim();

    if (title.isEmpty || location.isEmpty || organizer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập đủ tên sự kiện, địa điểm và đơn vị tổ chức.',
          ),
        ),
      );
      return;
    }

    if (pointText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập điểm rèn luyện.'),
        ),
      );
      return;
    }

    final point = int.tryParse(pointText);
    if (point == null || point < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Điểm rèn luyện phải là số nguyên không âm.',
          ),
        ),
      );
      return;
    }

    final registeredIds = _studentIdsController.text
        .split(RegExp(r'[\n\r,]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (_requiresRegistration && registeredIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập danh sách sinh viên đăng ký.',
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

    final selectedFac = FacultyHelper.findById(_selectedFacultyId) ??
        FacultyHelper.activeFaculties.first;

    setState(() => _isSubmitting = true);

    try {
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
        imageUrl: _imageUrlController.text.trim(),
        contact: contact.isNotEmpty ? contact : null,
        facultyId: selectedFac.id,
        facultyCode: selectedFac.code,
        facultyName: selectedFac.name,
        isOnline: _isOnline,
        onlineUrl: _onlineUrlController.text.trim(),
        registrationDeadline: _registrationDeadline,
        registrationUrl: _registrationUrlController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã tạo sự kiện thành công ',
          ),
        ),
      );

      widget.onCreated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tạo sự kiện: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _pageBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding =
          constraints.maxWidth < 700 ? 16.0 : 32.0;

          return SingleChildScrollView(
            primary: false,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              28,
              horizontalPadding,
              40,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: SizedBox(
                  width: double.infinity,
                  child: _buildFormCard(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tạo Hoạt động & Sự kiện mới',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),

          _sectionTitle('Thông tin sự kiện'),
          const SizedBox(height: 14),

          _buildFacultyDropdown(),
          const SizedBox(height: 16),

          _input(
            _titleController,
            'Tên hoạt động / sự kiện *',
          ),
          const SizedBox(height: 16),

          _input(
            _descriptionController,
            'Mô tả chi tiết',
            maxLines: 4,
          ),
          const SizedBox(height: 16),

          _input(
            _organizerController,
            'Đơn vị tổ chức *',
          ),
          const SizedBox(height: 16),

          _input(
            _contactController,
            'Thông tin người phụ trách / Liên hệ (email/SĐT)',
          ),
          const SizedBox(height: 16),

          _input(
            _locationController,
            'Địa điểm (tên phòng, địa chỉ) *',
          ),
          const SizedBox(height: 16),

          _buildOnlineSection(),
          const SizedBox(height: 16),

          _input(
            _pointController,
            'Điểm rèn luyện dự kiến *',
            isNumber: true,
          ),
          const SizedBox(height: 24),

          _sectionTitle('Thời gian diễn ra'),
          const SizedBox(height: 12),
          _buildDateTimeSection(),
          const SizedBox(height: 24),

          _sectionTitle('Hình ảnh / Thumbnail sự kiện'),
          const SizedBox(height: 10),
          _buildImageSection(),
          _buildImagePreview(),
          const SizedBox(height: 20),

          _input(
            _registrationUrlController,
            'Đường dẫn đến bài viết gốc',
          ),
          const SizedBox(height: 24),

          _buildRegistrationSection(),
          const SizedBox(height: 30),

          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 245,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : _handleCreateActivity,
                icon: _isSubmitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  _isSubmitting
                      ? 'Đang tạo...'
                      : 'Tạo Hoạt động & Sự kiện',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                  _primaryOrange.withOpacity(0.55),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn Khoa tổ chức *',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: _selectedFacultyId,
          isExpanded: true,
          decoration: _inputDecoration(
            hintText: 'Chọn khoa tổ chức',
            prefixIcon: Icons.apartment_rounded,
          ),
          items: FacultyHelper.activeFaculties.map((faculty) {
            return DropdownMenuItem<String>(
              value: faculty.id,
              child: Text(
                '${faculty.name} (${faculty.code})',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  color: _titleColor,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedFacultyId = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildOnlineSection() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _fieldBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Sự kiện diễn ra Online',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: _titleColor,
              ),
            ),
            value: _isOnline,
            onChanged: (value) {
              setState(() => _isOnline = value);
            },
            activeColor: _primaryBlue,
          ),
          if (_isOnline) ...[
            const Divider(height: 1),
            const SizedBox(height: 14),
            _input(
              _onlineUrlController,
              'Đường dẫn tham gia Online '
                  '(Zoom, Google Meet, MS Teams...)',
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildDateTimeSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumn = constraints.maxWidth < 650;

        final startBox = _dateBox(
          title: 'Thời gian bắt đầu *',
          value: _startTime,
          onTap: () async {
            final picked = await _pickDateTime(_startTime);
            if (picked != null) {
              setState(() => _startTime = picked);
            }
          },
        );

        final endBox = _dateBox(
          title: 'Thời gian kết thúc *',
          value: _endTime,
          onTap: () async {
            final picked = await _pickDateTime(_endTime);
            if (picked != null) {
              setState(() => _endTime = picked);
            }
          },
        );

        if (useColumn) {
          return Column(
            children: [
              startBox,
              const SizedBox(height: 12),
              endBox,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: startBox),
            const SizedBox(width: 14),
            Expanded(child: endBox),
          ],
        );
      },
    );
  }

  Widget _buildImageSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final urlField = _input(
          _imageUrlController,
          'Đường dẫn URL hình ảnh',
        );

        final uploadButton = SizedBox(
          width: 190,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isUploadingImage
                ? null
                : _handleUploadImage,
            icon: _isUploadingImage
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(
              Icons.upload_file_rounded,
              size: 20,
            ),
            label: Text(
              _isUploadingImage
                  ? 'Đang tải...'
                  : 'Tải ảnh từ máy',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
              _primaryBlue.withOpacity(0.55),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 17,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        );

        if (constraints.maxWidth < 650) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              urlField,
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 190,
                  child: uploadButton,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: urlField),
            const SizedBox(width: 12),
            uploadButton,
          ],
        );
      },
    );
  }

  Widget _buildImagePreview() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _imageUrlController,
      builder: (context, value, _) {
        final url = value.text.trim();

        if (url.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(top: 14),
          height: 210,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _fieldBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
          ),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Image preview error: $error');

              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 42,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Không thể hiển thị hình ảnh',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRegistrationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fieldBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Yêu cầu đăng ký trước khi điểm danh',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: _titleColor,
              ),
            ),
            subtitle: const Text(
              'Chỉ sinh viên trong danh sách mới được điểm danh tự động.',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: _secondaryText,
              ),
            ),
            value: _requiresRegistration,
            onChanged: (value) {
              setState(() => _requiresRegistration = value);
            },
            activeColor: _primaryBlue,
          ),
          if (_requiresRegistration) ...[
            const Divider(height: 30),
            LayoutBuilder(
              builder: (context, constraints) {
                final button = TextButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(
                    Icons.upload_file_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Chọn file (.txt, .csv)',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );

                if (constraints.maxWidth < 540) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Danh sách MSSV đăng ký',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          color: _titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      button,
                    ],
                  );
                }

                return Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Danh sách MSSV đăng ký',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          color: _titleColor,
                        ),
                      ),
                    ),
                    button,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _studentIdsController,
              maxLines: 5,
              decoration: _inputDecoration(
                hintText:
                'Nhập hoặc dán danh sách MSSV, mỗi mã một dòng...',
                fillColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _titleColor,
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _titleColor,
        ),
      ),
    );
  }

  Widget _input(
      TextEditingController controller,
      String label, {
        int maxLines = 1,
        bool isNumber = false,
        String? hintText,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(
            decimal: false,
            signed: false,
          )
              : TextInputType.text,
          inputFormatters: isNumber
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          decoration: _inputDecoration(
            hintText: hintText ?? label,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    IconData? prefixIcon,
    Color fillColor = _fieldBackground,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontFamily: 'Nunito',
        color: Color(0xFF98A2B3),
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
        prefixIcon,
        size: 20,
        color: _secondaryText,
      ),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 15,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: _primaryBlue,
          width: 1.5,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
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

    return Material(
      color: _fieldBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: _primaryBlue,
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
                        color: _titleColor,
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

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      locale: const Locale('vi', 'VN'),
    );

    if (date == null) return null;

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
}