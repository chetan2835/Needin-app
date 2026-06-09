import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/transport_icon_mapper.dart';
import '../../core/constants/ui_utils.dart';
import 'booking_details_page.dart';
import 'express_dashboard_page.dart';
import '../../core/widgets/app_bottom_navigation.dart';

/// ══════════════════════════════════════════════════════════════
///  PRODUCTION: My Bookings Page
///  Displays all parcel bookings for the currently logged-in sender.
///  Fetches real data from Supabase `parcels` table.
/// ══════════════════════════════════════════════════════════════
class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];
  late TabController _tabController;
  supabase.RealtimeChannel? _realtimeChannel;
  final Map<String, Timer> _deliveryTimers = {};

  final List<String> _tabs = [
    'Active',
    'Delivered',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _fetchBookings();
    _setupRealtime();
    // Trigger backend retention cleanup silently on page open
    // (non-blocking; client-side filter below is the safety net)
    SupabaseService().runRetentionCleanup();
  }

  void _setupRealtime() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    _realtimeChannel = SupabaseService().client
        .channel('my_bookings:$uid')
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.all,
          schema: 'public',
          table: 'parcels',
          callback: (payload) {
            debugPrint('REALTIME: Bookings update received: ${payload.eventType}');
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _fetchBookings(isSilent: true);
            });
          },
        )
        .subscribe((status, [error]) {
          debugPrint('REALTIME: Bookings subscription status: $status');
        });
  }

  @override
  void dispose() {
    for (final timer in _deliveryTimers.values) {
      timer.cancel();
    }
    _deliveryTimers.clear();
    _tabController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchBookings({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      debugPrint('BOOKINGS: Fetching for sender uid=$uid');

      // Fetch parcel bookings for this sender
      final response = await SupabaseService()
          .client
          .from('parcels')
          .select()
          .eq('sender_id', uid)
          .order('created_at', ascending: false)
          .limit(100);

      final bookings = List<Map<String, dynamic>>.from(response as List);
      debugPrint('BOOKINGS: Got ${bookings.length} bookings');

      // Safely fetch journeys for date enrichment (decoupled to avoid FK crash)
      final journeyIds = bookings.map((b) => b['journey_id']?.toString()).where((id) => id != null && id.isNotEmpty).toSet().toList();
      final Map<String, Map<String, dynamic>> journeysMap = {};
      
      if (journeyIds.isNotEmpty) {
        try {
          final jRes = await SupabaseService().client
              .from('journeys')
              .select('id, driver_id, user_id, departure_time, arrival_time, travel_mode')
              .inFilter('id', journeyIds.cast<String>());
          for (final j in jRes) {
            journeysMap[j['id'].toString()] = Map<String, dynamic>.from(j);
          }
        } catch (e) {
          debugPrint('BOOKINGS: Error bulk fetching journeys: $e');
        }
      }

      // Enrich with traveler profile data
      final nowUtc = DateTime.now().toUtc();
      final validBookings = <Map<String, dynamic>>[];

      for (final timer in _deliveryTimers.values) {
        timer.cancel();
      }
      _deliveryTimers.clear();

      for (var b in bookings) {
        try {
          b = Map<String, dynamic>.from(b);
          final jid = b['journey_id']?.toString();
          
          if (jid != null && journeysMap.containsKey(jid)) {
            final jData = journeysMap[jid]!;
            b['departure_time'] = jData['departure_time'] ?? b['departure_time'];
            b['arrival_time'] = jData['arrival_time'] ?? b['arrival_time'];
            if (b['travel_mode'] == null || b['travel_mode'].toString().isEmpty) {
              b['travel_mode'] = jData['travel_mode'];
            }
          }
        } catch (e) {
          debugPrint('BOOKINGS: Error enriching booking: $e');
        }

        String status = (b['status'] ?? '').toString().toLowerCase();
        final arrTimeStr = b['arrival_time']?.toString();
        
        bool autoDelivered = false;
        
        if (arrTimeStr != null && arrTimeStr.isNotEmpty && (status == 'active' || status == 'pending' || status == 'confirmed' || status == 'in_transit' || status == 'draft')) {
          try {
            final arrDate = DateTime.parse(arrTimeStr).toUtc();
            if (nowUtc.isAfter(arrDate)) {
              autoDelivered = true;
            } else {
              // Not yet delivered, schedule a timer to update it when ETA arrives
              final duration = arrDate.difference(nowUtc);
              final parcelId = b['id']?.toString();
              if (parcelId != null) {
                _deliveryTimers[parcelId] = Timer(duration, () {
                  SupabaseService().client.from('parcels').update({'status': 'delivered'}).eq('id', parcelId).then((_) {
                    debugPrint('BOOKINGS: Timer auto-delivered $parcelId');
                    if (mounted) _fetchBookings(isSilent: true);
                  }).catchError((_) {});
                });
              }
            }
          } catch (_) {}
        }

        if (autoDelivered) {
          // Immediately update database if we caught an expired ETA
          final parcelId = b['id']?.toString();
          if (parcelId != null && status != 'delivered') {
            SupabaseService().client.from('parcels').update({'status': 'delivered'}).eq('id', parcelId).then((_) {
              debugPrint('BOOKINGS: Auto-updated past ETA booking $parcelId to delivered');
            }).catchError((_) {});
            status = 'delivered'; // Optimistic local state update
            b = Map<String, dynamic>.from(b)..['status'] = 'delivered';
          }
        }
        
        validBookings.add(b);
      }

      final enriched = <Map<String, dynamic>>[];
      
      // Step 1: Pre-resolve and collect all unique traveler IDs
      final Set<String> uniqueTravelerIds = {};
      for (final booking in validBookings) {
        String? travelerId = booking['traveler_id']?.toString();
        final jid = booking['journey_id']?.toString();
        
        // 🔧 Repair missing traveler_id from journey data
        if ((travelerId == null || travelerId.isEmpty) && jid != null && journeysMap.containsKey(jid)) {
          travelerId = journeysMap[jid]!['driver_id']?.toString() ?? journeysMap[jid]!['user_id']?.toString();
          if (travelerId != null && travelerId.isNotEmpty) {
            final parcelId = booking['id']?.toString();
            if (parcelId != null) {
              SupabaseService().client.from('parcels').update({'traveler_id': travelerId}).eq('id', parcelId).then((_) {
                debugPrint('BOOKINGS: 🔧 Backfilled missing traveler_id $travelerId for booking $parcelId');
              }).catchError((_) {});
            }
            booking['traveler_id'] = travelerId;
          }
        }
        
        if (travelerId != null && travelerId.isNotEmpty) {
          uniqueTravelerIds.add(travelerId);
        }
      }

      // Step 2: Bulk fetch profiles
      final Map<String, Map<String, dynamic>> profilesMap = {};
      if (uniqueTravelerIds.isNotEmpty) {
        try {
          final profilesRes = await SupabaseService().client
              .from('profiles')
              .select()
              .inFilter('id', uniqueTravelerIds.toList().cast<String>());
          for (final p in profilesRes) {
            profilesMap[p['id'].toString()] = Map<String, dynamic>.from(p);
          }
        } catch (e) {
          debugPrint('BOOKINGS: Error bulk fetching profiles: $e');
        }
      }

      // Step 3: Enrich the validBookings list
      // For any traveler_id that the bulk fetch missed, fall back to getUserProfile()
      for (final booking in validBookings) {
        final travelerId = booking['traveler_id']?.toString();
        Map<String, dynamic>? profile = travelerId != null ? profilesMap[travelerId] : null;

        // Fallback: individual profile lookup if bulk missed it
        if (profile == null && travelerId != null && travelerId.isNotEmpty) {
          try {
            profile = await SupabaseService().getUserProfile(travelerId);
            if (profile != null) {
              profilesMap[travelerId] = profile; // cache for any duplicate IDs
              debugPrint('BOOKINGS: ✅ Fallback profile resolved for $travelerId: ${profile["full_name"]}');
            } else {
              debugPrint('BOOKINGS: ⚠️ Profile not found for traveler_id=$travelerId');
            }
          } catch (e) {
            debugPrint('BOOKINGS: ⚠️ Fallback profile fetch error for $travelerId: $e');
          }
        }

        enriched.add({
          ...booking,
          'traveler_name': profile?['full_name'] ?? 'Traveler',
          'traveler_avatar': profile?['profile_image_url'] ?? profile?['avatar_url'],
          'traveler_rating': profile?['rating'] ?? 5.0,
          'traveler_phone': profile?['phone'] ?? profile?['mobile_number'] ?? '',
          'is_verified': profile?['is_verified'] ?? false,
        });
      }

      if (!mounted) return;
      setState(() {
        _bookings = enriched;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('BOOKINGS: ❌ Fetch error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredBookings {
    final tabIndex = _tabController.index;
    final statusFilter = _tabs[tabIndex].toLowerCase();
    final now = DateTime.now().toUtc();
    // 30-day retention window — matches backend policy
    final retentionCutoff = now.subtract(const Duration(days: 30));
    
    var filtered = _bookings.where((b) {
      final status = (b['status'] ?? '').toString().toLowerCase();
      switch (statusFilter) {
        case 'active':
          return status == 'active' ||
              status == 'pending' ||
              status == 'confirmed' ||
              status == 'in_transit' ||
              status == 'draft';
        case 'delivered':
          if (status != 'delivered' && status != 'completed') return false;
          // Check backend retention_expires_at first (most accurate)
          final retExpiresStr = b['retention_expires_at']?.toString();
          if (retExpiresStr != null) {
            final retExpires = DateTime.tryParse(retExpiresStr)?.toUtc();
            if (retExpires != null && retExpires.isBefore(now)) return false;
          } else {
            // Fallback: 30-day rolling window
            final dateStr = b['arrival_time']?.toString() ?? b['created_at']?.toString();
            if (dateStr != null) {
              final dt = DateTime.tryParse(dateStr);
              if (dt != null && dt.toUtc().isBefore(retentionCutoff)) return false;
            }
          }
          return true;
        case 'cancelled':
          if (status != 'cancelled' && status != 'disputed') return false;
          // Check backend retention_expires_at first
          final retExpiresStr = b['retention_expires_at']?.toString();
          if (retExpiresStr != null) {
            final retExpires = DateTime.tryParse(retExpiresStr)?.toUtc();
            if (retExpires != null && retExpires.isBefore(now)) return false;
          } else {
            // Fallback: 30-day rolling window
            final dateStr = b['cancelled_at']?.toString() ?? b['created_at']?.toString();
            if (dateStr != null) {
              final dt = DateTime.tryParse(dateStr);
              if (dt != null && dt.toUtc().isBefore(retentionCutoff)) return false;
            }
          }
          return true;
        default:
          return true;
      }
    }).toList();
    
    return filtered;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'active':
      case 'confirmed':
      case 'in_transit':
      case 'pending':
      case 'draft':
        return const Color(0xFF2563EB);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'disputed':
        return const Color(0xFF9333EA);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return const Color(0xFFDCFCE7);
      case 'active':
      case 'confirmed':
      case 'in_transit':
      case 'pending':
      case 'draft':
        return const Color(0xFFDBEAFE);
      case 'cancelled':
        return const Color(0xFFFEE2E2);
      case 'disputed':
        return const Color(0xFFF3E8FF);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'in_transit':
        return 'In Transit';
      case 'pending':
      case 'draft':
      case 'active':
        return 'Active';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  String _formatBookingId(String? id) {
    if (id == null || id.isEmpty) return 'N/A';
    // Show last 8 chars of UUID
    return '#${id.length > 8 ? id.substring(id.length - 8).toUpperCase() : id.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                )
              ],
            ),
            child: const Icon(Icons.arrow_back,
                color: Color(0xFF0F172A), size: 18),
          ),
          onPressed: () {
            // Navigate to ExpressDashboard \u2014 NOT pop() which would
            // incorrectly land on ServiceSelectionPage.
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const ExpressDashboardPage(),
              ),
              (route) => false,
            );
          },
        ),
        title: const Text(
          "My Bookings",
          style: TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Column(
            children: [
              Container(height: 1, color: const Color(0xFFE2E8F0)),
              Container(
                height: 55,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF334155),
                  labelStyle: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  indicator: BoxDecoration(
                    color: const Color(0xFFF05A4F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  tabs: _tabs
                      .map((t) => Tab(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(t),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFF05A4F),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Loading your bookings...",
                    style: TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : _filteredBookings.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchBookings,
                  color: const Color(0xFFF05A4F),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredBookings.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _filteredBookings.length) {
                        return const SizedBox(height: 24);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child:
                            _buildBookingCard(_filteredBookings[index]),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    final isCancelled = _tabController.index == 2;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isCancelled 
                  ? const Color(0xFF64748B).withValues(alpha: 0.1) 
                  : const Color(0xFFF05A4F).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
                isCancelled ? Icons.history : Icons.inventory_2_outlined,
                color: isCancelled ? const Color(0xFF64748B) : const Color(0xFFF05A4F), 
                size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            isCancelled ? "No completed bookings" : "No bookings yet",
            style: const TextStyle(
              fontFamily: "Plus Jakarta Sans",
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCancelled 
                ? "Your recent completed bookings will\nappear here." 
                : "Book your first delivery by finding\na traveler on your route.",
            style: const TextStyle(
              fontFamily: "Plus Jakarta Sans",
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (!isCancelled) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
            // Always navigate back to ExpressDashboard
            // (not route.isFirst which would land on ServiceSelectionPage).
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const ExpressDashboardPage(),
              ),
              (route) => false,
            );
          },
              icon: const Icon(Icons.search, size: 18),
              label: const Text("Book your first delivery"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF05A4F),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor:
                    const Color(0xFFF05A4F).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = (booking['status'] ?? 'pending').toString();
    final origin = booking['origin']?.toString() ?? 'N/A';
    final destination = booking['destination']?.toString() ?? 'N/A';
    final bookingId = _formatBookingId(booking['id']?.toString());
    
    final travelerName = booking['traveler_name']?.toString() ?? 'Traveler';
    final travelerAvatar = booking['traveler_avatar']?.toString();
    final travelMode = booking['travel_mode']?.toString() ?? 'driving';

    final departureTime = booking['departure_time']?.toString();
    final arrivalTime = booking['arrival_time']?.toString();

    String? durationText;
    if (departureTime != null && arrivalTime != null) {
      final dep = DateTime.tryParse(departureTime);
      final arr = DateTime.tryParse(arrivalTime);
      if (dep != null && arr != null) {
        final diff = arr.difference(dep);
        final hours = diff.inHours;
        final minutes = diff.inMinutes % 60;
        if (hours > 0 && minutes > 0) {
          durationText = '${hours}h ${minutes.toString().padLeft(2, '0')}m';
        } else if (hours > 0) {
          durationText = '${hours}h 00m';
        } else {
          durationText = '${minutes}m';
        }
      }
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetailsPage(booking: booking),
          ),
        ).then((_) {
          // Immediately refetch when returning from details (handles cancel, etc.)
          if (mounted) _fetchBookings(isSilent: true);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: travelerAvatar != null && travelerAvatar.isNotEmpty
                      ? NetworkImage(travelerAvatar)
                      : null,
                  child: travelerAvatar == null || travelerAvatar.isEmpty
                      ? const Icon(Icons.person, color: Color(0xFF94A3B8), size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        travelerName,
                        style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        bookingId,
                        style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(status),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatStatus(status).toUpperCase(),
                    style: TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF2563EB), width: 2.5), shape: BoxShape.circle)),
                      Container(width: 2, height: durationText != null ? 16 : 24, color: const Color(0xFFCBD5E1)),
                      if (durationText != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(durationText, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        ),
                        Container(width: 2, height: 16, color: const Color(0xFFCBD5E1)),
                      ],
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF16A34A), width: 2.5), shape: BoxShape.circle)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(origin, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            if (departureTime != null)
                              Text(UIUtils.formatJourneyDateTime(departureTime), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                        SizedBox(height: durationText != null ? 14 : 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(destination, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            if (arrivalTime != null)
                              Text(UIUtils.formatJourneyDateTime(arrivalTime), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                    child: Icon(TransportIconMapper.getIconForMode(travelMode), size: 18, color: const Color(0xFFF05A4F)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // View Details button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingDetailsPage(booking: booking),
                    ),
                  ).then((_) {
                    if (mounted) _fetchBookings(isSilent: true);
                  });
                },
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text("View Details"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  foregroundColor: const Color(0xFFF05A4F),
                  side: const BorderSide(color: Color(0xFFF05A4F), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

