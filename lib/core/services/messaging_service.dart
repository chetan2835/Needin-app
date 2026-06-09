import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// ══════════════════════════════════════════════════════════════
///  NEEDIN EXPRESS — Production Messaging Service
///  Real-time chat between senders and travelers via Supabase.
/// ══════════════════════════════════════════════════════════════
class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ── Get or Create Conversation ──
  Future<Map<String, dynamic>?> getOrCreateConversation({
    required String bookingId,
    required String travelerId,
    required String senderId,
    String? journeyId,
  }) async {
    try {
      // Check if conversation already exists for this booking
      final existing = await _client
          .from('conversations')
          .select()
          .eq('booking_id', bookingId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('MESSAGING: Existing conversation found for booking $bookingId');
        return existing;
      }

      // Create new conversation
      final newConvo = await _client.from('conversations').insert({
        'booking_id': bookingId,
        'journey_id': journeyId,
        'traveler_id': travelerId,
        'sender_id': senderId,
        'last_message': 'Booking confirmed — start chatting!',
        'last_message_time': DateTime.now().toUtc().toIso8601String(),
      }).select().single();

      debugPrint('MESSAGING: ✅ New conversation created for booking $bookingId');
      return newConvo;
    } catch (e) {
      debugPrint('MESSAGING: ❌ Error creating conversation: $e');
      return null;
    }
  }

  // ── Get All Conversations for User ──
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    try {
      final response = await _client
          .from('conversations')
          .select()
          .or('sender_id.eq.$userId,traveler_id.eq.$userId')
          .order('last_message_time', ascending: false);

      final conversations = List<Map<String, dynamic>>.from(response as List);
      debugPrint('MESSAGING: Fetched ${conversations.length} conversations for $userId');
      return conversations;
    } catch (e) {
      debugPrint('MESSAGING: ❌ Error fetching conversations: $e');
      return [];
    }
  }

  // ── Get Messages for a Conversation ──
  Future<List<Map<String, dynamic>>> getMessages(String conversationId, {int limit = 100}) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('is_deleted', false)
          .order('created_at', ascending: true)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('MESSAGING: ❌ Error fetching messages: $e');
      return [];
    }
  }

  // ── Send Message ──
  Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return null;

    try {
      // Insert message
      final message = await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_user_id': uid,
        'message_text': text,
        'message_type': 'text',
      }).select().single();

      // Update conversation metadata
      // Determine which unread counter to increment
      final convo = await _client
          .from('conversations')
          .select('sender_id, traveler_id')
          .eq('id', conversationId)
          .single();

      final isSender = convo['sender_id'] == uid;
      final unreadField = isSender ? 'unread_count_traveler' : 'unread_count_sender';

      await _client.from('conversations').update({
        'last_message': text,
        'last_message_time': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        unreadField: (convo[unreadField] as int? ?? 0) + 1,
      }).eq('id', conversationId);

      return message;
    } catch (e) {
      debugPrint('MESSAGING: ❌ Error sending message: $e');
      return null;
    }
  }

  // ── Mark Messages as Read ──
  Future<void> markAsRead(String conversationId, String userId) async {
    try {
      final convo = await _client
          .from('conversations')
          .select('sender_id, traveler_id')
          .eq('id', conversationId)
          .single();

      final isSender = convo['sender_id'] == userId;
      final unreadField = isSender ? 'unread_count_sender' : 'unread_count_traveler';

      await _client.from('conversations').update({
        unreadField: 0,
      }).eq('id', conversationId);

      // Also mark individual messages as read
      await _client.from('messages').update({
        'is_read': true,
      }).eq('conversation_id', conversationId).neq('sender_user_id', userId);
    } catch (e) {
      debugPrint('MESSAGING: ❌ Error marking as read: $e');
    }
  }

  // ── Delete Message (soft) ──
  Future<bool> deleteMessage(String messageId) async {
    try {
      await _client.from('messages').update({
        'is_deleted': true,
      }).eq('id', messageId);
      return true;
    } catch (e) {
      debugPrint('MESSAGING: ❌ Error deleting message: $e');
      return false;
    }
  }

  // ── Subscribe to Conversations (realtime) ──
  RealtimeChannel subscribeToConversations(String userId, void Function(dynamic) callback) {
    return _client
        .channel('user_conversations:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            debugPrint('MESSAGING REALTIME: Conversation update: ${payload.eventType}');
            callback(payload);
          },
        )
        .subscribe();
  }

  // ── Subscribe to Messages (realtime) ──
  RealtimeChannel subscribeToMessages(String conversationId, void Function(dynamic) callback) {
    return _client
        .channel('chat:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            debugPrint('MESSAGING REALTIME: New message in $conversationId');
            callback(payload);
          },
        )
        .subscribe();
  }
}
