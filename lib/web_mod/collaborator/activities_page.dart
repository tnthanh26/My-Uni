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