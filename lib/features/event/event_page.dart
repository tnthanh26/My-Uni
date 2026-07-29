import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_uni/features/notification/notification_page.dart';
import 'package:my_uni/features/services/notification_service.dart';
import 'package:my_uni/models/notification_model.dart';
import 'package:my_uni/features/chat/pages/chat_list_page.dart';
import 'package:my_uni/features/chat/services/chat_service.dart';
import 'package:my_uni/features/chat/models/chat_models.dart';
import 'my_event_tab.dart';
import 'create_personal_event_page.dart';
import 'event_qr_scanner_dialog.dart';
import 'student_attendance_history_tab.dart';

class EventPage extends StatefulWidget {
  final bool? isActive;
  const EventPage({super.key, this.isActive = false});
  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _showFab = true;
  static const Color primaryBrown = Color(0xFF545454);
  static const Color _accent   = Color(0xFF6C63FF); // electric violet

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
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

  Widget _buildFixedHeader(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        // Background Image with Overlay
        Container(
          height: statusBarHeight + 102.0,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/hcmus_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            color: Colors.black.withOpacity(0.45),
          ),
        ),
        // Logo & HCMUS Text & Notification - Cố định
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 35),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cụm trái: Logo + Tên trường
                Row(children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Image.asset('assets/images/logoAppName.png', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text("HCMUS",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          fontFamily: 'Nunito',
                          letterSpacing: 1.2
                      )
                  ),
                ]),

                // Cụm phải: Nút quét QR Event & Nút thông báo UI Capsule
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => const EventQrScannerDialog(),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Color(0xff545454),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xff545454),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Nút Message (Bên trái nút Notification)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ChatListPage()),
                              );
                            },
                            child: StreamBuilder<List<ChatRoom>>(
                              stream: ChatService().getUserChatRoomsStream(),
                              builder: (context, snapshot) {
                                final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                                int unreadChatCount = 0;
                                if (snapshot.hasData) {
                                  for (var room in snapshot.data!) {
                                    unreadChatCount += room.unreadCounts[myUid] ?? 0;
                                  }
                                }

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 22),
                                    if (unreadChatCount > 0)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: CircleAvatar(
                                          radius: 6,
                                          backgroundColor: Colors.red,
                                          child: Text(
                                            unreadChatCount > 9 ? "9+" : unreadChatCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 7,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text("|", style: TextStyle(color: Colors.white38)),
                          const SizedBox(width: 8),
                          // Nút Notification
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const NotificationScreen()),
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
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 7,
                                                fontWeight: FontWeight.bold
                                            ),
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      floatingActionButton: _showFab
          ? FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreatePersonalEventPage()),
        ),
        backgroundColor: primaryBrown,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      )
          : null,
      body: Stack(
        children: [
          // 1. Header cố định (Dưới cùng)
          _buildFixedHeader(context),

          // 2. Nội dung (Giữa)
          Column(
            children: [
              // Khoảng trống để lộ phần Logo/Text của Header
              SizedBox(height: MediaQuery.of(context).padding.top + 64.0),
              Expanded(
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
                          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.center,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          indicator: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: isDarkMode ? Colors.white70 : Colors.black87,
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                          ),
                          tabs: const [
                            Tab(text: 'Cá nhân'),
                            Tab(text: 'Cộng đồng'),
                            Tab(text: 'Điểm danh'),
                          ],
                        ),
                      ),
                      // Nội dung các Tab
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: const [
                            MyEventTab(mode: EventTabMode.personal),
                            MyEventTab(mode: EventTabMode.community),
                            StudentAttendanceHistoryTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}