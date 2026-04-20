import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'file_helper_stub.dart'
if (dart.library.html) 'file_helper_web.dart';

class ModDashboard extends StatefulWidget {
  const ModDashboard({super.key});

  @override
  State<ModDashboard> createState() => _ModDashboardState();
}

class _ModDashboardState extends State<ModDashboard> {
  int _selectedCollIndex = 0;
  int _filterStatusIndex = 0;

  final List<String> _collections = ['forum_posts', 'course_reviews', 'study_materials'];
  final List<String> _collTitles = ['Diễn đàn sinh viên', 'Đánh giá môn học', 'Tài liệu học thuật'];
  final List<String> _filterLabels = ['Chờ duyệt', 'Bị báo cáo', 'Tất cả bài viết'];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          // --- SIDEBAR ---
          Container(
            width: 260,
            color: const Color(0xFF1A1F37),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 50),
                const SizedBox(height: 10),
                const Text(
                  "MYUNI MOD",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2, fontFamily: 'Nunito'),
                ),
                const SizedBox(height: 40),
                _buildMenuItem(0, Icons.forum_outlined, "Diễn đàn"),
                _buildMenuItem(1, Icons.rate_review_outlined, "Đánh giá"),
                _buildMenuItem(2, Icons.description_outlined, "Tài liệu"),
                const Spacer(),
                _buildUserAvatar(user),
              ],
            ),
          ),

          // --- MAIN CONTENT ---
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_collTitles[_selectedCollIndex],
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1F37), fontFamily: 'Nunito')),
                          const Spacer(),
                          const Icon(Icons.notifications_none, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: List.generate(_filterLabels.length, (index) => _buildFilterTab(index)),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(int index) {
    bool isSelected = _filterStatusIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _filterStatusIndex = index),
      child: Container(
        margin: const EdgeInsets.only(right: 32),
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: isSelected ? const Border(bottom: BorderSide(color: Colors.blueAccent, width: 3)) : null,
        ),
        child: Text(
          _filterLabels[index],
          style: TextStyle(fontFamily: 'Nunito', color: isSelected ? Colors.blueAccent : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title) {
    bool isSelected = _selectedCollIndex == index;
    return InkWell(
      onTap: () => setState(() {
        _selectedCollIndex = index;
        _filterStatusIndex = 0;
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey),
            const SizedBox(width: 15),
            Text(title, style: TextStyle(fontFamily: 'Nunito', color: isSelected ? Colors.white : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    Query query = FirebaseFirestore.instance.collection(_collections[_selectedCollIndex]);
    if (_filterStatusIndex == 0) query = query.where('status', isEqualTo: 'pending');
    else if (_filterStatusIndex == 1) query = query.where('isReported', isEqualTo: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('updatedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("🚨 [FIRESTORE ERROR]: ${snapshot.error}");
          return _buildErrorState(snapshot.error.toString());
        }
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(32),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            return _buildPostCard(docId, data);
          },
        );
      },
    );
  }

  Widget _buildPostCard(String docId, Map<String, dynamic> data) {
    double toxicity = (data['toxicityScore'] ?? 0).toDouble();
    bool isReported = data['isReported'] ?? false;
    int reportCount = data['reportCount'] ?? 0;
    String currentColl = _collections[_selectedCollIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(backgroundColor: Color(0xFFF0F2F5), child: Icon(Icons.person_outline, color: Colors.grey)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['authorName'] ?? "Ẩn danh", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Nunito')),
                    Text(data['timestamp']?.toDate().toString().substring(0, 16) ?? "", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
                const Spacer(),
                if (isReported)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text("Báo cáo: $reportCount", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Nunito')),
                  ),
                _buildToxicityBadge(toxicity),
              ],
            ),
            const SizedBox(height: 20),

            if (currentColl == 'course_reviews') ...[
              Text("Môn học: ${data['courseName']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 17, fontFamily: 'Nunito')),
              Text("Giảng viên: ${data['teacherName'] ?? 'N/A'}", style: const TextStyle(color: Colors.blueGrey, fontFamily: 'Nunito')),
              const SizedBox(height: 8),
              Row(children: List.generate(5, (i) => Icon(i < (data['rating'] ?? 0) ? Icons.star : Icons.star_border, color: Colors.amber, size: 24))),
              const SizedBox(height: 12),
            ],

            if (currentColl == 'study_materials') ...[
              Text("Tài liệu: ${data['courseName']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 17, fontFamily: 'Nunito')),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, color: Colors.blueGrey),
                    const SizedBox(width: 10),
                    Expanded(child: Text(data['fileName'] ?? "Chưa rõ tên file", style: const TextStyle(fontStyle: FontStyle.italic, fontFamily: 'Nunito'))),
                    ElevatedButton(
                      onPressed: () => _viewMaterial(data),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                      child: const Text("XEM FILE", style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (currentColl == 'forum_posts' && data['hashtags'] != null) ...[
              Wrap(spacing: 8, children: (data['hashtags'] as List).map((t) => Text("#$t", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Nunito'))).toList()),
              const SizedBox(height: 10),
            ],

            Text(data['content'] ?? "", style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF4A4A4A), fontFamily: 'Nunito')),

            if (data['imageUrl'] != null && data['imageUrl'] != '') ...[
              const SizedBox(height: 16),
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(data['imageUrl']), width: double.infinity, height: 300, fit: BoxFit.cover)),
            ],
            if (data['isImage'] == true && data['fileData'] != null) ...[
              const SizedBox(height: 16),
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(data['fileData']), width: double.infinity, height: 300, fit: BoxFit.cover)),
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 1. Hiển thị nhãn nếu bài viết đã bị xử lý (Ẩn)
                if (data['status'] == 'hidden')
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5))
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.visibility_off, color: Colors.redAccent, size: 16),
                        SizedBox(width: 8),
                        Text("ĐÃ GỠ KHỎI HỆ THỐNG",
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),

                // 2. Chỉ hiện các nút tương tác nếu bài viết CHƯA bị ẩn
                if (data['status'] != 'hidden') ...[
                  if (isReported)
                    _buildActionButton(Icons.refresh, "HỦY BÁO CÁO", Colors.blueGrey, () => _handleDismissReport(docId, data)),
                  const SizedBox(width: 12),
                  _buildActionButton(Icons.delete_sweep, "XÓA BÀI", Colors.redAccent, () => _handleDeletePost(docId, data)),
                  const SizedBox(width: 12),
                  if (data['status'] == 'pending')
                    _buildActionButton(Icons.check_circle, "DUYỆT BÀI", Colors.green, () => _handleApprovePost(docId, data)),
                ] else ...[
                  // NẾU BÀI ĐÃ ẨN: Cho phép Mod khôi phục lại nếu cần
                  _buildActionButton(Icons.restore, "KHÔI PHỤC", Colors.teal, () => _handleRestorePost(docId, data)),
                ],
              ],
            )
          ],
        ),
      ),
    );
  }


  void _viewMaterial(Map<String, dynamic> data) {
    if (data['fileData'] == null) return;

    final String base64str = data['fileData'];
    final String fileName = data['fileName'] ?? "tai_lieu.pdf";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(fileName, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data['isImage'] == true)
              Image.memory(base64Decode(base64str))
            else ...[
              const Icon(Icons.picture_as_pdf, size: 80, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text("Đây là tài liệu định dạng PDF/File.", textAlign: TextAlign.center),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),

          // NÚT TẢI FILE VỀ (Dành cho Web)
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text("TẢI XUỐNG"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              // Gọi class helper, Flutter sẽ tự biết lấy file nào tùy nền tảng
              FileHelper.downloadFile(base64str, fileName);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprovePost(String docId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection(_collections[_selectedCollIndex]).doc(docId).update({'status': 'approved', 'updatedAt': FieldValue.serverTimestamp()});
    _sendNotification(userId: data['authorId'], title: "Bài viết đã được duyệt", content: "Bài viết của bạn đã được phê duyệt thành công.", type: 'comment', postId: docId);
  }

  Future<void> _handleDeletePost(String docId, Map<String, dynamic> data) async {
    String reason = "Vi phạm tiêu chuẩn cộng đồng.";
    bool isReported = data['isReported'] ?? false;

    if (!isReported) {
      final TextEditingController reasonController = TextEditingController();
      bool? confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Lý do xóa bài", style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(controller: reasonController, decoration: const InputDecoration(hintText: "Nhập lý do cụ thể gửi user...")),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xác nhận", style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm != true) return;
      reason = reasonController.text.isEmpty ? "Nội dung không phù hợp với quy định của MyUni." : reasonController.text;
    }

    await FirebaseFirestore.instance.collection(_collections[_selectedCollIndex]).doc(docId).update({'status': 'hidden', 'isReported': false, 'updatedAt': FieldValue.serverTimestamp()});
    _sendNotification(userId: data['authorId'], title: "Bài viết bị gỡ bỏ", content: "Lý do: $reason", type: 'warning', postId: docId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã gỡ bài viết và gửi thông báo.")));
  }

  Future<void> _handleRestorePost(String docId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection(_collections[_selectedCollIndex])
        .doc(docId)
        .update({
      'status': 'approved', // Chuyển về trạng thái đã duyệt
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _sendNotification(
      userId: data['authorId'],
      title: "Bài viết đã được khôi phục",
      content: "Sau khi xem xét lại, Mod đã khôi phục bài viết của bạn.",
      type: 'comment',
      postId: docId,
    );

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã khôi phục bài viết")));
  }

  Future<void> _handleDismissReport(String docId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection(_collections[_selectedCollIndex]).doc(docId).update({'isReported': false, 'reportCount': 0});
  }

  Future<void> _sendNotification({required String userId, required String title, required String content, required String type, required String postId}) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId, 'title': title, 'content': content, 'type': type, 'timestamp': FieldValue.serverTimestamp(), 'isRead': false, 'relatedPostId': postId, 'collectionPath': _collections[_selectedCollIndex],
    });
  }

  // --- UI HELPERS ---
  Widget _buildToxicityBadge(double toxicity) {
    Color toxicColor = toxicity > 0.5 ? Colors.redAccent : (toxicity > 0.2 ? Colors.orangeAccent : Colors.greenAccent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: toxicColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text("Toxicity: ${toxicity.toStringAsFixed(2)}", style: TextStyle(color: toxicColor, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Nunito')),
    );
  }

  Widget _buildUserAvatar(User? user) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.person, color: Colors.white)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user?.displayName ?? "Moderator", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Nunito')),
            Text(user?.email ?? "", style: const TextStyle(color: Colors.grey, fontSize: 10), overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Nunito')),
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    );
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.done_all_rounded, size: 80, color: Colors.green[100]), const SizedBox(height: 20), const Text("Không có bài viết cần xử lý!", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500, fontFamily: 'Nunito'))]));

  Widget _buildErrorState(String error) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.report_gmailerrorred_outlined, color: Colors.redAccent, size: 60), const SizedBox(height: 16), const Text("THIẾU CHỈ MỤC (INDEX)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 18)), const SizedBox(height: 20), Text(error, style: const TextStyle(fontSize: 11, color: Colors.black54), textAlign: TextAlign.center)])));
}