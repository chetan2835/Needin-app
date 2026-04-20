import 'package:flutter/material.dart';
import 'express_dashboard_page.dart';

/// ══════════════════════════════════════════════════════════════
///  PRODUCTION: Dynamic Success Page
///  Displays REAL data from the parcel request flow.
///  Zero hardcoded values.
/// ══════════════════════════════════════════════════════════════
class SenderRequestSuccessPage extends StatefulWidget {
  final Map<String, dynamic>? travelerData;

  const SenderRequestSuccessPage({super.key, this.travelerData});

  @override
  State<SenderRequestSuccessPage> createState() =>
      _SenderRequestSuccessPageState();
}

class _SenderRequestSuccessPageState extends State<SenderRequestSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
    final mode = widget.travelerData?['travel_mode']?.toString().toLowerCase();
    switch (mode) {
      case 'flight':
        return Icons.flight_takeoff;
      case 'train':
        return Icons.train;
      case 'bus':
        return Icons.directions_bus;
      default:
        return Icons.directions_car;
    }
  }

  String get _dateDisplay {
    final dateStr = widget.travelerData?['departure_time']?.toString();
    if (dateStr == null || dateStr.isEmpty) return 'Flexible';
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${months[dt.month]} ${dt.day}, ${dt.year} • ${hour == 0 ? 12 : hour}:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            /// Main Content Area
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 32),
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
                              color: const Color(0xFFF27F0D)
                                  .withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF27F0D),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: const Color(0xFFF27F0D)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8))
                            ],
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 40),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Header
                  const Text(
                    "Request Sent\nSuccessfully",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        height: 1.2),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Your delivery request has been forwarded to the traveler for review.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.5),
                  ),
                  const SizedBox(height: 32),

                  // Summary Card — REAL DATA
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black
                                .withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "STATUS",
                              style: TextStyle(
                                  fontFamily: "Plus Jakarta Sans",
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 1),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF27F0D)
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(24)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        color: Color(0xFFF27F0D),
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "Waiting for approval",
                                    style: TextStyle(
                                        fontFamily:
                                            "Plus Jakarta Sans",
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF27F0D)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(
                            height: 1,
                            color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 16),

                        // Route — DYNAMIC
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFFAFAFA),
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              child: Icon(_modeIcon,
                                  color:
                                      const Color(0xFFF27F0D),
                                  size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text("Route",
                                      style: TextStyle(
                                          fontFamily:
                                              "Plus Jakarta Sans",
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w500,
                                          color: Color(
                                              0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _origin,
                                          style: const TextStyle(
                                              fontFamily:
                                                  "Plus Jakarta Sans",
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                              color: Color(
                                                  0xFF0F172A)),
                                          overflow: TextOverflow
                                              .ellipsis,
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets
                                            .symmetric(
                                                horizontal: 4),
                                        child: Icon(
                                            Icons
                                                .arrow_forward,
                                            size: 12,
                                            color: Color(
                                                0xFF94A3B8)),
                                      ),
                                      Flexible(
                                        child: Text(
                                          _destination,
                                          style: const TextStyle(
                                              fontFamily:
                                                  "Plus Jakarta Sans",
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                              color: Color(
                                                  0xFF0F172A)),
                                          overflow: TextOverflow
                                              .ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Date — DYNAMIC
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFFAFAFA),
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              child: const Icon(
                                  Icons.calendar_today,
                                  color: Color(0xFFF27F0D),
                                  size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text("Date & Time",
                                      style: TextStyle(
                                          fontFamily:
                                              "Plus Jakarta Sans",
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w500,
                                          color: Color(
                                              0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text(
                                    _dateDisplay,
                                    style: const TextStyle(
                                        fontFamily:
                                            "Plus Jakarta Sans",
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.bold,
                                        color: Color(
                                            0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(
                            height: 1,
                            color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 16),

                        // Traveler Info — DYNAMIC
                        Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        const Color(0xFFE2E8F0),
                                    image: _travelerAvatar !=
                                            null
                                        ? DecorationImage(
                                            image: NetworkImage(
                                                _travelerAvatar!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _travelerAvatar == null
                                      ? Center(
                                          child: Text(
                                            _travelerName
                                                    .isNotEmpty
                                                ? _travelerName[
                                                        0]
                                                    .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                fontFamily:
                                                    "Plus Jakarta Sans",
                                                fontSize: 16,
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                                color: Color(
                                                    0xFF64748B)),
                                          ),
                                        )
                                      : null,
                                ),
                                if (_isVerified)
                                  Positioned(
                                    bottom: -2,
                                    right: -2,
                                    child: Container(
                                      decoration:
                                          const BoxDecoration(
                                              color:
                                                  Colors.white,
                                              shape: BoxShape
                                                  .circle),
                                      child: const Icon(
                                          Icons.verified,
                                          color: Colors.blue,
                                          size: 14),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text("Traveler",
                                      style: TextStyle(
                                          fontFamily:
                                              "Plus Jakarta Sans",
                                          fontSize: 10,
                                          color: Color(
                                              0xFF64748B))),
                                  Text(
                                    _travelerName,
                                    style: const TextStyle(
                                        fontFamily:
                                            "Plus Jakarta Sans",
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.bold,
                                        color: Color(
                                            0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  color: Color(0xFFF27F0D)),
                              onPressed: () {},
                              constraints:
                                  const BoxConstraints(),
                              padding:
                                  const EdgeInsets.all(8),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            /// Fixed Bottom Actions
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                    top: BorderSide(color: Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4))
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFF27F0D),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFFF27F0D)
                            .withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16)),
                      ),
                      onPressed: () {},
                      child: const Text("View Requests",
                          style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            const Color(0xFF64748B),
                        side: const BorderSide(
                            color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ExpressDashboardPage()),
                          (Route<dynamic> route) =>
                              route.isFirst,
                        );
                      },
                      child: const Text("Back to Home",
                          style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
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
}
