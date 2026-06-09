import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../../screens/notifications/notification_center_page.dart';

/// ══════════════════════════════════════════════════════════════
///  NOTIFICATION BELL — Animated bell icon with unread badge
///  Drop into any AppBar or header for instant notification access
/// ══════════════════════════════════════════════════════════════
class NotificationBell extends StatelessWidget {
  final Color iconColor;
  final double iconSize;

  const NotificationBell({
    super.key,
    this.iconColor = const Color(0xFF64748B),
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const NotificationCenterPage(),
                transitionDuration: const Duration(milliseconds: 300),
                transitionsBuilder: (_, animation, __, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: child,
                  );
                },
              ),
            );
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_outlined, color: iconColor, size: iconSize),
                if (provider.hasUnread)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: Container(
                        width: provider.unreadCount > 9 ? 20 : 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF05A4F),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            provider.unreadCount > 99 ? '99+' : provider.unreadCount.toString(),
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
