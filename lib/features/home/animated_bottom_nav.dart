import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ── Drop-in usage ───────────────────────────────────────────
//
//   AnimatedBottomNav(
//     currentIndex: _selectedIndex,
//     onTap: _onItemTapped,
//     items: [
//       AnimatedNavItem(icon: 'assets/icons/home.svg',    label: 'Home'),
//       AnimatedNavItem(icon: 'assets/icons/event.svg',   label: 'Sự kiện'),
//       AnimatedNavItem(icon: 'assets/icons/chat.svg',    label: 'Hỏi Đáp'),
//       AnimatedNavItem(icon: 'assets/icons/space.svg',   label: 'Góc nhỏ'),
//       AnimatedNavItem(icon: 'assets/icons/account.svg', label: 'Tài Khoản'),
//     ],
//   )
// ───────────────────────────────────────────────────────────

class AnimatedNavItem {
  final String icon;
  final String label;
  const AnimatedNavItem({required this.icon, required this.label});
}

class AnimatedBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AnimatedNavItem> items;

  // Change these to nullable so we can detect if the user provided them
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? pillColor;
  final Color? backgroundColor;

  const AnimatedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.activeColor,
    this.inactiveColor,
    this.pillColor,
    this.backgroundColor,
  });

  @override
  State<AnimatedBottomNav> createState() => _AnimatedBottomNavState();
}

class _AnimatedBottomNavState extends State<AnimatedBottomNav>
    with SingleTickerProviderStateMixin {
  late int _previousIndex;
  static const Curve _spring = _SpringCurve();

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(AnimatedBottomNav old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _previousIndex = old.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;

    // --- Dark Mode Logic ---
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Use provided colors OR fallback to theme-specific defaults
    final effectiveBgColor = widget.backgroundColor ??
        (isDarkMode ? const Color(0xFF16161F) : Colors.white);

    final effectiveActiveColor = widget.activeColor ?? const Color(0xFF457EC0);

    final effectiveInactiveColor = widget.inactiveColor ??
        (isDarkMode ? Colors.white38 : const Color(0xFF8E8E93));

    final effectivePillColor = widget.pillColor ??
        effectiveActiveColor.withOpacity(0.1);

    return Container(
      color: effectiveBgColor, // Use effective color
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final itemWidth = totalWidth / count;

              return Stack(
                children: [
                  // Sliding pill background
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    curve: _spring,
                    left: widget.currentIndex * itemWidth + itemWidth * 0.1,
                    top: 8,
                    width: itemWidth * 0.8,
                    height: 46,
                    child: Container(
                      decoration: BoxDecoration(
                        color: effectivePillColor, // Use effective color
                        borderRadius: BorderRadius.circular(23),
                      ),
                    ),
                  ),

                  // Nav items
                  Row(
                    children: List.generate(count, (i) {
                      return _NavItemWidget(
                        item: widget.items[i],
                        isSelected: widget.currentIndex == i,
                        activeColor: effectiveActiveColor,   // Use effective color
                        inactiveColor: effectiveInactiveColor, // Use effective color
                        onTap: () => widget.onTap(i),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Single nav item ─────────────────────────────────────────
class _NavItemWidget extends StatelessWidget {
  final AnimatedNavItem item;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.item,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          // Lift the selected item slightly
          transform: Matrix4.translationValues(
            0,
            isSelected ? -2.0 : 0.0,
            0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                item.icon,
                width: 26,
                height: 26,
                colorFilter: ColorFilter.mode(
                  isSelected ? activeColor : inactiveColor,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  letterSpacing: 0.3,
                  fontWeight:
                  isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Spring curve (fast-out + slight overshoot) ──────────────
class _SpringCurve extends Curve {
  const _SpringCurve();

  @override
  double transformInternal(double t) {
    // Exponential decay spring: settles at 1 with a small overshoot
    const double damping   = 18.0;
    const double stiffness = 200.0;
    // Simplified spring formula (critically overdamped-ish with bounce)
    return 1 -
        (1 - t) *
            (1 +
                1.2 * t * (1 - t) * (1 - t));
  }
}