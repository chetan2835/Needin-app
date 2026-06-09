import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../../screens/notifications/notification_center_page.dart';

/// ══════════════════════════════════════════════════════════════
///  IN-APP NOTIFICATION BANNER — Slide-down toast overlay
///  Wraps the app content and shows animated banners on new notifications
/// ══════════════════════════════════════════════════════════════
class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;

  const InAppNotificationOverlay({super.key, required this.child});

  @override
  State<InAppNotificationOverlay> createState() => _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _currentNotification;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub?.cancel();
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    _sub = provider.notifications.isEmpty ? null : null; // dummy — actual subscription below

    // Listen to the notification service stream via provider's underlying service
    _sub = _listenToRealtimeStream();
  }

  StreamSubscription? _listenToRealtimeStream() {
    try {
      final provider = Provider.of<NotificationProvider>(context, listen: false);
      // We intercept notifications that arrive in real-time
      // The provider already adds them; we just need to detect new ones
      int previousCount = provider.notifications.length;

      return Stream.periodic(const Duration(milliseconds: 500)).listen((_) {
        if (!mounted) return;
        final current = Provider.of<NotificationProvider>(context, listen: false);
        if (current.notifications.length > previousCount && current.notifications.isNotEmpty) {
          final newest = current.notifications.first;
          if (newest['_tapped'] != true) {
            _showBanner(newest);
          }
          previousCount = current.notifications.length;
        }
      });
    } catch (_) {
      return null;
    }
  }

  void _showBanner(Map<String, dynamic> notification) {
    if (_currentNotification != null) {
      _animController.reverse().then((_) {
        if (mounted) _displayBanner(notification);
      });
    } else {
      _displayBanner(notification);
    }
  }

  void _displayBanner(Map<String, dynamic> notification) {
    setState(() => _currentNotification = notification);
    _animController.forward();

    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _dismissBanner();
    });
  }

  void _dismissBanner() {
    _animController.reverse().then((_) {
      if (mounted) setState(() => _currentNotification = null);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _autoDismissTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentNotification != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: SlideTransition(
              position: _slideAnimation,
              child: GestureDetector(
                onTap: () {
                  _dismissBanner();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationCenterPage()),
                  );
                },
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta != null && details.primaryDelta! < -5) {
                    _dismissBanner();
                  }
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF05A4F).withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.notifications, color: Color(0xFFF05A4F), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentNotification?['title']?.toString() ?? 'Notification',
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentNotification?['body']?.toString() ?? '',
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _dismissBanner,
                          child: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
