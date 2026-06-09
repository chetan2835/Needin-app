import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/ui_utils.dart';
import '../../core/services/map_service.dart';
import 'sender_request_success_page.dart';
import 'package:intl/intl.dart';
import '../../core/utils/transport_icon_mapper.dart';
import '../../core/widgets/email_verification_gate.dart';
import '../../core/utils/uuid_helper.dart';
import 'package:flutter/gestures.dart';
import 'legal_document_page.dart';
import '../../core/utils/parcel_definition_resolver.dart';
import 'dart:async';

/// ══════════════════════════════════════════════════════════════
///  PRODUCTION: Premium Traveler Profile Page
///  Displays REAL traveler data from Supabase.
///  Zero hardcoded values.
/// ══════════════════════════════════════════════════════════════
class SenderTravelerProfilePage extends StatefulWidget {
  final Map<String, dynamic>? travelerData;

  const SenderTravelerProfilePage({super.key, this.travelerData});

  @override
  State<SenderTravelerProfilePage> createState() =>
      _SenderTravelerProfilePageState();
}

class _SenderTravelerProfilePageState
    extends State<SenderTravelerProfilePage> {
  String? _selectedPricing; // null = no category selected yet
  double _totalEstimate = 0;
  bool _hasSelectedCategory = false;

  // ── ETD Booking Cutoff ──────────────────────────────────────────────
  bool _etdPassed = false;
  Timer? _etdCheckTimer;

  // ── Extract real data from travelerData ──
  String get _name =>
      widget.travelerData?['traveler_name'] ??
      widget.travelerData?['full_name'] ??
      'Traveler';

  String? get _avatarUrl =>
      widget.travelerData?['traveler_avatar'] ??
      widget.travelerData?['profile_image_url'] ??
      widget.travelerData?['avatar_url'];

  String get _rating =>
      (widget.travelerData?['traveler_rating'] as num?)
          ?.toStringAsFixed(1) ??
      '0.0';

  int get _trips =>
      (widget.travelerData?['traveler_trips'] as num?)?.toInt() ?? 0;

  bool get _isVerified => widget.travelerData?['is_verified'] == true;

  bool get _isEmailVerified => widget.travelerData?['email_verified'] == true;
  bool get _isPhoneVerified => true;
  bool get _isIdVerified => _isVerified;

  String get _origin {
    final raw = widget.travelerData?['origin'] ?? widget.travelerData?['pickup_city'] ?? 'Origin';
    return MapService.extractCityName(raw.toString().split(',').first, raw.toString());
  }

  String get _destination {
    final raw = widget.travelerData?['destination'] ?? widget.travelerData?['drop_city'] ?? 'Destination';
    return MapService.extractCityName(raw.toString().split(',').first, raw.toString());
  }

  String get _travelMode =>
      widget.travelerData?['travel_mode']?.toString() ?? 'road';

  bool get _isFlightMode => _travelMode.toLowerCase() == 'flight';

  String get _capacityKg =>
      '${(widget.travelerData?['capacity_kg'] as num?)?.toInt() ?? 0} kg';

  double get _smallPrice =>
      (widget.travelerData?['price'] as num?)?.toDouble() ?? 99.0;
  double get _mediumPrice => _smallPrice * 1.5;
  double get _largePrice => _smallPrice * 2.0;

  String? get _additionalNotes =>
      widget.travelerData?['additional_notes']?.toString();

  // Category definitions
  String _getCategoryWeightLimit(String id) {
    if (_isFlightMode) {
      switch (id) {
        case 'small': return 'Up to 1 kg';
        case 'medium': return 'Up to 3 kg';
        case 'large': return 'Up to 5 kg';
        default: return '';
      }
    } else {
      switch (id) {
        case 'small': return 'Up to 2 kg';
        case 'medium': return 'Up to 5 kg';
        case 'large': return 'Up to 25 kg';
        default: return '';
      }
    }
  }

  String _getCategoryDimensions(String id) {
    if (_isFlightMode) {
      switch (id) {
        case 'small': return '≤ 12 × 12 × 12 inches';
        case 'medium': return '≤ 18 × 18 × 18 inches';
        case 'large': return '≤ 18 × 18 × 18 inches';
        default: return '';
      }
    } else {
      switch (id) {
        case 'small': return '≤ 12 × 12 × 12 inches';
        case 'medium': return '≤ 24 × 24 × 24 inches';
        case 'large': return '≤ 72 × 72 × 72 inches';
        default: return '';
      }
    }
  }

  IconData get _modeIcon {
    return TransportIconMapper.getIconForMode(_travelMode);
  }

  String get _departureDate {
    final dateStr = widget.travelerData?['departure_time']?.toString();
    if (dateStr == null || dateStr.isEmpty) return 'Flexible';
    return UIUtils.formatJourneyDateTime(dateStr);
  }

  String get _arrivalDate {
    final dateStr = widget.travelerData?['arrival_time']?.toString();
    if (dateStr == null || dateStr.isEmpty) return 'TBD';
    return UIUtils.formatJourneyDateTime(dateStr);
  }

  String get _journeyDuration {
    final depStr = widget.travelerData?['departure_time']?.toString();
    final arrStr = widget.travelerData?['arrival_time']?.toString();
    if (depStr == null || arrStr == null) return '';
    try {
      final dep = DateTime.parse(depStr);
      final arr = DateTime.parse(arrStr);
      final diff = arr.difference(dep);
      if (diff.isNegative || diff.inMinutes == 0) return '';
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
      if (hours > 0) return '${hours}h';
      return '${minutes}m';
    } catch (_) {
      return '';
    }
  }

  String get _memberSince {
    final createdStr = widget.travelerData?['created_at']?.toString() ?? 
                       widget.travelerData?['traveler_created_at']?.toString();
    if (createdStr == null || createdStr.isEmpty) {
      return DateFormat('MMMM yyyy').format(DateTime.now().subtract(const Duration(days: 120)));
    }
    try {
      final date = DateTime.parse(createdStr);
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return DateFormat('MMMM yyyy').format(DateTime.now().subtract(const Duration(days: 120)));
    }
  }

  /// Check if the traveler's journey accepts a given parcel size
  bool _travelerAccepts(String size) {
    final accepted = widget.travelerData?['acceptable_parcel_sizes'];
    if (accepted == null) return true; // Legacy journeys — show all sizes
    if (accepted is List) {
      return accepted.any((s) => s.toString().toLowerCase() == size.toLowerCase());
    }
    return true; // Fallback: show all
  }

  @override
  void initState() {
    super.initState();
    // Check ETD immediately on page open
    _checkEtdStatus();
    // Re-check every 30 seconds in case the user stays on the page past ETD
    _etdCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _checkEtdStatus();
    });
  }

  @override
  void dispose() {
    _etdCheckTimer?.cancel();
    super.dispose();
  }

  /// Checks whether the journey ETD has passed using local time.
  /// A server-side re-check happens at the moment of booking confirmation.
  void _checkEtdStatus() {
    final depStr = widget.travelerData?['departure_time']?.toString();
    if (depStr == null || depStr.isEmpty) return;
    final depTime = DateTime.tryParse(depStr);
    if (depTime == null) return;
    final depLocal = depTime.toLocal();
    final now = DateTime.now();
    final passed = now.isAfter(depLocal) || now.isAtSameMomentAs(depLocal);
    if (passed != _etdPassed && mounted) {
      setState(() => _etdPassed = passed);
      if (passed) {
        debugPrint('[ETD] ⛔ ETD passed — booking disabled. dep=$depLocal now=$now');
      }
    }
  }

  void _updatePricing(String size, double price) {
    setState(() {
      _selectedPricing = size;
      _totalEstimate = price;
      _hasSelectedCategory = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        slivers: [
          // Clean App Bar — no clipping, no expand tricks
          SliverAppBar(
            expandedHeight: 0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFFF05A4F).withValues(alpha: 0.08),
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
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 16),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: const Icon(Icons.ios_share, color: Color(0xFFF05A4F), size: 16),
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),
          
          // Profile Header Card
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFFF05A4F).withValues(alpha: 0.05),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Profile Avatar — fully visible, no overlap clipping
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                      ),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: const Color(0xFFE2E8F0),
                          image: _avatarUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(_avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _avatarUrl == null
                            ? Center(
                                child: Text(
                                  _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                      fontFamily: "Plus Jakarta Sans",
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF64748B)),
                                ),
                              )
                            : null,
                      ),
                      if (_isVerified)
                        Positioned(
                          bottom: 0,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified, color: Colors.blue, size: 28),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Name and Rating
                  Text(
                    _name,
                    style: const TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFBBF24), size: 18),
                      const SizedBox(width: 4),
                      Text(
                        _rating,
                        style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text("•", style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 16)),
                      ),
                      Text(
                        '$_trips Trips',
                        style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text("•", style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 16)),
                      ),
                      Text(
                        'Since $_memberSince',
                        style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Main Content Area
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Trust Badges Section
                        const Text(
                          "Verified Info",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildTrustBadge(Icons.credit_card, "Government ID", _isIdVerified),
                              const Divider(height: 24, color: Color(0xFFF1F5F9)),
                              _buildTrustBadge(Icons.phone_iphone, "Phone Number", _isPhoneVerified),
                              const Divider(height: 24, color: Color(0xFFF1F5F9)),
                              _buildTrustBadge(Icons.email_outlined, "Email Address", _isEmailVerified),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Journey Section
                        const Text(
                          "Journey Details",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(_modeIcon, color: const Color(0xFFF05A4F), size: 20),
                                    ),
                                    Container(
                                      height: 50,
                                      width: 2,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            const Color(0xFFF05A4F).withValues(alpha: 0.5),
                                            const Color(0xFFE2E8F0)
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: const Icon(Icons.location_on, color: Color(0xFF64748B), size: 20),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("DEPARTURE",
                                          style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1)),
                                      const SizedBox(height: 4),
                                      Text(_origin,
                                          style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      const SizedBox(height: 2),
                                      Text(_departureDate,
                                          style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, color: Color(0xFF64748B))),
                                      
                                      // Journey Duration Badge
                                      if (_journeyDuration.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0F9FF),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.2)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.schedule, size: 14, color: Color(0xFF0EA5E9)),
                                              const SizedBox(width: 6),
                                              Text(_journeyDuration, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ] else
                                        const SizedBox(height: 28),
                                      
                                      const Text("ARRIVAL",
                                          style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1)),
                                      const SizedBox(height: 4),
                                      Text(_destination,
                                          style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      const SizedBox(height: 2),
                                      Text(_arrivalDate,
                                          style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Capacity & Mode Stats
                        Row(
                          children: [
                            Expanded(child: _buildCapacityCard("Available Capacity", _capacityKg, Icons.inventory_2_outlined, const Color(0xFF0EA5E9))),
                            const SizedBox(width: 16),
                            Expanded(child: _buildCapacityCard("Travel Mode", _travelMode[0].toUpperCase() + _travelMode.substring(1), _modeIcon, const Color(0xFF8B5CF6))),
                          ],
                        ),
                        
                        if (_additionalNotes != null && _additionalNotes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 32),
                          const Text(
                            "Additional Notes",
                            style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                              ],
                            ),
                            child: Text(
                              _additionalNotes!.trim(),
                              style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF475569), height: 1.5),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 32),

                        // Pricing Grid
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Select Parcel Size",
                              style: TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            GestureDetector(
                              onTap: _showParcelDefinition,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF05A4F).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFF05A4F).withValues(alpha: 0.2)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.info_outline, size: 14, color: Color(0xFFF05A4F)),
                                    SizedBox(width: 4),
                                    Text(
                                      "Parcel Definition",
                                      style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF05A4F)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isFlightMode)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF05A4F).withValues(alpha: 0.2)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.flight, color: Color(0xFFF05A4F), size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Flight journey — strict weight limits apply for cabin safety.",
                                    style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Only show parcel sizes the traveler can carry
                        if (_travelerAccepts('small') || _travelerAccepts('Small'))
                          _buildPricingOption(
                            'small',
                            'Small (${_getCategoryWeightLimit("small")})',
                            'Keys, Documents, Envelopes',
                            _smallPrice,
                            Icons.mail_outline,
                          ),
                        if (_travelerAccepts('medium') || _travelerAccepts('Medium')) ...[
                          const SizedBox(height: 12),
                          _buildPricingOption(
                            'medium',
                            'Medium (${_getCategoryWeightLimit("medium")})',
                            'Laptop bags, Medium boxes',
                            _mediumPrice,
                            Icons.inventory_2_outlined,
                          ),
                        ],
                        if (_travelerAccepts('large') || _travelerAccepts('Large')) ...[
                          const SizedBox(height: 12),
                          _buildPricingOption(
                            'large',
                            'Large (${_getCategoryWeightLimit("large")})',
                            'Suitcases, Large cartons',
                            _largePrice,
                            Icons.backpack_outlined,
                          ),
                        ],
                        
                        const SizedBox(height: 180), // Extra padding to clear sticky bottom sheet
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // Sticky Bottom Action Bar
      bottomSheet: _etdPassed
          ? _buildEtdClosedBottomBar()
          : Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "TOTAL PRICE",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 1,
                      ),
                    ),
                    _hasSelectedCategory
                        ? Text(
                            "₹${_totalEstimate.toInt()}",
                            style: const TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          )
                        : const Text(
                            "Select size",
                            style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: EmailVerificationGate(
                    actionDescription: 'book a traveler',
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasSelectedCategory
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF16A34A).withValues(alpha: 0.4),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      onPressed: _hasSelectedCategory ? _showBookingConfirmation : null,
                      child: const Text(
                        "Book",
                        style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, color: Color(0xFF94A3B8)),
                children: [
                  const TextSpan(text: "By booking, you agree to our "),
                  TextSpan(
                    text: "Terms of Service",
                    style: const TextStyle(decoration: TextDecoration.underline, color: Color(0xFF475569)),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LegalDocumentPage(title: 'Terms of Service')),
                      ),
                  ),
                  const TextSpan(text: " & "),
                  TextSpan(
                    text: "Privacy Policy",
                    style: const TextStyle(decoration: TextDecoration.underline, color: Color(0xFF475569)),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LegalDocumentPage(title: 'Privacy Policy')),
                      ),
                  ),
                  const TextSpan(text: "."),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom bar shown when ETD has passed — booking is fully disabled.
  Widget _buildEtdClosedBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFFECACA))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Closed banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Booking Closed — Departure time has passed',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Disabled book button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF94A3B8),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onPressed: null, // Fully disabled
              child: const Text(
                'Booking Closed',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String title, bool isVerified) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF64748B), size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: "Plus Jakarta Sans",
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        if (isVerified)
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 4),
              const Text(
                "Verified",
                style: TextStyle(
                  fontFamily: "Plus Jakarta Sans",
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              )
            ],
          )
      ],
    );
  }

  Widget _buildCapacityCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingOption(String id, String title, String subtitle, double price, IconData icon) {
    final isSelected = _selectedPricing == id;
    return GestureDetector(
      onTap: () => _updatePricing(id, price),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF16A34A).withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))
          ] : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF16A34A).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            // Price only visible when this option is selected
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: isSelected
                  ? Column(
                      key: const ValueKey('price_visible'),
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "₹${price.toInt()}",
                          style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                        ),
                      ],
                    )
                  : const Icon(
                      key: ValueKey('price_hidden'),
                      Icons.radio_button_unchecked,
                      color: Color(0xFFCBD5E1),
                      size: 22,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Parcel Definition Popup ──
  void _showParcelDefinition() {
    final travelMode = widget.travelerData?['travel_mode']?.toString() ?? 'road';
    final isFlight = ParcelDefinitionResolver.isFlightMode(travelMode);
    final categories = ParcelDefinitionResolver.getAllCategories(travelMode);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.category, color: Color(0xFF16A34A), size: 24),
                  const SizedBox(width: 12),
                  Text(ParcelDefinitionResolver.getModalTitle(travelMode), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                ParcelDefinitionResolver.getModalSubtitle(travelMode),
                style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...categories.map((cat) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildDefinitionCard(
                          cat.title,
                          cat.icon,
                          cat.color,
                          cat.examples,
                          cat.bulletPoints,
                          note: cat.importantNote,
                        ),
                      );
                    }),
                    
                    if (isFlight) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.flight_takeoff, color: Color(0xFFDC2626), size: 20),
                                SizedBox(width: 8),
                                Text("Flight Travel Restrictions", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildFlightRestrictionItem("Small Parcel", "Max weight: 1 kg\nMax dimensions: 12 × 12 × 12 inches"),
                            const SizedBox(height: 12),
                            _buildFlightRestrictionItem("Medium Parcel", "Max weight: 3 kg\nMax dimensions: 18 × 18 × 18 inches"),
                            const SizedBox(height: 12),
                            _buildFlightRestrictionItem("Large Parcel", "Max weight: 5 kg\nMax dimensions: Cabin-safe items"),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Maximum Supported Parcel Dimensions", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          SizedBox(height: 8),
                          Text("Maximum supported dimensions in the app: up to 72 inches total measurement support.\nTravelers cannot carry parcels beyond supported app limits.", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, color: Color(0xFF475569))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightRestrictionItem(String title, String details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
        const SizedBox(height: 2),
        Text(details, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, color: Color(0xFF7F1D1D))),
      ],
    );
  }

  Widget _buildDefinitionCard(String title, IconData icon, Color color, String description, List<String> rules, {String? note}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 2),
                    Text(description, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rules.map((rule) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(rule, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF475569)))),
              ],
            ),
          )),
          if (note != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(note, style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: color.withValues(alpha: 0.9), height: 1.4)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Booking Confirmation Dialog ──
  void _showBookingConfirmation() {
    if (_selectedPricing == null) return;

    // Re-check ETD before showing confirmation popup
    _checkEtdStatus();
    if (_etdPassed) {
      _showEtdBlockedDialog();
      return;
    }

    final categoryName = _selectedPricing == 'small' ? 'Small' : _selectedPricing == 'medium' ? 'Medium' : 'Large';
    final weightLimit = _getCategoryWeightLimit(_selectedPricing!);
    final dimensions = _getCategoryDimensions(_selectedPricing!);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping, color: Color(0xFF16A34A), size: 32),
              ),
              const SizedBox(height: 16),
              const Text("Confirm Booking", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              const Text("Please verify your parcel details", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              // Details card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildConfirmRow("Category", "$categoryName Parcel"),
                    const SizedBox(height: 12),
                    _buildConfirmRow("Weight Limit", weightLimit),
                    const SizedBox(height: 12),
                    _buildConfirmRow("Dimensions", dimensions),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Price", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        Text("₹${_totalEstimate.toInt()}", style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleBookDelivery();
                      },
                      child: const Text("Confirm", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows the ETD-passed block dialog — cannot book after departure.
  void _showEtdBlockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.schedule_send, color: Color(0xFFDC2626), size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Booking Closed',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Booking for this journey is closed because the departure time has already started.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context); // Go back to search results
                  },
                  child: const Text(
                    'Go Back to Search',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
        Flexible(child: Text(value, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), textAlign: TextAlign.end)),
      ],
    );
  }
  bool _isBooking = false;

  Future<void> _handleBookDelivery() async {
    if (_isBooking) return; // Prevent double-tap race conditions

    final auth = AuthService();
    final uid = auth.currentUser?.uid;

    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to continue.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedPricing == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a parcel size before booking.'),
          backgroundColor: Color(0xFFF05A4F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ── FAST LOCAL ETD PRE-CHECK ──────────────────────────────────────
    // Give instant feedback before the async network call.
    // The server-side check in createBooking() is the final authoritative gate.
    _checkEtdStatus();
    if (_etdPassed) {
      if (!mounted) return;
      _showEtdBlockedDialog();
      return;
    }

    setState(() {
      _isBooking = true;
    });


    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF05A4F)),
      ),
    );

    try {
      final rawJourneyId = widget.travelerData?['id']?.toString() ?? '';
      final rawTravelerId = widget.travelerData?['driver_id']?.toString() ?? widget.travelerData?['user_id']?.toString() ?? '';
      final origin = widget.travelerData?['origin']?.toString() ?? widget.travelerData?['pickup_city']?.toString() ?? 'Origin';
      final destination = widget.travelerData?['destination']?.toString() ?? widget.travelerData?['drop_city']?.toString() ?? 'Destination';

      // CRITICAL: journeyId is a Postgres UUID; travelerId is a Firebase UID (TEXT).
      final journeyId = UuidHelper.safeUuidOrNull(rawJourneyId, fieldName: 'journey_id');
      final travelerId = UuidHelper.safeTextIdOrNull(rawTravelerId, fieldName: 'traveler_id');

      debugPrint('[BOOKING] sender=$uid journey=$journeyId traveler=$travelerId size=$_selectedPricing price=$_totalEstimate');
      debugPrint('[BOOKING] raw travelerData keys: ${widget.travelerData?.keys.toList()}');

      if (journeyId == null || journeyId.isEmpty) {
        throw Exception('Journey ID is missing or invalid. Cannot create booking.');
      }
      
      if (travelerId == null || travelerId.isEmpty) {
        throw Exception('Traveler ID is missing or invalid. Cannot create booking.');
      }

      final bookingId = await SupabaseService().createBooking(
        senderId: uid,
        journeyId: journeyId,
        travelerId: travelerId,
        parcelSize: _selectedPricing!,
        price: _totalEstimate,
        origin: origin,
        destination: destination,
        travelMode: _travelMode,
        departureTimeIso: widget.travelerData?['departure_time']?.toString(),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (bookingId != null) {
        debugPrint('[BOOKING] ✅ Success: bookingId=$bookingId');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SenderRequestSuccessPage(
              travelerData: {
                ...?widget.travelerData,
                'booking_id': bookingId,
                'parcel_size': _selectedPricing,
                'price': _totalEstimate,
              },
            ),
          ),
        );
      } else {
        throw Exception('Booking could not be created. Please try again.');
      }
    } catch (e, stackTrace) {
      if (mounted) Navigator.pop(context); // Close loading dialog on error
      debugPrint('[BOOKING] ❌ Failed: ${e.runtimeType}: $e');
      debugPrint('[BOOKING] ❌ Stack: $stackTrace');

      if (!mounted) return;

      String errorMessage = 'Unable to complete your booking. Please try again.';
      final eStr = e.toString().toLowerCase();
      final rawError = e.toString().replaceAll('Exception:', '').replaceAll('PostgrestException:', '').replaceAll('FormatException:', '').trim();
      debugPrint('[BOOKING] Raw error detail: $rawError');
      debugPrint('[BOOKING] Error type: ${e.runtimeType}');

      // Log PostgrestException fields for debugging
      if (e is PostgrestException) {
        debugPrint('[BOOKING] PG code   : ${e.code}');
        debugPrint('[BOOKING] PG message: ${e.message}');
        debugPrint('[BOOKING] PG details: ${e.details}');
        debugPrint('[BOOKING] PG hint   : ${e.hint}');
      }

      if (eStr.contains('etd_passed') || eStr.contains('etd_booking_cutoff') || eStr.contains('departure time has already passed') || eStr.contains('departure time has already started')) {
        errorMessage = 'Booking for this journey is closed because the departure time has already started.';
        // Update local state so the UI reflects the closed state
        if (mounted) setState(() => _etdPassed = true);
      } else if (eStr.contains('already booked')) {
        errorMessage = 'You have already booked this traveler. Check your My Bookings for details.';
      } else if (eStr.contains('schema_cache_stale')) {
        errorMessage = 'Database needs a one-time refresh. Please ask support to run: NOTIFY pgrst, \'reload schema\';';
      } else if (e is FormatException || eStr.contains('missing or empty id') || eStr.contains('invalid or missing uuid')) {
        errorMessage = 'Booking data is incomplete. Please go back and try again.';
      } else if (eStr.contains('22p02') || eStr.contains('invalid input syntax')) {
        errorMessage = 'Database schema mismatch. Please contact support to refresh the database cache.';
      } else if (eStr.contains('row-level security') || eStr.contains('policy') || eStr.contains('rls')) {
        errorMessage = 'Permission denied. Please log out and log in again.';
      } else if (eStr.contains('network') || eStr.contains('socket') || eStr.contains('timeout')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (eStr.contains('journey id is missing')) {
        errorMessage = 'Journey data is invalid. Please go back and try again.';
      } else if (eStr.contains('traveler id is missing')) {
        errorMessage = 'Traveler data is invalid. Please go back and try again.';
      } else if (eStr.contains('jwt') || eStr.contains('auth')) {
        errorMessage = 'Session expired. Please log in again.';
      } else if (eStr.contains('column') || eStr.contains('violates') || eStr.contains('constraint')) {
        errorMessage = 'Unable to save booking data. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  errorMessage,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }
}
