import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/ui_utils.dart';
import '../../core/utils/transport_icon_mapper.dart';
import '../../core/utils/travel_mode_mapper.dart';
import '../../core/utils/earnings_formatter.dart';
import 'journey_detail_page.dart';
import 'post_journey_page.dart';

class MyJourneysPage extends StatefulWidget {
  const MyJourneysPage({super.key});

  @override
  State<MyJourneysPage> createState() => _MyJourneysPageState();
}

class _MyJourneysPageState extends State<MyJourneysPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allJourneys = [];
  bool _isLoading = true;
  supabase.RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadJourneys();
    _setupRealtime();
    // Trigger backend retention cleanup silently on page open
    SupabaseService().runRetentionCleanup();
  }

  void _setupRealtime() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    
    _subscription = SupabaseService().client
      .channel('my_journeys:$uid')
      .onPostgresChanges(
        event: supabase.PostgresChangeEvent.all,
        schema: 'public',
        table: 'journeys',
        callback: (payload) {
          debugPrint('REALTIME: My Journeys update received: ${payload.eventType}');
          // Delay slightly to allow the transaction to fully commit
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _loadJourneys(isSilent: true);
          });
        },
      )
      .subscribe((status, [error]) {
        debugPrint('REALTIME: My Journeys subscription status: $status');
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadJourneys({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);
    try {
      final uid = AuthService().currentUser?.uid;
      debugPrint('JOURNEYS: Loading journeys for uid=$uid');
      if (uid != null) {
        final journeys = await SupabaseService().getUserJourneys(uid);
        debugPrint('JOURNEYS: Got ${journeys.length} journeys from DB');
        if (mounted) {
          setState(() {
            _allJourneys = journeys;
            _isLoading = false;
          });
        }
      } else {
        debugPrint('JOURNEYS: ⚠️ uid is null — user not authenticated');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('JOURNEYS: ❌ Error loading journeys: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _activeJourneys {
    final now = DateTime.now();
    return _allJourneys.where((j) {
      final status = j['status']?.toString().toLowerCase() ?? '';
      final isDeleted = j['is_deleted'] == true;
      if (isDeleted) return false;
      // Must be in an active-like status
      if (status != 'active' && status != 'live' && status != 'in_progress') return false;
      // Must have departure time in the future (or today, not yet passed)
      final depTimeStr = j['departure_time']?.toString();
      if (depTimeStr != null) {
        final depDate = DateTime.tryParse(depTimeStr);
        if (depDate != null && depDate.toLocal().isBefore(now)) {
          return false; // Past departure → belongs in Expired
        }
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final da = a['departure_time']?.toString() ?? a['created_at']?.toString() ?? '';
        final db = b['departure_time']?.toString() ?? b['created_at']?.toString() ?? '';
        return da.compareTo(db); // Earliest departure first
      });
  }

  List<Map<String, dynamic>> get _expiredJourneys {
    final now = DateTime.now();
    // 30-day retention window — matches backend policy
    final retentionCutoff = now.subtract(const Duration(days: 30));

    return _allJourneys.where((j) {
      final status = j['status']?.toString().toLowerCase() ?? '';
      final isDeleted = j['is_deleted'] == true;
      if (isDeleted) return false;

      // Extract the relevant date for expiry (departure_time, fallback to created_at)
      final depTimeStr = j['departure_time']?.toString() ?? j['created_at']?.toString();
      DateTime? depDate;
      if (depTimeStr != null) {
        depDate = DateTime.tryParse(depTimeStr)?.toLocal();
      }

      // Check backend retention_expires_at first (most accurate)
      final retExpiresStr = j['retention_expires_at']?.toString();
      if (retExpiresStr != null) {
        final retExpires = DateTime.tryParse(retExpiresStr)?.toLocal();
        if (retExpires != null && retExpires.isBefore(now)) return false; // Past retention window
      }

      // Explicitly expired status
      if (status == 'expired') {
        // If no backend retention_expires_at, use client-side 30-day window
        if (retExpiresStr == null && depDate != null && depDate.isBefore(retentionCutoff)) return false;
        return true;
      }
      
      // Active but past departure time → treat as expired
      if (status == 'active' || status == 'live' || status == 'in_progress') {
        if (depDate != null && depDate.isBefore(now)) {
          if (retExpiresStr == null && depDate.isBefore(retentionCutoff)) return false;
          return true;
        }
      }
      return false;
    }).toList()
      ..sort((a, b) {
        final da = a['departure_time']?.toString() ?? a['created_at']?.toString() ?? '';
        final db = b['departure_time']?.toString() ?? b['created_at']?.toString() ?? '';
        return db.compareTo(da); // Newest first
      });
  }


  List<Map<String, dynamic>> get _draftJourneys {
    return _allJourneys.where((j) => j['status']?.toString().toLowerCase() == 'draft').toList();
  }

  String _getStatusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'live':
        return 'Live';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'draft':
        return 'Draft';
      case 'expired':
        return 'Expired';
      default:
        return 'Upcoming';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'live':
        return const Color(0xFF16A34A);
      case 'in_progress':
        return const Color(0xFFF05A4F);
      case 'completed':
        return const Color(0xFF64748B);
      case 'expired':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Color _getStatusBgColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'live':
        return const Color(0xFFDCFCE7);
      case 'in_progress':
        return const Color(0xFFFDE8E7);
      case 'completed':
        return const Color(0xFFF1F5F9);
      case 'expired':
        return const Color(0xFFE2E8F0);
      default:
        return const Color(0xFFEFF6FF);
    }
  }

  IconData _getTravelIcon(String? mode) {
    return TransportIconMapper.getIconForMode(mode);
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '--';
    return UIUtils.formatJourneyDateTime(isoDate);
  }

  String _getEarnings(Map<String, dynamic> j) {
    return EarningsFormatter.getCardEarnings(j);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        "My Journeys",
                        style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  // Notification bell
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: const Icon(Icons.notifications_none, color: Color(0xFF64748B), size: 20),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))],
                ),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF0F172A),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                unselectedLabelColor: const Color(0xFF94A3B8),
                labelStyle: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(text: "Active\n(${_activeJourneys.length})"),
                  Tab(text: "Expired\n(${_expiredJourneys.length})"),
                  Tab(text: "Drafts\n(${_draftJourneys.length})"),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFF05A4F)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildJourneyList(_activeJourneys),
                        _buildJourneyList(_expiredJourneys, isExpired: true),
                        _buildJourneyList(_draftJourneys, isDraft: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostJourneyPage())),
        backgroundColor: const Color(0xFFF05A4F),
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildJourneyList(List<Map<String, dynamic>> journeys, {bool isExpired = false, bool isDraft = false}) {
    if (journeys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.luggage_outlined, size: 64, color: const Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            const Text("No journeys found", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
            const SizedBox(height: 8),
            Text(isExpired ? "No expired journeys" : (isDraft ? "No saved drafts" : "Post a journey to see it here"), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFFCBD5E1))),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF05A4F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostJourneyPage())),
              child: const Text("Post a Journey", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJourneys,
      color: const Color(0xFFF05A4F),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
        itemCount: journeys.length,
        itemBuilder: (context, index) {
          final journey = journeys[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + index * 80),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _buildJourneyCard(journey, isDraft: isDraft, isExpired: isExpired),
          );
        },
      ),
    );
  }

  void _handleEditJourney(Map<String, dynamic> journey, bool isDraft) {
    final journeyId = journey['id']?.toString();
    if (isDraft) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostJourneyPage(
            draftId: journeyId,
            initialDraftData: journey['draft_data'] is Map ? Map<String,dynamic>.from(journey['draft_data']) : {},
          ),
        ),
      );
    } else {
      // ── EDIT TIME-WINDOW CHECK (24 hours from posting) ──
      final createdAt = journey['created_at']?.toString();
      if (createdAt != null) {
        try {
          final postedTime = DateTime.parse(createdAt);
          final hoursSincePost = DateTime.now().difference(postedTime).inHours;
          if (hoursSincePost > 24) {
            _showEditExpiredDialog(hoursSincePost);
            return;
          }
        } catch (_) {}
      }

      // Map existing journey data to the draft format so PostJourneyPage can read it natively
      final draftData = <String, dynamic>{
        'origin': journey['origin'],
        'origin_lat': journey['origin_lat'],
        'origin_lng': journey['origin_lng'],
        'destination': journey['destination'],
        'dest_lat': journey['dest_lat'] ?? journey['destination_lat'],
        'dest_lng': journey['dest_lng'] ?? journey['destination_lng'],
      };
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostJourneyPage(
            draftId: journeyId,
            initialDraftData: draftData,
          ),
        ),
      );
    }
  }

  void _showEditExpiredDialog(int hoursSincePost) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: const Color(0xFFF05A4F).withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.lock_clock, color: Color(0xFFF05A4F), size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Edit Window Closed',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Journeys can only be edited within 24 hours of posting. This journey was posted ${hoursSincePost}h ago.\n\nYou can delete this journey and create a new one instead.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: Color(0xFF64748B), height: 1.5),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF05A4F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Got it', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteJourney(String journeyId) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DeleteJourneyModal(journeyId: journeyId),
    );

    if (result == true && mounted) {
      _loadJourneys();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journey deleted successfully'),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PostJourneyPage()),
        (route) => route.isFirst,
      );
    }
  }

  Widget _buildJourneyCard(Map<String, dynamic> journey, {bool isDraft = false, bool isExpired = false}) {
    final status = isExpired ? 'expired' : journey['status']?.toString();
    final origin = journey['origin'] ?? 'Unknown';
    final destination = journey['destination'] ?? 'Unknown';
    final travelMode = journey['travel_mode']?.toString();
    final departureTime = journey['departure_time']?.toString();
    // Use created_at for "Posted on" — exact posting timestamp
    final createdAt = journey['created_at']?.toString() ?? departureTime;
    final journeyId = journey['id']?.toString() ?? '--';

    return GestureDetector(
      onTap: () {
        if (isDraft) {
          // Resume Draft
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostJourneyPage(
                draftId: journeyId,
                initialDraftData: journey['draft_data'] is Map ? Map<String,dynamic>.from(journey['draft_data']) : {},
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => JourneyDetailPage(journeyData: journey),
              transitionDuration: const Duration(milliseconds: 350),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                );
              },
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isExpired ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Status + ID + Price + Actions
            Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isDraft)
                      Icon(Icons.edit_note, size: 12, color: _getStatusColor(status))
                    else
                      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: _getStatusColor(status))),
                    const SizedBox(width: 6),
                    Text(_getStatusLabel(status), style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusColor(status))),
                  ]),
                ),
                const SizedBox(width: 8),
                Text("ID: #${journeyId.length > 5 ? journeyId.substring(0, 5) : journeyId}", style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 11, color: Color(0xFF94A3B8))),
                const Spacer(),
                if (!isDraft && !isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.account_balance_wallet, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _getEarnings(journey),
                          style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                // Three dot menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF64748B), size: 20),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _handleEditJourney(journey, isDraft);
                    } else if (value == 'delete') {
                      _handleDeleteJourney(journeyId);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isExpired)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')]),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Route
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF94A3B8), width: 2))),
                  Container(height: 28, width: 1.5, color: const Color(0xFFE2E8F0)),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF05A4F))),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("From", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(origin, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      const Text("To", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(destination, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom info
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.access_time_filled, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(
                      'Posted ${_formatDate(createdAt)}',
                      style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ]),
                  Row(children: [
                    Icon(_getTravelIcon(travelMode), size: 16, color: const Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      TravelModeMapper.getLabel(travelMode),
                      style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ══════════════════════════════════════════════════════════════
///  DELETE JOURNEY MODAL — Mandatory reason + audit trail
///  Reasons list + custom text field + animated confirmation
/// ══════════════════════════════════════════════════════════════
class _DeleteJourneyModal extends StatefulWidget {
  final String journeyId;

  const _DeleteJourneyModal({required this.journeyId});

  @override
  State<_DeleteJourneyModal> createState() => _DeleteJourneyModalState();
}

class _DeleteJourneyModalState extends State<_DeleteJourneyModal> {
  String? _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();
  bool _isDeleting = false;

  static const List<Map<String, dynamic>> _reasons = [
    {'code': 'travel_cancelled', 'label': 'Travel plans cancelled', 'icon': Icons.cancel_outlined},
    {'code': 'date_changed', 'label': 'Travel date changed', 'icon': Icons.calendar_today},
    {'code': 'capacity_unavailable', 'label': 'No capacity available anymore', 'icon': Icons.inventory_2_outlined},
    {'code': 'route_changed', 'label': 'Route or destination changed', 'icon': Icons.alt_route},
    {'code': 'personal_reasons', 'label': 'Personal reasons', 'icon': Icons.person_outline},
    {'code': 'safety_concerns', 'label': 'Safety or security concerns', 'icon': Icons.shield_outlined},
    {'code': 'duplicate_journey', 'label': 'Duplicate or accidental post', 'icon': Icons.content_copy},
    {'code': 'other', 'label': 'Other (please specify)', 'icon': Icons.edit_note},
  ];

  bool get _canDelete {
    if (_selectedReason == null) return false;
    if (_selectedReason == 'other' && _customReasonController.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _deleteJourney() async {
    if (!_canDelete) return;
    setState(() => _isDeleting = true);

    final reasonText = _selectedReason == 'other'
        ? _customReasonController.text.trim()
        : _reasons.firstWhere((r) => r['code'] == _selectedReason)['label'];

    try {
      final uid = AuthService().currentUser?.uid;

      // 1. Attempt to log the deletion reason (audit trail — non-blocking)
      try {
        await SupabaseService().client.from('journey_deletion_logs').insert({
          'journey_id': widget.journeyId,
          'user_id': uid ?? '',
          'reason_code': _selectedReason,
          'reason_text': reasonText,
        });
      } catch (logErr) {
        // Audit log is optional — if the table doesn't exist or RLS blocks it,
        // we still proceed with the deletion.
        debugPrint('[Delete] Audit log skipped: $logErr');
      }

      // 2. Delete the journey — this is the critical operation
      final response = await SupabaseService().client
          .from('journeys')
          .update({
            'is_deleted': true,
            'status': 'cancelled',
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'deleted_reason': reasonText,
          })
          .eq('id', widget.journeyId)
          .select();

      if (response.isEmpty) {
        throw Exception("Journey not found or you don't have permission to delete it. It might be already deleted or have active bookings.");
      }

      if (!mounted) return;
      Navigator.pop(context, true); // Close the modal and return success
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(width: 48, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          // Warning icon
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.delete_forever, color: Colors.red, size: 28),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Delete Journey?',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'This journey will be permanently removed from your listings and will no longer be visible to senders.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: Color(0xFF64748B), height: 1.5),
            ),
          ),
          const SizedBox(height: 20),

          // Mandatory reason label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text(
                  'Reason for deletion',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('Required', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Reason list (scrollable)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  ..._reasons.map((reason) {
                    final isSelected = _selectedReason == reason['code'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedReason = reason['code']),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.red.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.red.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(reason['icon'] as IconData, size: 20, color: isSelected ? Colors.red : const Color(0xFF64748B)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                reason['label'] as String,
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.red : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? Colors.red : Colors.transparent,
                                border: Border.all(color: isSelected ? Colors.red : const Color(0xFFCBD5E1), width: 2),
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Custom reason text field (when 'Other' selected)
                  if (_selectedReason == 'other') ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: _customReasonController,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Please describe your reason...',
                        hintStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans', color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canDelete && !_isDeleting ? _deleteJourney : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canDelete ? Colors.red : const Color(0xFFE2E8F0),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: _canDelete ? 4 : 0,
                      shadowColor: Colors.red.withValues(alpha: 0.3),
                    ),
                    child: _isDeleting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            'Delete Journey',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _canDelete ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
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
