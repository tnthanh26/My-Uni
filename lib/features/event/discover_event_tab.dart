import 'package:flutter/material.dart';

class DiscoverEventTab extends StatelessWidget {
  const DiscoverEventTab({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Builder(
      builder: (context) {
        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Stack(
                              children: [
                                Image.network(
                                  'https://student.hcmus.edu.vn/_next/image?url=%2Fbackground.jpg&w=3840&q=75',
                                  height: 160, width: double.infinity, fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 12, left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                                    child: const Text('Đang Diễn Ra', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                )
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '[Khoa CNTT] Hội nghị thảo luận ứng dụng AI',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDarkMode ? Colors.white : Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: Color(0xFF6797E1)),
                                    const SizedBox(width: 4),
                                    Text('05/03/2026 - 07/03/2026', style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.grey)),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF6797E1)),
                                    const SizedBox(width: 4),
                                    Text('Cơ sở NVC', style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: 3,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}