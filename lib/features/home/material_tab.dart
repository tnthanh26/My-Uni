import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'create_material_page.dart';
import 'post_action_row.dart';
import 'post_detail_page.dart';

class MaterialTab extends StatelessWidget {
  final Function(String, Map<String, dynamic>) onSave;
  const MaterialTab({super.key, required this.onSave});

  // --- Giữ nguyên logic mở file ---
  Future<void> _handleOpenFile(BuildContext context, String base64Data, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đang chuẩn bị tài liệu..."), duration: Duration(seconds: 1)),
      );
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(base64Decode(base64Data));
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Không có ứng dụng để mở loại file này: ${result.message}")),
        );
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('study_materials')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF5893D8)));
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "Chưa có tài liệu nào.",
                style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String docId = doc.id;
              String? fileData = data['fileData'];
              String? fileName = data['fileName'];
              bool isImage = data['isImage'] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.transparent : Colors.white,
                  border: Border(
                      bottom: BorderSide(
                          color: isDarkMode ? Colors.white10 : const Color(0xFFDFE6E9),
                          width: 2
                      )
                  ),
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailPage(docId: docId, initialPostData: data)));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HEADER ---
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['courseName'] ?? 'Tài liệu',
                                    style: TextStyle(
                                        fontFamily: 'Encode Sans Expanded',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: isDarkMode ? Colors.white : const Color(0xFF545454)
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Giảng viên: ${data['teacherName'] ?? ''}",
                                    style: TextStyle(
                                        fontFamily: 'Encode Sans Expanded',
                                        fontWeight: FontWeight.w300,
                                        fontSize: 14,
                                        color: isDarkMode ? Colors.white70 : const Color(0xFF545454)
                                    ),
                                  ),
                                  Text(
                                    data['semester'] ?? '',
                                    style: TextStyle(
                                        fontFamily: 'Encode Sans Expanded',
                                        fontWeight: FontWeight.w300,
                                        fontSize: 14,
                                        color: isDarkMode ? Colors.white60 : const Color(0xFF545454)
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.more_horiz, color: isDarkMode ? Colors.white38 : const Color(0xFF777777)),
                          ],
                        ),
                      ),

                      // --- CONTENT ---
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          data['content'] ?? '',
                          style: TextStyle(
                              fontFamily: 'Encode Sans Expanded',
                              fontSize: 15,
                              color: isDarkMode ? Colors.white : const Color(0xFF545454),
                              height: 1.33
                          ),
                        ),
                      ),

                      // --- FILE/IMAGE DISPLAY ---
                      if (fileData != null && fileData.isNotEmpty)
                        GestureDetector(
                          onTap: () => _handleOpenFile(context, fileData, fileName ?? 'document'),
                          child: isImage
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(base64Decode(fileData), width: double.infinity, height: 260, fit: BoxFit.cover),
                          )
                              : _buildFileDisplay(context, fileName),
                        ),

                      // --- XEM THÊM ---
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                            "Xem thêm",
                            style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 15,
                                color: isDarkMode ? Colors.white38 : const Color(0xFFA9A9A9)
                            )
                        ),
                      ),

                      // --- ACTION ROW ---
                      GestureDetector(
                        onTap: () {},
                        behavior: HitTestBehavior.opaque,
                        child: PostActionRow(
                          docId: docId,
                          data: data,
                          onSave: onSave,
                          collectionPath: 'study_materials',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "fab_material_tab",
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateMaterialPage())),
        backgroundColor: const Color(0xFF5893D8),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_outlined, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildFileDisplay(BuildContext context, String? name) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDarkMode ? Colors.white10 : const Color(0xFFDFE6E9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_rounded, color: Color(0xFF5893D8), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name ?? 'Tài liệu đính kèm',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : const Color(0xFF545454)
              ),
            ),
          ),
          Icon(Icons.file_download_outlined, color: isDarkMode ? Colors.white38 : const Color(0xFF777777)),
        ],
      ),
    );
  }
}