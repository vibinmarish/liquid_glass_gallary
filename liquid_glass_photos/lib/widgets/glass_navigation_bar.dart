import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  
  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// iOS 26 style navigation bar - Liquid Glass translucent
/// 2 tabs only: Library, Albums (removed Search & Utilities per user request)
class GlassNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<NavItem> items;
  
  const GlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.items = const [
      NavItem(
        icon: Icons.photo_library_outlined,
        activeIcon: Icons.photo_library,
        label: 'Library',
      ),
      NavItem(
        icon: Icons.photo_album_outlined,
        activeIcon: Icons.photo_album,
        label: 'Albums',
      ),
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (index) {
          return Expanded(
            child: _NavBarItem(
              item: items[index],
              isSelected: index == selectedIndex,
              onTap: () => onItemSelected(index),
            ),
          );
        }),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(25),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? GlassColors.primary : Colors.white.withValues(alpha: 0.8),
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                color: isSelected ? GlassColors.primary : Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
