import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'create_material_page.dart';
import 'post_action_row.dart';
import 'post_detail_page.dart';
import 'package:my_uni/utils/base64_image_cache.dart';
import 'widgets/home_skeleton.dart';

class MaterialTab extends StatefulWidget {
  final Function(String, Map<String, dynamic>) onSave;
  const MaterialTab({super.key, required this.onSave});

  @override
  State<MaterialTab> createState() => _MaterialTabState();
}

class _MaterialTabState extends State<MaterialTab> {
  List<String>? _cachedMaterialIds;
  final Map<String, QueryDocumentSnapshot> _cachedMaterialDocsMap = {};

  Future<void> _handleOpenFile(
      BuildContext context,
      String base64Data,
      String fileName,
      ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Đang chuẩn bị tài liệu..."),
          duration: Duration(seconds: 1),
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(base64Decode(base64Data));
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Không có ứng dụng để mở loại file này: ${result.message}",
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $e")),
        );
      }
    }
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required bool isDarkMode,
    Color? iconColor,
  }) {
    final Color textColor =
    isDarkMode ? Colors.white70 : const Color(0xFF344054);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.06)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: iconColor ?? textColor,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileDisplay(BuildContext context, String? name) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.04)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFEAEFF5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF5893D8).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: Color(0xFF5893D8),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? 'Tài liệu đính kèm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nhấn để mở tài liệu',
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.file_download_outlined,
            color: isDarkMode ? Colors.white38 : const Color(0xFF777777),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context, String fileData) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Image.memory(
            Base64ImageCache.decode(fileData),
            width: double.infinity,
            height: 240,
            fit: BoxFit.cover,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.03),
                    Colors.black.withOpacity(0.26),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.open_in_full_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Mở ảnh',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Encode Sans Expanded',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(
      BuildContext context,
      Map<String, dynamic> data,
      String docId,
      bool isDarkMode,
      ) {
    String? fileData = data['fileData'];
    String? fileName = data['fileName'];
    bool isImage = data['isImage'] ?? false;

    final String courseName = data['courseName']?.toString() ?? 'Tài liệu';
    final String teacherName = data['teacherName']?.toString() ?? '';
    final String semester = data['semester']?.toString() ?? '';
    final String content = data['content']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
        ),
        boxShadow: isDarkMode
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PostDetailPage(docId: docId, initialPostData: data),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              courseName,
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                height: 1.35,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Giảng viên: ${teacherName.isEmpty ? 'Chưa cập nhật' : teacherName}",
                              style: const TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: Color(0xFF5893D8),
                              ),
                            ),
                            if (semester.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                semester,
                                style: TextStyle(
                                  fontFamily: 'Encode Sans Expanded',
                                  fontSize: 13,
                                  color: isDarkMode
                                      ? Colors.white60
                                      : const Color(0xFF667085),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        icon: Icons.tag_rounded,
                        label: isImage ? "Hình ảnh" : "Tài liệu",
                        isDarkMode: isDarkMode,
                        iconColor: const Color(0xFF306CFE),
                      ),
                      if (semester.isNotEmpty)
                        _buildInfoChip(
                          icon: Icons.calendar_month_rounded,
                          label: semester,
                          isDarkMode: isDarkMode,
                        ),
                    ],
                  ),
                ),

                if (content.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Text(
                      content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 15,
                        color: isDarkMode
                            ? Colors.white70
                            : const Color(0xFF4B5563),
                        height: 1.65,
                      ),
                    ),
                  ),

                if (fileData != null && fileData.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: GestureDetector(
                      onTap: () => _handleOpenFile(
                        context,
                        fileData,
                        fileName ?? 'document',
                      ),
                      child: isImage
                          ? _buildImagePreview(context, fileData)
                          : _buildFileDisplay(context, fileName),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.03)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: GestureDetector(
                      onTap: () {},
                      behavior: HitTestBehavior.opaque,
                      child: PostActionRow(
                        docId: docId,
                        data: data,
                        onSave: widget.onSave,
                        collectionPath: 'study_materials',
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
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('study_materials')
            .where('status', isEqualTo: 'approved')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const MaterialSkeletonListView();
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white10
                        : const Color(0xFFE9EEF3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 42,
                      color: isDarkMode ? Colors.white38 : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Chưa có tài liệu nào.",
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          List<QueryDocumentSnapshot> docs = snapshot.data!.docs.toList();

          if (_cachedMaterialIds == null) {
            _cachedMaterialIds = docs.map((d) => d.id).toList();
            _cachedMaterialDocsMap.clear();
            for (var d in docs) {
              _cachedMaterialDocsMap[d.id] = d;
            }
          } else {
            for (var d in docs) {
              if (_cachedMaterialDocsMap.containsKey(d.id)) {
                _cachedMaterialDocsMap[d.id] = d;
              }
            }
          }

          final List<QueryDocumentSnapshot> orderedMaterials = [];
          for (var id in _cachedMaterialIds!) {
            if (_cachedMaterialDocsMap.containsKey(id)) {
              orderedMaterials.add(_cachedMaterialDocsMap[id]!);
            }
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600.0),
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _cachedMaterialIds = null;
                    _cachedMaterialDocsMap.clear();
                  });
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  itemCount: orderedMaterials.length,
                  itemBuilder: (context, index) {
                    var doc = orderedMaterials[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String docId = doc.id;

                    return _buildMaterialCard(
                      context,
                      data,
                      docId,
                      isDarkMode,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "fab_material_tab",
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateMaterialPage()),
          );
          if (res == true || res != null) {
            setState(() {
              _cachedMaterialIds = null;
              _cachedMaterialDocsMap.clear();
            });
          }
        },
        backgroundColor: const Color(0xFF5893D8),
        elevation: 5,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.edit_outlined,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}