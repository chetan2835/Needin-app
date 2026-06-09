import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/notification_provider.dart';

/// ══════════════════════════════════════════════════════════════
///  NOTIFICATION CENTER — Full notification inbox screen
///  Tabs: All, Messages, Bookings, Payments, System
///  Swipe to archive, pull to refresh, empty states
/// ══════════════════════════════════════════════════════════════
class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _tabs = [
    {'label': 'All', 'category': 'all', 'icon': Icons.notifications},
    {'label': 'Messages', 'category': 'message', 'icon': Icons.chat_bubble},
    {'label': 'Bookings', 'category': 'booking', 'icon': Icons.luggage},
    {'label': 'System', 'category': 'system', 'icon': Icons.settings},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Consumer<NotificationProvider>(
                        builder: (context, provider, _) {
                          if (!provider.hasUnread) return const SizedBox.shrink();
                          return GestureDetector(
                            onTap: () => provider.markAllAsRead(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF05A4F).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Read All',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF05A4F),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: const Color(0xFFF05A4F),
                    unselectedLabelColor: const Color(0xFF94A3B8),
                    indicatorColor: const Color(0xFFF05A4F),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: _tabs.map((t) => Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t['icon'] as IconData, size: 16),
                          const SizedBox(width: 6),
                          Text(t['label'] as String),
                        ],
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: Consumer<NotificationProvider>(
                builder: (context, provider, _) {
                  return TabBarView(
                    controller: _tabController,
                    children: _tabs.map((tab) {
                      final category = tab['category'] as String;
                      final items = provider.getByCategory(category);
                      return _buildNotificationList(items, provider);
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<Map<String, dynamic>> items, NotificationProvider provider) {
    if (provider.isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF05A4F)));
    }

    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: const Color(0xFFF05A4F),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final notification = items[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 250 + index * 50),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Dismissible(
              key: Key(notification['id']?.toString() ?? '$index'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.archive_outlined, color: Colors.white, size: 24),
              ),
              onDismissed: (_) {
                final id = notification['id']?.toString();
                if (id != null) provider.archive(id);
              },
              child: _buildNotificationCard(notification, provider),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, NotificationProvider provider) {
    final isRead = notification['is_read'] == true;
    final title = notification['title']?.toString() ?? '';
    final body = notification['body']?.toString() ?? '';
    final category = notification['category']?.toString() ?? 'system';
    final createdAt = notification['created_at']?.toString();

    return GestureDetector(
      onTap: () {
        final id = notification['id']?.toString();
        if (id != null && !isRead) {
          provider.markAsRead(id);
        }
        // Deep link navigation based on action_route
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF05A4F).withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead ? const Color(0xFFF1F5F9) : const Color(0xFFF05A4F).withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getCategoryIcon(category), color: _getCategoryColor(category), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF05A4F),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatRelativeTime(createdAt),
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF05A4F).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined, color: Color(0xFFF05A4F), size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'No notifications yet',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We\'ll notify you when something happens',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'journey': return Icons.flight_takeoff;
      case 'parcel': return Icons.inventory_2;
      case 'message': return Icons.chat_bubble;
      case 'booking': return Icons.luggage;
      case 'payment': return Icons.account_balance_wallet;
      case 'auth': return Icons.security;
      case 'profile': return Icons.person;
      case 'rating': return Icons.star;
      case 'promo': return Icons.local_offer;
      default: return Icons.notifications;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'journey': return const Color(0xFFF05A4F);
      case 'parcel': return const Color(0xFF3B82F6);
      case 'message': return const Color(0xFF8B5CF6);
      case 'booking': return const Color(0xFF10B981);
      case 'payment': return const Color(0xFFF05A4F);
      case 'auth': return const Color(0xFFEF4444);
      case 'profile': return const Color(0xFF6366F1);
      case 'rating': return const Color(0xFFF37A72);
      case 'promo': return const Color(0xFF14B8A6);
      default: return const Color(0xFF64748B);
    }
  }

  String _formatRelativeTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
