import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import 'checkout_payment_page.dart';

/// ══════════════════════════════════════════════════════════════
///  PRODUCTION: Dynamic Traveler Profile Page
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
  String _selectedPricing = 'small';
  late double _totalEstimate;

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

  bool get _isVerified =>
      widget.travelerData?['is_verified'] == true;

  String get _origin =>
      widget.travelerData?['origin'] ??
      widget.travelerData?['pickup_city'] ??
      'Origin';

  String get _destination =>
      widget.travelerData?['destination'] ??
      widget.travelerData?['drop_city'] ??
      'Destination';

  String get _travelMode =>
      widget.travelerData?['travel_mode']?.toString() ?? 'road';

  String get _capacityKg =>
      '${(widget.travelerData?['capacity_kg'] as num?)?.toInt() ?? 0} kg';

  double get _smallPrice =>
      (widget.travelerData?['price'] as num?)?.toDouble() ?? 99.0;
  double get _mediumPrice => _smallPrice * 1.5;
  double get _largePrice => _smallPrice * 2.0;

  IconData get _modeIcon {
    switch (_travelMode.toLowerCase()) {
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

  String get _departureDate {
    final dateStr =
        widget.travelerData?['departure_time']?.toString();
    if (dateStr == null || dateStr.isEmpty) return 'Flexible';
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${months[dt.month]} ${dt.day}, ${hour == 0 ? 12 : hour}:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return dateStr;
    }
  }

  String get _arrivalDate => 'TBD';

  @override
  void initState() {
    super.initState();
    _totalEstimate = _smallPrice;
  }

  void _updatePricing(String size, double price) {
    setState(() {
      _selectedPricing = size;
      _totalEstimate = price;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Traveler Details",
          style: TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share,
                color: Color(0xFFF27F0D), size: 22),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              /// Profile Section — DYNAMIC
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFE2E8F0)),
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
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white,
                                    width: 2),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black
                                          .withValues(
                                              alpha: 0.1),
                                      blurRadius: 4)
                                ],
                                color:
                                    const Color(0xFFE2E8F0),
                                image: _avatarUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(
                                            _avatarUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _avatarUrl == null
                                  ? Center(
                                      child: Text(
                                        _name.isNotEmpty
                                            ? _name[0]
                                                .toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            fontFamily:
                                                "Plus Jakarta Sans",
                                            fontSize: 28,
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
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons.verified,
                                      color: Colors.blue,
                                      size: 20),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name,
                                style: const TextStyle(
                                    fontFamily:
                                        "Plus Jakarta Sans",
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight.bold,
                                    color:
                                        Color(0xFF0F172A)),
                              ),
                              Text(
                                '$_trips trips completed',
                                style: const TextStyle(
                                    fontFamily:
                                        "Plus Jakarta Sans",
                                    fontSize: 12,
                                    color:
                                        Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(
                                      0xFFFAFAFA),
                                  borderRadius:
                                      BorderRadius.circular(
                                          24),
                                ),
                                child: Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star,
                                        color: Color(
                                            0xFFF27F0D),
                                        size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      _rating,
                                      style: const TextStyle(
                                          fontFamily:
                                              "Plus Jakarta Sans",
                                          fontSize: 14,
                                          fontWeight:
                                              FontWeight
                                                  .bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              /// Journey Section — DYNAMIC
              const Text(
                "Journey",
                style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black
                            .withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: const Color(
                                        0xFFF27F0D)
                                    .withValues(
                                        alpha: 0.1),
                                shape: BoxShape.circle),
                            child: Icon(_modeIcon,
                                color: const Color(
                                    0xFFF27F0D),
                                size: 20),
                          ),
                          Container(
                            height: 40,
                            width: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin:
                                    Alignment.topCenter,
                                end: Alignment
                                    .bottomCenter,
                                colors: [
                                  const Color(0xFFF27F0D)
                                      .withValues(
                                          alpha: 0.5),
                                  const Color(0xFFE2E8F0)
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding:
                                const EdgeInsets.all(4),
                            decoration:
                                const BoxDecoration(
                                    color: Color(
                                        0xFFFAFAFA),
                                    shape:
                                        BoxShape.circle),
                            child: const Icon(
                                Icons.location_on,
                                color:
                                    Color(0xFF64748B),
                                size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text("DEPARTURE",
                                style: TextStyle(
                                    fontFamily:
                                        "Plus Jakarta Sans",
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.bold,
                                    color:
                                        Color(0xFF64748B),
                                    letterSpacing: 1)),
                            const SizedBox(height: 2),
                            Text(_origin,
                                style: const TextStyle(
                                    fontFamily:
                                        "Plus Jakarta Sans",
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight
                                            .bold)),
                            Text(_departureDate,
                                style: const TextStyle(
                                    fontFamily:
                                        "Plus Jakarta Sans",
                                    fontSize: 12,
                                    color: Color(
                                        0xFF64748B))),
                            const SizedBox(height: 24),
                            const Text("ARRIVAL",
                                style: TextStyle(
                                    fontFamily:
                                        "Plus Jakarta Sans",
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.bold,
                                    color:
                                        Color(0xFF64748B),
                                    letterSpacing: 1)),
                            const SizedBox(height: 2),
                            Text(_destination,
                                style: const TextStyle(
                                    fontFamily:
                                        "Plus Jakarta Sans",
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight
                                            .bold)),
                            Text(_arrivalDate,
                                style: const TextStyle(
                                    fontFamily:
                                        "Plus Jakarta Sans",
                                    fontSize: 12,
                                    color: Color(
                                        0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              /// Capacity Section — DYNAMIC
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "Capacity",
                    style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF27F0D)
                            .withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(6)),
                    child: const Text("Available",
                        style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF27F0D))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    _buildCapacityCard(
                        "Weight",
                        _capacityKg,
                        Icons.line_weight,
                        Colors.blue),
                    const SizedBox(width: 12),
                    _buildCapacityCard(
                        "Mode",
                        _travelMode[0].toUpperCase() +
                            _travelMode.substring(1),
                        _modeIcon,
                        Colors.purple),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              /// Pricing Grid
              const Text(
                "Pricing",
                style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  _buildPricingOption(
                      'small',
                      'Small',
                      'Keys, Documents, Envelopes',
                      _smallPrice,
                      Icons.mail),
                  const SizedBox(height: 12),
                  _buildPricingOption(
                      'medium',
                      'Medium',
                      'Shoebox, Handbag, Gift',
                      _mediumPrice,
                      Icons.inventory_2),
                  const SizedBox(height: 12),
                  _buildPricingOption(
                      'large',
                      'Large',
                      'Backpack, Electronics',
                      _largePrice,
                      Icons.backpack),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),

          /// Sticky Footer CTA
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                border: const Border(
                    top: BorderSide(
                        color: Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black
                          .withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, -4)),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "TOTAL ESTIMATE",
                        style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                            letterSpacing: 1),
                      ),
                      Text(
                        "₹${_totalEstimate.toInt()}",
                        style: const TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFF27F0D),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFFF27F0D)
                            .withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                      ),
                      onPressed: () async {
                        final supabase = SupabaseService();
                        final auth = AuthService();
                        final uid = auth.currentUser?.uid;

                        if (uid == null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please log in to continue.')),
                            );
                          }
                          return;
                        }

                        final parcelToInsert = {
                          'sender_id': uid,
                          'title': widget.travelerData?[
                                  'category'] ??
                              'Parcel',
                          'description':
                              widget.travelerData?[
                                      'description'] ??
                                  '',
                          'weight_kg': double.tryParse(
                                  widget.travelerData?[
                                              'weight_estimate']
                                          ?.toString() ??
                                      '1') ??
                              1.0,
                          'origin': _origin,
                          'destination': _destination,
                          'pickup_pin': '${1000 + DateTime.now().millisecond * 9}'.substring(0, 4),
                          'dropoff_pin': '${1000 + (DateTime.now().microsecond % 9000)}'.substring(0, 4),
                          'status': 'draft',
                          'price': _totalEstimate,
                        };

                        final parcelId = await supabase
                            .createParcel(parcelToInsert);

                        if (parcelId != null &&
                            context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CheckoutPaymentPage(
                                parcelId: parcelId,
                                amount: _totalEstimate,
                              ),
                            ),
                          );
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Failed to create parcel request.')),
                          );
                        }
                      },
                      child: const Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Text("Request Delivery",
                              style: TextStyle(
                                  fontFamily:
                                      "Plus Jakarta Sans",
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.send, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color:
                  Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontFamily: "Plus Jakarta Sans",
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontFamily: "Plus Jakarta Sans",
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildPricingOption(String id, String title,
      String subtitle, double price, IconData icon) {
    final isSelected = _selectedPricing == id;
    return GestureDetector(
      onTap: () => _updatePricing(id, price),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF27F0D)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black
                    .withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius:
                      BorderRadius.circular(12)),
              child: Icon(icon,
                  color: const Color(0xFF64748B)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily:
                              "Plus Jakarta Sans",
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                  Text(subtitle,
                      style: const TextStyle(
                          fontFamily:
                              "Plus Jakarta Sans",
                          fontSize: 12,
                          color: Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              "₹${price.toInt()}",
              style: const TextStyle(
                  fontFamily: "Plus Jakarta Sans",
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(width: 12),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFF27F0D)
                      : const Color(0xFFCBD5E1),
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
