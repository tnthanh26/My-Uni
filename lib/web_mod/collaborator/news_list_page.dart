import 'package:flutter/material.dart';

import '../services/image_upload_helper.dart';
import '../services/news_service.dart';

class NewsListPage extends StatefulWidget {
  const NewsListPage({
    super.key,
    required this.onNavigateToCreate,
  });

  final VoidCallback onNavigateToCreate;

  @override
  State<NewsListPage> createState() => _NewsListPageState();
}

class _NewsListPageState extends State<NewsListPage> {
  static const Color _pageBackground = Color(0xFFF6F8FB);
  static const Color _borderColor = Color(0xFFE7ECF2);
  static const Color _titleColor = Color(0xFF1A1F37);
  static const Color _secondaryTextColor = Color(0xFF667085);
  static const Color _primaryOrange = Color(0xFFFFA726);

  String _safeText(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Future<void> _confirmDeleteNews(
      BuildContext context,
      String collectionPath,
      String docId,
      String title,
      ) async {
    if (docId.trim().isEmpty) {
      _showMessage('Không tìm thấy mã bài viết để xóa.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: const Row(
            children: [
              Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text(
                'Xóa tin tức',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: Text.rich(
            TextSpan(
              text: 'Bạn có chắc muốn xóa bài viết ',
              children: [
                TextSpan(
                  text: '"$title"',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(
                  text: '?\n\nBài viết sẽ bị xóa vĩnh viễn khỏi ứng dụng.',
                ),
              ],
            ),
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              height: 1.5,
              color: _secondaryTextColor,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Hủy',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  color: Colors.grey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Xác nhận xóa'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await NewsService.deleteNews(
        collectionPath: collectionPath,
        docId: docId,
      );
      _showMessage('Đã xóa bài viết.');
    } catch (e) {
      _showMessage('Xóa tin tức thất bại: $e', isError: true);
    }
  }

  Future<void> _showEditNewsDialog(
      BuildContext context,
      Map<String, dynamic> item,
      ) async {
    final collectionPath = _safeText(item['collectionPath'], 'official_news');
    final docId = _safeText(item['docId']);
    final title = _safeText(item['title']);
    final department = _safeText(item['department']);
    final summary = _safeText(item['summary']);
    final content = _safeText(item['content']);
    final imageUrl = _safeText(item['imageUrl']);
    final link = _safeText(item['link']);

    if (docId.isEmpty) {
      _showMessage(
        'Không tìm thấy mã bài viết để chỉnh sửa.',
        isError: true,
      );
      return;
    }

    final titleController = TextEditingController(text: title);
    final departmentController = TextEditingController(text: department);
    final summaryController = TextEditingController(text: summary);
    final contentController = TextEditingController(text: content);
    final imageUrlController = TextEditingController(text: imageUrl);
    final linkController = TextEditingController(text: link);

    bool isUploading = false;
    Map<String, String>? updateData;

    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final screenSize = MediaQuery.sizeOf(dialogContext);
              final dialogWidth =
              screenSize.width < 700 ? screenSize.width - 32 : 640.0;
              final dialogHeight =
              (screenSize.height - 48).clamp(300.0, 760.0);

              return Dialog(
                insetPadding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: dialogWidth,
                  height: dialogHeight,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_note_rounded,
                              color: Colors.blueAccent,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Chỉnh sửa bài viết',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isUploading
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: titleController,
                                decoration: _buildEditInputDecoration(
                                  'Tiêu đề bài viết',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: departmentController,
                                decoration: _buildEditInputDecoration(
                                  'Đơn vị / Phòng ban phát hành',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: summaryController,
                                minLines: 2,
                                maxLines: 3,
                                decoration: _buildEditInputDecoration(
                                  'Tóm tắt bài viết',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: contentController,
                                minLines: 5,
                                maxLines: 10,
                                decoration: _buildEditInputDecoration(
                                  'Nội dung chi tiết',
                                ),
                              ),
                              const SizedBox(height: 14),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact =
                                      constraints.maxWidth < 520;

                                  final imageField = TextField(
                                    controller: imageUrlController,
                                    decoration: _buildEditInputDecoration(
                                      'URL hình ảnh',
                                    ),
                                  );

                                  final uploadButton =
                                  ElevatedButton.icon(
                                    onPressed: isUploading
                                        ? null
                                        : () async {
                                      setDialogState(
                                            () => isUploading = true,
                                      );

                                      try {
                                        final url =
                                        await ImageUploadHelper
                                            .pickAndUploadImage(
                                          folder: 'news_images',
                                        );

                                        if (!dialogContext.mounted) {
                                          return;
                                        }

                                        if (url != null &&
                                            url.trim().isNotEmpty) {
                                          imageUrlController.text =
                                              url.trim();
                                        }
                                      } catch (e) {
                                        _showMessage(
                                          'Lỗi tải ảnh: $e',
                                          isError: true,
                                        );
                                      } finally {
                                        if (dialogContext.mounted) {
                                          setDialogState(
                                                () => isUploading = false,
                                          );
                                        }
                                      }
                                    },
                                    icon: isUploading
                                        ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child:
                                      CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                        : const Icon(
                                      Icons.upload_file_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isUploading
                                          ? 'Đang tải...'
                                          : 'Tải ảnh',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(120, 52),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                    ),
                                  );

                                  if (compact) {
                                    return Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                      children: [
                                        imageField,
                                        const SizedBox(height: 10),
                                        uploadButton,
                                      ],
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: imageField),
                                      const SizedBox(width: 10),
                                      uploadButton,
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: linkController,
                                decoration: _buildEditInputDecoration(
                                  'Link liên kết bài viết (nếu có)',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isUploading
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              child: const Text(
                                'Hủy',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: isUploading
                                  ? null
                                  : () {
                                final updatedTitle =
                                titleController.text.trim();

                                if (updatedTitle.isEmpty) {
                                  _showMessage(
                                    'Tiêu đề bài viết không được để trống.',
                                    isError: true,
                                  );
                                  return;
                                }

                                updateData = {
                                  'title': updatedTitle,
                                  'summary':
                                  summaryController.text.trim(),
                                  'content':
                                  contentController.text.trim(),
                                  'department':
                                  departmentController.text.trim(),
                                  'imageUrl':
                                  imageUrlController.text.trim(),
                                  'link': linkController.text.trim(),
                                };

                                Navigator.of(dialogContext).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(140, 46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Lưu thay đổi',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
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
            },
          );
        },
      );

      if (updateData == null) return;

      await WidgetsBinding.instance.endOfFrame;

      try {
        await NewsService.updateNews(
          collectionPath: collectionPath,
          docId: docId,
          title: updateData!['title']!,
          summary: updateData!['summary']!,
          content: updateData!['content']!,
          department: updateData!['department']!,
          imageUrl: updateData!['imageUrl']!,
          link: updateData!['link']!,
        );

        _showMessage('Đã cập nhật bài viết thành công!');
      } catch (e) {
        _showMessage(
          'Lỗi cập nhật: $e',
          isError: true,
        );
      }
    } finally {
      titleController.dispose();
      departmentController.dispose();
      summaryController.dispose();
      contentController.dispose();
      imageUrlController.dispose();
      linkController.dispose();
    }
  }

  InputDecoration _buildEditInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.blueAccent,
          width: 1.5,
        ),
      ),
    );
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
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

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _pageBackground,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: NewsService.getMyNews(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final newsList = snapshot.data ?? [];

          if (newsList.isEmpty) {
            return _buildEmptyState();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding =
              constraints.maxWidth < 700 ? 16.0 : 32.0;

              return Scrollbar(
                child: ListView.separated(
                  primary: false,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    28,
                    horizontalPadding,
                    40,
                  ),
                  itemCount: newsList.length + 1,
                  separatorBuilder: (_, index) {
                    if (index == 0) return const SizedBox(height: 18);
                    return const SizedBox(height: 14);
                  },
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1050),
                          child: _buildHeader(newsList.length),
                        ),
                      );
                    }

                    final item = newsList[index - 1];

                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1050),
                        child: _buildNewsCard(item),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(int itemCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tin tức của tôi',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$itemCount bài viết do bạn đăng',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: _secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: widget.onNavigateToCreate,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Đăng tin mới',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> item) {
    final title = _safeText(item['title'], 'Bài viết không tên');
    final summary = _safeText(item['summary']);
    final department = _safeText(item['department'], 'Đơn vị');
    final dateText = _safeText(
      item['publishedDateText'] ?? item['date'],
    );
    final imageUrl = _safeText(item['imageUrl']);
    final collectionPath = _safeText(
      item['collectionPath'],
      'official_news',
    );
    final docId = _safeText(item['docId']);
    final isFaculty = collectionPath == 'faculty_official_news';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;

          if (compact) {
            return _buildCompactCard(
              title: title,
              summary: summary,
              department: department,
              dateText: dateText,
              imageUrl: imageUrl,
              isFaculty: isFaculty,
              onEdit: () => _showEditNewsDialog(this.context, item),
              onDelete: () => _confirmDeleteNews(
                context,
                collectionPath,
                docId,
                title,
              ),
            );
          }

          return _buildDesktopCard(
            title: title,
            summary: summary,
            department: department,
            dateText: dateText,
            imageUrl: imageUrl,
            isFaculty: isFaculty,
            onEdit: () => _showEditNewsDialog(this.context, item),
            onDelete: () => _confirmDeleteNews(
              context,
              collectionPath,
              docId,
              title,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopCard({
    required String title,
    required String summary,
    required String department,
    required String dateText,
    required String imageUrl,
    required bool isFaculty,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrl.isNotEmpty) ...[
          _buildImage(imageUrl, width: 132, height: 96),
          const SizedBox(width: 18),
        ],
        Expanded(
          child: _buildCardContent(
            title: title,
            summary: summary,
            department: department,
            dateText: dateText,
            isFaculty: isFaculty,
          ),
        ),
        const SizedBox(width: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEditButton(onEdit),
            const SizedBox(width: 8),
            _buildDeleteButton(onDelete),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactCard({
    required String title,
    required String summary,
    required String department,
    required String dateText,
    required String imageUrl,
    required bool isFaculty,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrl.isNotEmpty) ...[
          _buildImage(imageUrl, width: double.infinity, height: 180),
          const SizedBox(height: 14),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildCardContent(
                title: title,
                summary: summary,
                department: department,
                dateText: dateText,
                isFaculty: isFaculty,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditButton(onEdit),
                const SizedBox(width: 8),
                _buildDeleteButton(onDelete),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardContent({
    required String title,
    required String summary,
    required String department,
    required String dateText,
    required bool isFaculty,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildTypeBadge(isFaculty),
            Text(
              department,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: _secondaryTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (dateText.isNotEmpty)
              Text(
                dateText,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 17,
            height: 1.35,
            fontWeight: FontWeight.w800,
            color: _titleColor,
          ),
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              height: 1.45,
              color: _secondaryTextColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTypeBadge(bool isFaculty) {
    final color =
    isFaculty ? const Color(0xFF2563EB) : const Color(0xFFD97706);
    final background =
    isFaculty ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isFaculty ? 'Tin Khoa' : 'Tin Toàn trường',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildImage(
      String imageUrl, {
        required double width,
        required double height,
      }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
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
  }

  Widget _buildEditButton(VoidCallback onPressed) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Chỉnh sửa bài viết',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: 40,
          height: 40,
        ),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFEFF6FF),
          foregroundColor: const Color(0xFF2563EB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.edit_outlined, size: 20),
      ),
    );
  }

  Widget _buildDeleteButton(VoidCallback onPressed) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Xóa bài viết',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: 40,
          height: 40,
        ),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFFEF2F2),
          foregroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 700 ? 16.0 : 32.0;

        return SingleChildScrollView(
          primary: false,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            32,
            horizontalPadding,
            40,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 44,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF7ED),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.newspaper_outlined,
                        size: 38,
                        color: _primaryOrange,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Bạn chưa đăng bài tin tức nào',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Các bài tin tức do bạn đăng sẽ xuất hiện tại đây.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        color: _secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: widget.onNavigateToCreate,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text(
                          'Đăng tin ngay',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Lỗi tải tin tức: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Nunito',
              color: Colors.redAccent,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}