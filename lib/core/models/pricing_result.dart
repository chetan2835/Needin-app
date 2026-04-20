// ══════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — Pricing Result Model v3.0
//  Complete structured pricing response object
// ══════════════════════════════════════════════════════════════

enum PricingType { sameCity, slab, flight }

class PricingResult {
  final int price;
  final double distanceKm;
  final String duration;
  final PricingType pricingType;
  final String parcelSizeLabel;
  final String travelModeLabel;
  final int etrSeconds;
  final String etrText;
  final PricingBreakdown breakdown;
  final bool isSuccess;
  final String? error;

  const PricingResult({
    required this.price,
    required this.distanceKm,
    required this.duration,
    required this.pricingType,
    required this.parcelSizeLabel,
    required this.travelModeLabel,
    required this.breakdown,
    this.etrSeconds = 0,
    this.etrText = '',
    this.isSuccess = true,
    this.error,
  });

  factory PricingResult.error(String message) {
    return PricingResult(
      price: 0,
      distanceKm: 0,
      duration: '',
      pricingType: PricingType.slab,
      parcelSizeLabel: '',
      travelModeLabel: '',
      etrSeconds: 0,
      etrText: '',
      breakdown: PricingBreakdown.empty(),
      isSuccess: false,
      error: message,
    );
  }

  String get priceFormatted => '₹$price';

  String get pricingTypeLabel {
    switch (pricingType) {
      case PricingType.sameCity: return 'Same City';
      case PricingType.slab: return 'City to City';
      case PricingType.flight: return 'Flight';
    }
  }

  Map<String, dynamic> toJson() => {
    'price': price,
    'distance_km': distanceKm,
    'duration': duration,
    'pricing_type': pricingType.name,
    'parcel_size': parcelSizeLabel,
    'travel_mode': travelModeLabel,
    'etr_seconds': etrSeconds,
    'etr_text': etrText,
    'breakdown': breakdown.toJson(),
  };

  factory PricingResult.fromJson(Map<String, dynamic> json) {
    PricingType pType;
    switch (json['pricing_type']?.toString()) {
      case 'sameCity':
      case 'same_city':
        pType = PricingType.sameCity;
        break;
      case 'flight':
        pType = PricingType.flight;
        break;
      default:
        pType = PricingType.slab;
    }

    return PricingResult(
      price: (json['price'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      duration: json['duration']?.toString() ?? '',
      pricingType: pType,
      parcelSizeLabel: json['parcel_size']?.toString() ?? '',
      travelModeLabel: json['travel_mode']?.toString() ?? '',
      etrSeconds: (json['etr_seconds'] as num?)?.toInt() ?? 0,
      etrText: json['etr_text']?.toString() ?? '',
      breakdown: json['breakdown'] != null
          ? PricingBreakdown.fromJson(json['breakdown'] as Map<String, dynamic>)
          : PricingBreakdown.empty(),
    );
  }

  @override
  String toString() =>
      'PricingResult(₹$price, ${distanceKm}km, $pricingTypeLabel, ${breakdown.finalReason})';
}

class PricingBreakdown {
  final int basePrice;
  final String slabRange;
  final double timeMultiplier;
  final String timePerformanceLabel;
  final String routeType;
  final String finalReason;
  final String? flightCategory;

  const PricingBreakdown({
    required this.basePrice,
    required this.slabRange,
    required this.timeMultiplier,
    required this.timePerformanceLabel,
    required this.routeType,
    required this.finalReason,
    this.flightCategory,
  });

  factory PricingBreakdown.empty() => const PricingBreakdown(
    basePrice: 0,
    slabRange: '',
    timeMultiplier: 1.0,
    timePerformanceLabel: '',
    routeType: '',
    finalReason: '',
  );

  Map<String, dynamic> toJson() => {
    'base_price': basePrice,
    'slab_range': slabRange,
    'time_multiplier': timeMultiplier,
    'time_performance': timePerformanceLabel,
    'route_type': routeType,
    'final_reason': finalReason,
    if (flightCategory != null) 'flight_category': flightCategory,
  };

  factory PricingBreakdown.fromJson(Map<String, dynamic> json) {
    return PricingBreakdown(
      basePrice: (json['base_price'] as num?)?.toInt() ?? 0,
      slabRange: json['slab_range']?.toString() ?? '',
      timeMultiplier: (json['time_multiplier'] as num?)?.toDouble() ?? 1.0,
      timePerformanceLabel: json['time_performance']?.toString() ?? '',
      routeType: json['route_type']?.toString() ?? '',
      finalReason: json['final_reason']?.toString() ?? '',
      flightCategory: json['flight_category']?.toString(),
    );
  }

  @override
  String toString() => 'Breakdown($slabRange, ×$timeMultiplier, $finalReason)';
}
