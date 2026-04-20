// ══════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — Official Pricing Data v3.0
//  SINGLE SOURCE OF TRUTH for all slab data
//  Exact match to official pricing specification document
// ══════════════════════════════════════════════════════════════

import '../services/pricing_engine.dart';
export '../services/pricing_engine.dart';

// ══════════════════════════════════════════════════════════════
//  SLAB ENTRY
// ══════════════════════════════════════════════════════════════

class SlabEntry {
  final int minKm;
  final int maxKm;
  final int underTime;
  final int delay60;
  final int delayAbove60;

  const SlabEntry({
    required this.minKm,
    required this.maxKm,
    required this.underTime,
    required this.delay60,
    required this.delayAbove60,
  });
}

// ══════════════════════════════════════════════════════════════
//  SAME CITY FIXED PRICING (Floor Model)
//  Base: ₹99 × 0.5 = ₹49.5 → Floor → ₹49
// ══════════════════════════════════════════════════════════════

class SameCityPricing {
  static const _prices = {
    'small':  { 'under_time': 49, 'delay_60': 49, 'delay_above_60': 49 },
    'medium': { 'under_time': 79, 'delay_60': 69, 'delay_above_60': 59 },
    'large':  { 'under_time': 99, 'delay_60': 89, 'delay_above_60': 79 },
  };

  static int getPrice(String size, TimePerformance perf) {
    final sizeKey = size.toLowerCase();
    final perfKey = perf == TimePerformance.underTime ? 'under_time'
        : perf == TimePerformance.delayUpTo60 ? 'delay_60'
        : 'delay_above_60';
    return _prices[sizeKey]?[perfKey] ?? 49;
  }
}

// ══════════════════════════════════════════════════════════════
//  FLIGHT FIXED PRICING
//  Ignores all other logic
//  Flight parcel definitions:
//  - Micro: L,W,H < 1 ft, weight ≤ 1 kg
//  - Small: L,W,H ≤ 1 ft, weight ≤ 5 kg
//  - Medium: L,W,H ≤ 2 ft, weight ≤ 10 kg
// ══════════════════════════════════════════════════════════════

class FlightPricing {
  static const _prices = {
    'micro': 449,
    'small': 649,
    'medium': 949,
  };

  static int getPrice(String size) {
    return _prices[size.toLowerCase()] ?? _prices['small']!;
  }

  /// Classify a parcel for flight based on dimensions and weight
  static String classifyFlightParcel({
    required double lengthFt,
    required double widthFt,
    required double heightFt,
    required double weightKg,
  }) {
    if (lengthFt < 1 && widthFt < 1 && heightFt < 1 && weightKg <= 1) {
      return 'micro';
    } else if (lengthFt <= 1 && widthFt <= 1 && heightFt <= 1 && weightKg <= 5) {
      return 'small';
    } else if (lengthFt <= 2 && widthFt <= 2 && heightFt <= 2 && weightKg <= 10) {
      return 'medium';
    }
    return 'medium'; // Cap at medium for flight
  }
}

// ══════════════════════════════════════════════════════════════
//  CITY-TO-CITY DISTANCE SLAB TABLES
//  Small (A), Medium (B), Large (C)
//  Part 1: 1–1200 KM
//  Part 2: 1201–3000 KM (₹20 increment per 100 KM after 1200)
// ══════════════════════════════════════════════════════════════

class CityToCitySlabs {
  // ── SMALL PARCEL (A) — 1–1200 KM ──
  static const List<SlabEntry> smallSlabs1200 = [
    SlabEntry(minKm: 1,    maxKm: 100,  underTime: 99,  delay60: 89,  delayAbove60: 79),
    SlabEntry(minKm: 101,  maxKm: 200,  underTime: 129, delay60: 109, delayAbove60: 99),
    SlabEntry(minKm: 201,  maxKm: 300,  underTime: 159, delay60: 139, delayAbove60: 119),
    SlabEntry(minKm: 301,  maxKm: 400,  underTime: 189, delay60: 159, delayAbove60: 139),
    SlabEntry(minKm: 401,  maxKm: 500,  underTime: 219, delay60: 189, delayAbove60: 169),
    SlabEntry(minKm: 501,  maxKm: 600,  underTime: 249, delay60: 209, delayAbove60: 189),
    SlabEntry(minKm: 601,  maxKm: 700,  underTime: 279, delay60: 239, delayAbove60: 209),
    SlabEntry(minKm: 701,  maxKm: 800,  underTime: 309, delay60: 259, delayAbove60: 229),
    SlabEntry(minKm: 801,  maxKm: 900,  underTime: 339, delay60: 289, delayAbove60: 259),
    SlabEntry(minKm: 901,  maxKm: 1000, underTime: 369, delay60: 319, delayAbove60: 279),
    SlabEntry(minKm: 1001, maxKm: 1100, underTime: 399, delay60: 339, delayAbove60: 299),
    SlabEntry(minKm: 1101, maxKm: 1200, underTime: 429, delay60: 369, delayAbove60: 319),
  ];

  // ── SMALL PARCEL (A) — 1201–3000 KM ──
  static const List<SlabEntry> smallSlabs3000 = [
    SlabEntry(minKm: 1201, maxKm: 1300, underTime: 449, delay60: 379, delayAbove60: 339),
    SlabEntry(minKm: 1301, maxKm: 1400, underTime: 469, delay60: 399, delayAbove60: 349),
    SlabEntry(minKm: 1401, maxKm: 1500, underTime: 489, delay60: 419, delayAbove60: 369),
    SlabEntry(minKm: 1501, maxKm: 1600, underTime: 509, delay60: 429, delayAbove60: 379),
    SlabEntry(minKm: 1601, maxKm: 1700, underTime: 529, delay60: 449, delayAbove60: 399),
    SlabEntry(minKm: 1701, maxKm: 1800, underTime: 549, delay60: 469, delayAbove60: 409),
    SlabEntry(minKm: 1801, maxKm: 1900, underTime: 569, delay60: 479, delayAbove60: 429),
    SlabEntry(minKm: 1901, maxKm: 2000, underTime: 589, delay60: 499, delayAbove60: 439),
    SlabEntry(minKm: 2001, maxKm: 2100, underTime: 609, delay60: 519, delayAbove60: 459),
    SlabEntry(minKm: 2101, maxKm: 2200, underTime: 629, delay60: 529, delayAbove60: 469),
    SlabEntry(minKm: 2201, maxKm: 2300, underTime: 649, delay60: 549, delayAbove60: 489),
    SlabEntry(minKm: 2301, maxKm: 2400, underTime: 669, delay60: 569, delayAbove60: 499),
    SlabEntry(minKm: 2401, maxKm: 2500, underTime: 689, delay60: 579, delayAbove60: 519),
    SlabEntry(minKm: 2501, maxKm: 2600, underTime: 709, delay60: 599, delayAbove60: 529),
    SlabEntry(minKm: 2601, maxKm: 2700, underTime: 729, delay60: 619, delayAbove60: 549),
    SlabEntry(minKm: 2701, maxKm: 2800, underTime: 749, delay60: 629, delayAbove60: 559),
    SlabEntry(minKm: 2801, maxKm: 2900, underTime: 769, delay60: 649, delayAbove60: 579),
    SlabEntry(minKm: 2901, maxKm: 3000, underTime: 789, delay60: 669, delayAbove60: 589),
  ];

  // ── MEDIUM PARCEL (B) — 1–1200 KM ──
  static const List<SlabEntry> mediumSlabs1200 = [
    SlabEntry(minKm: 1,    maxKm: 100,  underTime: 149, delay60: 129, delayAbove60: 109),
    SlabEntry(minKm: 101,  maxKm: 200,  underTime: 189, delay60: 159, delayAbove60: 139),
    SlabEntry(minKm: 201,  maxKm: 300,  underTime: 239, delay60: 209, delayAbove60: 179),
    SlabEntry(minKm: 301,  maxKm: 400,  underTime: 279, delay60: 239, delayAbove60: 209),
    SlabEntry(minKm: 401,  maxKm: 500,  underTime: 329, delay60: 279, delayAbove60: 249),
    SlabEntry(minKm: 501,  maxKm: 600,  underTime: 369, delay60: 319, delayAbove60: 279),
    SlabEntry(minKm: 601,  maxKm: 700,  underTime: 419, delay60: 359, delayAbove60: 319),
    SlabEntry(minKm: 701,  maxKm: 800,  underTime: 459, delay60: 389, delayAbove60: 349),
    SlabEntry(minKm: 801,  maxKm: 900,  underTime: 509, delay60: 429, delayAbove60: 379),
    SlabEntry(minKm: 901,  maxKm: 1000, underTime: 549, delay60: 469, delayAbove60: 409),
    SlabEntry(minKm: 1001, maxKm: 1100, underTime: 599, delay60: 509, delayAbove60: 449),
    SlabEntry(minKm: 1101, maxKm: 1200, underTime: 639, delay60: 539, delayAbove60: 479),
  ];

  // ── MEDIUM PARCEL (B) — 1201–3000 KM ──
  static const List<SlabEntry> mediumSlabs3000 = [
    SlabEntry(minKm: 1201, maxKm: 1300, underTime: 669, delay60: 569, delayAbove60: 499),
    SlabEntry(minKm: 1301, maxKm: 1400, underTime: 699, delay60: 589, delayAbove60: 519),
    SlabEntry(minKm: 1401, maxKm: 1500, underTime: 729, delay60: 619, delayAbove60: 549),
    SlabEntry(minKm: 1501, maxKm: 1600, underTime: 759, delay60: 649, delayAbove60: 569),
    SlabEntry(minKm: 1601, maxKm: 1700, underTime: 789, delay60: 669, delayAbove60: 589),
    SlabEntry(minKm: 1701, maxKm: 1800, underTime: 819, delay60: 699, delayAbove60: 609),
    SlabEntry(minKm: 1801, maxKm: 1900, underTime: 849, delay60: 719, delayAbove60: 629),
    SlabEntry(minKm: 1901, maxKm: 2000, underTime: 879, delay60: 749, delayAbove60: 659),
    SlabEntry(minKm: 2001, maxKm: 2100, underTime: 909, delay60: 769, delayAbove60: 679),
    SlabEntry(minKm: 2101, maxKm: 2200, underTime: 939, delay60: 799, delayAbove60: 699),
    SlabEntry(minKm: 2201, maxKm: 2300, underTime: 969, delay60: 819, delayAbove60: 719),
    SlabEntry(minKm: 2301, maxKm: 2400, underTime: 999, delay60: 849, delayAbove60: 749),
    SlabEntry(minKm: 2401, maxKm: 2500, underTime: 1029, delay60: 869, delayAbove60: 769),
    SlabEntry(minKm: 2501, maxKm: 2600, underTime: 1059, delay60: 899, delayAbove60: 789),
    SlabEntry(minKm: 2601, maxKm: 2700, underTime: 1089, delay60: 919, delayAbove60: 819),
    SlabEntry(minKm: 2701, maxKm: 2800, underTime: 1119, delay60: 949, delayAbove60: 839),
    SlabEntry(minKm: 2801, maxKm: 2900, underTime: 1149, delay60: 969, delayAbove60: 869),
    SlabEntry(minKm: 2901, maxKm: 3000, underTime: 1179, delay60: 999, delayAbove60: 889),
  ];

  // ── LARGE PARCEL (C) — 1–1200 KM ──
  static const List<SlabEntry> largeSlabs1200 = [
    SlabEntry(minKm: 1,    maxKm: 100,  underTime: 199, delay60: 169, delayAbove60: 149),
    SlabEntry(minKm: 101,  maxKm: 200,  underTime: 259, delay60: 219, delayAbove60: 199),
    SlabEntry(minKm: 201,  maxKm: 300,  underTime: 319, delay60: 269, delayAbove60: 239),
    SlabEntry(minKm: 301,  maxKm: 400,  underTime: 379, delay60: 319, delayAbove60: 279),
    SlabEntry(minKm: 401,  maxKm: 500,  underTime: 439, delay60: 369, delayAbove60: 319),
    SlabEntry(minKm: 501,  maxKm: 600,  underTime: 499, delay60: 419, delayAbove60: 369),
    SlabEntry(minKm: 601,  maxKm: 700,  underTime: 559, delay60: 469, delayAbove60: 409),
    SlabEntry(minKm: 701,  maxKm: 800,  underTime: 619, delay60: 519, delayAbove60: 459),
    SlabEntry(minKm: 801,  maxKm: 900,  underTime: 679, delay60: 569, delayAbove60: 499),
    SlabEntry(minKm: 901,  maxKm: 1000, underTime: 739, delay60: 619, delayAbove60: 549),
    SlabEntry(minKm: 1001, maxKm: 1100, underTime: 799, delay60: 669, delayAbove60: 599),
    SlabEntry(minKm: 1101, maxKm: 1200, underTime: 859, delay60: 719, delayAbove60: 639),
  ];

  // ── LARGE PARCEL (C) — 1201–3000 KM ──
  static const List<SlabEntry> largeSlabs3000 = [
    SlabEntry(minKm: 1201, maxKm: 1300, underTime: 899, delay60: 759, delayAbove60: 679),
    SlabEntry(minKm: 1301, maxKm: 1400, underTime: 939, delay60: 799, delayAbove60: 699),
    SlabEntry(minKm: 1401, maxKm: 1500, underTime: 979, delay60: 829, delayAbove60: 739),
    SlabEntry(minKm: 1501, maxKm: 1600, underTime: 1019, delay60: 869, delayAbove60: 759),
    SlabEntry(minKm: 1601, maxKm: 1700, underTime: 1059, delay60: 899, delayAbove60: 789),
    SlabEntry(minKm: 1701, maxKm: 1800, underTime: 1099, delay60: 939, delayAbove60: 819),
    SlabEntry(minKm: 1801, maxKm: 1900, underTime: 1139, delay60: 969, delayAbove60: 849),
    SlabEntry(minKm: 1901, maxKm: 2000, underTime: 1179, delay60: 999, delayAbove60: 879),
    SlabEntry(minKm: 2001, maxKm: 2100, underTime: 1219, delay60: 1039, delayAbove60: 919),
    SlabEntry(minKm: 2101, maxKm: 2200, underTime: 1259, delay60: 1069, delayAbove60: 949),
    SlabEntry(minKm: 2201, maxKm: 2300, underTime: 1299, delay60: 1109, delayAbove60: 979),
    SlabEntry(minKm: 2301, maxKm: 2400, underTime: 1339, delay60: 1139, delayAbove60: 1009),
    SlabEntry(minKm: 2401, maxKm: 2500, underTime: 1379, delay60: 1169, delayAbove60: 1039),
    SlabEntry(minKm: 2501, maxKm: 2600, underTime: 1419, delay60: 1209, delayAbove60: 1069),
    SlabEntry(minKm: 2601, maxKm: 2700, underTime: 1459, delay60: 1239, delayAbove60: 1109),
    SlabEntry(minKm: 2701, maxKm: 2800, underTime: 1499, delay60: 1279, delayAbove60: 1139),
    SlabEntry(minKm: 2801, maxKm: 2900, underTime: 1539, delay60: 1309, delayAbove60: 1169),
    SlabEntry(minKm: 2901, maxKm: 3000, underTime: 1579, delay60: 1349, delayAbove60: 1189),
  ];

  /// Get all slabs for a given parcel size (combined 1–3000 KM)
  static List<SlabEntry> getSlabs(ParcelSize size) {
    switch (size) {
      case ParcelSize.small:
        return [...smallSlabs1200, ...smallSlabs3000];
      case ParcelSize.medium:
        return [...mediumSlabs1200, ...mediumSlabs3000];
      case ParcelSize.large:
        return [...largeSlabs1200, ...largeSlabs3000];
    }
  }

  /// Find the matching slab for a given distance in KM
  static SlabEntry? findSlab(List<SlabEntry> slabs, int km) {
    for (final slab in slabs) {
      if (km >= slab.minKm && km <= slab.maxKm) {
        return slab;
      }
    }
    // Cap at max slab for distances > 3000 KM
    if (km > 3000 && slabs.isNotEmpty) {
      return slabs.last;
    }
    return null;
  }
}
