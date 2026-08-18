import 'package:flutter/material.dart';

import '../../features/home/faculty_helper.dart';
import '../services/image_upload_helper.dart';
import '../services/news_service.dart';

class CreateNewsPage extends StatefulWidget {
  const CreateNewsPage({super.key, required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<CreateNewsPage> createState() => _CreateNewsPageState();
}

class _CreateNewsPageState extends State<CreateNewsPage> {
  static const Color _primaryOrange = Color(0xFFFFA726);
  static const Color _pageBackground = Color(0xFFF6F8FB);
  static const Color _borderColor = Color(0xFFE7ECF2);
  static const Color _fieldColor = Color(0xFFF8FAFC);
  static const Color _titleColor = Color(0xFF1A1F37);
  static const Color _secondaryTextColor = Color(0xFF667085);

  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _departmentController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _linkController = TextEditingController();

  bool _isFacultyNews = true;
  String _selectedFacultyId = 'fit';
  bool _isUploadingImage = false;
  bool _isSubmitting = false;
  bool _imageWasUploaded = false;

  @override
  void initState() {
    super.initState();
    _syncDepartmentWithScope();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _departmentController.dispose();
    _imageUrlController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _syncDepartmentWithScope() {
    if (_isFacultyNews) {
      final faculty =
          FacultyHelper.findById(_selectedFacultyId) ??
          FacultyHelper.activeFaculties.first;
      _selectedFacultyId = faculty.id;
      _departmentController.text = faculty.name;
    } else {
      _departmentController.text = 'Phòng Công tác Sinh viên';
    }
  }

  Future<void> _handleUploadImage() async {
    if (_isUploadingImage || _isSubmitting) return;

    try {
      final url = await ImageUploadHelper.pickAndUploadImage(
        folder: 'news_images',
        onUploadingStateChanged: (uploading) {
          if (!mounted) return;
          setState(() => _isUploadingImage = uploading);
        },
      );

      if (url == null || !mounted) return;

      setState(() {
        _imageWasUploaded = true;
        _imageUrlController.text = url;
      });

      _showMessage('Tải hình ảnh lên thành công!');
    } catch (e) {
      _showMessage('Tải ảnh thất bại: $e', isError: true);
    } finally {
      if (mounted && _isUploadingImage) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _handlePublishNews() async {
    if (_isSubmitting || _isUploadingImage) return;

    final title = _titleController.text.trim();
    final summary = _summaryController.text.trim();
    final content = _contentController.text.trim();
    final department = _departmentController.text.trim();
    final imageUrl = _imageUrlController.text.trim();
    final link = _linkController.text.trim();

    if (title.isEmpty) {
      _showMessage('Vui lòng nhập tiêu đề bài viết.', isError: true);
      return;
    }

    if (department.isEmpty) {
      _showMessage(
        'Vui lòng nhập đơn vị hoặc phòng ban đăng tin.',
        isError: true,
      );
      return;
    }

    if (summary.isEmpty && content.isEmpty) {
      _showMessage(
        'Vui lòng nhập tóm tắt hoặc nội dung bài viết.',
        isError: true,
      );
      return;
    }

    final selectedFaculty =
        FacultyHelper.findById(_selectedFacultyId) ??
        FacultyHelper.activeFaculties.first;

    setState(() => _isSubmitting = true);

    try {
      await NewsService.createNews(
        isFacultyNews: _isFacultyNews,
        facultyId: _isFacultyNews ? selectedFaculty.id : null,
        facultyCode: _isFacultyNews ? selectedFaculty.code : null,
        facultyName: _isFacultyNews ? selectedFaculty.name : null,
        title: title,
        summary: summary.isNotEmpty ? summary : content,
        content: content.isNotEmpty ? content : summary,
        department: department,
        hashtags: const [],
        imageUrl: imageUrl,
        imageSource: imageUrl.isEmpty
            ? 'none'
            : (_imageWasUploaded ? 'uploaded' : 'external_url'),
        link: link,
      );

      if (!mounted) return;

      _showMessage('Đã đăng bài viết tin tức thành công!');
      widget.onCreated();
    } catch (e) {
      _showMessage('Lỗi khi đăng tin tức: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _selectNewsScope(bool isFacultyNews) {
    setState(() {
      _isFacultyNews = isFacultyNews;
      _syncDepartmentWithScope();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _pageBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 700 ? 16.0 : 32.0;

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
                constraints: const BoxConstraints(maxWidth: 820),
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
        border: Border.all(color: _borderColor),
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
            'Đăng tin tức mới',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bài viết sẽ hiển thị trong mục tin chính thức của ứng dụng sinh viên.',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              height: 1.45,
              color: _secondaryTextColor,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),
          _buildSectionTitle('Phạm vi tin tức'),
          const SizedBox(height: 10),
          _buildScopeSelector(),
          if (_isFacultyNews) ...[
            const SizedBox(height: 22),
            _buildSectionTitle('Khoa phát hành'),
            const SizedBox(height: 8),
            _buildFacultyDropdown(),
          ],
          const SizedBox(height: 24),
          _buildTextField(
            controller: _titleController,
            label: 'Tiêu đề tin tức',
            hintText: 'Nhập tiêu đề bài viết',
            requiredField: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _departmentController,
            label: 'Đơn vị / Phòng ban đăng tin',
            hintText: 'Ví dụ: Phòng Đào tạo',
            requiredField: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _summaryController,
            label: 'Tóm tắt ngắn',
            hintText: 'Nội dung ngắn hiển thị trên danh sách tin',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _contentController,
            label: 'Nội dung chi tiết',
            hintText: 'Nhập đầy đủ nội dung bài viết',
            maxLines: 7,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Hình ảnh minh họa'),
          const SizedBox(height: 8),
          _buildImageInput(),
          _buildImagePreview(),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _linkController,
            label: 'Liên kết tham khảo',
            hintText: 'https://...',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_isSubmitting || _isUploadingImage)
                    ? null
                    : _handlePublishNews,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _isSubmitting ? 'Đang đăng bài...' : 'Đăng bài tin tức',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _primaryOrange.withOpacity(0.55),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
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

  Widget _buildScopeSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumn = constraints.maxWidth < 620;

        final facultyOption = _buildScopeOption(
          selected: _isFacultyNews,
          icon: Icons.account_balance_rounded,
          title: 'Tin của Khoa',
          description: 'Hiển thị tin tức riêng từng khoa',
          onTap: () => _selectNewsScope(true),
        );

        final schoolOption = _buildScopeOption(
          selected: !_isFacultyNews,
          icon: Icons.school_rounded,
          title: 'Tin Toàn trường',
          description: 'Hiển thị tin tức cho sinh viên toàn trường',
          onTap: () => _selectNewsScope(false),
        );

        if (useColumn) {
          return Column(
            children: [facultyOption, const SizedBox(height: 10), schoolOption],
          );
        }

        return Row(
          children: [
            Expanded(child: facultyOption),
            const SizedBox(width: 12),
            Expanded(child: schoolOption),
          ],
        );
      },
    );
  }

  Widget _buildScopeOption({
    required bool selected,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFFFF7ED) : _fieldColor,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? _primaryOrange : _borderColor,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? _primaryOrange.withOpacity(0.14)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: selected ? _primaryOrange : _secondaryTextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: selected ? _titleColor : _secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? _primaryOrange : Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacultyDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedFacultyId,
      isExpanded: true,
      decoration: _inputDecoration(
        hintText: 'Chọn khoa',
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
      onChanged: _isSubmitting
          ? null
          : (value) {
              if (value == null) return;
              setState(() {
                _selectedFacultyId = value;
                _syncDepartmentWithScope();
              });
            },
    );
  }

  Widget _buildImageInput() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final uploadButton = SizedBox(
          width: 190,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: (_isUploadingImage || _isSubmitting)
                ? null
                : _handleUploadImage,
            icon: _isUploadingImage
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_file_rounded, size: 20),
            label: Text(
              _isUploadingImage ? 'Đang tải...' : 'Tải ảnh từ máy',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF93C5FD),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        );

        final urlField = TextField(
          controller: _imageUrlController,
          keyboardType: TextInputType.url,
          onChanged: (_) {
            if (_imageWasUploaded) {
              setState(() => _imageWasUploaded = false);
            }
          },
          decoration: _inputDecoration(
            hintText: 'Dán URL hình ảnh hoặc tải ảnh từ máy',
            prefixIcon: Icons.image_outlined,
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
                child: SizedBox(width: 190, child: uploadButton),
              ),
            ],
          );
        }

        return Row(
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
        if (url.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 14),
          height: 210,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _fieldColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: _titleColor,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    int maxLines = 1,
    bool requiredField = false,
    String? helperText,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (requiredField)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.redAccent),
                ),
            ],
          ),
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textInputAction: maxLines == 1
              ? TextInputAction.next
              : TextInputAction.newline,
          decoration: _inputDecoration(
            hintText: hintText,
            helperText: helperText,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? helperText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      helperText: helperText,
      hintStyle: const TextStyle(
        fontFamily: 'Nunito',
        color: Color(0xFF98A2B3),
      ),
      helperStyle: const TextStyle(fontFamily: 'Nunito', color: Colors.grey),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, size: 20, color: _secondaryTextColor),
      filled: true,
      fillColor: _fieldColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _primaryOrange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
    );
  }
}
