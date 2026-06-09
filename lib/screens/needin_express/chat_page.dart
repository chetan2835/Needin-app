import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/services/messaging_service.dart';
import '../../core/services/auth_service.dart';

/// ══════════════════════════════════════════════════════════════
///  PRODUCTION: Real-Time Chat Page
///  Premium messaging UI with live Supabase subscriptions.
/// ══════════════════════════════════════════════════════════════
class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  supabase.RealtimeChannel? _messageChannel;

  String get _uid => AuthService().currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealtime();
    // Mark as read when opening
    MessagingService().markAsRead(widget.conversationId, _uid);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _messageChannel = MessagingService().subscribeToMessages(
      widget.conversationId,
      (payload) {
        if (mounted) {
          _loadMessages(isSilent: true);
          MessagingService().markAsRead(widget.conversationId, _uid);
        }
      },
    );
  }

  Future<void> _loadMessages({bool isSilent = false}) async {
    if (!isSilent && mounted) setState(() => _isLoading = true);
    final msgs = await MessagingService().getMessages(widget.conversationId);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    // Optimistic UI: add immediately
    final optimisticMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'conversation_id': widget.conversationId,
      'sender_user_id': _uid,
      'message_text': text,
      'message_type': 'text',
      'is_read': false,
      'is_deleted': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() => _messages.add(optimisticMsg));
    _scrollToBottom();

    await MessagingService().sendMessage(
      conversationId: widget.conversationId,
      text: text,
    );

    setState(() => _isSending = false);
    // Reload to get real IDs
    _loadMessages(isSilent: true);
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Message', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold)),
        content: const Text('This message will be removed.', style: TextStyle(fontFamily: 'Plus Jakarta Sans')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Plus Jakarta Sans')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontFamily: 'Plus Jakarta Sans')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await MessagingService().deleteMessage(messageId);
      _loadMessages(isSilent: true);
    }
  }

  String _formatMessageTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF1F5F9),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipOval(
                child: widget.otherUserAvatar != null && widget.otherUserAvatar!.isNotEmpty
                    ? Image.network(widget.otherUserAvatar!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 18, color: Color(0xFF94A3B8)))
                    : const Icon(Icons.person, size: 18, color: Color(0xFF94A3B8)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF05A4F)))
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Say hello! 👋',
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, color: Color(0xFF94A3B8)),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender_user_id'] == _uid;
                          final text = msg['message_text']?.toString() ?? '';
                          final time = _formatMessageTime(msg['created_at']?.toString());
                          final msgId = msg['id']?.toString() ?? '';

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: isMe ? () => _deleteMessage(msgId) : null,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? const Color(0xFFF05A4F) : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      text,
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 14,
                                        color: isMe ? Colors.white : const Color(0xFF0F172A),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 10,
                                        color: isMe ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Input Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset > 0 ? 10 : 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(fontFamily: 'Plus Jakarta Sans', color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF05A4F),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
