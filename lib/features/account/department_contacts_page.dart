import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class DepartmentContactsPage extends StatefulWidget {
  const DepartmentContactsPage({super.key});

  @override
  State<DepartmentContactsPage> createState() => _DepartmentContactsPageState();
}

class _DepartmentContactsPageState extends State<DepartmentContactsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openLink(String value) async {
    final raw = value.trim();
    if (raw.isEmpty) return;

    Uri uri;
    if (raw.contains('@') && !raw.startsWith('http')) {
      uri = Uri(scheme: 'mailto', path: raw);
    } else if (raw.startsWith('http')) {
      uri = Uri.parse(raw);
    } else if (raw.startsWith('www.')) {
      uri = Uri.parse('https://$raw');
    } else {
      uri = Uri(scheme: 'tel', path: raw.replaceAll(RegExp(r'[^0-9+]'), ''));
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở liên kết này')),
      );
    }
  }

  Future<void> _copyText(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép')),
    );
  }

  IconData _departmentIcon(String id) {
    switch (id) {
      case 'training':
        return Icons.school_outlined;
      case 'student_affairs':
        return Icons.groups_2_outlined;
      case 'testing_quality':
        return Icons.assignment_turned_in_outlined;
      case 'communication':
        return Icons.campaign_outlined;
      case 'inspection_legal':
        return Icons.gavel_outlined;
      case 'science_technology':
        return Icons.science_outlined;
      case 'international_relations':
        return Icons.public_outlined;
      case 'finance':
        return Icons.account_balance_wallet_outlined;
      case 'medical':
        return Icons.local_hospital_outlined;
      case 'library':
        return Icons.local_library_outlined;
      default:
        return Icons.business_outlined;
    }
  }

  bool _matchesKeyword(Map<String, dynamic> data) {
    final q = _keyword.trim().toLowerCase();
    if (q.isEmpty) return true;
    final text = [
      data['name'],
      data['email'],
      data['website'],
      data['phone'],
      data['campus1Address'],
      data['campus1Room'],
      data['campus2Address'],
      data['campus2Room'],
      ...(data['links'] as List<dynamic>? ?? []),
    ].whereType<Object>().join(' ').toLowerCase();
    return text.contains(q);
  }

  Widget _contactChip({
    required IconData icon,
    required String text,
    required bool isDarkMode,
    bool canOpen = true,
  }) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: canOpen ? () => _openLink(text) : () => _copyText(text),
      onLongPress: () => _copyText(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF6797E1)),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campusBlock({
    required String title,
    required String address,
    required String room,
    required String phone,
    required bool isDarkMode,
  }) {
    if ([address, room, phone].every((e) => e.trim().isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF101215) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Encode Sans Expanded',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          if (address.trim().isNotEmpty) _infoLine(Icons.location_on_outlined, address, isDarkMode),
          if (room.trim().isNotEmpty) _infoLine(Icons.meeting_room_outlined, room, isDarkMode),
          if (phone.trim().isNotEmpty)
            InkWell(
              onTap: () => _openLink(phone),
              onLongPress: () => _copyText(phone),
              child: _infoLine(Icons.phone_outlined, phone, isDarkMode),
            ),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF6797E1)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 12.5,
                height: 1.4,
                color: isDarkMode ? Colors.white70 : const Color(0xFF475467),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _departmentCard(Map<String, dynamic> data, bool isDarkMode) {
    final id = data['id']?.toString() ?? '';
    final name = data['name']?.toString() ?? 'Phòng ban';
    final email = data['email']?.toString() ?? '';
    final website = data['website']?.toString() ?? '';
    final phone = data['phone']?.toString() ?? '';
    final campus1Address = data['campus1Address']?.toString() ?? '';
    final campus1Room = data['campus1Room']?.toString() ?? '';
    final campus1Phone = data['campus1Phone']?.toString() ?? '';
    final campus2Address = data['campus2Address']?.toString() ?? '';
    final campus2Room = data['campus2Room']?.toString() ?? '';
    final campus2Phone = data['campus2Phone']?.toString() ?? '';
    final links = (data['links'] as List<dynamic>? ?? []).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF15171A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
        ),
        boxShadow: isDarkMode
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6797E1).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_departmentIcon(id), color: const Color(0xFF6797E1), size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 15.5,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                          color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thông tin liên hệ',
                        style: TextStyle(
                          fontFamily: 'Encode Sans Expanded',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white54 : const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _contactChip(icon: Icons.email_outlined, text: email, isDarkMode: isDarkMode),
                _contactChip(icon: Icons.language_outlined, text: website, isDarkMode: isDarkMode),
                _contactChip(icon: Icons.phone_outlined, text: phone, isDarkMode: isDarkMode),
                for (final link in links)
                  _contactChip(icon: Icons.link_outlined, text: link, isDarkMode: isDarkMode),
              ],
            ),
            const SizedBox(height: 14),
            _campusBlock(
              title: 'Cơ sở 1',
              address: campus1Address,
              room: campus1Room,
              phone: campus1Phone,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 10),
            _campusBlock(
              title: 'Cơ sở 2',
              address: campus2Address,
              room: campus2Room,
              phone: campus2Phone,
              isDarkMode: isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F1113) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Liên hệ phòng ban',
          style: TextStyle(
            fontFamily: 'Encode Sans Expanded',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDarkMode ? Colors.white : const Color(0xFF545454),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF111315) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : const Color(0xFF545454),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _keyword = value),
              style: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
              ),
              decoration: InputDecoration(
                hintText: 'Tìm phòng ban, email, số điện thoại...',
                hintStyle: TextStyle(
                  fontFamily: 'Encode Sans Expanded',
                  fontSize: 13,
                  color: isDarkMode ? Colors.white38 : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6797E1)),
                suffixIcon: _keyword.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _keyword = '');
                  },
                ),
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF15171A) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.white10 : const Color(0xFFE9EEF3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFF6797E1), width: 1.4),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('utilities')
                  .doc('department_contacts')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Đã có lỗi xảy ra'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF6797E1)));
                }

                final rawDepartments = snapshot.data?.data()?['departments'] as List<dynamic>? ?? [];
                final departments = rawDepartments
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .where(_matchesKeyword)
                    .toList()
                  ..sort((a, b) => (a['index'] ?? 999).compareTo(b['index'] ?? 999));

                if (departments.isEmpty) {
                  return Center(
                    child: Text(
                      _keyword.isEmpty ? 'Chưa có dữ liệu liên hệ.' : 'Không tìm thấy phòng ban phù hợp.',
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        color: isDarkMode ? Colors.white60 : const Color(0xFF667085),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: departments.length,
                  itemBuilder: (context, index) => _departmentCard(departments[index], isDarkMode),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}