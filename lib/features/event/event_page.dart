import 'package:flutter/material.dart';
import 'discover_event_tab.dart';
import 'my_event_tab.dart';
import 'create_personal_event_page.dart';

class EventPage extends StatefulWidget {
  const EventPage({super.key});

  @override
  State<EventPage> createState() => _EventPageState();
}

// Thêm TickerProviderStateMixin để dùng TabController
class _EventPageState extends State<EventPage> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _showFab = true; // Biến điều khiển ẩn hiện FAB
  static const Color primaryBrown = Color(0xFF47352E); // Màu nâu chuẩn của Thanh

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Lắng nghe thay đổi tab để ẩn/hiện FAB
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          // Chỉ hiện FAB khi ở tab 0 (Sự kiện của tôi)
          _showFab = _tabController.index == 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Giữ nguyên hàm _showCreateEventMenu của bạn, chỉ đổi màu Icon bên trong cho hợp tông
  void _showCreateEventMenu(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMenuOption(
                context,
                icon: Icons.school_rounded,
                label: 'Cộng Đồng',
                isDarkMode: isDarkMode,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 20),
              _buildMenuOption(
                context,
                icon: Icons.person_rounded,
                label: 'Cá Nhân',
                isDarkMode: isDarkMode,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreatePersonalEventPage()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption(BuildContext context, {required IconData icon, required String label, required bool isDarkMode, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140, height: 140,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: primaryBrown), // Đổi màu icon menu sang nâu cho đồng bộ
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),

      // LOGIC ẨN HIỆN VÀ ĐỔI MÀU NÂU CHO FAB
      floatingActionButton: _showFab
          ? FloatingActionButton(
        onPressed: () => _showCreateEventMenu(context),
        backgroundColor: primaryBrown, // ĐỔI SANG MÀU NÂU
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Bo góc cho đẹp giống switcher
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      )
          : null, // Trả về null khi qua tab Khám phá

      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar(
                expandedHeight: 120.0,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: const Color(0xFF6797E1),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        'https://student.hcmus.edu.vn/_next/image?url=%2Fbackground.jpg&w=3840&q=75',
                        fit: BoxFit.cover,
                      ),
                      Container(color: isDarkMode ? Colors.black54 : Colors.black38),
                      const Positioned(
                        left: 20, bottom: 80,
                        child: Row(
                          children: [
                            Icon(Icons.logo_dev_sharp, color: Colors.white, size: 32),
                            SizedBox(width: 10),
                            Text('HCMUS', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
                  _buildNotificationIcon(),
                  const SizedBox(width: 8),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Container(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: TabBar(
                      controller: _tabController, // Gán controller thủ công
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: const Color(0xFF6797E1).withOpacity(isDarkMode ? 0.3 : 0.2),
                      ),
                      labelColor: isDarkMode ? const Color(0xFF91B5EE) : const Color(0xFF003366),
                      unselectedLabelColor: isDarkMode ? Colors.white38 : Colors.grey,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Sự kiện của tôi'),
                        Tab(text: 'Khám Phá'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController, // Gán controller thủ công
          children: const [
            MyEventTab(),
            DiscoverEventTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        IconButton(icon: const Icon(Icons.notifications_none_rounded, color: Colors.white), onPressed: () {}),
        Positioned(
          right: 8, top: 8,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
            child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        )
      ],
    );
  }
}