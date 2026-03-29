import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_uni/features/search/myuni_search_delegate.dart';
import 'package:my_uni/features/home/forum_tab.dart';
import 'package:my_uni/features/home/official_tab.dart';
import 'package:my_uni/features/home/review_tab.dart';
import 'package:my_uni/features/home/material_tab.dart';
import 'package:my_uni/features/account/account_page.dart';
import 'package:my_uni/features/chatbot/chatbot_page.dart';
import 'package:my_uni/features/event/event_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildMainHomeContent() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        // Màu nền tự động thích ứng
        backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverAppBar(
                  expandedHeight: 120.0,
                  pinned: true,
                  floating: false,
                  backgroundColor: const Color(0xFF6797E1),
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://student.hcmus.edu.vn/_next/image?url=%2Fbackground.jpg&w=3840&q=75',
                          fit: BoxFit.cover,
                        ),
                        Container(color: Colors.black38),
                        const Positioned(
                          left: 20,
                          bottom: 80,
                          child: Row(
                            children: [
                              Icon(Icons.logo_dev_sharp, color: Colors.white, size: 32),
                              SizedBox(width: 10),
                              Text(
                                'HCMUS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 10, color: Colors.black45)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    Builder( // Cần Builder để lấy context của Scaffold
                        builder: (context) {
                          return IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () {
                              // Lấy TabIndex hiện tại từ DefaultTabController
                              final tabIndex = DefaultTabController.of(context).index;

                              // Map TabIndex sang SearchScope (Tạo Map này ở đầu class hoặc local)
                              final Map<int, SearchScope> tabScopeMap = {
                                0: SearchScope.official,
                                1: SearchScope.forum,
                                2: SearchScope.review,
                                3: SearchScope.material,
                              };
                              final currentScope = tabScopeMap[tabIndex] ?? SearchScope.forum; // Mặc định là forum nếu lỗi

                              // GỌI SEARCH DELEGATE MỚI
                              showSearch(
                                context: context,
                                delegate: MyUniSearchDelegate(currentScope: currentScope),
                              );
                            },
                          );
                        }
                    ),
                    IconButton(icon: const Icon(Icons.notifications_none_rounded, color: Colors.white), onPressed: () {}),
                    const SizedBox(width: 8),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(52),
                    child: Container(
                      // Màu nền TabBar thích ứng
                      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        padding: const EdgeInsets.only(left: 12),
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: const Color(0xFF6797E1).withOpacity(isDarkMode ? 0.3 : 0.2),
                        ),
                        // Màu chữ khi chọn: Xanh nhạt hơn trong Dark Mode để nổi bật
                        labelColor: isDarkMode ? const Color(0xFF91B5EE) : const Color(0xFF003366),
                        unselectedLabelColor: isDarkMode ? Colors.white38 : Colors.grey,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Chính thức'))),
                          Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Diễn đàn'))),
                          Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Review'))),
                          Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Tài liệu'))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: Builder(
            builder: (context) {
              return CustomScrollView(
                slivers: [
                  SliverOverlapInjector(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  ),
                  const SliverFillRemaining(
                    child: TabBarView(
                      children: [
                        OfficialTab(),
                        ForumTab(),
                        ReviewTab(),
                        MaterialTab(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final bool isGuest = user == null;

    final guestScreen = _buildGuestAccountScreen(context);

    final List<Widget> pages = [
      isGuest ? guestScreen : _buildMainHomeContent(),
      isGuest ? guestScreen : const EventPage(),
      isGuest ? guestScreen : const ChatbotPage(),
      Center(child: Text('Góc Nhỏ', style: TextStyle(fontSize: 24, color: isDarkMode ? Colors.white : Colors.black87))),
      isGuest ? guestScreen : const AccountPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: _buildBottomNav(isDarkMode),
    );
  }

  Widget _buildBottomNav(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(top: BorderSide(color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF6797E1),
        unselectedItemColor: isDarkMode ? Colors.white38 : Colors.grey,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 0,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.event_available_outlined), label: 'Sự kiện'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Hỏi Đáp'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), label: 'Góc Nhỏ'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), label: 'Tài khoản'),
        ],
      ),
    );
  }

  Widget _buildGuestAccountScreen(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_circle_outlined, size: 100, color: isDarkMode ? Colors.white24 : Colors.grey),
                const SizedBox(height: 20),
                Text(
                    'Bạn đang ở chế độ khách',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)
                ),
                const SizedBox(height: 10),
                const Text(
                  'Đăng nhập để sử dụng đầy đủ tính năng.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6797E1),
                      minimumSize: const Size(200, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('Đăng nhập ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                )
              ]
          ),
        )
    );
  }
}