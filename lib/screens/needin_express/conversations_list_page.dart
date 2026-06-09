import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/services/messaging_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_bottom_navigation.dart';
import '../../core/widgets/email_verification_gate.dart';
import 'chat_page.dart';

/// ══════════════════════════════════════════════════════════════
///  PRODUCTION: Conversations List Page
///  Shows all chat threads for the currently logged-in user.
/// ══════════════════════════════════════════════════════════════
class ConversationsListPage extends StatefulWidget {
  const ConversationsListPage({super.key});

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  supabase.RealtimeChannel? _realtimeChannel;
  final Map<String, Map<String, dynamic>?> _profileCache = {};

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _setupRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    _realtimeChannel = MessagingService().subscribeToConversations(uid, (_) {
      if (mounted) _fetchConversations(isSilent: true);
    });
  }

  Future<void> _fetchConversations({bool isSilent = false}) async {
    if (!isSilent && mounted) setState(() => _isLoading = true);
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final convos = await MessagingService().getConversations(uid);

    // Enrich with other user's profile
    for (final convo in convos) {
      final otherUserId = convo['sender_id'] == uid
          ? convo['traveler_id']
          : convo['sender_id'];
      if (otherUserId != null && !_profileCache.containsKey(otherUserId)) {
        _profileCache[otherUserId] = await SupabaseService().getUserProfile(otherUserId);
      }
      convo['_other_profile'] = _profileCache[otherUserId];
    }

    if (mounted) {
      setState(() {
        _conversations = convos;
        _isLoading = false;
      });
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "Messages",
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF05A4F)))
          : _conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFFF05A4F),
                  onRefresh: () => _fetchConversations(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 80,
                      endIndent: 24,
                      color: Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final convo = _conversations[index];
                      final profile = convo['_other_profile'] as Map<String, dynamic>?;
                      final name = profile?['full_name']?.toString() ?? 'User';
                      final avatar = profile?['profile_image_url']?.toString() ?? profile?['avatar_url']?.toString();
                      final lastMsg = convo['last_message']?.toString() ?? '';
                      final time = _formatTime(convo['last_message_time']?.toString());
                      final isSender = convo['sender_id'] == uid;
                      final unread = isSender
                          ? (convo['unread_count_sender'] as int? ?? 0)
                          : (convo['unread_count_traveler'] as int? ?? 0);

                      return EmailVerificationGate(
                        actionDescription: 'view messages',
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  conversationId: convo['id'].toString(),
                                  otherUserName: name,
                                  otherUserAvatar: avatar,
                                ),
                              ),
                            );
                            _fetchConversations(isSilent: true);
                          },
                          behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          color: unread > 0 ? const Color(0xFFFFF5F4) : Colors.transparent,
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFF1F5F9),
                                  border: Border.all(
                                    color: unread > 0 ? const Color(0xFFF05A4F) : const Color(0xFFE2E8F0),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: avatar != null && avatar.isNotEmpty
                                      ? Image.network(
                                          avatar,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFF94A3B8), size: 24),
                                        )
                                      : const Icon(Icons.person, color: Color(0xFF94A3B8), size: 24),
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Name + Message
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontSize: 15,
                                              fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                                              color: const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          time,
                                          style: TextStyle(
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontSize: 11,
                                            color: unread > 0 ? const Color(0xFFF05A4F) : const Color(0xFF94A3B8),
                                            fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lastMsg,
                                            style: TextStyle(
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontSize: 13,
                                              color: unread > 0 ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                                              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (unread > 0)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFF05A4F),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '$unread',
                                              style: const TextStyle(
                                                fontFamily: 'Plus Jakarta Sans',
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ));
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline, color: Color(0xFFF05A4F), size: 36),
            ),
            const SizedBox(height: 24),
            const Text(
              "No messages yet",
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Conversations will appear here when\na booking is made between you and\na traveler or sender.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
