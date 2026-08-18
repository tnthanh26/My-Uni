import 'package:flutter/material.dart';
import 'package:my_uni/features/notification/notification_page.dart';
import 'package:my_uni/features/notification/message_notification_page.dart';
import 'package:my_uni/features/services/notification_service.dart';
import 'package:my_uni/models/notification_model.dart';
import 'my_event_tab.dart';
import 'discover_event_tab.dart';
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

  static const Color _primaryColor = Color(0xFF5893D8);
  static const Color _darkSurface = Color(0xFF1C1E21);

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

  Widget _buildHeaderActionButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withOpacity(0.32),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderNotificationButton({
    required String tooltip,
    required IconData icon,
    required int unreadCount,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 30,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                if (unreadCount > 0)
                  Positioned(
                    right: 1,
                    top: 0,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF04438),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF303030),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
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
          child: Container(color: Colors.black.withOpacity(0.38)),
        ),
        // Logo & HCMUS Text & Notification - Cố định
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 35,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cụm trái: Logo + Tên trường
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 18,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Image.asset(
                          'assets/images/logoAppName.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "HCMUS",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        fontFamily: 'Nunito',
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),

                // Cụm phải: QR + Chat + Notification trong cùng pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.32),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nút QR
                      _buildHeaderNotificationButton(
                        tooltip: 'Quét mã QR điểm danh',
                        icon: Icons.qr_code_scanner_rounded,
                        unreadCount: 0,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => const EventQrScannerDialog(),
                          );
                        },
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: Colors.white.withOpacity(0.20),
                      ),
                      StreamBuilder<List<MyUniNotification>>(
                        stream: NotificationService.getMessageNotifications(),
                        builder: (context, snapshot) {
                          final int unreadChatCount =
                              snapshot.data
                                  ?.where((noti) => !noti.isRead)
                                  .length ??
                              0;

                          return _buildHeaderNotificationButton(
                            tooltip: 'Thông báo tin nhắn',
                            icon: Icons.chat_bubble_rounded,
                            unreadCount: unreadChatCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const MessageNotificationScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: Colors.white.withOpacity(0.20),
                      ),
                      StreamBuilder<List<MyUniNotification>>(
                        stream: NotificationService.getNotifications(),
                        builder: (context, snapshot) {
                          final int unreadCount =
                              snapshot.data
                                  ?.where((noti) => !noti.isRead)
                                  .length ??
                              0;

                          return _buildHeaderNotificationButton(
                            tooltip: 'Thông báo hoạt động',
                            icon: Icons.notifications_rounded,
                            unreadCount: unreadCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
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
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF8F9FA),
      floatingActionButton: _showFab
          ? FloatingActionButton(
              heroTag: 'create_personal_event_fab',
              tooltip: 'Tạo sự kiện cá nhân',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreatePersonalEventPage(),
                  ),
                );
              },
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, size: 27),
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
                          color: isDarkMode
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
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
                          dividerColor: Colors.transparent,
                          splashBorderRadius: BorderRadius.circular(16),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: isDarkMode
                              ? Colors.white70
                              : Colors.black87,
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
                            Tab(height: 34, text: 'Cá nhân'),
                            Tab(height: 34, text: 'Cộng đồng'),
                            Tab(height: 34, text: 'Hoạt động'),
                          ],
                        ),
                      ),
                      // Nội dung các Tab
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: const [
                            MyEventTab(mode: EventTabMode.personal),
                            DiscoverEventTab(useNestedScrollOverlap: false),
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
