import 'package:flutter/material.dart';
import 'account/account_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const Center(child: Text('Trang chủ', style: TextStyle(fontSize: 24))),
    const Center(child: Text('Sự kiện', style: TextStyle(fontSize: 24))),
    const Center(child: Text('Hỏi Đáp', style: TextStyle(fontSize: 24))),
    const Center(child: Text('Góc Nhỏ', style: TextStyle(fontSize: 24))),
    const AccountPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 1. Kiểm tra xem người dùng hiện tại có login không
    final user = FirebaseAuth.instance.currentUser;
    final bool isGuest = user == null;

    final List<Widget> _pages = [
      const Center(child: Text('Trang chủ', style: TextStyle(fontSize: 24))),
      const Center(child: Text('Sự kiện', style: TextStyle(fontSize: 24))),
      const Center(child: Text('Hỏi Đáp', style: TextStyle(fontSize: 24))),
      const Center(child: Text('Góc Nhỏ', style: TextStyle(fontSize: 24))),

      // 2. Logic điều hướng trang Tài khoản
      isGuest ? _buildGuestAccountScreen(context) : const AccountPage(),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      // Bọc BottomNavigationBar trong Container để tùy chỉnh Border và Shadow
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
              width: 1, // Đường kẻ mảnh phía trên để phân tách với body
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2), // Đổ bóng ngược lên trên
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent, // Dùng màu của Container bên ngoài
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF6797E1),
          unselectedItemColor: isDarkMode ? Colors.white38 : Colors.grey,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0, // Tắt bóng mặc định của widget
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_available_outlined),
              activeIcon: Icon(Icons.event_available),
              label: 'Sự kiện',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Hỏi Đáp',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Góc Nhỏ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined),
              activeIcon: Icon(Icons.account_circle),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }

  // 3. Widget hiển thị khi Khách bấm vào tab Tài khoản
  Widget _buildGuestAccountScreen(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle_outlined, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text(
              'Bạn đang ở chế độ khách',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Vui lòng đăng nhập để quản lý thông tin cá nhân và sử dụng đầy đủ tính năng.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Quay về màn hình Login hoặc Welcome
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6797E1),
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text('Đăng nhập ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}