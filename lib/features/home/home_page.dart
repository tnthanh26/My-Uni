import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:my_uni/features/event/my_event_tab.dart';
import 'package:my_uni/features/myspace/myspace_screen.dart';
import 'package:my_uni/features/notification/notification_page.dart';
import 'package:my_uni/features/services/notification_service.dart';
import 'package:my_uni/models/notification_model.dart';
import 'animated_bottom_nav.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  Future<void> _toggleSavePost({
    required BuildContext context,
    required String docId,
    required Map<String, dynamic> data,
    required String saveType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_posts')
        .doc(docId);
    try {
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        await docRef.delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã bỏ lưu bài viết")));
        }
      } else {
        final Map<String, dynamic> saveData = Map.from(data);
        saveData['saveType'] = saveType;
        saveData['savedAt'] = FieldValue.serverTimestamp();
        saveData['originalDocId'] = docId;
        await docRef.set(saveData);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã lưu vào mục Bài đã lưu")));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: ${e.toString()}")));
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    EventPageNotifier.isActive.value = (index == 1);
  }

  Widget _buildHeaderBackground(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/hcmus_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(color: Colors.black.withOpacity(0.45)),
    );
  }

  Widget _buildHeaderForeground(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 35),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Cụm trái: Logo + Tên trường
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.asset('assets/images/logoAppName.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'HCMUS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),

            // Cụm phải: Capsule Search & Notification
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xff545454),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Nút Search
                  GestureDetector(
                    onTap: () {
                      final tabIndex = DefaultTabController.of(context).index;
                      showSearch(
                        context: context,
                        delegate: MyUniSearchDelegate(
                          currentScope: [
                            SearchScope.official,
                            SearchScope.forum,
                            SearchScope.review,
                            SearchScope.material
                          ][tabIndex],
                        ),
                      );
                    },
                    child: const Icon(Icons.search, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 8),
                  const Text("|", style: TextStyle(color: Colors.white38)),
                  const SizedBox(width: 8),
                  // Nút Notification
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => NotificationScreen()),
                      );
                    },
                    child: StreamBuilder<List<MyUniNotification>>(
                      stream: NotificationService.getNotifications(),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data?.where((n) => !n.isRead).length ?? 0;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                            if (unreadCount > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: CircleAvatar(
                                  radius: 6,
                                  backgroundColor: Colors.red,
                                  child: Text(
                                    unreadCount > 9 ? "9+" : unreadCount.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              )
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainHomeContent() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      child: Stack(
        children: [
          // 1. Header Background (Dưới cùng)
          _buildHeaderBackground(context),

          // 2. Nội dung có thể cuộn (Giữa)
          Column(
            children: [
              // Khoảng trống 102px để lộ phần Logo/Text của Header
              const SizedBox(height: 102),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // TabBar được đặt ngay đầu Container nội dung
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.center,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: isDarkMode ? Colors.white70 : Colors.black87,
                          labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, fontSize: 16),
                          unselectedLabelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w400, fontSize: 12),
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'Chính Thức'),
                            Tab(text: 'Diễn Đàn'),
                            Tab(text: 'Review'),
                            Tab(text: 'Tài Liệu'),
                          ],
                        ),
                      ),
                      // Nội dung các Tab
                      Expanded(
                        child: TabBarView(
                          children: [
                            OfficialTab(onSave: (id, data) => _toggleSavePost(context: context, docId: id, data: data, saveType: 'general')),
                            ForumTab(onSave: (id, data) => _toggleSavePost(context: context, docId: id, data: data, saveType: 'general')),
                            ReviewTab(onSave: (id, data) => _toggleSavePost(context: context, docId: id, data: data, saveType: 'course')),
                            MaterialTab(onSave: (id, data) => _toggleSavePost(context: context, docId: id, data: data, saveType: 'course')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Header Foreground (Trên cùng để bấm được)
          Builder(
            builder: (headerContext) => _buildHeaderForeground(headerContext),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildMainHomeContent(),
      const EventPage(),
      const ChatbotPage(),
      const MySpaceScreen(),
      const AccountPage(),
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF6F6F6),
        border: Border(top: BorderSide(color: isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.1))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, -4)
          ),
        ],
      ),
      child: AnimatedBottomNav(
         currentIndex: _selectedIndex,
         onTap: _onItemTapped,
         items: [
           AnimatedNavItem(icon: 'assets/icons/home.svg',    label: 'Home'),
           AnimatedNavItem(icon: 'assets/icons/event.svg',   label: 'Sự kiện'),
           AnimatedNavItem(icon: 'assets/icons/chat.svg',    label: 'Hỏi Đáp'),
           AnimatedNavItem(icon: 'assets/icons/space.svg',   label: 'Góc nhỏ'),
           AnimatedNavItem(icon: 'assets/icons/account.svg', label: 'Tài Khoản'),
         ],
      ),
    );
  }
}