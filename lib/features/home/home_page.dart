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
import 'package:my_uni/features/myspace/myspace_screen.dart';
import 'package:my_uni/features/notification/notification_page.dart';
import 'package:my_uni/notification_service.dart';
import 'package:my_uni/models/notification_model.dart';

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
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng đăng nhập để lưu bài viết")),
      );
      return;
    }
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
  }

  Widget _buildMainHomeContent() {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 102.0,
                pinned: true,
                elevation: 0,
                backgroundColor: const Color(0xFF5893D8),
                automaticallyImplyLeading: false,
                actions: const [SizedBox.shrink()],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        height: 102,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/background.jpg'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(color: Colors.black38),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 60),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.white,
                                    child: Padding(
                                      padding: const EdgeInsets.all(3.0),
                                      child: Image.asset('assets/images/logoApp1.png', fit: BoxFit.contain),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'HCMUS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Nunito',
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              // --- CỤM THANH TIỆN ÍCH (ĐÃ CẬP NHẬT LOGIC) ---
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xff545454),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    // NÚT SEARCH
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
                                            children: [
                                              const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                                              if (unreadCount > 0)
                                                Positioned(
                                                  right: 0,
                                                  top: 0,
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
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF5893D8),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.black87,
                      labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, fontSize: 16),
                      unselectedLabelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w400, fontSize: 14),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Chính Thức'),
                        Tab(text: 'Diễn Đàn'),
                        Tab(text: 'Review'),
                        Tab(text: 'Tài Liệu'),
                      ],
                    ),
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final tabController = DefaultTabController.of(context);
                  return AnimatedBuilder(
                    animation: tabController,
                    builder: (context, child) {
                      if (tabController.index == 0) {
                        return SliverToBoxAdapter(
                          child: Container(
                            color: Colors.transparent,
                            child: _buildPromoBanner(),
                          ),
                        );
                      }
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    },
                  );
                },
              ),
            ];
          },
          body: TabBarView(
            children: [
              OfficialTab(onSave: (id, data) => _toggleSavePost(context: context, docId: id, data: data, saveType: 'general')),
              ForumTab(onSave: (id, data) => _toggleSavePost(context: context, docId: id, data: data, saveType: 'general')),
              ReviewTab(onSave: (id, data) => _toggleSavePost(context: context, docId: id, data: data, saveType: 'course')),
              MaterialTab(onSave: (id, data) => _toggleSavePost(context: context, docId: id, data: data, saveType: 'course')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: AspectRatio(
        aspectRatio: 391 / 73, // Tỉ lệ chính xác theo Figma của bạn (W:378, H:94)
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16), // Bo góc nhẹ cho giống ảnh mẫu
            image: const DecorationImage(
              image: AssetImage('assets/images/Ads_template.png'),
              fit: BoxFit.fill, // Ép ảnh vừa khít khung hình mà không cần design lại
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isGuest = user == null;
    final guestScreen = _buildGuestAccountScreen(context);

    final List<Widget> pages = [
      isGuest ? guestScreen : _buildMainHomeContent(),
      isGuest ? guestScreen : const EventPage(),
      isGuest ? guestScreen : const ChatbotPage(),
      isGuest ? guestScreen : const MySpaceScreen(),
      isGuest ? guestScreen : const AccountPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.2))),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF457EC0), // Active color CSS
        unselectedItemColor: const Color(0xFF545454), // Inactive color CSS
        selectedLabelStyle: const TextStyle(fontSize: 10, fontFamily: 'Inter', letterSpacing: 0.3),
        unselectedLabelStyle: const TextStyle(fontSize: 10, fontFamily: 'Inter', letterSpacing: 0.3),
        elevation: 0,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.event_note_rounded), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Hỏi Đáp'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'MySpace'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Account'),
        ],
      ),
    );
  }

  Widget _buildGuestAccountScreen(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle_outlined, size: 100, color: Colors.grey),
          const SizedBox(height: 20),
          const Text('Chế độ khách', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF457EC0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Đăng nhập ngay', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}