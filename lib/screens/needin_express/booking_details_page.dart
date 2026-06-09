import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/ui_utils.dart';
import '../../core/utils/transport_icon_mapper.dart';
import '../../core/widgets/email_verification_gate.dart';
import 'chat_page.dart';
import 'express_dashboard_page.dart';

class BookingDetailsPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingDetailsPage({super.key, required this.booking});

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  late Map<String, dynamic> _booking;
  bool _isHydrating = true;
  supabase.RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _booking = Map<String, dynamic>.from(widget.booking);
    _setupRealtime();
    _hydrateTravelerProfile();
  }

  /// Fetches the traveler's real profile from Supabase and updates _booking.
  /// This ensures Booking Details always shows real identity, even if the
  /// upstream list did not fully enrich the booking row.
  Future<void> _hydrateTravelerProfile() async {
    // Resolve traveler_id: first from booking directly, then from journey
    String? travelerId = _booking['traveler_id']?.toString();

    if (travelerId == null || travelerId.isEmpty) {
      // Try to pull from the journey row
      final journeyId = _booking['journey_id']?.toString();
      if (journeyId != null && journeyId.isNotEmpty) {
        try {
          final jRes = await SupabaseService().client
              .from('journeys')
              .select('driver_id, user_id, travel_mode')
              .eq('id', journeyId)
              .maybeSingle();
          if (jRes != null) {
            travelerId = jRes['driver_id']?.toString() ?? jRes['user_id']?.toString();
            final jMode = jRes['travel_mode']?.toString();
            
            if (mounted) {
              setState(() {
                if (_booking['travel_mode'] == null || _booking['travel_mode'].toString().isEmpty) {
                  _booking['travel_mode'] = jMode;
                }
              });
            }

            if (travelerId != null && travelerId.isNotEmpty) {
              // Backfill the parcel row so future lookups work
              final parcelId = _booking['id']?.toString();
              if (parcelId != null) {
                SupabaseService().client
                    .from('parcels')
                    .update({'traveler_id': travelerId})
                    .eq('id', parcelId)
                    .then((_) => debugPrint('[BOOKING_DETAILS] Backfilled traveler_id=$travelerId'))
                    .catchError((_) {});
              }
            }
          }
        } catch (e) {
          debugPrint('[BOOKING_DETAILS] Could not resolve traveler_id from journey: $e');
        }
      }
    }

    if (travelerId == null || travelerId.isEmpty) {
      debugPrint('[BOOKING_DETAILS] traveler_id unresolvable — showing placeholder');
      return;
    }

    try {
      final profile = await SupabaseService().getUserProfile(travelerId);
      if (profile != null && mounted) {
        setState(() {
          // Helper to find the first non-empty value
          String firstNonEmpty(List<String?> values) {
            for (final val in values) {
              if (val != null && val.trim().isNotEmpty) {
                return val.trim();
              }
            }
            return '';
          }

          final resolvedPhone = firstNonEmpty([
            profile['phone']?.toString(),
            profile['mobile_number']?.toString(),
            _booking['traveler_phone']?.toString(),
          ]);

          _booking = {
            ..._booking,
            'traveler_name': profile['full_name'] ?? _booking['traveler_name'],
            'traveler_avatar': profile['profile_image_url'] ?? profile['avatar_url'] ?? _booking['traveler_avatar'],
            'traveler_phone': resolvedPhone,
            'traveler_rating': profile['rating'] ?? _booking['traveler_rating'] ?? 5.0,
            'is_verified': profile['is_verified'] ?? _booking['is_verified'] ?? false,
          };
          _isHydrating = false;
        });
        debugPrint('[BOOKING_DETAILS] ✅ Traveler hydrated: ${profile["full_name"]}');
      } else {
        debugPrint('[BOOKING_DETAILS] ⚠️ Profile null for traveler_id=$travelerId');
        if (mounted) setState(() => _isHydrating = false);
      }
    } catch (e) {
      debugPrint('[BOOKING_DETAILS] Profile fetch error: $e');
      if (mounted) setState(() => _isHydrating = false);
    }
  }

  void _setupRealtime() {
    final bookingId = _booking['id']?.toString();
    if (bookingId == null) return;

    _realtimeChannel = SupabaseService().client
        .channel('public:parcels:id=$bookingId')
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.all,
          schema: 'public',
          table: 'parcels',
          filter: supabase.PostgresChangeFilter(
            type: supabase.PostgresChangeFilterType.eq,
            column: 'id',
            value: bookingId,
          ),
          callback: (payload) {
            if (mounted) {
                setState(() {
                  final prevDep = _booking['departure_time'];
                  final prevArr = _booking['arrival_time'];
                  _booking = {
                    ..._booking, // preserve traveler profile details
                    ...payload.newRecord,
                  };
                  if (payload.newRecord['departure_time'] == null && prevDep != null) {
                    _booking['departure_time'] = prevDep;
                  }
                  if (payload.newRecord['arrival_time'] == null && prevArr != null) {
                    _booking['arrival_time'] = prevArr;
                  }
                });
              }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  String _formatBookingId(String? id) {
    if (id == null || id.isEmpty) return '#UNKNOWN';
    final parts = id.split('-');
    if (parts.isNotEmpty) {
      return '#${parts.first.toUpperCase()}';
    }
    return '#${id.substring(0, 8).toUpperCase()}';
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
      case 'disputed':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getStatusBgColor(String status) {
    return _getStatusColor(status).withValues(alpha: 0.1);
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return Icons.check_circle;
      case 'active':
      case 'confirmed':
      case 'in_transit':
      case 'pending':
      case 'draft':
        return Icons.local_shipping;
      case 'cancelled':
      case 'disputed':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return 'Unknown';
    if (status.toLowerCase() == 'pending' || status.toLowerCase() == 'draft') return 'Active';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  /// Resolves the saved parcel category from the booking record.
  /// Reads multiple fields in priority order. NEVER defaults to Medium blindly.
  String _resolveParcelCategory() {
    // Priority 1: explicit parcel_size field (e.g. 'small', 'medium', 'large')
    final fromSize = _booking['parcel_size']?.toString().trim().toLowerCase();
    if (fromSize != null && fromSize.isNotEmpty && ['small', 'medium', 'large'].contains(fromSize)) {
      return fromSize;
    }

    // Priority 2: parcel_category field (capitalized e.g. 'Small', 'Medium', 'Large')
    final fromCategory = _booking['parcel_category']?.toString().trim().toLowerCase();
    if (fromCategory != null && fromCategory.isNotEmpty && ['small', 'medium', 'large'].contains(fromCategory)) {
      return fromCategory;
    }

    // Priority 3: derive from title field (e.g. 'Small Parcel', 'Medium Parcel')
    final title = _booking['title']?.toString().toLowerCase() ?? '';
    if (title.contains('large')) return 'large';
    if (title.contains('medium')) return 'medium';
    if (title.contains('small')) return 'small';

    // Priority 4: derive from weight_kg using travel mode
    final weightKg = (_booking['weight_kg'] as num?)?.toDouble();
    final isFlight = (_booking['travel_mode'] ?? '').toString().toLowerCase() == 'flight';
    if (weightKg != null) {
      if (isFlight) {
        if (weightKg <= 1.0) return 'small';
        if (weightKg <= 3.0) return 'medium';
        return 'large';
      } else {
        if (weightKg <= 2.0) return 'small';
        if (weightKg <= 5.0) return 'medium';
        return 'large';
      }
    }

    // Safe last resort — never blindly default to 'medium'
    debugPrint('[BOOKING_DETAILS] ⚠️ Could not resolve parcel category from booking data — defaulting to small');
    return 'small';
  }

  Map<String, String> _getParcelDetails(String category) {
    final cat = category.toLowerCase();
    final isFlight = (_booking['travel_mode'] ?? '').toString().toLowerCase() == 'flight';

    if (isFlight) {
      if (cat.contains('small')) {
        return {'weight': 'Up to 1 kg', 'dim': 'Each side ≤ 12 inches'};
      } else if (cat.contains('large')) {
        return {'weight': 'Up to 5 kg', 'dim': 'Each side ≤ 18 inches'};
      } else {
        return {'weight': 'Up to 3 kg', 'dim': 'Each side ≤ 18 inches'};
      }
    } else {
      if (cat.contains('small')) {
        return {'weight': 'Up to 2 kg', 'dim': 'Each side ≤ 12 inches'};
      } else if (cat.contains('large')) {
        return {'weight': 'Up to 25 kg', 'dim': 'Each side ≤ 72 inches'};
      } else {
        return {'weight': 'Up to 5 kg', 'dim': 'Each side ≤ 24 inches'};
      }
    }
  }

  Future<void> _makePhoneCall(BuildContext context) async {
    // Get the most up-to-date phone from the hydrated _booking.
    // After _hydrateTravelerProfile() completes, traveler_phone is populated.
    final raw = _booking['traveler_phone']?.toString().trim() ?? '';

    if (raw.isEmpty) {
      // This means the traveler's profile has no phone number recorded.
      // This should be extremely rare since phone is mandatory on registration.
      debugPrint('[BOOKING_DETAILS] ⚠️ traveler_phone is empty for traveler_id=${_booking["traveler_id"]}. Profile may not have been hydrated yet.');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Traveler phone number is not available yet. Please wait a moment and try again.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Sanitize: keep only digits and the leading '+' if present.
    // Handles formats: +919876543210, 09876543210, 9876543210
    final cleanNumber = raw.replaceAll(RegExp(r'[^\d+]'), '');
    debugPrint('[BOOKING_DETAILS] 📞 Dialing traveler: $cleanNumber (raw: $raw)');

    final Uri launchUri = Uri(scheme: 'tel', path: cleanNumber);
    try {
      // canLaunchUrl check: ensures the device has a dialer app
      final canLaunch = await canLaunchUrl(launchUri);
      if (canLaunch) {
        // MUST use externalApplication so the dialer opens as a separate OS activity.
        // This preserves the entire Flutter navigation stack intact.
        // When the user presses back from the dialer, they return exactly to this page.
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('[BOOKING_DETAILS] ❌ Cannot launch tel URI: $launchUri');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open the phone dialer. Please dial manually.'),
              backgroundColor: Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[BOOKING_DETAILS] Error launching dialer: $e');
    }
  }

  void _openChat() {
    final travelerName = _booking['traveler_name']?.toString() ?? 'Traveler';
    final travelerAvatar = _booking['traveler_avatar']?.toString();
    final bookingId = _booking['id']?.toString() ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: bookingId,
          otherUserName: travelerName,
          otherUserAvatar: travelerAvatar,
        ),
      ),
    );
  }

  void _handleCancelAction() {
    final departureTime = _booking['departure_time']?.toString() ?? _booking['created_at']?.toString();
    final arrivalTime = _booking['arrival_time']?.toString();

    if (departureTime != null && arrivalTime != null) {
      final etd = DateTime.tryParse(departureTime)?.toLocal();
      final eta = DateTime.tryParse(arrivalTime)?.toLocal();
      final now = DateTime.now();

      if (etd != null && eta != null) {
        if ((now.isAfter(etd) || now.isAtSameMomentAs(etd)) && 
            (now.isBefore(eta) || now.isAtSameMomentAs(eta))) {
          _showCancellationBlockedPopup();
          return;
        }
      }
    }
    _showCancelDialog();
  }

  void _showCancellationBlockedPopup() {
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
              'Cancellation Blocked',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'You cannot cancel the booking during the journey duration between ETD and ETA.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: Color(0xFF64748B), height: 1.5),
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
              child: const Text('OK', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelDialog() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CancelBookingModal(booking: _booking),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled successfully'),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ExpressDashboardPage()),
        (route) => route.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_booking['status'] ?? 'pending').toString();
    final origin = _booking['origin']?.toString() ?? 'N/A';
    final destination = _booking['destination']?.toString() ?? 'N/A';
    final bookingId = _formatBookingId(_booking['id']?.toString());
    final price = (_booking['price'] as num?)?.toDouble() ?? 0;
    final parcelCategory = _resolveParcelCategory();
    final parcelSpecs = _getParcelDetails(parcelCategory);
    final travelerName = _booking['traveler_name']?.toString();
    final travelerAvatar = _booking['traveler_avatar']?.toString();
    final isVerified = _booking['is_verified'] == true;
    final travelMode = _booking['travel_mode']?.toString() ?? 'driving';
    final createdAt = _booking['created_at']?.toString();
    final departureTime = _booking['departure_time']?.toString() ?? createdAt;
    final arrivalTime = _booking['arrival_time']?.toString();
    final isInactive = status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'delivered' || status.toLowerCase() == 'completed' || status.toLowerCase() == 'disputed';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // BACK NAVIGATION FIX:
        // BookingDetailsPage is ALWAYS pushed via Navigator.push() from MyBookingsPage.
        // It is never the root route. Therefore Navigator.pop() is always safe.
        // We do NOT use PopScope or canPop checks — those caused the black screen
        // because canPop was evaluated stale, and onPopInvokedWithResult was
        // calling pushReplacement even after the pop already completed.
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 18),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Booking Details",
          style: TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Card (Booking ID & Status)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "BOOKING ID",
                        style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bookingId,
                        style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getStatusIcon(status), size: 14, color: _getStatusColor(status)),
                        const SizedBox(width: 6),
                        Text(
                          _formatStatus(status),
                          style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.bold, color: _getStatusColor(status)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Traveler Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  // Avatar — show shimmer while hydrating
                  _isHydrating
                    ? Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF05A4F)),
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFF1F5F9),
                        backgroundImage: travelerAvatar != null && travelerAvatar.isNotEmpty ? NetworkImage(travelerAvatar) : null,
                        child: travelerAvatar == null || travelerAvatar.isEmpty
                          ? Text(
                              (travelerName != null && travelerName.isNotEmpty) ? travelerName[0].toUpperCase() : '?',
                              style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            )
                          : null,
                      ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _isHydrating ? 'Loading...' : (travelerName ?? 'Traveler'),
                                style: TextStyle(
                                  fontFamily: "Plus Jakarta Sans",
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isHydrating ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified && !_isHydrating) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Color(0xFF2563EB), size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isVerified ? 'Verified Traveler' : 'Verified & Registered Traveler',
                          style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Route & Logistics Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                        child: Icon(TransportIconMapper.getIconForMode(travelMode), size: 18, color: const Color(0xFFF05A4F)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Route Details",
                        style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Builder(builder: (context) {
                    // Calculate duration between departure and arrival
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

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF2563EB), width: 3), shape: BoxShape.circle)),
                            Container(width: 2, height: durationText != null ? 20 : 40, color: const Color(0xFFE2E8F0)),
                            if (durationText != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(durationText, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                              ),
                              Container(width: 2, height: 20, color: const Color(0xFFE2E8F0)),
                            ],
                            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF16A34A), width: 3), shape: BoxShape.circle)),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(origin, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  if (departureTime != null)
                                    Text(UIUtils.formatJourneyDateTime(departureTime), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF64748B))),
                                ],
                              ),
                              SizedBox(height: durationText != null ? 28 : 18),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(destination, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  if (arrivalTime != null)
                                    Text(UIUtils.formatJourneyDateTime(arrivalTime), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Parcel & Price Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Parcel Specifications", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Category", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF64748B))),
                      Text(parcelCategory[0].toUpperCase() + parcelCategory.substring(1), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Weight Limit", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF64748B))),
                      Text(parcelSpecs['weight']!, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Dimensions", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF64748B))),
                      Text(parcelSpecs['dim']!, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total Price", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text("₹${price.toInt()}", style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Operational Actions
            if (!isInactive) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _makePhoneCall(context),
                      icon: const Icon(Icons.call, size: 20),
                      label: const Text("Call"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EmailVerificationGate(
                      actionDescription: 'message this traveler',
                      child: ElevatedButton.icon(
                        onPressed: _openChat,
                        icon: const Icon(Icons.chat_bubble, size: 20),
                        label: const Text("Message"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (status.toLowerCase() == 'pending' || status.toLowerCase() == 'active' || status.toLowerCase() == 'draft')
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _handleCancelAction,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: const Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      "Cancel Booking",
                      style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// ══════════════════════════════════════════════════════════════
///  CANCEL BOOKING MODAL
/// ══════════════════════════════════════════════════════════════
class _CancelBookingModal extends StatefulWidget {
  final Map<String, dynamic> booking;

  const _CancelBookingModal({required this.booking});

  @override
  State<_CancelBookingModal> createState() => _CancelBookingModalState();
}

class _CancelBookingModalState extends State<_CancelBookingModal> {
  String? _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();
  bool _isCancelling = false;

  static const List<Map<String, dynamic>> _reasons = [
    {'code': 'plans_changed', 'label': 'Plans changed', 'icon': Icons.schedule},
    {'code': 'wrong_booking', 'label': 'Wrong booking', 'icon': Icons.error_outline},
    {'code': 'found_another', 'label': 'Found another traveler', 'icon': Icons.person_search},
    {'code': 'mistake', 'label': 'Created by mistake', 'icon': Icons.undo},
    {'code': 'other', 'label': 'Other (please specify)', 'icon': Icons.edit_note},
  ];

  bool get _canCancel {
    if (_selectedReason == null) return false;
    if (_selectedReason == 'other' && _customReasonController.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _cancelBooking() async {
    if (!_canCancel) return;
    setState(() => _isCancelling = true);

    try {
      final parcelId = widget.booking['id']?.toString();
      if (parcelId != null) {
        final uid = AuthService().currentUser?.uid ?? '';
        final reason = _selectedReason == 'other' ? _customReasonController.text : _selectedReason;
        await SupabaseService().cancelBooking(
          parcelId: parcelId,
          reason: reason ?? 'cancelled',
          canceledByUid: uid,
          travelerId: widget.booking['traveler_id']?.toString(),
        );
      }
      if (mounted) {
        Navigator.pop(context, true); // Close modal and return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cancel Booking', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.close, size: 20, color: Color(0xFF64748B))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('This action will permanently remove the booking.', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: Color(0xFF64748B))),
            const SizedBox(height: 20),
            ..._reasons.map((reason) {
              final isSelected = _selectedReason == reason['code'];
              return GestureDetector(
                onTap: () => setState(() => _selectedReason = reason['code']),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF05A4F).withValues(alpha: 0.05) : Colors.white,
                    border: Border.all(color: isSelected ? const Color(0xFFF05A4F) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(reason['icon'], size: 20, color: isSelected ? const Color(0xFFF05A4F) : const Color(0xFF64748B)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(reason['label'], style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFFF05A4F) : const Color(0xFF334155)))),
                      if (isSelected) const Icon(Icons.check_circle, color: Color(0xFFF05A4F), size: 20),
                    ],
                  ),
                ),
              );
            }),
            if (_selectedReason == 'other')
              Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 8),
                child: TextField(
                  controller: _customReasonController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(hintText: 'Tell us more...', hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Plus Jakarta Sans'), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  maxLines: 3,
                ),
              ),
            const SizedBox(height: 8),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            const Text("Are you sure you want to cancel this booking? This action cannot be undone.", style: TextStyle(fontFamily: "Plus Jakarta Sans", color: Color(0xFFDC2626), fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Color(0xFFE2E8F0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Keep Booking', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold, color: Color(0xFF64748B))))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: _isCancelling || !_canCancel ? null : _cancelBooking, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), disabledBackgroundColor: const Color(0xFFF1F5F9), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: _isCancelling ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Confirm Cancel', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold, color: _canCancel ? Colors.white : const Color(0xFF94A3B8))))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
