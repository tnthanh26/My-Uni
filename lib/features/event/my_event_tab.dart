import 'package:flutter/material.dart';

class MyEventTab extends StatefulWidget {
  const MyEventTab({super.key});

  @override
  State<MyEventTab> createState() => _MyEventTabState();
}

class _MyEventTabState extends State<MyEventTab> with SingleTickerProviderStateMixin {
  late TabController _viewTabController;
  int _selectedMonth = 3; // Mặc định tháng 3

  @override
  void initState() {
    super.initState();
    _viewTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _viewTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Builder(builder: (context) {
      return CustomScrollView(
        slivers: [
          SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),

          // --- THANH CÔNG CỤ CẤP 2 (Dropdown & View Switcher) ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // SỬ DỤNG ANIMATION BUILDER ĐỂ UPDATE CHỮ REAL-TIME KHI VUỐT
                  AnimatedBuilder(
                    animation: _viewTabController.animation!,
                    builder: (context, child) {
                      // Tính toán index dựa trên giá trị animation (0.0 -> 1.0)
                      double animValue = _viewTabController.animation!.value;
                      String label = animValue < 0.5 ? "Gần nhất" : "Tháng $_selectedMonth";

                      return _buildFilterChip(isDarkMode, label);
                    },
                  ),
                  const Spacer(),
                  // TabBar chuyển đổi View
                  Container(
                    height: 38,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white10 : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _viewTabController,
                      isScrollable: true,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF6797E1) : Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: isDarkMode ? [] : [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      labelColor: isDarkMode ? Colors.white : const Color(0xFF6797E1),
                      unselectedLabelColor: Colors.grey,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(icon: Icon(Icons.list_alt_rounded, size: 20)),
                        Tab(icon: Icon(Icons.calendar_month_outlined, size: 20)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- NỘI DUNG TAB VIEW ---
          SliverFillRemaining(
            child: TabBarView(
              controller: _viewTabController,
              children: [
                _buildListView(isDarkMode),     // Chế độ Danh sách
                _buildCalendarView(isDarkMode), // Chế độ Lịch
              ],
            ),
          ),
        ],
      );
    });
  }

  // --- WIDGETS HỖ TRỢ ---

  Widget _buildFilterChip(bool isDarkMode, String label) {
    return InkWell(
      onTap: () {
        // Chỉ cho phép chọn tháng nếu đang ở tab Lịch (index > 0.5)
        if (_viewTabController.animation!.value > 0.5) {
          _showMonthPicker(isDarkMode);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600
                )
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(bool isDarkMode) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Text('Bạn đang có 2 sự kiện sắp diễn ra',
            style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
        const SizedBox(height: 16),
        _buildSmallEventCard(isDarkMode, "Hội nghị AI", "4 giờ tới", "27/03/2026"),
        const SizedBox(height: 12),
        _buildSmallEventCard(isDarkMode, "Workshop UX", "8 giờ tới", "27/03/2026"),
      ],
    );
  }

  Widget _buildCalendarView(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lịch trình chi tiết',
              style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          // Calendar Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateItem('CN', '22', false, isDarkMode),
              _buildDateItem('T2', '23', false, isDarkMode),
              _buildDateItem('T3', '24', false, isDarkMode),
              _buildDateItem('T4', '25', false, isDarkMode),
              _buildDateItem('T5', '26', false, isDarkMode),
              _buildDateItem('T6', '27', true, isDarkMode), // Ngày hiện tại
              _buildDateItem('T7', '28', false, isDarkMode),
            ],
          ),
          const SizedBox(height: 24),
          _buildTimelineRow(isDarkMode, '14:30', 'Event 1', 'Phòng I.21', const Color(0xFFE3F2FD)),
          const SizedBox(height: 16),
          _buildTimelineRow(isDarkMode, '18:30', 'Event 2', 'Online', const Color(0xFFFFF3E0)),
        ],
      ),
    );
  }

  // --- COMPONENT CHI TIẾT ---

  Widget _buildSmallEventCard(bool isDarkMode, String title, String time, String date) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.black87,
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(
          image: NetworkImage('https://student.hcmus.edu.vn/_next/image?url=%2Fbackground.jpg&w=3840&q=75'),
          fit: BoxFit.cover, opacity: 0.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(time, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(date, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(bool isDarkMode, String time, String title, String loc, Color lightBg) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(time, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.black87)),
        const SizedBox(width: 15),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : lightBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(loc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const Spacer(),
                    const Text('Details', style: TextStyle(color: Color(0xFF6797E1), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateItem(String day, String date, bool isSelected, bool isDarkMode) {
    return Column(
      children: [
        Text(day, style: TextStyle(color: isSelected ? const Color(0xFF6797E1) : Colors.grey, fontSize: 11)),
        const SizedBox(height: 5),
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF6797E1) : Colors.transparent,
              shape: BoxShape.circle
          ),
          child: Center(
            child: Text(date, style: TextStyle(color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87), fontSize: 13)),
          ),
        ),
      ],
    );
  }

  void _showMonthPicker(bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Chọn tháng", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: List.generate(12, (i) => InkWell(
                  onTap: () {
                    setState(() => _selectedMonth = i + 1);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 70, padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedMonth == (i+1) ? const Color(0xFF6797E1) : (isDarkMode ? Colors.white10 : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text("Tháng ${i+1}")),
                  ),
                )),
              ),
            ],
          ),
        );
      },
    );
  }
}