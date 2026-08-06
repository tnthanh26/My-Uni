import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:my_uni/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_uni/features/search/myuni_search_delegate.dart';
import 'package:my_uni/features/home/forum_tab.dart';
import 'package:my_uni/features/home/official_tab.dart';
import 'package:my_uni/features/home/review_tab.dart';
import 'package:my_uni/features/home/material_tab.dart';
import 'package:my_uni/features/account/account_page.dart';
import 'package:my_uni/features/account/edit_profile_page.dart';
import 'package:my_uni/features/chatbot/chatbot_page.dart';
import 'package:my_uni/features/event/event_page.dart';
import 'package:my_uni/features/event/my_event_tab.dart';
import 'package:my_uni/features/myspace/myspace_screen.dart';
import 'package:my_uni/features/notification/notification_page.dart';
import 'package:my_uni/features/notification/message_notification_page.dart';
import 'package:my_uni/features/services/notification_service.dart';
import 'package:my_uni/models/notification_model.dart';
import 'animated_bottom_nav.dart';
import 'onboarding_dialog.dart';
import 'package:my_uni/features/services/daily_active_service.dart';
import 'package:my_uni/features/myspace/models/weather_models.dart';
import 'package:my_uni/features/myspace/campus_data.dart';
import 'package:my_uni/features/myspace/services/weather_alert_service.dart';
import 'package:my_uni/features/myspace/services/weather_service.dart';
import 'package:my_uni/features/myspace/services/myspace_weather_coordinator.dart';
import 'package:my_uni/features/myspace/myspace_firebase_service.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

class WeatherAlertTheme {
  final Color accent;
  final String lottieAsset;
  final String fallbackAsset;

  const WeatherAlertTheme({
    required this.accent,
    required this.lottieAsset,
    required this.fallbackAsset,
  });

  static const thunderstorm = WeatherAlertTheme(
    accent: AppColors.hcmusAmber, // Vàng cam giông sét
    lottieAsset: 'assets/icons/rainy.json',
    fallbackAsset: 'assets/images/rain_icon.png',
  );

  static const heavyRain = WeatherAlertTheme(
    accent: AppColors.hcmusBlue, // Xanh dương mưa lớn
    lottieAsset: 'assets/icons/rainy.json',
    fallbackAsset: 'assets/images/rain_icon.png',
  );

  static const lightRain = WeatherAlertTheme(
    accent: AppColors.hcmusBlueLight, // Xanh dương nhạt mưa nhỏ
    lottieAsset: 'assets/icons/rainy.json',
    fallbackAsset: 'assets/images/rain_icon.png',
  );

  static const none = WeatherAlertTheme(
    accent: AppColors.hcmusTeal, // Xanh lá thời tiết đẹp
    lottieAsset: 'assets/icons/rainy.json',
    fallbackAsset: 'assets/images/rain_icon.png',
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static final ValueNotifier<bool> showWalkthroughNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<int> activeTabNotifier = ValueNotifier<int>(0);

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _showWalkthrough = false;
  int _walkthroughStep = 0;

  // Weather alert state (Chỉ hiển thị 1 lần duy nhất khi vừa mở app)
  bool _hasShownWeatherAlert = false;

  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  @override
  void initState() {
    super.initState();
    DailyActiveService.logDailyActiveUser();
    HomePage.activeTabNotifier.value = _selectedIndex;
    HomePage.activeTabNotifier.addListener(_onActiveTabChanged);
    _checkOnboarding();
    HomePage.showWalkthroughNotifier.addListener(_onWalkthroughTriggered);
    _syncExistingProfileData();
    _checkWeatherAlertAndShowDialog();
    _listenToUserDocChanges();
  }

  void _onActiveTabChanged() {
    if (mounted && HomePage.activeTabNotifier.value != _selectedIndex) {
      setState(() {
        _selectedIndex = HomePage.activeTabNotifier.value;
      });
    }
  }

  void _listenToUserDocChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userDocSubscription?.cancel();
    _userDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) return;

      // User document was deleted from Firestore (e.g. by Mod)
      _userDocSubscription?.cancel();

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Tài khoản đã bị xóa', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
            content: const Text(
              'Tài khoản của bạn đã bị xóa khỏi hệ thống bởi kiểm duyệt viên.\n\nBạn sẽ được tự động đăng xuất để có thể đăng ký tài khoản mới.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: const Text('Đồng ý', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        await FirebaseAuth.instance.signOut();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_token');
        await prefs.remove('saved_user');

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      }
    });
  }

  DateTime _combineTodayAndTime(String time) {
    final input = time.trim().toUpperCase();
    final now = DateTime.now();
    try {
      DateTime parsed;
      if (input.contains('AM') || input.contains('PM')) {
        parsed = DateFormat('h:mm a').parse(input);
      } else {
        parsed = DateFormat('HH:mm').parse(input);
      }
      return DateTime(
        now.year,
        now.month,
        now.day,
        parsed.hour,
        parsed.minute,
      );
    } catch (e) {
      debugPrint('Cannot parse schedule time: $time, error: $e');
      return DateTime(now.year, now.month, now.day, 7, 30);
    }
  }

  Future<void> _checkWeatherAlertAndShowDialog() async {
    // -------------------------------------------------------------
    // CHẾ ĐỘ DEBUG: Luôn hiển thị Dialog cảnh báo để test UI khi vừa mở app
    // Khi nạp ổn rồi, chỉ cần comment phần MOCK này và uncomment phần thực tế bên dưới.
    // -------------------------------------------------------------
    /*
    final testResult = WeatherAlertResult(
      shouldShow: true,
      level: WeatherAlertLevel.thunderstorm,
      title: "Hôm nay đi học, trời có thể mưa đấy.",
      subtitle: "Đừng để bị ướt nhé!",
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWeatherAlertDialog(testResult, theme: WeatherAlertTheme.thunderstorm);
    });
    */

    // LOGIC THỰC TẾ (Bỏ comment để khôi phục khi debug xong)
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) return;

      final userData = userDoc.data();
      if (userData == null) return;
      final String userUniversity = userData['university'] ?? '';

      final localSchedule = await MySpaceFirebaseService().getSchedule();
      final todayWeekday = DateTime.now().weekday + 1; // T2=2, T3=3... CN=8
      final todayClasses = localSchedule.where((c) => c.weekday == todayWeekday).toList();
      if (todayClasses.isEmpty) return;

      final defaultCampusId = CampusData.mapUniversityToCampusId(userUniversity);
      final scheduleItems = todayClasses.map((c) {
        final classCampusId = c.campusId ?? defaultCampusId ?? '';
        return ScheduleItem(
          id: c.id,
          title: c.name,
          startTime: _combineTodayAndTime(c.start),
          endTime: _combineTodayAndTime(c.end),
          campusId: classCampusId,
          room: c.room,
        );
      }).where((item) => item.campusId.isNotEmpty).toList();

      if (scheduleItems.isEmpty) return;

      final coordinator = MySpaceWeatherCoordinator(
        weatherService: WeatherService(),
        alertService: WeatherAlertService(),
      );

      if (_hasShownWeatherAlert) return;

      final result = await coordinator.buildWeatherAlertForToday(
        schedules: scheduleItems,
      );

      if (result.shouldShow && mounted && !_hasShownWeatherAlert) {
        _hasShownWeatherAlert = true;
        WeatherAlertTheme theme;
        switch (result.level) {
          case WeatherAlertLevel.thunderstorm:
            theme = WeatherAlertTheme.thunderstorm;
            break;
          case WeatherAlertLevel.heavyRain:
            theme = WeatherAlertTheme.heavyRain;
            break;
          case WeatherAlertLevel.lightRain:
            theme = WeatherAlertTheme.lightRain;
            break;
          case WeatherAlertLevel.none:
            theme = WeatherAlertTheme.none;
            break;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showWeatherAlertDialog(result, theme: theme);
          }
        });
      }
    } catch (e) {
      debugPrint('[WeatherDialog] Lỗi kiểm tra thời tiết: $e');
    }
  }

  void _showWeatherAlertDialog(
    WeatherAlertResult result, {
    WeatherAlertTheme theme = WeatherAlertTheme.thunderstorm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2C4A6E).withOpacity(0.48),
                        const Color(0xFF16283F).withOpacity(0.96),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: theme.accent.withOpacity(0.15),
                        blurRadius: 40,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: theme.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CẢNH BÁO THỜI TIẾT',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  theme.accent.withOpacity(0.18),
                                  theme.accent.withOpacity(0.0),
                                ],
                              ),
                            ),
                            child: Lottie.asset(
                              theme.lottieAsset,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  theme.fallbackAsset,
                                  fit: BoxFit.contain,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "Hôm nay đi học có thể gặp trời mưa đấy",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF2F6FA),
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  "Đừng để bị ướt nhé!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        const Color(0xFFE6EEF4).withOpacity(0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Material(
                          color: AppColors.hcmusBlue,
                          borderRadius: BorderRadius.circular(100),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(100),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                              child: Text(
                                'Đã hiểu',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  Future<void> _syncExistingProfileData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data();
      if (userData == null) return;

      final String displayName = userData['displayName'] ?? '';
      final String? photoUrl = userData['photoUrl'];

      if (displayName.isEmpty) return;

      final firestore = FirebaseFirestore.instance;

      // 1. Sync forum_posts
      try {
        final forumQuery = await firestore
            .collection('forum_posts')
            .where('authorId', isEqualTo: user.uid)
            .get();

        if (forumQuery.docs.isNotEmpty) {
          WriteBatch batch = firestore.batch();
          int count = 0;
          for (var doc in forumQuery.docs) {
            final data = doc.data();
            if (data['isAnonymous'] != true) {
              final currentName = data['authorName'];
              final currentAvatar = data['authorAvatar'];

              if (currentName != displayName || currentAvatar != photoUrl) {
                batch.update(doc.reference, {
                  'authorName': displayName,
                  'authorAvatar': photoUrl,
                });
                count++;
                if (count >= 400) {
                  await batch.commit();
                  batch = firestore.batch();
                  count = 0;
                }
              }
            }
          }
          if (count > 0) {
            await batch.commit();
          }
        }
      } catch (e) {
        debugPrint("Error auto-syncing forum_posts: $e");
      }

      // 2. Sync study_materials
      try {
        final materialsQuery = await firestore
            .collection('study_materials')
            .where('authorId', isEqualTo: user.uid)
            .get();

        if (materialsQuery.docs.isNotEmpty) {
          WriteBatch batch = firestore.batch();
          int count = 0;
          for (var doc in materialsQuery.docs) {
            final data = doc.data();
            final currentName = data['authorName'];
            final currentAvatar = data['authorAvatar'];

            if (currentName != displayName || currentAvatar != photoUrl) {
              batch.update(doc.reference, {
                'authorName': displayName,
                'authorAvatar': photoUrl,
              });
              count++;
              if (count >= 400) {
                await batch.commit();
                batch = firestore.batch();
                count = 0;
              }
            }
          }
          if (count > 0) {
            await batch.commit();
          }
        }
      } catch (e) {
        debugPrint("Error auto-syncing study_materials: $e");
      }

      // 3. Sync comments
      try {
        final commentsQuery = await firestore
            .collectionGroup('comments')
            .where('authorId', isEqualTo: user.uid)
            .get();

        if (commentsQuery.docs.isNotEmpty) {
          WriteBatch batch = firestore.batch();
          int count = 0;
          for (var doc in commentsQuery.docs) {
            final data = doc.data();
            final currentName = data['authorName'];
            final currentAvatar = data['authorAvatar'];

            if (currentName != displayName || currentAvatar != photoUrl) {
              batch.update(doc.reference, {
                'authorName': displayName,
                'authorAvatar': photoUrl,
              });
              count++;
              if (count >= 400) {
                await batch.commit();
                batch = firestore.batch();
                count = 0;
              }
            }
          }
          if (count > 0) {
            await batch.commit();
          }
        }
      } catch (e) {
        debugPrint("Error auto-syncing comments: $e");
      }
    } catch (e) {
      debugPrint("Error in _syncExistingProfileData: $e");
    }
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    HomePage.showWalkthroughNotifier.removeListener(_onWalkthroughTriggered);
    super.dispose();
  }

  void startWalkthrough() {
    setState(() {
      _showWalkthrough = true;
      _walkthroughStep = 0;
      _selectedIndex = 0;
      EventPageNotifier.isActive.value = (_selectedIndex == 1);
      HomePage.activeTabNotifier.value = 0;
    });
  }

  void _onWalkthroughTriggered() {
    if (HomePage.showWalkthroughNotifier.value) {
      startWalkthrough();
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
      } else {
        final Map<String, dynamic> saveData = Map.from(data);
        saveData['saveType'] = saveType;
        saveData['savedAt'] = FieldValue.serverTimestamp();
        saveData['originalDocId'] = docId;
        await docRef.set(saveData);
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
    HomePage.activeTabNotifier.value = index;
    EventPageNotifier.isActive.value = (index == 1);
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
              border: Border.all(
                color: Colors.white.withOpacity(0.16),
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
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
                Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 1,
                    top: 0,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                      ),
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
                        unreadCount > 9
                            ? '9+'
                            : unreadCount.toString(),
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

  Widget _buildHeaderBackground(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      height: statusBarHeight + 102.0,
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/hcmus_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(color: Colors.black.withValues(alpha: 0.45)),
    );
  }

  Widget _buildHeaderForeground(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 35),
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
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),

            // Cụm phải: Search + Chat + Notification trong cùng pill
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.32),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nút Search
                  _buildHeaderNotificationButton(
                    tooltip: 'Tìm kiếm',
                    icon: Icons.search_rounded,
                    unreadCount: 0,
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
                      final int unreadChatCount = snapshot.data
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
                      final int unreadCount = snapshot.data
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
    );
  }

  Widget _buildMainHomeContent() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return DefaultTabController(
      length: 4,
      child: Stack(
        children: [
          // 1. Header Background (Dưới cùng)
          _buildHeaderBackground(context),

          // 2. Nội dung có thể cuộn (Giữa)
          Column(
            children: [
              // Khoảng trống để lộ phần Logo/Text của Header
              SizedBox(height: statusBarHeight + 64.0),
              Expanded(
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
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
        HomePage.activeTabNotifier.value = _selectedIndex;
      } else {
        _showWalkthrough = false;
        _selectedIndex = 0;
        EventPageNotifier.isActive.value = false;
        HomePage.activeTabNotifier.value = 0;
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
        HomePage.activeTabNotifier.value = _selectedIndex;
      });
    }
  }

  void _skipWalkthrough() {
    setState(() {
      _showWalkthrough = false;
      _selectedIndex = 0;
      EventPageNotifier.isActive.value = false;
      HomePage.activeTabNotifier.value = 0;
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
                      color: stepData.accentColor.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
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
                        right: 18,
                        height: 38,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: stepData.accentColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                stepData.icon,
                                color: stepData.accentColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                stepData.title,
                                maxLines: 1,
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
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${_walkthroughStep + 1}/${walkthroughSteps.length}",
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.none,
                                  color: isDarkMode ? Colors.white70 : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        left: 18,
                        right: 18,
                        top: 66,
                        height: 110,
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

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final statusBarStyle = (_selectedIndex == 4)
        ? (isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
        : SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyle,
      child: PopScope(
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