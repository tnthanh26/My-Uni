import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'onboarding_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static final ValueNotifier<bool> showWalkthroughNotifier = ValueNotifier<bool>(false);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _showWalkthrough = false;
  int _walkthroughStep = 0;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    HomePage.showWalkthroughNotifier.addListener(_onWalkthroughTriggered);
  }

  @override
  void dispose() {
    HomePage.showWalkthroughNotifier.removeListener(_onWalkthroughTriggered);
    super.dispose();
  }

  void _onWalkthroughTriggered() {
    if (HomePage.showWalkthroughNotifier.value) {
      setState(() {
        _showWalkthrough = true;
        _walkthroughStep = 0;
        _selectedIndex = 0;
        EventPageNotifier.isActive.value = (_selectedIndex == 1);
      });
      HomePage.showWalkthroughNotifier.value = false;
    }
  }

  Future<void> _checkOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = 'show_onboarding_${user.uid}';
        final showOnboarding = prefs.getBool(key) ?? false;
        if (showOnboarding) {
          // Xóa cờ ngay lập tức để không hiện lại lần sau
          await prefs.setBool(key, false);
          if (mounted) {
            setState(() {
              _showWalkthrough = true;
              _walkthroughStep = 0;
              _selectedIndex = 0;
              EventPageNotifier.isActive.value = (_selectedIndex == 1);
            });
          }
        }
      } catch (e) {
        debugPrint("Error checking onboarding: $e");
      }
    }
  }

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

  void _nextWalkthroughStep() {
    setState(() {
      if (_walkthroughStep < walkthroughSteps.length - 1) {
        _walkthroughStep++;
        _selectedIndex = _walkthroughStep;
        EventPageNotifier.isActive.value = (_selectedIndex == 1);
      } else {
        _showWalkthrough = false;
        _saveOnboardingDone();
      }
    });
  }

  void _prevWalkthroughStep() {
    if (_walkthroughStep > 0) {
      setState(() {
        _walkthroughStep--;
        _selectedIndex = _walkthroughStep;
        EventPageNotifier.isActive.value = (_selectedIndex == 1);
      });
    }
  }

  void _skipWalkthrough() {
    setState(() {
      _showWalkthrough = false;
      _saveOnboardingDone();
    });
  }

  Future<void> _saveOnboardingDone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = 'show_onboarding_${user.uid}';
        await prefs.setBool(key, false);
      } catch (e) {
        debugPrint("Error saving onboarding: $e");
      }
    }
  }

  Widget _buildWalkthroughOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;
        final double paddingBottom = mediaQuery.padding.bottom;

        final stepData = walkthroughSteps[_walkthroughStep];

        final double cardWidth = (screenWidth * 0.88).clamp(280.0, 360.0);
        final double cardHeight = 245;
        final double cardLeft = ((screenWidth - cardWidth) / 2)
            .clamp(12.0, screenWidth - cardWidth - 12);

        return SizedBox(
          width: screenWidth,
          height: screenHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    size: Size(screenWidth, screenHeight),
                    painter: WalkthroughSpotlightPainter(
                      step: _walkthroughStep,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                      paddingBottom: paddingBottom,
                    ),
                  ),
                ),
              ),

              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                ),
              ),

              Positioned(
                left: cardLeft,
                bottom: paddingBottom + 84,
                width: cardWidth,
                height: cardHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E24) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: stepData.accentColor.withOpacity(0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 18,
                        top: 16,
                        width: 36,
                        height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            color: stepData.accentColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            stepData.icon,
                            color: stepData.accentColor,
                            size: 20,
                          ),
                        ),
                      ),

                      Positioned(
                        left: 64,
                        top: 17,
                        right: 54,
                        height: 42,
                        child: Text(
                          stepData.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.none,
                            color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                      ),

                      Positioned(
                        right: 18,
                        top: 24,
                        child: Text(
                          "${_walkthroughStep + 1}/${walkthroughSteps.length}",
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                            color: isDarkMode ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ),

                      Positioned(
                        left: 18,
                        right: 18,
                        top: 72,
                        height: 104,
                        child: Text(
                          stepData.description.replaceAll('**', ''),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13.5,
                            height: 1.45,
                            decoration: TextDecoration.none,
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),

                      Positioned(
                        left: 18,
                        bottom: 16,
                        width: 88,
                        height: 38,
                        child: GestureDetector(
                          onTap: _skipWalkthrough,
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: Text(
                              "Bỏ qua",
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                decoration: TextDecoration.none,
                                color: isDarkMode ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_walkthroughStep > 0)
                        Positioned(
                          right: 124,
                          bottom: 16,
                          width: 38,
                          height: 38,
                          child: GestureDetector(
                            onTap: _prevWalkthroughStep,
                            behavior: HitTestBehavior.opaque,
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: stepData.accentColor,
                              size: 22,
                            ),
                          ),
                        ),

                      Positioned(
                        right: 18,
                        bottom: 16,
                        width: 100,
                        height: 38,
                        child: GestureDetector(
                          onTap: _nextWalkthroughStep,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: stepData.accentColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _walkthroughStep == walkthroughSteps.length - 1
                                  ? "Xong"
                                  : "Tiếp theo",
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                decoration: TextDecoration.none,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildMainHomeContent(),
      const EventPage(),
      const ChatbotPage(),
      MySpaceScreen(isActive: _selectedIndex == 3),
      const AccountPage(),
    ];

    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          Scaffold(
            body: IndexedStack(index: _selectedIndex, children: pages),
            bottomNavigationBar: _buildBottomNav(),
          ),
          if (_showWalkthrough)
            Positioned.fill(
              child: _buildWalkthroughOverlay(),
            ),
        ],
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