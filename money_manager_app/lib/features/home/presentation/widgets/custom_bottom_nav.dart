import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onFabPressed;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onFabPressed,
  });

  static const Color purpleAccent = Color(0xFF6C5CE7);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Nav items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home,
                label: 'Trang chủ',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
                isDark: isDark,
              ),
              _buildNavItem(
                icon: Icons.swap_horiz,
                label: 'Giao dịch',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
                isDark: isDark,
              ),
              const SizedBox(width: 60), // Space for FAB
              _buildNavItem(
                icon: Icons.access_time,
                label: 'Thống kê',
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
                isDark: isDark,
              ),
              _buildNavItem(
                icon: Icons.person,
                label: 'Hồ sơ',
                isActive: currentIndex == 4,
                onTap: () => onTap(4),
                isDark: isDark,
              ),
            ],
          ),

          // Floating Action Button
          Positioned(
            top: -28,
            child: GestureDetector(
              onTap: onFabPressed,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: purpleAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: purpleAccent.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? icon : _getOutlinedIcon(icon),
              color: isActive ? purpleAccent : (isDark ? Colors.grey[500] : Colors.grey[400]),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? purpleAccent : (isDark ? Colors.grey[500] : Colors.grey[400]),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getOutlinedIcon(IconData icon) {
    switch (icon) {
      case Icons.home:
        return Icons.home_outlined;
      case Icons.swap_horiz:
        return Icons.swap_horiz;
      case Icons.access_time:
        return Icons.access_time_outlined;
      case Icons.person:
        return Icons.person_outline;
      default:
        return icon;
    }
  }
}
