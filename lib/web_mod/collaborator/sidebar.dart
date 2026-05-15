import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CollaboratorSidebar extends StatelessWidget {
  const CollaboratorSidebar({
    super.key,
    required this.selectedIndex,
    required this.onMenuSelected,
    required this.user,
  });

  final int selectedIndex;
  final ValueChanged<int> onMenuSelected;
  final User? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      color: const Color(0xFF1A1F37),
      child: Column(
        children: [
          const SizedBox(height: 38),
          const Icon(
            Icons.groups_2_outlined,
            color: Colors.orangeAccent,
            size: 52,
          ),
          const SizedBox(height: 10),
          const Text(
            'MYUNI CTV',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.bold,
              fontSize: 21,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 34),
          _sectionTitle('QUẢN LÝ HOẠT ĐỘNG'),
          _menuItem(0, Icons.dashboard_outlined, 'Tổng quan'),
          _menuItem(1, Icons.event_note_outlined, 'Hoạt động của tôi'),
          _menuItem(2, Icons.add_circle_outline_rounded, 'Tạo hoạt động'),
          _menuItem(3, Icons.fact_check_outlined, 'Điểm danh'),
          const Spacer(),
          _buildCollaboratorAvatar(context),
        ],
      ),
    );
  }

  Widget _menuItem(int index, IconData icon, String title) {
    final selected = selectedIndex == index;

    return InkWell(
      onTap: () => onMenuSelected(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.orangeAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.orangeAccent : Colors.grey),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Nunito',
                color: selected ? Colors.white : Colors.grey,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontFamily: 'Nunito',
          ),
        ),
      ),
    );
  }

  Widget _buildCollaboratorAvatar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.orangeAccent,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Collaborator',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text(
                        'Đăng xuất?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      content: const Text(
                        'Bạn có chắc muốn đăng xuất khỏi trang CTV?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hủy'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Đăng xuất',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true) return;

                  await FirebaseAuth.instance.signOut();

                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                          (route) => false,
                    );
                  }
                },
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: Colors.redAccent,
                ),
                label: const Text(
                  'Đăng xuất',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Nunito',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Colors.redAccent.withOpacity(0.35),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}