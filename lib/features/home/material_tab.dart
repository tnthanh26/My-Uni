import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'create_material_page.dart';

class MaterialTab extends StatelessWidget {
  const MaterialTab({super.key});

  Future<void> _handleOpenFile(BuildContext context, String base64Data, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đang chuẩn bị tài liệu..."), duration: Duration(seconds: 1)),
      );

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      // Ghi byte
      await file.writeAsBytes(base64Decode(base64Data));
      debugPrint("Đã lưu file tạm tại: $filePath");

      // Mở file và lấy kết quả trả về
      final result = await OpenFilex.open(filePath);

      debugPrint("Kết quả mở file: ${result.message}");

      if (result.type != ResultType.done) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Không có ứng dụng để mở loại file này: ${result.message}")),
          );
        }
      }
    } catch (e) {
      debugPrint("Lỗi hệ thống: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('study_materials')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF6797E1)));

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Chưa có tài liệu nào."));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;

              String? fileData = data['fileData'];
              String? fileName = data['fileName'];
              bool isImage = data['isImage'] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4)
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['courseName'] ?? 'Tài liệu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(data['semester'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              Text("Giảng viên: ${data['teacherName'] ?? ''}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.more_horiz, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(data['content'] ?? '', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, height: 1.4)),
                    const SizedBox(height: 12),

                    // PHẦN HIỂN THỊ FILE/ẢNH CÓ THỂ BẤM
                    if (fileData != null && fileData.isNotEmpty)
                      GestureDetector(
                        onTap: () => _handleOpenFile(context, fileData, fileName ?? 'document'),
                        child: isImage
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(base64Decode(fileData), width: double.infinity, fit: BoxFit.cover),
                        )
                            : _buildFileDisplay(fileName, isDarkMode),
                      ),

                    const SizedBox(height: 8),
                    const Text("Xem thêm", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const Divider(),
                    _buildActionRow(),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateMaterialPage())),
        backgroundColor: const Color(0xFF6797E1),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        child: const Icon(Icons.edit_outlined, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildFileDisplay(String? name, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file, color: Color(0xFF6797E1), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name ?? 'Tài liệu đính kèm',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          const Icon(Icons.file_download_outlined, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return const Row(
      children: [
        Icon(Icons.favorite_border, color: Colors.grey, size: 20),
        SizedBox(width: 4), Text("96", style: TextStyle(color: Colors.grey)),
        SizedBox(width: 20),
        Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20),
        SizedBox(width: 4), Text("40", style: TextStyle(color: Colors.grey)),
        Spacer(),
        Icon(Icons.bookmark_outline, color: Colors.grey, size: 20),
      ],
    );
  }
}