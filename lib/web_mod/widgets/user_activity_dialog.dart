import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserActivityDialog extends StatefulWidget {
  const UserActivityDialog({
    super.key,
    required this.displayName,
    required this.forumPosts,
    required this.reviews,
    required this.materials,
    required this.logs,
  });

  final String displayName;
  final List<QueryDocumentSnapshot> forumPosts;
  final List<QueryDocumentSnapshot> reviews;
  final List<QueryDocumentSnapshot> materials;
  final List<QueryDocumentSnapshot> logs;

  @override
  State<UserActivityDialog> createState() => _UserActivityDialogState();
}

class _UserActivityDialogState extends State<UserActivityDialog> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _ActivityTabData(
        label: "Diễn đàn",
        icon: Icons.forum_rounded,
        count: widget.forumPosts.length,
      ),
      _ActivityTabData(
        label: "Đánh giá",
        icon: Icons.rate_review_rounded,
        count: widget.reviews.length,
      ),
      _ActivityTabData(
        label: "Tài liệu",
        icon: Icons.description_rounded,
        count: widget.materials.length,
      ),
      _ActivityTabData(
        label: "Xử lý",
        icon: Icons.history_rounded,
        count: widget.logs.length,
      ),
    ];

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      title: _Header(displayName: widget.displayName),
      content: SizedBox(
        width: 720,
        height: 540,
        child: Column(
          children: [
            _TabBar(
              tabs: tabs,
              selectedIndex: _selectedTab,
              onChanged: (index) {
                setState(() => _selectedTab = index);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _ActivityList(
                    docs: widget.forumPosts,
                    emptyText: "Người dùng này chưa có bài diễn đàn.",
                  ),
                  _ActivityList(
                    docs: widget.reviews,
                    emptyText: "Người dùng này chưa có đánh giá.",
                  ),
                  _ActivityList(
                    docs: widget.materials,
                    emptyText: "Người dùng này chưa đăng tài liệu.",
                  ),
                  _LogList(docs: widget.logs),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Đóng"),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE0E7FF),
            child: Icon(Icons.person_search_rounded, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Hoạt động của $displayName",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          IconButton(
            tooltip: "Đóng",
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _ActivityTabData {
  const _ActivityTabData({
    required this.label,
    required this.icon,
    required this.count,
  });

  final String label;
  final IconData icon;
  final int count;
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<_ActivityTabData> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (index) {
        final tab = tabs[index];
        final bool selected = selectedIndex == index;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFEEF2FF)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab.icon,
                      size: 18,
                      color: selected
                          ? const Color(0xFF4F46E5)
                          : Colors.black45,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tab.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: selected
                              ? const Color(0xFF4F46E5)
                              : Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF4F46E5)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        "${tab.count}",
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: selected ? Colors.white : Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.docs, required this.emptyText});

  final List<QueryDocumentSnapshot> docs;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return _EmptyState(text: emptyText);
    }

    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;

        final content =
            data['content'] ??
            data['courseName'] ??
            data['fileName'] ??
            'Không có nội dung';

        final status = data['status'] ?? 'unknown';

        return _ActivityCard(
          content: content.toString(),
          status: status.toString(),
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.content, required this.status});

  final String content;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusChip(status: status),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(status);

    return Container(
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        style.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: style.foreground,
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

_StatusStyle _statusStyle(String rawStatus) {
  final status = rawStatus.toLowerCase().trim();

  switch (status) {
    case 'approved':
      return const _StatusStyle(
        label: 'Approved',
        background: Color(0xFFDCFCE7),
        foreground: Color(0xFF15803D),
      );
    case 'hidden':
      return const _StatusStyle(
        label: 'Hidden',
        background: Color(0xFFFEE2E2),
        foreground: Color(0xFFB91C1C),
      );
    case 'pending':
      return const _StatusStyle(
        label: 'Pending',
        background: Color(0xFFFEF3C7),
        foreground: Color(0xFFD97706),
      );
    case 'rejected':
      return const _StatusStyle(
        label: 'Rejected',
        background: Color(0xFFF3F4F6),
        foreground: Color(0xFF4B5563),
      );
    default:
      return _StatusStyle(
        label: rawStatus.isEmpty ? 'Unknown' : rawStatus,
        background: const Color(0xFFEFF6FF),
        foreground: const Color(0xFF2563EB),
      );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({required this.docs});

  final List<QueryDocumentSnapshot> docs;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const _EmptyState(text: "Chưa có lịch sử xử lý.");
    }

    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;

        final action = data['action'] ?? '';
        final reason = data['reason'] ?? '';
        final modEmail = data['modEmail'] ?? '';

        final actionText = action == 'suspend'
            ? 'Khóa tài khoản'
            : action == 'restore'
            ? 'Mở khóa tài khoản'
            : action.toString();

        final bool isSuspend = action == 'suspend';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isSuspend
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFDCFCE7),
                child: Icon(
                  isSuspend ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 18,
                  color: isSuspend
                      ? const Color(0xFFB91C1C)
                      : const Color(0xFF15803D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actionText,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      modEmail.isEmpty ? "Không rõ moderator" : "Bởi $modEmail",
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reason.toString().isEmpty
                          ? "Không có lý do."
                          : "Lý do: $reason",
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded, size: 34, color: Colors.black26),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
