import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'flexibility_options_page.dart';
import '../../core/utils/parcel_definition_resolver.dart';
import '../../core/data/pricing_slabs.dart';
import 'package:provider/provider.dart';
import '../../core/providers/journey_draft_provider.dart';

class ParcelSizeSelectionPage extends StatefulWidget {
  final Map<String, dynamic> journeyData;

  const ParcelSizeSelectionPage({super.key, required this.journeyData});

  @override
  State<ParcelSizeSelectionPage> createState() => _ParcelSizeSelectionPageState();
}

class _ParcelSizeSelectionPageState extends State<ParcelSizeSelectionPage> {
  final bool _isLoading = false;

  bool get _isFlightMode => (widget.journeyData['travel_mode'] ?? 'road') == 'flight';

  // ── Compute route distance from coordinates (haversine) ──
  double get _routeDistanceKm {
    final stored = (widget.journeyData['distance_km'] as num?)?.toDouble();
    if (stored != null && stored > 0) return stored;
    final oLat = (widget.journeyData['origin_lat'] as num?)?.toDouble();
    final oLng = (widget.journeyData['origin_lng'] as num?)?.toDouble();
    final dLat = (widget.journeyData['dest_lat'] as num?)?.toDouble() ??
        (widget.journeyData['destination_lat'] as num?)?.toDouble();
    final dLng = (widget.journeyData['dest_lng'] as num?)?.toDouble() ??
        (widget.journeyData['destination_lng'] as num?)?.toDouble();
    if (oLat == null || oLng == null || dLat == null || dLng == null) return 0;
    const R = 6371.0;
    final dLatR = (dLat - oLat) * math.pi / 180;
    final dLngR = (dLng - oLng) * math.pi / 180;
    final a = math.sin(dLatR / 2) * math.sin(dLatR / 2) +
        math.cos(oLat * math.pi / 180) * math.cos(dLat * math.pi / 180) *
        math.sin(dLngR / 2) * math.sin(dLngR / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)) * 1.3; // road factor
  }

  // ── Slab price for a parcel size (non-flight only) ──
  String? _getSlabPrice(String size) {
    if (_isFlightMode) {
      // Flight: fixed prices from FlightPricing
      return '\u20B9${FlightPricing.getPrice(size.toLowerCase())}';
    }
    final km = _routeDistanceKm;
    if (km <= 0) return null; // no coords, don't show price
    final kmInt = km.round();
    List<SlabEntry> slabs;
    switch (size.toLowerCase()) {
      case 'small': slabs = CityToCitySlabs.smallSlabs; break;
      case 'medium': slabs = CityToCitySlabs.mediumSlabs; break;
      default: slabs = CityToCitySlabs.largeSlabs;
    }
    final slab = CityToCitySlabs.findSlab(slabs, kmInt);
    if (slab == null) return null;
    return '\u20B9${slab.underTime}';
  }

  bool _isSupported(String size) {
    final supported = widget.journeyData['supported_categories'] as List<dynamic>? ?? [];
    return supported.contains(size);
  }

  Future<void> _submitJourney() async {
    final provider = Provider.of<JourneyDraftProvider>(context, listen: false);

    List<String> parcelSizes = [];
    if (_isSupported('Small')) parcelSizes.add('Small');
    if (_isSupported('Medium')) parcelSizes.add('Medium');
    if (_isSupported('Large')) parcelSizes.add('Large');

    Map<String, dynamic> parcelSizeLimits;
    Map<String, dynamic> priceData = {};

    if (_isFlightMode) {
      parcelSizeLimits = {
        'small_max_kg': 1,
        'medium_max_kg': 3,
        'large_max_kg': 5,
        'is_flight_restricted': true,
      };
      priceData = {
        'price_small': FlightPricing.getPrice('small'),
        'price_medium': FlightPricing.getPrice('medium'),
        'price_large': FlightPricing.getPrice('large'),
        'earnings_small': FlightPricing.getPrice('small'),
        'earnings_medium': FlightPricing.getPrice('medium'),
        'earnings_large': FlightPricing.getPrice('large'),
      };
    } else {
      parcelSizeLimits = {
        'small_max_kg': 2,
        'medium_max_kg': 5,
        'large_max_kg': 25,
        'is_flight_restricted': false,
      };
      final km = _routeDistanceKm;
      final kmInt = km.round();
      final smallSlab = CityToCitySlabs.findSlab(CityToCitySlabs.smallSlabs, kmInt);
      final medSlab = CityToCitySlabs.findSlab(CityToCitySlabs.mediumSlabs, kmInt);
      final largeSlab = CityToCitySlabs.findSlab(CityToCitySlabs.largeSlabs, kmInt);
      priceData = {
        'price_small': smallSlab?.underTime,
        'price_medium': medSlab?.underTime,
        'price_large': largeSlab?.underTime,
        'earnings_small': smallSlab?.underTime,
        'earnings_medium': medSlab?.underTime,
        'earnings_large': largeSlab?.underTime,
      };
    }

    provider.updateData({
      'acceptable_parcel_sizes': parcelSizes,
      'parcel_size_limits': parcelSizeLimits,
      ...priceData,
    });

    Navigator.push(context,
      MaterialPageRoute(
        builder: (_) => FlexibilityOptionsPage(journeyData: provider.draftData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            /// Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              color: const Color(0xFFFAFAFA).withValues(alpha: 0.95),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      color: Colors.transparent,
                      child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      "Traveler Journey",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            /// Progress Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: const [
                        Text(
                          "Step 4 of 7",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          "57%",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22C55E),
                          ),
                        )
                     ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.57,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "What size parcel can you carry?",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "According to the space and weight provided by you, you can only carry these parcel categories.",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 15,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Non-flight: Route Pricing Info Badge
                    if (!_isFlightMode && _routeDistanceKm > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.route, color: Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 10),
                            Text(
                              '${_routeDistanceKm.round()} km route · Prices shown per parcel',
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Flight Restriction Info


                    Builder(
                      builder: (context) {
                        final travelMode = widget.journeyData['travel_mode']?.toString() ?? 'road';
                        final categories = ParcelDefinitionResolver.getAllCategories(travelMode);
                        return Column(
                          children: categories.map((cat) {
                            final isSmall = cat.title.contains('Small');
                            final isMedium = cat.title.contains('Medium');
                            final sizeKey = isSmall ? 'Small' : isMedium ? 'Medium' : 'Large';
                            final priceStr = _getSlabPrice(sizeKey);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildReadOnlyCard(
                                title: sizeKey,
                                maxWeight: cat.maxWeight,
                                dimensionHint: cat.dimensions,
                                subtitle: cat.examples,
                                icon: isSmall ? Icons.mail : isMedium ? Icons.inventory_2 : Icons.luggage,
                                isSelected: _isSupported(sizeKey),
                                priceStr: priceStr,
                              ),
                            );
                          }).toList(),
                        );
                      }
                    ),
                    const SizedBox(height: 12),
                    
                    // Helper Note
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isFlightMode 
                              ? "Automatically determined for air travel based on dimensions and weight." 
                              : "Automatically determined based on parcel dimensions and weight.",
                            style: const TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 100), // buffer
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA).withValues(alpha: 0.95),
          border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF16A34A).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isLoading ? null : _submitJourney,
            child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      "Continue",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyCard({
    required String title,
    required String maxWeight,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    String? priceStr,
    String? dimensionHint,
  }) {
    final activeColor = const Color(0xFF16A34A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? activeColor.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? activeColor : const Color(0xFFE2E8F0),
          width: 2,
        ),
        boxShadow: [
          if (!isSelected)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                  : [],
            ),
            child: Icon(
              icon,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        maxWeight,
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
                if (dimensionHint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    dimensionHint,
                    style: TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? activeColor : const Color(0xFFCBD5E1),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 14,
                    color: isSelected ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          if (priceStr != null && isSelected)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Text(
                priceStr,
                style: const TextStyle(
                  fontFamily: "Plus Jakarta Sans",
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          if (isSelected)
            Icon(Icons.lock, color: activeColor, size: 16),
        ],
      ),
    );
  }
}
