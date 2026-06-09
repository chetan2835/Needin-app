import 'package:flutter/material.dart';
import '../../screens/needin_express/express_dashboard_page.dart';
import '../../screens/needin_express/my_bookings_page.dart';
import '../../screens/needin_express/express_profile_page.dart';
import '../../screens/needin_express/conversations_list_page.dart';

/// Persistent bottom navigation bar used across the Needin Express module.
///
/// Tabs:
///   0 – Home (Express Dashboard)
///   1 – My Bookings (Parcel Bookings)
///   2 – Messages (placeholder)
///   3 – Profile
///
/// Usage:
/// ```dart
/// Scaffold(
///   bottomNavigationBar: const AppBottomNavigation(currentIndex: 1),
///   ...
/// )
/// ```
class AppBottomNavigation extends StatelessWidget {
  /// Which tab is currently selected (0-3).
  final int currentIndex;

  const AppBottomNavigation({super.key, required this.currentIndex});

  static const Color _activeColor = Color(0xFFF25F5C);
  static const Color _inactiveColor = Color(0xFF94A3B8);

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_filled, label: 'Home'),
    _NavItem(icon: Icons.inventory_2, label: 'My Bookings'),
    _NavItem(icon: Icons.chat_bubble_outline, label: 'Messages'),
    _NavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return; // already on this tab

    switch (index) {
      case 0:
        // Navigate to Home – preserve stack root, push dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ExpressDashboardPage()),
          (route) => route.isFirst,
        );
        break;
      case 1:
        // Navigate to My Bookings – preserve stack root
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MyBookingsPage()),
          (route) => route.isFirst,
        );
        break;
      case 2:
        // Navigate to Messages – preserve stack root
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ConversationsListPage()),
          (route) => route.isFirst,
        );
        break;
      case 3:
        // Navigate to Profile – preserve stack root
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ExpressProfilePage()),
          (route) => route.isFirst,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 12, top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final isActive = i == currentIndex;
          return GestureDetector(
            onTap: () => _onTap(context, i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: isActive ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      item.icon,
                      color: isActive ? _activeColor : _inactiveColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive ? _activeColor : _inactiveColor,
                    ),
                  ),
                  // Active indicator dot
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(top: 4),
                    width: isActive ? 4 : 0,
                    height: isActive ? 4 : 0,
                    decoration: const BoxDecoration(
                      color: _activeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Internal model for navigation items.
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
