import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';

/// ══════════════════════════════════════════════════════════════
///  NOTIFICATION PROVIDER — Reactive state for notification UI
///  Powers: bell badge, notification center, in-app banners
/// ══════════════════════════════════════════════════════════════
class NotificationProvider with ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  StreamSubscription? _realtimeSub;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get hasUnread => _unreadCount > 0;

  /// Initialize and start listening
  Future<void> initialize() async {
    await _service.initialize();
    _service.startRealtimeSubscription();

    // Listen to realtime insertions for in-app banners
    _realtimeSub = _service.onNotification.listen((notification) {
      if (notification['_tapped'] == true) return; // skip tap events
      _notifications.insert(0, notification);
      _unreadCount++;
      notifyListeners();
    });

    await refresh();
  }

  /// Refresh all notifications from DB
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await _service.getNotifications();
      _unreadCount = await _service.getUnreadCount();
    } catch (e) {
      debugPrint('[NotificationProvider] Refresh error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Mark single notification as read
  Future<void> markAsRead(String id) async {
    await _service.markAsRead(id);
    final idx = _notifications.indexWhere((n) => n['id'] == id);
    if (idx != -1) {
      _notifications[idx]['is_read'] = true;
      _notifications[idx]['read_at'] = DateTime.now().toIso8601String();
      if (_unreadCount > 0) _unreadCount--;
      notifyListeners();
    }
  }

  /// Mark all as read
  Future<void> markAllAsRead() async {
    await _service.markAllAsRead();
    for (var n in _notifications) {
      n['is_read'] = true;
    }
    _unreadCount = 0;
    notifyListeners();
  }

  /// Archive (dismiss) notification
  Future<void> archive(String id) async {
    await _service.archiveNotification(id);
    final idx = _notifications.indexWhere((n) => n['id'] == id);
    if (idx != -1) {
      if (_notifications[idx]['is_read'] != true && _unreadCount > 0) {
        _unreadCount--;
      }
      _notifications.removeAt(idx);
      notifyListeners();
    }
  }

  /// Filter by category
  List<Map<String, dynamic>> getByCategory(String category) {
    if (category == 'all') return _notifications;
    return _notifications.where((n) => n['category'] == category).toList();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _service.stopRealtimeSubscription();
    super.dispose();
  }
}
