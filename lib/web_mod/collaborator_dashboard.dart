import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'collaborator/sidebar.dart';
import 'collaborator/overview_page.dart';
import 'collaborator/activities_page.dart';
import 'collaborator/create_activity_page.dart';
import 'collaborator/attendance_page.dart';
import 'collaborator/create_news_page.dart';
import 'collaborator/news_list_page.dart';

class CollaboratorDashboard extends StatefulWidget {
  const CollaboratorDashboard({super.key});

  @override
  State<CollaboratorDashboard> createState() => _CollaboratorDashboardState();
}

class _CollaboratorDashboardState extends State<CollaboratorDashboard> {
  int _selectedIndex = 2; // Default to Overview (Tổng quan)
  String? _selectedActivityId;
  Map<String, dynamic>? _selectedActivityData;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          CollaboratorSidebar(
            selectedIndex: _selectedIndex,
            user: user,
            onMenuSelected: (index) {
              setState(() {
                _selectedIndex = index;

                if (index != 5) {
                  _selectedActivityId = null;
                  _selectedActivityData = null;
                }
              });
            },
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 22),
                  color: Colors.white,
                  child: Text(
                    _pageTitle(),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1F37),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _pageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Tin tức của tôi';
      case 1:
        return 'Đăng tin tức mới';
      case 2:
        return 'Tổng quan hoạt động';
      case 3:
        return 'Hoạt động & Sự kiện của tôi';
      case 4:
        return 'Tạo hoạt động & sự kiện mới';
      case 5:
        return 'Điểm danh sinh viên';
      default:
        return 'MYUNI CTV';
    }
  }

  Widget _buildContent() {
    if (_selectedIndex == 0) {
      return NewsListPage(
        onNavigateToCreate: () {
          setState(() => _selectedIndex = 1);
        },
      );
    }

    if (_selectedIndex == 1) {
      return CreateNewsPage(
        onCreated: () {
          setState(() => _selectedIndex = 0);
        },
      );
    }

    if (_selectedIndex == 2) {
      return OverviewPage(
        onCreateActivity: () {
          setState(() => _selectedIndex = 4);
        },
        onOpenActivities: () {
          setState(() => _selectedIndex = 3);
        },
        onOpenAttendance: (activityId, data) {
          setState(() {
            _selectedActivityId = activityId;
            _selectedActivityData = data;
            _selectedIndex = 5;
          });
        },
      );
    }

    if (_selectedIndex == 3) {
      return ActivitiesPage(
        onOpenAttendance: (activityId, data) {
          setState(() {
            _selectedActivityId = activityId;
            _selectedActivityData = data;
            _selectedIndex = 5;
          });
        },
      );
    }

    if (_selectedIndex == 4) {
      return CreateActivityPage(
        onCreated: () {
          setState(() {
            _selectedIndex = 3;
          });
        },
      );
    }

    return AttendancePage(
      selectedActivityId: _selectedActivityId,
      selectedActivityData: _selectedActivityData,
      onBackToActivities: () {
        setState(() {
          _selectedIndex = 3;
          _selectedActivityId = null;
          _selectedActivityData = null;
        });
      },
      onChooseActivity: () {
        setState(() {
          _selectedIndex = 3;
        });
      },
    );
  }
}