import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// ══════════════════════════════════════════════════════════════
///  NOTIFICATION SERVICE — Production-grade FCM + Local + Supabase
///  Handles push, in-app, device tokens, and realtime sync
/// ══════════════════════════════════════════════════════════════
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _realtimeChannel;
  final StreamController<Map<String, dynamic>> _notificationStream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get onNotification => _notificationStream.stream;

  bool _initialized = false;

  // ── Android notification channel ──
  static const _androidChannel = AndroidNotificationChannel(
    'needin_notifications',
    'Needin Notifications',
    description: 'Notifications from Needin app',
    importance: Importance.high,
    playSound: true,
  );

  /// Initialize the entire notification stack
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. Request permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[Notifications] Permission: ${settings.authorizationStatus}');

      // 2. Setup local notifications plugin
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create Android notification channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      // 3. Handle FCM messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from a terminated state notification
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // 4. Save device token
      await _saveDeviceToken();
      _fcm.onTokenRefresh.listen((token) => _saveDeviceToken(token: token));

      debugPrint('[Notifications] ✅ Initialized successfully');
    } catch (e) {
      debugPrint('[Notifications] ⚠️ Init error: $e');
    }
  }

  /// Start realtime subscription for in-app notifications
  void startRealtimeSubscription() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase
        .channel('notifications:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            debugPrint('[Notifications] Realtime: ${newRecord['title']}');
            _notificationStream.add(newRecord);
          },
        )
        .subscribe();

    debugPrint('[Notifications] 🔴 Realtime subscription active for $uid');
  }

  /// Stop realtime subscription
  void stopRealtimeSubscription() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  // ── FCM Token Management ──

  Future<void> _saveDeviceToken({String? token}) async {
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) return;

      final deviceToken = token ?? await _fcm.getToken();
      if (deviceToken == null) return;

      await _supabase.from('user_devices').upsert({
        'user_id': uid,
        'device_token': deviceToken,
        'platform': 'android',
        'is_active': true,
        'last_seen_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,device_token');

      debugPrint('[Notifications] Token saved: ${deviceToken.substring(0, 20)}...');
    } catch (e) {
      debugPrint('[Notifications] Token save error: $e');
    }
  }

  /// Remove device token on logout
  Future<void> removeDeviceToken() async {
    try {
      final uid = AuthService().currentUser?.uid;
      final deviceToken = await _fcm.getToken();
      if (uid == null || deviceToken == null) return;

      await _supabase
          .from('user_devices')
          .update({'is_active': false})
          .eq('user_id', uid)
          .eq('device_token', deviceToken);
    } catch (e) {
      debugPrint('[Notifications] Token removal error: $e');
    }
  }

  // ── FCM Message Handlers ──

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[Notifications] Foreground: ${message.notification?.title}');

    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data['action_route'],
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[Notifications] Opened: ${message.data}');
    // Deep link handling — the payload contains the route
    final route = message.data['action_route'];
    if (route != null) {
      _notificationStream.add({
        'action_route': route,
        'action_payload': message.data,
        '_tapped': true,
      });
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      _notificationStream.add({
        'action_route': response.payload,
        '_tapped': true,
      });
    }
  }

  // ── Database Operations ──

  /// Fetch notifications for current user
  Future<List<Map<String, dynamic>>> getNotifications({int limit = 30, int offset = 0}) async {
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) return [];

      final result = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .eq('is_archived', false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('[Notifications] Fetch error: $e');
      return [];
    }
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) return 0;

      final result = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', uid)
          .eq('is_read', false)
          .eq('is_archived', false);

      return (result as List).length;
    } catch (e) {
      debugPrint('[Notifications] Unread count error: $e');
      return 0;
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('[Notifications] Mark read error: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) return;

      await _supabase
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[Notifications] Mark all read error: $e');
    }
  }

  /// Archive a notification
  Future<void> archiveNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_archived': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('[Notifications] Archive error: $e');
    }
  }

  /// Create a local notification (for in-app events)
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
    String category = 'system',
    String? actionRoute,
    Map<String, dynamic>? actionPayload,
    String priority = 'normal',
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'category': category,
        'action_route': actionRoute,
        'action_payload': actionPayload ?? {},
        'priority': priority,
      });
    } catch (e) {
      debugPrint('[Notifications] Create error: $e');
    }
  }

  // ── Notification Preferences ──

  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) return _defaultPreferences();

      final result = await _supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      return result ?? _defaultPreferences();
    } catch (e) {
      return _defaultPreferences();
    }
  }

  Future<void> updatePreferences(Map<String, dynamic> prefs) async {
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) return;

      await _supabase.from('notification_preferences').upsert({
        'user_id': uid,
        ...prefs,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[Notifications] Prefs update error: $e');
    }
  }

  Map<String, dynamic> _defaultPreferences() => {
    'push_enabled': true,
    'in_app_enabled': true,
    'messages_enabled': true,
    'bookings_enabled': true,
    'payments_enabled': true,
    'marketing_enabled': true,
    'security_enabled': true,
    'sound_enabled': true,
    'vibration_enabled': true,
  };

  void dispose() {
    stopRealtimeSubscription();
    _notificationStream.close();
  }
}
