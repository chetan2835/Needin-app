// ══════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — Official Pricing Data v5.0
//  SINGLE SOURCE OF TRUTH for all slab data
//  Exact match to official "Vertical Slab Pricing" table (2026-05-09)
//
//  KEY CHANGES from v4:
//  - Complete rewrite of ALL slab values to match the official
//    Needin Express Vertical Slab Pricing table exactly.
//  - underTime values are the ONLY displayed "Potential Earnings".
//  - delay30 and delayAbove30 retained for backend settlement.
// ══════════════════════════════════════════════════════════════

import '../services/pricing_engine.dart';
export '../services/pricing_engine.dart';

// ══════════════════════════════════════════════════════════════
//  SLAB ENTRY
// ══════════════════════════════════════════════════════════════

class SlabEntry {
  final int minKm;
  final int maxKm;
  final int underTime;     // Within ETR + 10% grace
  final int delay30;       // Delay ≤30% beyond ETR
  final int delayAbove30;  // Delay >30% beyond ETR

  const SlabEntry({
    required this.minKm,
    required this.maxKm,
    required this.underTime,
    required this.delay30,
    required this.delayAbove30,
  });
}

// ══════════════════════════════════════════════════════════════
//  SAME CITY FIXED PRICING (Floor Model)
//  Base: ₹99 × 0.5 = ₹49.5 → Floor → ₹49
//  Threshold: ≤15 km driving distance
// ══════════════════════════════════════════════════════════════

class SameCityPricing {
  /// Same city threshold in kilometres (driving distance)
  static const double thresholdKm = 15.0;

  static const _prices = {
    'small':  { 'under_time': 49, 'delay_30': 49, 'delay_above_30': 49 },
    'medium': { 'under_time': 79, 'delay_30': 69, 'delay_above_30': 59 },
    'large':  { 'under_time': 99, 'delay_30': 89, 'delay_above_30': 79 },
  };

  static int getPrice(String size, TimePerformance perf) {
    final sizeKey = size.toLowerCase();
    final perfKey = perf == TimePerformance.underTime ? 'under_time'
        : perf == TimePerformance.delayUpTo30 ? 'delay_30'
        : 'delay_above_30';
    return _prices[sizeKey]?[perfKey] ?? 49;
  }
}

// ══════════════════════════════════════════════════════════════
//  FLIGHT FIXED PRICING
//  Ignores all distance slabs and time multipliers
//  small=₹449, medium=₹649, large=₹949
// ══════════════════════════════════════════════════════════════

class FlightPricing {
  static const _prices = {
    'small': 449,
    'medium': 649,
    'large': 949,
  };

  static int getPrice(String size) {
    return _prices[size.toLowerCase()] ?? _prices['small']!;
  }

  /// Classify a parcel for flight based on dimensions and weight
  /// Micro (<1ft all sides, ≤1kg) → maps to small fare
  /// Small (≤1ft all sides, ≤3kg)
  /// Medium (≤3ft all sides, ≤15kg)
  /// Large (≤5ft all sides, ≤50kg)
  static String classifyFlightParcel({
    required double lengthFt,
    required double widthFt,
    required double heightFt,
    required double weightKg,
  }) {
    if (lengthFt < 1 && widthFt < 1 && heightFt < 1 && weightKg <= 1) {
      return 'small'; // Micro maps to small fare
    } else if (lengthFt <= 1 && widthFt <= 1 && heightFt <= 1 && weightKg <= 3) {
      return 'small';
    } else if (lengthFt <= 3 && widthFt <= 3 && heightFt <= 3 && weightKg <= 15) {
      return 'medium';
    } else if (lengthFt <= 5 && widthFt <= 5 && heightFt <= 5 && weightKg <= 50) {
      return 'large';
    }
    return 'large'; // Default to large for oversized
  }
}

// ══════════════════════════════════════════════════════════════
//  NEEDIN DROP PARTNER PRICING (per 24 hours)
// ══════════════════════════════════════════════════════════════

class DropPartnerPricing {
  static const _fees = {
    'small': 50,
    'medium': 100,
    'large': 150,
  };

  static int getFee(String size) {
    return _fees[size.toLowerCase()] ?? 50;
  }
}

// ══════════════════════════════════════════════════════════════
//  PARCEL SIZE CLASSIFICATION (All Modes)
// ══════════════════════════════════════════════════════════════

class ParcelClassification {
  /// Classify parcel based on dimensions (inches) and weight (kg)
  /// Returns 'small', 'medium', or 'large'
  /// Returns null if parcel exceeds platform limits
  static String? classify({
    required double lengthIn,
    required double widthIn,
    required double heightIn,
    required double weightKg,
  }) {
    // Platform limit: 60x60x60 inches, 50 kg
    if (lengthIn > 60 || widthIn > 60 || heightIn > 60 || weightKg > 50) {
      return null; // Exceeds platform limits
    }

    // Small: All dims ≤12in AND weight ≤5kg
    if (lengthIn <= 12 && widthIn <= 12 && heightIn <= 12 && weightKg <= 5) {
      return 'small';
    }

    // Medium: All dims ≤36in AND weight ≤15kg
    if (lengthIn <= 36 && widthIn <= 36 && heightIn <= 36 && weightKg <= 15) {
      return 'medium';
    }

    // Large: Within platform limits
    return 'large';
  }
}

// ══════════════════════════════════════════════════════════════
//  CITY-TO-CITY DISTANCE SLAB TABLES
//  Official Needin Express Vertical Slab Pricing v5.0
//  Exact match to the official pricing table image.
//
//  underTime = base price (displayed as "Potential Earnings")
//  delay30   = 85% of underTime (rounded)
//  delayAbove30 = 75% of underTime (rounded)
// ══════════════════════════════════════════════════════════════

class CityToCitySlabs {

  // ── SMALL PARCEL — 1–3000 KM ──
  static const List<SlabEntry> smallSlabs = [
    SlabEntry(minKm: 1,    maxKm: 100,  underTime:  99,  delay30:  84,  delayAbove30:  74),
    SlabEntry(minKm: 101,  maxKm: 200,  underTime: 129,  delay30: 110,  delayAbove30:  97),
    SlabEntry(minKm: 201,  maxKm: 300,  underTime: 159,  delay30: 135,  delayAbove30: 119),
    SlabEntry(minKm: 301,  maxKm: 400,  underTime: 189,  delay30: 161,  delayAbove30: 142),
    SlabEntry(minKm: 401,  maxKm: 500,  underTime: 219,  delay30: 186,  delayAbove30: 164),
    SlabEntry(minKm: 501,  maxKm: 600,  underTime: 249,  delay30: 212,  delayAbove30: 187),
    SlabEntry(minKm: 601,  maxKm: 700,  underTime: 279,  delay30: 237,  delayAbove30: 209),
    SlabEntry(minKm: 701,  maxKm: 800,  underTime: 309,  delay30: 263,  delayAbove30: 232),
    SlabEntry(minKm: 801,  maxKm: 900,  underTime: 339,  delay30: 288,  delayAbove30: 254),
    SlabEntry(minKm: 901,  maxKm: 1000, underTime: 369,  delay30: 314,  delayAbove30: 277),
    SlabEntry(minKm: 1001, maxKm: 1100, underTime: 399,  delay30: 339,  delayAbove30: 299),
    SlabEntry(minKm: 1101, maxKm: 1200, underTime: 429,  delay30: 365,  delayAbove30: 322),
    SlabEntry(minKm: 1201, maxKm: 1300, underTime: 429,  delay30: 365,  delayAbove30: 322),
    SlabEntry(minKm: 1301, maxKm: 1400, underTime: 459,  delay30: 390,  delayAbove30: 344),
    SlabEntry(minKm: 1401, maxKm: 1500, underTime: 499,  delay30: 424,  delayAbove30: 374),
    SlabEntry(minKm: 1501, maxKm: 1600, underTime: 529,  delay30: 450,  delayAbove30: 397),
    SlabEntry(minKm: 1601, maxKm: 1700, underTime: 569,  delay30: 484,  delayAbove30: 427),
    SlabEntry(minKm: 1701, maxKm: 1800, underTime: 599,  delay30: 509,  delayAbove30: 449),
    SlabEntry(minKm: 1801, maxKm: 1900, underTime: 639,  delay30: 543,  delayAbove30: 479),
    SlabEntry(minKm: 1901, maxKm: 2000, underTime: 669,  delay30: 569,  delayAbove30: 502),
    SlabEntry(minKm: 2001, maxKm: 2100, underTime: 709,  delay30: 603,  delayAbove30: 532),
    SlabEntry(minKm: 2101, maxKm: 2200, underTime: 739,  delay30: 628,  delayAbove30: 554),
    SlabEntry(minKm: 2201, maxKm: 2300, underTime: 779,  delay30: 662,  delayAbove30: 584),
    SlabEntry(minKm: 2301, maxKm: 2400, underTime: 809,  delay30: 688,  delayAbove30: 607),
    SlabEntry(minKm: 2401, maxKm: 2500, underTime: 849,  delay30: 722,  delayAbove30: 637),
    SlabEntry(minKm: 2501, maxKm: 2600, underTime: 879,  delay30: 747,  delayAbove30: 659),
    SlabEntry(minKm: 2601, maxKm: 2700, underTime: 919,  delay30: 781,  delayAbove30: 689),
    SlabEntry(minKm: 2701, maxKm: 2800, underTime: 949,  delay30: 807,  delayAbove30: 712),
    SlabEntry(minKm: 2801, maxKm: 2900, underTime: 989,  delay30: 841,  delayAbove30: 742),
    SlabEntry(minKm: 2901, maxKm: 3000, underTime: 1019, delay30: 866,  delayAbove30: 764),
  ];

  // ── MEDIUM PARCEL — 1–3000 KM ──
  static const List<SlabEntry> mediumSlabs = [
    SlabEntry(minKm: 1,    maxKm: 100,  underTime:  149,  delay30:  127,  delayAbove30:  112),
    SlabEntry(minKm: 101,  maxKm: 200,  underTime:  189,  delay30:  161,  delayAbove30:  142),
    SlabEntry(minKm: 201,  maxKm: 300,  underTime:  239,  delay30:  203,  delayAbove30:  179),
    SlabEntry(minKm: 301,  maxKm: 400,  underTime:  279,  delay30:  237,  delayAbove30:  209),
    SlabEntry(minKm: 401,  maxKm: 500,  underTime:  329,  delay30:  280,  delayAbove30:  247),
    SlabEntry(minKm: 501,  maxKm: 600,  underTime:  369,  delay30:  314,  delayAbove30:  277),
    SlabEntry(minKm: 601,  maxKm: 700,  underTime:  419,  delay30:  356,  delayAbove30:  314),
    SlabEntry(minKm: 701,  maxKm: 800,  underTime:  459,  delay30:  390,  delayAbove30:  344),
    SlabEntry(minKm: 801,  maxKm: 900,  underTime:  509,  delay30:  433,  delayAbove30:  382),
    SlabEntry(minKm: 901,  maxKm: 1000, underTime:  549,  delay30:  467,  delayAbove30:  412),
    SlabEntry(minKm: 1001, maxKm: 1100, underTime:  599,  delay30:  509,  delayAbove30:  449),
    SlabEntry(minKm: 1101, maxKm: 1200, underTime:  639,  delay30:  543,  delayAbove30:  479),
    SlabEntry(minKm: 1201, maxKm: 1300, underTime:  649,  delay30:  552,  delayAbove30:  487),
    SlabEntry(minKm: 1301, maxKm: 1400, underTime:  689,  delay30:  586,  delayAbove30:  517),
    SlabEntry(minKm: 1401, maxKm: 1500, underTime:  749,  delay30:  637,  delayAbove30:  562),
    SlabEntry(minKm: 1501, maxKm: 1600, underTime:  799,  delay30:  679,  delayAbove30:  599),
    SlabEntry(minKm: 1601, maxKm: 1700, underTime:  859,  delay30:  730,  delayAbove30:  644),
    SlabEntry(minKm: 1701, maxKm: 1800, underTime:  899,  delay30:  764,  delayAbove30:  674),
    SlabEntry(minKm: 1801, maxKm: 1900, underTime:  959,  delay30:  815,  delayAbove30:  719),
    SlabEntry(minKm: 1901, maxKm: 2000, underTime: 1009,  delay30:  858,  delayAbove30:  757),
    SlabEntry(minKm: 2001, maxKm: 2100, underTime: 1069,  delay30:  909,  delayAbove30:  802),
    SlabEntry(minKm: 2101, maxKm: 2200, underTime: 1109,  delay30:  943,  delayAbove30:  832),
    SlabEntry(minKm: 2201, maxKm: 2300, underTime: 1169,  delay30:  994,  delayAbove30:  877),
    SlabEntry(minKm: 2301, maxKm: 2400, underTime: 1219,  delay30: 1036,  delayAbove30:  914),
    SlabEntry(minKm: 2401, maxKm: 2500, underTime: 1279,  delay30: 1087,  delayAbove30:  959),
    SlabEntry(minKm: 2501, maxKm: 2600, underTime: 1319,  delay30: 1121,  delayAbove30:  989),
    SlabEntry(minKm: 2601, maxKm: 2700, underTime: 1379,  delay30: 1172,  delayAbove30: 1034),
    SlabEntry(minKm: 2701, maxKm: 2800, underTime: 1419,  delay30: 1206,  delayAbove30: 1064),
    SlabEntry(minKm: 2801, maxKm: 2900, underTime: 1489,  delay30: 1266,  delayAbove30: 1117),
    SlabEntry(minKm: 2901, maxKm: 3000, underTime: 1529,  delay30: 1300,  delayAbove30: 1147),
  ];

  // ── LARGE PARCEL — 1–3000 KM ──
  static const List<SlabEntry> largeSlabs = [
    SlabEntry(minKm: 1,    maxKm: 100,  underTime:  199,  delay30:  169,  delayAbove30:  149),
    SlabEntry(minKm: 101,  maxKm: 200,  underTime:  259,  delay30:  220,  delayAbove30:  194),
    SlabEntry(minKm: 201,  maxKm: 300,  underTime:  319,  delay30:  271,  delayAbove30:  239),
    SlabEntry(minKm: 301,  maxKm: 400,  underTime:  379,  delay30:  322,  delayAbove30:  284),
    SlabEntry(minKm: 401,  maxKm: 500,  underTime:  439,  delay30:  373,  delayAbove30:  329),
    SlabEntry(minKm: 501,  maxKm: 600,  underTime:  499,  delay30:  424,  delayAbove30:  374),
    SlabEntry(minKm: 601,  maxKm: 700,  underTime:  559,  delay30:  475,  delayAbove30:  419),
    SlabEntry(minKm: 701,  maxKm: 800,  underTime:  619,  delay30:  526,  delayAbove30:  464),
    SlabEntry(minKm: 801,  maxKm: 900,  underTime:  679,  delay30:  577,  delayAbove30:  509),
    SlabEntry(minKm: 901,  maxKm: 1000, underTime:  739,  delay30:  628,  delayAbove30:  554),
    SlabEntry(minKm: 1001, maxKm: 1100, underTime:  799,  delay30:  679,  delayAbove30:  599),
    SlabEntry(minKm: 1101, maxKm: 1200, underTime:  859,  delay30:  730,  delayAbove30:  644),
    SlabEntry(minKm: 1201, maxKm: 1300, underTime:  859,  delay30:  730,  delayAbove30:  644),
    SlabEntry(minKm: 1301, maxKm: 1400, underTime:  919,  delay30:  781,  delayAbove30:  689),
    SlabEntry(minKm: 1401, maxKm: 1500, underTime:  999,  delay30:  849,  delayAbove30:  749),
    SlabEntry(minKm: 1501, maxKm: 1600, underTime: 1059,  delay30:  900,  delayAbove30:  794),
    SlabEntry(minKm: 1601, maxKm: 1700, underTime: 1139,  delay30:  968,  delayAbove30:  854),
    SlabEntry(minKm: 1701, maxKm: 1800, underTime: 1199,  delay30: 1019,  delayAbove30:  899),
    SlabEntry(minKm: 1801, maxKm: 1900, underTime: 1279,  delay30: 1087,  delayAbove30:  959),
    SlabEntry(minKm: 1901, maxKm: 2000, underTime: 1339,  delay30: 1138,  delayAbove30: 1004),
    SlabEntry(minKm: 2001, maxKm: 2100, underTime: 1419,  delay30: 1206,  delayAbove30: 1064),
    SlabEntry(minKm: 2101, maxKm: 2200, underTime: 1479,  delay30: 1257,  delayAbove30: 1109),
    SlabEntry(minKm: 2201, maxKm: 2300, underTime: 1559,  delay30: 1325,  delayAbove30: 1169),
    SlabEntry(minKm: 2301, maxKm: 2400, underTime: 1619,  delay30: 1376,  delayAbove30: 1214),
    SlabEntry(minKm: 2401, maxKm: 2500, underTime: 1699,  delay30: 1444,  delayAbove30: 1274),
    SlabEntry(minKm: 2501, maxKm: 2600, underTime: 1759,  delay30: 1495,  delayAbove30: 1319),
    SlabEntry(minKm: 2601, maxKm: 2700, underTime: 1839,  delay30: 1563,  delayAbove30: 1379),
    SlabEntry(minKm: 2701, maxKm: 2800, underTime: 1899,  delay30: 1614,  delayAbove30: 1424),
    SlabEntry(minKm: 2801, maxKm: 2900, underTime: 1979,  delay30: 1682,  delayAbove30: 1484),
    SlabEntry(minKm: 2901, maxKm: 3000, underTime: 2039,  delay30: 1733,  delayAbove30: 1529),
  ];

  /// Get all slabs for a given parcel size
  static List<SlabEntry> getSlabs(ParcelSize size) {
    switch (size) {
      case ParcelSize.small:
        return smallSlabs;
      case ParcelSize.medium:
        return mediumSlabs;
      case ParcelSize.large:
        return largeSlabs;
    }
  }

  /// Find the matching slab for a given distance in KM
  static SlabEntry? findSlab(List<SlabEntry> slabs, int km) {
    for (final slab in slabs) {
      if (km >= slab.minKm && km <= slab.maxKm) {
        return slab;
      }
    }
    // Distance > 3000 km → return null (error case)
    return null;
  }
}
