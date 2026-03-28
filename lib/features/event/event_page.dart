import 'package:flutter/material.dart';
import 'discover_event_tab.dart';
import 'my_event_tab.dart';

class EventPage extends StatefulWidget {
  const EventPage({super.key});

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          backgroundColor: const Color(0xFF6797E1),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverAppBar(
                  expandedHeight: 120.0,
                  pinned: true,
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
                        Container(color: isDarkMode ? Colors.black54 : Colors.black38),
                        const Positioned(
                          left: 20,
                          bottom: 80,
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
                    IconButton(icon: const Icon(Icons.notifications_none_rounded, color: Colors.white), onPressed: () {}),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(60),
                    child: Container(
                      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: TabBar(
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: const Color(0xFF6797E1).withOpacity(isDarkMode ? 0.3 : 0.2),
                        ),
                        labelColor: isDarkMode ? const Color(0xFF91B5EE) : const Color(0xFF003366),
                        unselectedLabelColor: isDarkMode ? Colors.white38 : Colors.grey,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: 'Khám Phá'),
                          Tab(text: 'Sự Kiện của tôi'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: const TabBarView(
            children: [
              DiscoverEventTab(),
              MyEventTab(),
            ],
          ),
        ),
      ),
    );
  }
}