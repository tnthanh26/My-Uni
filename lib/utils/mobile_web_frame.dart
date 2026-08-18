import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_uni/features/home/home_page.dart';

class MyUniRouteObserver extends NavigatorObserver {
  static String currentRoute = '/';
  static final ValueNotifier<String> activeRoute = ValueNotifier<String>('/');

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name != null) {
      currentRoute = route.settings.name!;
      activeRoute.value = currentRoute;
    } else {
      activeRoute.value = 'sub_route';
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute?.settings.name != null) {
      currentRoute = previousRoute!.settings.name!;
      activeRoute.value = currentRoute;
    } else {
      activeRoute.value = 'sub_route';
    }
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute?.settings.name != null) {
      currentRoute = newRoute!.settings.name!;
      activeRoute.value = currentRoute;
    } else {
      activeRoute.value = 'sub_route';
    }
  }
}

class MobileWebFrame extends StatelessWidget {
  final Widget child;

  const MobileWebFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Container(
                width: 390,
                height: 844,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(padding: const EdgeInsets.only(top: 36)),
                      child: Stack(
                        children: [
                          child,
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 36,
                            child: MobileStatusBar(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MobileStatusBar extends StatefulWidget {
  const MobileStatusBar({super.key});

  @override
  State<MobileStatusBar> createState() => _MobileStatusBarState();
}

class _MobileStatusBarState extends State<MobileStatusBar> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String timeStr =
        "${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}";

    return ValueListenableBuilder<String>(
      valueListenable: MyUniRouteObserver.activeRoute,
      builder: (context, route, _) {
        return ValueListenableBuilder<int>(
          valueListenable: HomePage.activeTabNotifier,
          builder: (context, tabIndex, _) {
            final bool isLightIcons = _isLightIcons(context, route, tabIndex);
            final Color contentColor = isLightIcons
                ? Colors.white
                : Colors.black87;

            return Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Clock
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: contentColor,
                    ),
                  ),

                  // Icons
                  Row(
                    children: [
                      Icon(
                        Icons.signal_cellular_4_bar_rounded,
                        size: 15,
                        color: contentColor,
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.wifi_rounded, size: 15, color: contentColor),
                      const SizedBox(width: 6),
                      Text(
                        "98%",
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: contentColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 22,
                        height: 11,
                        decoration: BoxDecoration(
                          border: Border.all(color: contentColor, width: 1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        padding: const EdgeInsets.all(1),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: contentColor,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 1),
                      Container(
                        width: 1.5,
                        height: 4,
                        decoration: BoxDecoration(
                          color: contentColor,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(1),
                            bottomRight: Radius.circular(1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _isLightIcons(BuildContext context, String route, int tabIndex) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (isDarkMode) return true;

    if (route == '/login' ||
        route == '/signup' ||
        route == '/otp' ||
        route == '/forgot_password' ||
        route == '/blocked' ||
        route == '/welcome') {
      return false;
    }

    if (route == '/') {
      return true;
    }

    if (route == '/home') {
      if (tabIndex == 4) {
        return false;
      }
      return true;
    }

    return false;
  }
}
