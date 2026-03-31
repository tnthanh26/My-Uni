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
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('study_materials')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF5893D8)));
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Chưa có tài liệu nào."));

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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFDFE6E9), width: 2)), // CSS: Vector 136
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailPage(docId: docId, initialPostData: data)));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HEADER (CSS: Frame 1359) ---
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tên môn (CSS: font-weight: 700, size: 16)
                                  Text(
                                    data['courseName'] ?? 'Tài liệu',
                                    style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF545454)),
                                  ),
                                  const SizedBox(height: 4),
                                  // Giảng viên (CSS: font-weight: 300, size: 14)
                                  Text(
                                    "Giảng viên: ${data['teacherName'] ?? ''}",
                                    style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w300, fontSize: 14, color: Color(0xFF545454)),
                                  ),
                                  // Học kỳ (CSS: font-weight: 300, size: 14)
                                  Text(
                                    data['semester'] ?? '',
                                    style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w300, fontSize: 14, color: Color(0xFF545454)),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.more_horiz, color: Color(0xFF777777)),
                          ],
                        ),
                      ),

                      // --- CONTENT (CSS: 15px, height 1.33) ---
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          data['content'] ?? '',
                          style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: Color(0xFF545454), height: 1.33),
                        ),
                      ),

                      // --- FILE/IMAGE DISPLAY (CSS: Frame 1354) ---
                      if (fileData != null && fileData.isNotEmpty)
                        GestureDetector(
                          onTap: () => _handleOpenFile(context, fileData, fileName ?? 'document'),
                          child: isImage
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(base64Decode(fileData), width: double.infinity, height: 260, fit: BoxFit.cover),
                          )
                              : _buildFileDisplay(fileName),
                        ),

                      // --- XEM THÊM ---
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text("Xem thêm", style: TextStyle(fontFamily: 'Encode Sans Expanded', fontSize: 15, color: Color(0xFFA9A9A9))),
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

  Widget _buildFileDisplay(String? name) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDFE6E9)),
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
              style: const TextStyle(fontFamily: 'Encode Sans Expanded', fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF545454)),
            ),
          ),
          const Icon(Icons.file_download_outlined, color: Color(0xFF777777)),
        ],
      ),
    );
  }
}