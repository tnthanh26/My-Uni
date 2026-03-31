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
                expandedHeight: 160.0,
                pinned: true,
                elevation: 4,
                shadowColor: Colors.black26,
                backgroundColor: const Color(0xFF5893D8),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset('assets/images/background.jpg', fit: BoxFit.cover),
                      Container(color: Colors.black26),
                      // HCMUS Text (CSS: left 58px, top 48px)
                      Positioned(
                        left: 20,
                        bottom: 65,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
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
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  // Search button (CSS: mingcute:search-line)
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () {
                      final tabIndex = DefaultTabController.of(context).index;
                      showSearch(
                        context: context,
                        delegate: MyUniSearchDelegate(
                          currentScope: [SearchScope.official, SearchScope.forum, SearchScope.review, SearchScope.material][tabIndex],
                        ),
                      );
                    },
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0xFFFF6868), shape: BoxShape.circle),
                          child: const Text('1', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(width: 10),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(40),
                  child: Container(
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF5893D8),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.black,
                      labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14),
                      unselectedLabelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w400, fontSize: 14),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Chính Thức'))),
                        Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Diễn Đàn'))),
                        Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Review'))),
                        Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Tài Liệu'))),
                      ],
                    ),
                  ),
                ),
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