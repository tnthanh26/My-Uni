import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'collaborator/sidebar.dart';
import 'collaborator/overview_page.dart';
import 'collaborator/activities_page.dart';
import 'collaborator/create_activity_page.dart';
import 'collaborator/attendance_page.dart';

class CollaboratorDashboard extends StatefulWidget {
  const CollaboratorDashboard({super.key});

  @override
  State<CollaboratorDashboard> createState() => _CollaboratorDashboardState();
}

class _CollaboratorDashboardState extends State<CollaboratorDashboard> {
  int _selectedIndex = 0;
  String? _selectedActivityId;
  Map<String, dynamic>? _selectedActivityData;

  @override
  void dispose() {
    super.dispose();
  }

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

                if (index == 3) {
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
        return 'Tổng quan hoạt động';
      case 1:
        return 'Hoạt động của tôi';
      case 2:
        return 'Tạo hoạt động mới';
      case 3:
        return 'Điểm danh sinh viên';
      default:
        return 'MYUNI CTV';
    }
  }

  Widget _buildContent() {
    if (_selectedIndex == 0) {
      return OverviewPage(
        onCreateActivity: () {
          setState(() => _selectedIndex = 2);
        },
        onOpenActivities: () {
          setState(() => _selectedIndex = 1);
        },
        onOpenAttendance: (activityId, data) {
          setState(() {
            _selectedActivityId = activityId;
            _selectedActivityData = data;
            _selectedIndex = 3;
          });
        },
      );
    }

    if (_selectedIndex == 1) {
      return ActivitiesPage(
        onOpenAttendance: (activityId, data) {
          setState(() {
            _selectedActivityId = activityId;
            _selectedActivityData = data;
            _selectedIndex = 3;
          });
        },
      );
    }

    if (_selectedIndex == 2) {
      return CreateActivityPage(
        onCreated: () {
          setState(() {
            _selectedIndex = 1;
          });
        },
      );
    }
    return AttendancePage(
      selectedActivityId: _selectedActivityId,
      selectedActivityData: _selectedActivityData,
      onBackToActivities: () {
        setState(() {
          _selectedIndex = 1;
          _selectedActivityId = null;
          _selectedActivityData = null;
        });
      },
      onChooseActivity: () {
        setState(() {
          _selectedIndex = 1;
        });
      },
    );
  }
}