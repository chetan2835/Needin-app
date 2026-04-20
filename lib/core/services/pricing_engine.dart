// ══════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — Local Pricing Engine v3.0
//  ⚠️ OFFLINE FALLBACK ONLY — Backend is the source of truth
//
//  Used ONLY when the Edge Function is unreachable.
//  Mirrors the exact same logic and slab data as the backend.
// ══════════════════════════════════════════════════════════════

import '../data/pricing_slabs.dart';
import '../models/pricing_result.dart';

/// Time performance tiers
/// Under Time = within ETR (Time₁ + 10% grace)
/// Delay ≤60% = × 0.85
/// Delay > 60% = × 0.75
enum TimePerformance { underTime, delayUpTo60, delayAbove60 }

/// Travel mode
enum TravelMode { bike, car, train, bus, flight }

/// Parcel size categories
enum ParcelSize { small, medium, large }

/// Pure stateless pricing engine — local fallback only.
class PricingEngine {
  PricingEngine._();

  // ──────────────────────────────────────────────────
  //  MAIN ENTRY POINT
  //  Priority: Flight → Same City → Slab
  // ──────────────────────────────────────────────────

  static PricingResult calculate({
    required double distanceKm,
    required String durationText,
    required int durationSeconds,
    required ParcelSize parcelSize,
    TravelMode travelMode = TravelMode.car,
    bool isSameCity = false,
    TimePerformance timePerformance = TimePerformance.underTime,
  }) {
    // ── COMPUTE ETR ──
    final etrSeconds = (durationSeconds * 1.10).ceil();
    final etrH = etrSeconds ~/ 3600;
    final etrM = (etrSeconds % 3600) ~/ 60;
    final etrText = etrH > 0 ? '$etrH hr $etrM min' : '$etrM min';
    final timeMultiplier = _timeMultiplier(timePerformance);

    // ═══════════════════════════════════════════════
    //  PRIORITY 1: FLIGHT OVERRIDE
    // ═══════════════════════════════════════════════
    if (travelMode == TravelMode.flight) {
      final flightSize = _mapToFlightSize(parcelSize);
      final price = FlightPricing.getPrice(flightSize);

      return PricingResult(
        price: price,
        distanceKm: distanceKm,
        duration: durationText,
        pricingType: PricingType.flight,
        parcelSizeLabel: flightSize,
        travelModeLabel: 'flight',
        etrSeconds: etrSeconds,
        etrText: etrText,
        breakdown: PricingBreakdown(
          basePrice: price,
          slabRange: 'N/A',
          timeMultiplier: 1.0,
          timePerformanceLabel: 'N/A',
          routeType: 'flight',
          finalReason: 'Flight override — fixed ₹$price for $flightSize parcel',
          flightCategory: flightSize,
        ),
      );
    }

    // ═══════════════════════════════════════════════
    //  PRIORITY 2: SAME CITY FIXED PRICING
    // ═══════════════════════════════════════════════
    if (isSameCity) {
      final sizeStr = parcelSize == ParcelSize.small ? 'small'
          : parcelSize == ParcelSize.medium ? 'medium' : 'large';
      final price = SameCityPricing.getPrice(sizeStr, timePerformance);
      final perfLabel = _perfLabel(timePerformance);

      return PricingResult(
        price: price,
        distanceKm: distanceKm,
        duration: durationText,
        pricingType: PricingType.sameCity,
        parcelSizeLabel: sizeStr,
        travelModeLabel: _modeLabel(travelMode),
        etrSeconds: etrSeconds,
        etrText: etrText,
        breakdown: PricingBreakdown(
          basePrice: 49,
          slabRange: 'Same City (0–50 km)',
          timeMultiplier: timeMultiplier,
          timePerformanceLabel: perfLabel,
          routeType: 'same_city',
          finalReason: 'Same city fixed pricing — ₹$price for $sizeStr ($perfLabel)',
        ),
      );
    }

    // ═══════════════════════════════════════════════
    //  PRIORITY 3: CITY-TO-CITY SLAB PRICING
    // ═══════════════════════════════════════════════
    final km = distanceKm.ceil();
    final slabs = CityToCitySlabs.getSlabs(parcelSize);
    final slab = CityToCitySlabs.findSlab(slabs, km);

    if (slab == null) {
      return PricingResult.error('Distance ${distanceKm.toStringAsFixed(1)} km out of range');
    }

    final price = _getSlabPrice(slab, timePerformance);
    final slabLabel = '${slab.minKm}–${slab.maxKm} km';
    final sizeStr = parcelSize == ParcelSize.small ? 'small'
        : parcelSize == ParcelSize.medium ? 'medium' : 'large';
    final perfLabel = _perfLabel(timePerformance);

    return PricingResult(
      price: price,
      distanceKm: distanceKm,
      duration: durationText,
      pricingType: PricingType.slab,
      parcelSizeLabel: sizeStr,
      travelModeLabel: _modeLabel(travelMode),
      etrSeconds: etrSeconds,
      etrText: etrText,
      breakdown: PricingBreakdown(
        basePrice: 99,
        slabRange: slabLabel,
        timeMultiplier: timeMultiplier,
        timePerformanceLabel: perfLabel,
        routeType: 'city_to_city',
        finalReason: 'Slab $slabLabel, $sizeStr parcel, $perfLabel',
      ),
    );
  }

  // ──────────────────────────────────────────────────
  //  SAME CITY DETECTION
  // ──────────────────────────────────────────────────

  static bool detectSameCity(double distanceKm, {String? originCity, String? destCity}) {
    // Method 1: City name match
    if (originCity != null && destCity != null) {
      final normO = originCity.toLowerCase().trim();
      final normD = destCity.toLowerCase().trim();
      if (normO == normD) return true;
      if (normO.contains(normD) || normD.contains(normO)) return true;
    }

    // Method 2: Distance threshold
    return distanceKm <= 50;
  }

  // ──────────────────────────────────────────────────
  //  HELPERS
  // ──────────────────────────────────────────────────

  static double _timeMultiplier(TimePerformance perf) {
    switch (perf) {
      case TimePerformance.underTime: return 1.0;
      case TimePerformance.delayUpTo60: return 0.85;
      case TimePerformance.delayAbove60: return 0.75;
    }
  }

  static String _perfLabel(TimePerformance perf) {
    switch (perf) {
      case TimePerformance.underTime: return 'Under Time (within ETR + 10%)';
      case TimePerformance.delayUpTo60: return 'Delay ≤60% beyond ETR';
      case TimePerformance.delayAbove60: return 'Delay >60% beyond ETR';
    }
  }

  static String _modeLabel(TravelMode mode) {
    switch (mode) {
      case TravelMode.bike: return 'bike';
      case TravelMode.car: return 'road';
      case TravelMode.train: return 'train';
      case TravelMode.bus: return 'bus';
      case TravelMode.flight: return 'flight';
    }
  }

  static String _mapToFlightSize(ParcelSize size) {
    switch (size) {
      case ParcelSize.small: return 'small';
      case ParcelSize.medium: return 'medium';
      case ParcelSize.large: return 'medium'; // Max for flight
    }
  }

  static int _getSlabPrice(SlabEntry slab, TimePerformance perf) {
    switch (perf) {
      case TimePerformance.underTime: return slab.underTime;
      case TimePerformance.delayUpTo60: return slab.delay60;
      case TimePerformance.delayAbove60: return slab.delayAbove60;
    }
  }
}
