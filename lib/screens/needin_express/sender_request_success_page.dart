import 'package:flutter/material.dart';
import '../../core/constants/ui_utils.dart';
import '../../core/utils/transport_icon_mapper.dart';
import 'express_dashboard_page.dart';
import 'my_bookings_page.dart';
import '../../core/services/messaging_service.dart';
import '../../core/services/auth_service.dart';

/// ══════════════════════════════════════════════════════════════
///  PRODUCTION: Premium Booking Success Page
///  Displays REAL data from the completed booking flow.
/// ══════════════════════════════════════════════════════════════
class SenderRequestSuccessPage extends StatefulWidget {
  final Map<String, dynamic>? travelerData;

  const SenderRequestSuccessPage({super.key, this.travelerData});

  @override
  State<SenderRequestSuccessPage> createState() =>
      _SenderRequestSuccessPageState();
}

class _SenderRequestSuccessPageState extends State<SenderRequestSuccessPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
        
    _autoCreateConversation();
  }
  
  void _autoCreateConversation() {
    final bookingId = widget.travelerData?['booking_id']?.toString();
    final travelerId = widget.travelerData?['driver_id']?.toString() ?? widget.travelerData?['traveler_id']?.toString();
    final journeyId = widget.travelerData?['id']?.toString() ?? widget.travelerData?['journey_id']?.toString();
    final senderId = AuthService().currentUser?.uid;
    
    if (bookingId != null && travelerId != null && senderId != null) {
      MessagingService().getOrCreateConversation(
        bookingId: bookingId,
        travelerId: travelerId,
        senderId: senderId,
        journeyId: journeyId,
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Extract real data from travelerData ──
  String get _origin =>
      widget.travelerData?['pickup_city'] ??
      widget.travelerData?['origin'] ??
      'Origin';

  String get _destination =>
      widget.travelerData?['drop_city'] ??
      widget.travelerData?['destination'] ??
      'Destination';

  String get _travelerName =>
      widget.travelerData?['traveler_name'] ??
      widget.travelerData?['full_name'] ??
      'Traveler';

  String? get _travelerAvatar =>
      widget.travelerData?['traveler_avatar'] ??
      widget.travelerData?['profile_image_url'] ??
      widget.travelerData?['avatar_url'];

  bool get _isVerified =>
      widget.travelerData?['is_verified'] == true;

  IconData get _modeIcon {
    final mode = widget.travelerData?['travel_mode']?.toString();
    return TransportIconMapper.getIconForMode(mode);
  }

  String get _departureDisplay {
    final dateStr = widget.travelerData?['departure_time']?.toString();
    if (dateStr == null || dateStr.isEmpty) return 'Flexible';
    return UIUtils.formatJourneyDateTime(dateStr);
  }

  String get _arrivalDisplay {
    final dateStr = widget.travelerData?['arrival_time']?.toString();
    if (dateStr == null || dateStr.isEmpty) return 'TBD';
    return UIUtils.formatJourneyDateTime(dateStr);
  }

  String get _parcelSize {
    final size = widget.travelerData?['parcel_size']?.toString() ?? 'medium';
    return size[0].toUpperCase() + size.substring(1);
  }

  String get _priceDisplay {
    final price = widget.travelerData?['price'];
    if (price is num) return '\u20B9${price.toInt()}';
    return '\u20B90';
  }

  String get _bookingId {
    final id = widget.travelerData?['booking_id']?.toString() ?? '';
    if (id.length > 8) return '#${id.substring(0, 8).toUpperCase()}';
    if (id.isNotEmpty) return '#${id.toUpperCase()}';
    return '';
  }

  // Navigate to ExpressDashboard, clearing all stale booking flow pages.
  void _goToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ExpressDashboardPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Block system back — redirect to dashboard instead
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goToDashboard();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            /// Main Content Area
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    children: [
                      // Success Animation
                      const SizedBox(height: 24),
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 40),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Header
                      const Text(
                        "Booking Successful!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Your parcel booking has been confirmed successfully.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Summary Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Booking ID + Status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_bookingId.isNotEmpty)
                                  Text(
                                    _bookingId,
                                    style: const TextStyle(
                                      fontFamily: "Plus Jakarta Sans",
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF94A3B8),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, size: 12, color: Color(0xFF22C55E)),
                                      SizedBox(width: 4),
                                      Text("Confirmed", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 16),

                            // Route
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(_modeIcon, color: const Color(0xFF16A34A), size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Route", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Flexible(child: Text(_origin, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                                          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward, size: 12, color: Color(0xFF94A3B8))),
                                          Flexible(child: Text(_destination, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Departure & Arrival
                            Row(
                              children: [
                                Expanded(child: _buildInfoColumn("Departure", _departureDisplay)),
                                Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                                Expanded(child: _buildInfoColumn("Arrival", _arrivalDisplay)),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 16),

                            // Parcel + Price
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Parcel Size", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 11, color: Color(0xFF64748B))),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(_parcelSize, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text("Price", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 11, color: Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    Text(_priceDisplay, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 16),

                            // Traveler Info
                            Row(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFFE2E8F0),
                                        image: _travelerAvatar != null
                                            ? DecorationImage(image: NetworkImage(_travelerAvatar!), fit: BoxFit.cover)
                                            : null,
                                      ),
                                      child: _travelerAvatar == null
                                          ? Center(child: Text(_travelerName.isNotEmpty ? _travelerName[0].toUpperCase() : '?', style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B))))
                                          : null,
                                    ),
                                    if (_isVerified)
                                      Positioned(
                                        bottom: -2, right: -2,
                                        child: Container(
                                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                          child: const Icon(Icons.verified, color: Colors.blue, size: 14),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Traveler", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, color: Color(0xFF64748B))),
                                      Text(_travelerName, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    ],
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
              ),
            ),

            /// Fixed Bottom Actions
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFF16A34A).withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        // Clear the entire booking flow and go to MyBookings
                        // on top of ExpressDashboard.
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const MyBookingsPage()),
                          (Route<dynamic> route) => false,
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2, size: 20),
                          SizedBox(width: 8),
                          Text("My Bookings", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        // Clear the entire booking flow and go back to the
                        // Express Dashboard (Earn by Travelling / Search a Traveller).
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const ExpressDashboardPage()),
                          (Route<dynamic> route) => false,
                        );
                      },
                      child: const Text("Send Another Parcel", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ), // close child: Scaffold
    ); // end PopScope
  }

  Widget _buildInfoColumn(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
