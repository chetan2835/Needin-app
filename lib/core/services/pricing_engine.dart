// ══════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — Local Pricing Engine v4.0
//  ⚠️ OFFLINE FALLBACK ONLY — Backend is the source of truth
//
//  Used ONLY when the Edge Function is unreachable.
//  Mirrors the exact same logic and slab data as the backend.
//
//  v4 changes:
//  - Time delay tiers: 30% (not 60%)
//  - Same city: 15 km (not 50 km)
//  - Flight: supports large parcel (₹949)
// ══════════════════════════════════════════════════════════════

import '../data/pricing_slabs.dart';
import '../models/pricing_result.dart';

/// Time performance tiers (ETR-based)
/// Under Time = within ETR (Time₁ + 10% grace)
/// Delay ≤30% beyond ETR → × 0.85
/// Delay >30% beyond ETR → × 0.75
enum TimePerformance { underTime, delayUpTo30, delayAbove30 }

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
      final sizeStr = _sizeStr(parcelSize);
      final price = FlightPricing.getPrice(sizeStr);

      return PricingResult(
        price: price,
        distanceKm: distanceKm,
        duration: durationText,
        pricingType: PricingType.flight,
        parcelSizeLabel: sizeStr,
        travelModeLabel: 'flight',
        etrSeconds: etrSeconds,
        etrText: etrText,
        breakdown: PricingBreakdown(
          basePrice: price,
          slabRange: 'N/A',
          timeMultiplier: 1.0,
          timePerformanceLabel: 'N/A',
          routeType: 'flight',
          finalReason: 'Flight override — fixed ₹$price for $sizeStr parcel',
          flightCategory: sizeStr,
        ),
      );
    }

    // ═══════════════════════════════════════════════
    //  PRIORITY 2: SAME CITY FIXED PRICING
    // ═══════════════════════════════════════════════
    if (isSameCity) {
      final sizeStr = _sizeStr(parcelSize);
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
          slabRange: 'Same City (≤15 km)',
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

    // Enforce 3000 km max
    if (km > 3000) {
      return PricingResult.error(
        'Route distance ${distanceKm.toStringAsFixed(1)} km exceeds the maximum supported distance of 3000 km.',
      );
    }

    final slabs = CityToCitySlabs.getSlabs(parcelSize);
    final slab = CityToCitySlabs.findSlab(slabs, km);

    if (slab == null) {
      return PricingResult.error('Distance ${distanceKm.toStringAsFixed(1)} km out of range');
    }

    final price = _getSlabPrice(slab, timePerformance);
    final slabLabel = '${slab.minKm}–${slab.maxKm} km';
    final sizeStr = _sizeStr(parcelSize);
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
  //  SAME CITY DETECTION — 15 km threshold
  // ──────────────────────────────────────────────────

  static bool detectSameCity(double distanceKm, {String? originCity, String? destCity}) {
    return distanceKm <= SameCityPricing.thresholdKm;
  }

  // ──────────────────────────────────────────────────
  //  HELPERS
  // ──────────────────────────────────────────────────

  static String _sizeStr(ParcelSize size) {
    switch (size) {
      case ParcelSize.small: return 'small';
      case ParcelSize.medium: return 'medium';
      case ParcelSize.large: return 'large';
    }
  }

  static double _timeMultiplier(TimePerformance perf) {
    switch (perf) {
      case TimePerformance.underTime: return 1.0;
      case TimePerformance.delayUpTo30: return 0.85;
      case TimePerformance.delayAbove30: return 0.75;
    }
  }

  static String _perfLabel(TimePerformance perf) {
    switch (perf) {
      case TimePerformance.underTime: return 'Under Time (within ETR + 10%)';
      case TimePerformance.delayUpTo30: return 'Delay ≤30% beyond ETR';
      case TimePerformance.delayAbove30: return 'Delay >30% beyond ETR';
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

  static int _getSlabPrice(SlabEntry slab, TimePerformance perf) {
    switch (perf) {
      case TimePerformance.underTime: return slab.underTime;
      case TimePerformance.delayUpTo30: return slab.delay30;
      case TimePerformance.delayAbove30: return slab.delayAbove30;
    }
  }
}
