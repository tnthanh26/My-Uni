import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/activity_service.dart';
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
                    '? \n\nHoạt động sẽ bị ẩn khỏi hệ thống và không thể khôi phục từ phía bạn.',
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