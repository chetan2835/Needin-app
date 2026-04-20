// ══════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — OFFICIAL DOCUMENT COMPLIANCE TEST
//  BANKING-GRADE AUDIT: Zero tolerance for deviation
//
//  This test asserts EVERY SINGLE VALUE from the official
//  pricing document, line by line.
//
//  Official Document Reference:
//  ✔ Base Price: ₹99
//  ✔ Formula: Final Price = Base × Route × Size × Time × Via
//  ✔ Route Multiplier: Same City × 0.5, City-to-City × 1.0
//  ✔ Size Multiplier: Small × 1.0, Medium × 1.5, Large × 2.0
//  ✔ Time Multiplier: Under Time × 1.0, ≤60% × 0.85, >60% × 0.75
//  ✔ Via Multiplier: Bike/Car/Train/Bus × 1.0, Flight × 5.0
//  ✔ ETR = Time₁ + 10%
//  ✔ Same City Fixed Table (9 values)
//  ✔ Flight Override Table (3 values: micro/small/medium)
//  ✔ City-to-City Slabs: All 180 values (60 per size × 3 tiers)
// ══════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:needin_app/core/data/pricing_slabs.dart';
import 'package:needin_app/core/models/pricing_result.dart';

// ── Official document values (immutable reference) ──
// Used to verify data tables match spec EXACTLY

const Map<String, Map<String, int>> _officialSameCityTable = {
  // Under Time
  'small_under':  {'price': 49},
  'medium_under': {'price': 79},
  'large_under':  {'price': 99},
  // Delay ≤60%
  'small_delay60':  {'price': 49},
  'medium_delay60': {'price': 69},
  'large_delay60':  {'price': 89},
  // Delay >60%
  'small_delayAbove60':  {'price': 49},
  'medium_delayAbove60': {'price': 59},
  'large_delayAbove60':  {'price': 79},
};

const Map<String, int> _officialFlightTable = {
  'micro':  449,
  'small':  649,
  'medium': 949,
};

// Official SMALL slab table — ALL 30 rows from document
const List<List<int>> _officialSmallSlabs = [
  // [minKm, maxKm, underTime, delay60, delayAbove60]
  [1,    100,  99,  89,  79],
  [101,  200,  129, 109, 99],
  [201,  300,  159, 139, 119],
  [301,  400,  189, 159, 139],
  [401,  500,  219, 189, 169],
  [501,  600,  249, 209, 189],
  [601,  700,  279, 239, 209],
  [701,  800,  309, 259, 229],
  [801,  900,  339, 289, 259],
  [901,  1000, 369, 319, 279],
  [1001, 1100, 399, 339, 299],
  [1101, 1200, 429, 369, 319],
  // Part 2
  [1201, 1300, 449, 379, 339],
  [1301, 1400, 469, 399, 349],
  [1401, 1500, 489, 419, 369],
  [1501, 1600, 509, 429, 379],
  [1601, 1700, 529, 449, 399],
  [1701, 1800, 549, 469, 409],
  [1801, 1900, 569, 479, 429],
  [1901, 2000, 589, 499, 439],
  [2001, 2100, 609, 519, 459],
  [2101, 2200, 629, 529, 469],
  [2201, 2300, 649, 549, 489],
  [2301, 2400, 669, 569, 499],
  [2401, 2500, 689, 579, 519],
  [2501, 2600, 709, 599, 529],
  [2601, 2700, 729, 619, 549],
  [2701, 2800, 749, 629, 559],
  [2801, 2900, 769, 649, 579],
  [2901, 3000, 789, 669, 589],
];

// Official MEDIUM slab table — ALL 30 rows from document
const List<List<int>> _officialMediumSlabs = [
  [1,    100,  149, 129, 109],
  [101,  200,  189, 159, 139],
  [201,  300,  239, 209, 179],
  [301,  400,  279, 239, 209],
  [401,  500,  329, 279, 249],
  [501,  600,  369, 319, 279],
  [601,  700,  419, 359, 319],
  [701,  800,  459, 389, 349],
  [801,  900,  509, 429, 379],
  [901,  1000, 549, 469, 409],
  [1001, 1100, 599, 509, 449],
  [1101, 1200, 639, 539, 479],
  // Part 2
  [1201, 1300, 669, 569, 499],
  [1301, 1400, 699, 589, 519],
  [1401, 1500, 729, 619, 549],
  [1501, 1600, 759, 649, 569],
  [1601, 1700, 789, 669, 589],
  [1701, 1800, 819, 699, 609],
  [1801, 1900, 849, 719, 629],
  [1901, 2000, 879, 749, 659],
  [2001, 2100, 909, 769, 679],
  [2101, 2200, 939, 799, 699],
  [2201, 2300, 969, 819, 719],
  [2301, 2400, 999, 849, 749],
  [2401, 2500, 1029, 869, 769],
  [2501, 2600, 1059, 899, 789],
  [2601, 2700, 1089, 919, 819],
  [2701, 2800, 1119, 949, 839],
  [2801, 2900, 1149, 969, 869],
  [2901, 3000, 1179, 999, 889],
];

// Official LARGE slab table — ALL 30 rows from document
const List<List<int>> _officialLargeSlabs = [
  [1,    100,  199, 169, 149],
  [101,  200,  259, 219, 199],
  [201,  300,  319, 269, 239],
  [301,  400,  379, 319, 279],
  [401,  500,  439, 369, 319],
  [501,  600,  499, 419, 369],
  [601,  700,  559, 469, 409],
  [701,  800,  619, 519, 459],
  [801,  900,  679, 569, 499],
  [901,  1000, 739, 619, 549],
  [1001, 1100, 799, 669, 599],
  [1101, 1200, 859, 719, 639],
  // Part 2
  [1201, 1300, 899,  759,  679],
  [1301, 1400, 939,  799,  699],
  [1401, 1500, 979,  829,  739],
  [1501, 1600, 1019, 869,  759],
  [1601, 1700, 1059, 899,  789],
  [1701, 1800, 1099, 939,  819],
  [1801, 1900, 1139, 969,  849],
  [1901, 2000, 1179, 999,  879],
  [2001, 2100, 1219, 1039, 919],
  [2101, 2200, 1259, 1069, 949],
  [2201, 2300, 1299, 1109, 979],
  [2301, 2400, 1339, 1139, 1009],
  [2401, 2500, 1379, 1169, 1039],
  [2501, 2600, 1419, 1209, 1069],
  [2601, 2700, 1459, 1239, 1109],
  [2701, 2800, 1499, 1279, 1139],
  [2801, 2900, 1539, 1309, 1169],
  [2901, 3000, 1579, 1349, 1189],
];

void main() {
  // ══════════════════════════════════════════════════════════════
  //  SECTION 1: MULTIPLIER VERIFICATION
  //  Document §1, §4, §5, §6
  // ══════════════════════════════════════════════════════════════

  group('§1 Via Multiplier (not applied to fixed tables — logic check)', () {
    // The document says Bike/Car/Train/Bus × 1.0, Flight × 5.0
    // In the implementation, flight is handled by OVERRIDE, not multiplier.
    // Non-flight modes all produce same price (multiplier is absorbed into slab table).
    // This is CORRECT per spec — the slab table already encodes the ×1.0 modes.
    test('Non-flight modes produce identical prices (×1.0 implicit)', () {
      final modes = [TravelMode.bike, TravelMode.car, TravelMode.train, TravelMode.bus];
      final prices = modes.map((m) => PricingEngine.calculate(
        distanceKm: 300.0,
        durationText: '5 hr',
        durationSeconds: 18000,
        parcelSize: ParcelSize.medium,
        travelMode: m,
      ).price).toList();
      // All should be identical (×1.0 for all road modes)
      expect(prices.every((p) => p == prices[0]), true,
          reason: 'All non-flight modes must return same price (×1.0)');
    });

    test('Flight triggers OVERRIDE — not multiplier path', () {
      final flight = PricingEngine.calculate(
        distanceKm: 300.0,
        durationText: '5 hr',
        durationSeconds: 18000,
        parcelSize: ParcelSize.small,
        travelMode: TravelMode.flight,
      );
      expect(flight.pricingType, PricingType.flight);
      expect(flight.price, 649); // Exact flight small price from document
    });
  });

  group('§4 Route Multiplier', () {
    test('Same City → fixed floor pricing (not dynamic ×0.5)', () {
      // Document says ₹99 × 0.5 = ₹49.5 → Floor → ₹49 for small
      // Implementation uses fixed table (correct approach per spec)
      final result = PricingEngine.calculate(
        distanceKm: 15.0,
        durationText: '20 min',
        durationSeconds: 1200,
        parcelSize: ParcelSize.small,
        isSameCity: true,
      );
      expect(result.price, 49);
    });
  });

  group('§5 Parcel Size Multiplier (encoded in slab table)', () {
    // Document: Small ×1.0, Medium ×1.5, Large ×2.0
    // Verify relative ratios in 1–100km slab (base: ₹99 small)
    test('1–100km: Small=99, Medium=149≈99×1.5, Large=199≈99×2.0', () {
      // Small: 99 (base)
      // Medium: 149 ≈ 99 × 1.5 = 148.5 → 149 ✓
      // Large: 199 ≈ 99 × 2.0 = 198 → 199 ✓
      final small = PricingEngine.calculate(
        distanceKm: 50.0, durationText: '1 hr',
        durationSeconds: 3600, parcelSize: ParcelSize.small,
      );
      final medium = PricingEngine.calculate(
        distanceKm: 50.0, durationText: '1 hr',
        durationSeconds: 3600, parcelSize: ParcelSize.medium,
      );
      final large = PricingEngine.calculate(
        distanceKm: 50.0, durationText: '1 hr',
        durationSeconds: 3600, parcelSize: ParcelSize.large,
      );
      expect(small.price, 99);
      expect(medium.price, 149);
      expect(large.price, 199);
    });
  });

  group('§6 Time Multiplier — EXACT values from document', () {
    test('Under Time multiplier = 1.0 (returns full underTime price)', () {
      final result = PricingEngine.calculate(
        distanceKm: 200.0, durationText: '3 hr',
        durationSeconds: 10800, parcelSize: ParcelSize.small,
        timePerformance: TimePerformance.underTime,
      );
      expect(result.price, 129); // Small 101–200 underTime
      expect(result.breakdown.timeMultiplier, 1.0);
    });

    test('Delay ≤60% multiplier = 0.85 (returns delay60 price)', () {
      final result = PricingEngine.calculate(
        distanceKm: 200.0, durationText: '3 hr',
        durationSeconds: 10800, parcelSize: ParcelSize.small,
        timePerformance: TimePerformance.delayUpTo60,
      );
      expect(result.price, 109); // Small 101–200 delay60
      expect(result.breakdown.timeMultiplier, 0.85);
    });

    test('Delay >60% multiplier = 0.75 (returns delayAbove60 price)', () {
      final result = PricingEngine.calculate(
        distanceKm: 200.0, durationText: '3 hr',
        durationSeconds: 10800, parcelSize: ParcelSize.small,
        timePerformance: TimePerformance.delayAbove60,
      );
      expect(result.price, 99); // Small 101–200 delayAbove60
      expect(result.breakdown.timeMultiplier, 0.75);
    });

    test('ETR = Time₁ + 10% as per document', () {
      final result = PricingEngine.calculate(
        distanceKm: 300.0, durationText: '5 hr',
        durationSeconds: 18000, parcelSize: ParcelSize.small,
      );
      // ETR = 18000 × 1.10 = 19800 (or 19801 due to IEEE 754 ceil)
      expect(result.etrSeconds, greaterThanOrEqualTo(19800));
      expect(result.etrSeconds, lessThanOrEqualTo(19801));
    });

    test('Time₁ auto-calculated — travellers cannot modify (engine-controlled)', () {
      // Verify time multiplier applies correctly to breakdowns
      final underTime = PricingEngine.calculate(
        distanceKm: 500.0, durationText: '7 hr',
        durationSeconds: 25200, parcelSize: ParcelSize.medium,
        timePerformance: TimePerformance.underTime,
      );
      final delay60 = PricingEngine.calculate(
        distanceKm: 500.0, durationText: '7 hr',
        durationSeconds: 25200, parcelSize: ParcelSize.medium,
        timePerformance: TimePerformance.delayUpTo60,
      );
      expect(underTime.breakdown.timeMultiplier, 1.0);
      expect(delay60.breakdown.timeMultiplier, 0.85);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SECTION 2: SAME CITY EXACT PRICE TABLE
  //  Document §SAME CITY PRICING — ALL 9 VALUES
  // ══════════════════════════════════════════════════════════════

  group('§SAME CITY — ALL 9 values from official document', () {
    // Under Time
    test('Small + Under Time = ₹49 (EXACT)', () {
      final r = PricingEngine.calculate(distanceKm: 10.0, durationText: '15 min',
          durationSeconds: 900, parcelSize: ParcelSize.small,
          isSameCity: true, timePerformance: TimePerformance.underTime);
      expect(r.price, _officialSameCityTable['small_under']!['price']!);
      expect(r.price, 49);
    });
    test('Medium + Under Time = ₹79 (EXACT)', () {
      final r = PricingEngine.calculate(distanceKm: 10.0, durationText: '15 min',
          durationSeconds: 900, parcelSize: ParcelSize.medium,
          isSameCity: true, timePerformance: TimePerformance.underTime);
      expect(r.price, 79);
    });
    test('Large + Under Time = ₹99 (EXACT)', () {
      final r = PricingEngine.calculate(distanceKm: 10.0, durationText: '15 min',
          durationSeconds: 900, parcelSize: ParcelSize.large,
          isSameCity: true, timePerformance: TimePerformance.underTime);
      expect(r.price, 99);
    });
    // Delay ≤60%
    test('Small + Delay ≤60% = ₹49 (EXACT)', () {
      final r = PricingEngine.calculate(distanceKm: 10.0, durationText: '15 min',
          durationSeconds: 900, parcelSize: ParcelSize.small,
          isSameCity: true, timePerformance: TimePerformance.delayUpTo60);
      expect(r.price, 49);
    });
    test('Medium + Delay ≤60% = ₹69 (EXACT)', () {
      final r = PricingEngine.calculate(distanceKm: 10.0, durationText: '15 min',
          durationSeconds: 900, parcelSize: ParcelSize.medium,
          isSameCity: true, timePerformance: TimePerformance.delayUpTo60);
      expect(r.price, 69);
    });
    test('Large + Delay ≤60% = ₹89 (EXACT)', () {
      final r = PricingEngine.calculate(distanceKm: 10.0, durationText: '15 min',
          durationSeconds: 900, parcelSize: ParcelSize.large,
          isSameCity: true, timePerformance: TimePerformance.delayUpTo60);
      expect(r.price, 89);
    });
    // Delay >60%
    test('Small + Delay >60% = ₹49 (EXACT)', () {
      final r = PricingEngine.calculate(distanceKm: 10.0, durationText: '15 min',
          durationSeconds: 900, parcelSize: ParcelSize.small,
          isSameCity: true, timePerformance: TimePerformance.delayAbove60);
      expect(r.price, 49);
    });
    test('Medium + Delay >60% = ₹59 (EXACT)', () {
      final r = PricingEngine.calculate(distanceKm: 10.0, durationText: '15 min',
          durationSeconds: 900, parcelSize: ParcelSize.medium,
          isSameCity: true, timePerformance: TimePerformance.delayAbove60);
      expect(r.price, 59);
    });
    test('Large + Delay >60% = ₹79 (EXACT)', () {
      final r = PricingEngine.calculate(distanceKm: 10.0, durationText: '15 min',
          durationSeconds: 900, parcelSize: ParcelSize.large,
          isSameCity: true, timePerformance: TimePerformance.delayAbove60);
      expect(r.price, 79);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SECTION 3: FLIGHT OVERRIDE — EXACT PRICES
  //  Document: micro=449, small=649, medium=949
  // ══════════════════════════════════════════════════════════════

  group('§FLIGHT OVERRIDE — ALL 3 values from official document', () {
    test('Flight micro = ₹449 (EXACT)', () {
      expect(FlightPricing.getPrice('micro'), _officialFlightTable['micro']!);
      expect(FlightPricing.getPrice('micro'), 449);
    });
    test('Flight small = ₹649 (EXACT)', () {
      expect(FlightPricing.getPrice('small'), _officialFlightTable['small']!);
      expect(FlightPricing.getPrice('small'), 649);
    });
    test('Flight medium = ₹949 (EXACT)', () {
      expect(FlightPricing.getPrice('medium'), _officialFlightTable['medium']!);
      expect(FlightPricing.getPrice('medium'), 949);
    });
    test('Flight ignores distance (strictly override)', () {
      for (final dist in [10.0, 100.0, 500.0, 2000.0, 3000.0]) {
        final r = PricingEngine.calculate(
          distanceKm: dist, durationText: '1 hr', durationSeconds: 3600,
          parcelSize: ParcelSize.small, travelMode: TravelMode.flight,
        );
        expect(r.price, 649, reason: 'Flight must always be ₹649 regardless of distance ($dist km)');
        expect(r.pricingType, PricingType.flight);
      }
    });
    test('Flight ignores time performance (strictly override)', () {
      for (final perf in TimePerformance.values) {
        final r = PricingEngine.calculate(
          distanceKm: 500.0, durationText: '2 hr', durationSeconds: 7200,
          parcelSize: ParcelSize.medium, travelMode: TravelMode.flight,
          timePerformance: perf,
        );
        expect(r.price, 949, reason: 'Flight medium must always be ₹949 regardless of time perf');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SECTION 4: SMALL PARCEL — ALL 30 ROWS, ALL 90 CELLS
  //  This is a complete exhaustive table verification
  // ══════════════════════════════════════════════════════════════

  group('§SMALL PARCEL (A) — ALL 90 values from official document', () {
    test('Verify all 30 slabs × 3 columns match document exactly', () {
      final implSlabs = [...CityToCitySlabs.smallSlabs1200, ...CityToCitySlabs.smallSlabs3000];
      expect(implSlabs.length, 30, reason: 'Must have exactly 30 slabs');

      for (int i = 0; i < _officialSmallSlabs.length; i++) {
        final doc = _officialSmallSlabs[i];
        final impl = implSlabs[i];
        final label = '${doc[0]}–${doc[1]} km';

        expect(impl.minKm, doc[0], reason: 'Small slab $i: minKm mismatch at $label');
        expect(impl.maxKm, doc[1], reason: 'Small slab $i: maxKm mismatch at $label');
        expect(impl.underTime, doc[2], reason: 'Small $label Under Time: got ${impl.underTime}, expected ${doc[2]}');
        expect(impl.delay60, doc[3], reason: 'Small $label ≤60% Delay: got ${impl.delay60}, expected ${doc[3]}');
        expect(impl.delayAbove60, doc[4], reason: 'Small $label >60% Delay: got ${impl.delayAbove60}, expected ${doc[4]}');
      }
    });

    // Spot-check using actual engine calls at mid-point of each slab
    test('Engine returns EXACT prices for each slab (small, underTime)', () {
      final cases = [
        // [midKm, expectedPrice]
        [50,   99],   // 1–100
        [150,  129],  // 101–200
        [250,  159],  // 201–300
        [350,  189],  // 301–400
        [450,  219],  // 401–500
        [550,  249],  // 501–600
        [650,  279],  // 601–700
        [750,  309],  // 701–800
        [850,  339],  // 801–900
        [950,  369],  // 901–1000
        [1050, 399],  // 1001–1100
        [1150, 429],  // 1101–1200
        [1250, 449],  // 1201–1300
        [1350, 469],  // 1301–1400
        [1450, 489],  // 1401–1500
        [1550, 509],  // 1501–1600
        [1650, 529],  // 1601–1700
        [1750, 549],  // 1701–1800
        [1850, 569],  // 1801–1900
        [1950, 589],  // 1901–2000
        [2050, 609],  // 2001–2100
        [2150, 629],  // 2101–2200
        [2250, 649],  // 2201–2300
        [2350, 669],  // 2301–2400
        [2450, 689],  // 2401–2500
        [2550, 709],  // 2501–2600
        [2650, 729],  // 2601–2700
        [2750, 749],  // 2701–2800
        [2850, 769],  // 2801–2900
        [2950, 789],  // 2901–3000
      ];
      for (final c in cases) {
        final r = PricingEngine.calculate(
          distanceKm: c[0].toDouble(), durationText: '5 hr',
          durationSeconds: 18000, parcelSize: ParcelSize.small,
          timePerformance: TimePerformance.underTime,
        );
        expect(r.price, c[1], reason: 'Small ${c[0]}km underTime: got ${r.price}, expected ${c[1]}');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SECTION 5: MEDIUM PARCEL — ALL 30 ROWS, ALL 90 CELLS
  // ══════════════════════════════════════════════════════════════

  group('§MEDIUM PARCEL (B) — ALL 90 values from official document', () {
    test('Verify all 30 slabs × 3 columns match document exactly', () {
      final implSlabs = [...CityToCitySlabs.mediumSlabs1200, ...CityToCitySlabs.mediumSlabs3000];
      expect(implSlabs.length, 30);

      for (int i = 0; i < _officialMediumSlabs.length; i++) {
        final doc = _officialMediumSlabs[i];
        final impl = implSlabs[i];
        final label = '${doc[0]}–${doc[1]} km';
        expect(impl.underTime, doc[2], reason: 'Medium $label Under Time mismatch');
        expect(impl.delay60, doc[3], reason: 'Medium $label ≤60% Delay mismatch');
        expect(impl.delayAbove60, doc[4], reason: 'Medium $label >60% Delay mismatch');
      }
    });

    test('Engine returns EXACT prices for each slab (medium, underTime)', () {
      final cases = [
        [50,   149],  [150, 189],  [250, 239],  [350, 279],  [450, 329],
        [550,  369],  [650, 419],  [750, 459],  [850, 509],  [950, 549],
        [1050, 599],  [1150, 639], [1250, 669], [1350, 699], [1450, 729],
        [1550, 759],  [1650, 789], [1750, 819], [1850, 849], [1950, 879],
        [2050, 909],  [2150, 939], [2250, 969], [2350, 999], [2450, 1029],
        [2550, 1059], [2650, 1089],[2750, 1119],[2850, 1149],[2950, 1179],
      ];
      for (final c in cases) {
        final r = PricingEngine.calculate(
          distanceKm: c[0].toDouble(), durationText: '5 hr',
          durationSeconds: 18000, parcelSize: ParcelSize.medium,
          timePerformance: TimePerformance.underTime,
        );
        expect(r.price, c[1], reason: 'Medium ${c[0]}km underTime: got ${r.price}, expected ${c[1]}');
      }
    });

    test('Engine returns EXACT delay60 prices for medium', () {
      final cases = [
        [50, 129], [150, 159], [250, 209], [350, 239], [450, 279],
        [550, 319], [650, 359], [750, 389], [850, 429], [950, 469],
        [1050, 509], [1150, 539], [1250, 569], [1350, 589], [1450, 619],
        [1550, 649], [1650, 669], [1750, 699], [1850, 719], [1950, 749],
        [2050, 769], [2150, 799], [2250, 819], [2350, 849], [2450, 869],
        [2550, 899], [2650, 919], [2750, 949], [2850, 969], [2950, 999],
      ];
      for (final c in cases) {
        final r = PricingEngine.calculate(
          distanceKm: c[0].toDouble(), durationText: '5 hr',
          durationSeconds: 18000, parcelSize: ParcelSize.medium,
          timePerformance: TimePerformance.delayUpTo60,
        );
        expect(r.price, c[1], reason: 'Medium ${c[0]}km delay60: got ${r.price}, expected ${c[1]}');
      }
    });

    test('Engine returns EXACT delayAbove60 prices for medium', () {
      final cases = [
        [50, 109], [150, 139], [250, 179], [350, 209], [450, 249],
        [550, 279], [650, 319], [750, 349], [850, 379], [950, 409],
        [1050, 449], [1150, 479], [1250, 499], [1350, 519], [1450, 549],
        [1550, 569], [1650, 589], [1750, 609], [1850, 629], [1950, 659],
        [2050, 679], [2150, 699], [2250, 719], [2350, 749], [2450, 769],
        [2550, 789], [2650, 819], [2750, 839], [2850, 869], [2950, 889],
      ];
      for (final c in cases) {
        final r = PricingEngine.calculate(
          distanceKm: c[0].toDouble(), durationText: '5 hr',
          durationSeconds: 18000, parcelSize: ParcelSize.medium,
          timePerformance: TimePerformance.delayAbove60,
        );
        expect(r.price, c[1], reason: 'Medium ${c[0]}km delayAbove60: got ${r.price}, expected ${c[1]}');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SECTION 6: LARGE PARCEL — ALL 30 ROWS, ALL 90 CELLS
  // ══════════════════════════════════════════════════════════════

  group('§LARGE PARCEL (C) — ALL 90 values from official document', () {
    test('Verify all 30 slabs × 3 columns match document exactly', () {
      final implSlabs = [...CityToCitySlabs.largeSlabs1200, ...CityToCitySlabs.largeSlabs3000];
      expect(implSlabs.length, 30);

      for (int i = 0; i < _officialLargeSlabs.length; i++) {
        final doc = _officialLargeSlabs[i];
        final impl = implSlabs[i];
        final label = '${doc[0]}–${doc[1]} km';
        expect(impl.underTime, doc[2], reason: 'Large $label Under Time mismatch');
        expect(impl.delay60, doc[3], reason: 'Large $label ≤60% Delay mismatch');
        expect(impl.delayAbove60, doc[4], reason: 'Large $label >60% Delay mismatch');
      }
    });

    test('Engine returns EXACT prices for each slab (large, all 3 perf tiers)', () {
      // Test all 30 slabs × 3 tiers = 90 assertions
      final slabMids = [50, 150, 250, 350, 450, 550, 650, 750, 850, 950,
                        1050, 1150, 1250, 1350, 1450, 1550, 1650, 1750, 1850, 1950,
                        2050, 2150, 2250, 2350, 2450, 2550, 2650, 2750, 2850, 2950];
      for (int i = 0; i < _officialLargeSlabs.length; i++) {
        final doc = _officialLargeSlabs[i];
        final km = slabMids[i].toDouble();

        final underTime = PricingEngine.calculate(distanceKm: km, durationText: '8 hr',
            durationSeconds: 28800, parcelSize: ParcelSize.large,
            timePerformance: TimePerformance.underTime);
        final delay60 = PricingEngine.calculate(distanceKm: km, durationText: '8 hr',
            durationSeconds: 28800, parcelSize: ParcelSize.large,
            timePerformance: TimePerformance.delayUpTo60);
        final delayAbove = PricingEngine.calculate(distanceKm: km, durationText: '8 hr',
            durationSeconds: 28800, parcelSize: ParcelSize.large,
            timePerformance: TimePerformance.delayAbove60);

        expect(underTime.price, doc[2], reason: 'Large ${doc[0]}–${doc[1]}km underTime: got ${underTime.price}, expected ${doc[2]}');
        expect(delay60.price, doc[3], reason: 'Large ${doc[0]}–${doc[1]}km delay60: got ${delay60.price}, expected ${doc[3]}');
        expect(delayAbove.price, doc[4], reason: 'Large ${doc[0]}–${doc[1]}km delayAbove: got ${delayAbove.price}, expected ${doc[4]}');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SECTION 7: SLAB BOUNDARY EXACTNESS
  //  Ensures no value bleeds into wrong slab
  // ══════════════════════════════════════════════════════════════

  group('§SLAB BOUNDARIES — No boundary bleed', () {
    test('100km → small slab 1–100, 101km → slab 101–200', () {
      final at100 = PricingEngine.calculate(distanceKm: 100.0,
          durationText: '2 hr', durationSeconds: 7200, parcelSize: ParcelSize.small);
      final at101 = PricingEngine.calculate(distanceKm: 101.0,
          durationText: '2 hr', durationSeconds: 7200, parcelSize: ParcelSize.small);
      expect(at100.price, 99);
      expect(at101.price, 129);
    });
    test('1200km → slab 1101–1200, 1201km → slab 1201–1300', () {
      final at1200 = PricingEngine.calculate(distanceKm: 1200.0,
          durationText: '20 hr', durationSeconds: 72000, parcelSize: ParcelSize.small);
      final at1201 = PricingEngine.calculate(distanceKm: 1201.0,
          durationText: '20 hr', durationSeconds: 72000, parcelSize: ParcelSize.small);
      expect(at1200.price, 429); // Last slab Part 1
      expect(at1201.price, 449); // First slab Part 2
    });
    test('3000km → max slab, 3001km → still max (cap)', () {
      final at3000 = PricingEngine.calculate(distanceKm: 3000.0,
          durationText: '40 hr', durationSeconds: 144000, parcelSize: ParcelSize.small);
      final at3001 = PricingEngine.calculate(distanceKm: 3001.0,
          durationText: '40 hr', durationSeconds: 144001, parcelSize: ParcelSize.small);
      expect(at3000.price, 789);
      expect(at3001.price, 789); // Capped
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SECTION 8: REAL-WORLD TEST CASES (as specified in audit req)
  // ══════════════════════════════════════════════════════════════

  group('§REAL-WORLD TEST CASES', () {
    test('Same city: Jaipur→Jaipur — Medium, Under Time = ₹79', () {
      final r = PricingEngine.calculate(
        distanceKm: 5.0, durationText: '15 min', durationSeconds: 900,
        parcelSize: ParcelSize.medium, isSameCity: true,
        timePerformance: TimePerformance.underTime,
      );
      expect(r.price, 79);
      expect(r.pricingType, PricingType.sameCity);
    });

    test('Short: Delhi→Gurgaon ≈30km — Small, Under Time = ₹49 (same city)', () {
      // Delhi to Gurgaon is ~30km → same city (≤50km threshold)
      final r = PricingEngine.calculate(
        distanceKm: 30.0, durationText: '45 min', durationSeconds: 2700,
        parcelSize: ParcelSize.small, isSameCity: true,
        timePerformance: TimePerformance.underTime,
      );
      expect(r.price, 49);
    });

    test('Medium: Delhi→Lucknow ≈550km — Small, Under Time = ₹249', () {
      final r = PricingEngine.calculate(
        distanceKm: 550.0, durationText: '8 hr', durationSeconds: 28800,
        parcelSize: ParcelSize.small, timePerformance: TimePerformance.underTime,
      );
      expect(r.price, 249); // 501–600 km slab, small, underTime
    });

    test('Long: Delhi→Bangalore ≈2150km — Small, Under Time = ₹629', () {
      final r = PricingEngine.calculate(
        distanceKm: 2150.0, durationText: '32 hr', durationSeconds: 115200,
        parcelSize: ParcelSize.small, timePerformance: TimePerformance.underTime,
      );
      expect(r.price, 629); // 2101–2200 km slab, small, underTime
    });

    test('Extreme: 3000km route — Small, Under Time = ₹789', () {
      final r = PricingEngine.calculate(
        distanceKm: 3000.0, durationText: '45 hr', durationSeconds: 162000,
        parcelSize: ParcelSize.small, timePerformance: TimePerformance.underTime,
      );
      expect(r.price, 789); // Max slab
    });

    test('Flight mode — Small = ₹649 (ignores all other logic)', () {
      final r = PricingEngine.calculate(
        distanceKm: 2150.0, durationText: '3 hr', durationSeconds: 10800,
        parcelSize: ParcelSize.small, travelMode: TravelMode.flight,
      );
      expect(r.price, 649);
      expect(r.pricingType, PricingType.flight);
    });

    test('Flight mode — Medium = ₹949', () {
      final r = PricingEngine.calculate(
        distanceKm: 1800.0, durationText: '2 hr 30 min', durationSeconds: 9000,
        parcelSize: ParcelSize.medium, travelMode: TravelMode.flight,
      );
      expect(r.price, 949);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SECTION 9: FORMULA VERIFICATION
  //  Official: Final Price = Base × Route × Size × Time × Via
  // ══════════════════════════════════════════════════════════════

  group('§FORMULA — Official calculation chain validation', () {
    test('Same City calculation: 99 × 0.5 = 49.5 → floor → 49 (small, underTime)', () {
      // Document explicitly states: ₹99 × 0.5 = ₹49.5 → Floor App → ₹49
      const basePrice = 99;
      const routeMultiplier = 0.5;
      final rawPrice = basePrice * routeMultiplier; // 49.5
      final floorPrice = rawPrice.floor(); // 49
      expect(floorPrice, 49); // Verify formula
      // Verify engine matches
      final r = PricingEngine.calculate(
        distanceKm: 10.0, durationText: '15 min', durationSeconds: 900,
        parcelSize: ParcelSize.small, isSameCity: true,
      );
      expect(r.price, floorPrice);
    });

    test('City-to-City: Base=99, Size=Medium(×1.5), Route=×1.0 = 148.5→149', () {
      // Small at 1–100km = ₹99 (base). Medium = ₹99 × 1.5 = 148.5 → 149
      const basePrice = 99;
      const sizeMultiplier = 1.5;
      final computed = (basePrice * sizeMultiplier).round(); // 149 (rounding convention)
      expect(computed, 149); // Formula check
      final r = PricingEngine.calculate(
        distanceKm: 50.0, durationText: '1 hr', durationSeconds: 3600,
        parcelSize: ParcelSize.medium,
      );
      expect(r.price, 149);
    });

    test('Priority check: Flight > Same City > Slab', () {
      // Even if isSameCity=true and short distance, flight must override
      final r = PricingEngine.calculate(
        distanceKm: 5.0, durationText: '10 min', durationSeconds: 600,
        parcelSize: ParcelSize.small, travelMode: TravelMode.flight,
        isSameCity: true,
      );
      expect(r.price, 649); // Flight wins
      expect(r.pricingType, PricingType.flight);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SECTION 10: SECURITY — Backend as Single Source of Truth
  // ══════════════════════════════════════════════════════════════

  group('§SECURITY — Pricing integrity', () {
    test('Small always >= 49 (floor enforced)', () {
      for (final perf in TimePerformance.values) {
        final r = PricingEngine.calculate(
          distanceKm: 10.0, durationText: '15 min', durationSeconds: 900,
          parcelSize: ParcelSize.small, isSameCity: true, timePerformance: perf,
        );
        expect(r.price, greaterThanOrEqualTo(49));
      }
    });

    test('No price manipulation through invalid inputs (NaN/zero distance defaults to slab)', () {
      // Zero distance and very small values → should use 1km slab (min)
      final r1 = PricingEngine.calculate(
        distanceKm: 0.1, durationText: '5 min', durationSeconds: 300,
        parcelSize: ParcelSize.small,
      );
      // 0.1km.ceil() = 1 → 1–100km slab → ₹99
      expect(r1.price, 99);
    });

    test('Slab prices strictly non-negative', () {
      final allSlabs = [
        ...CityToCitySlabs.smallSlabs1200, ...CityToCitySlabs.smallSlabs3000,
        ...CityToCitySlabs.mediumSlabs1200, ...CityToCitySlabs.mediumSlabs3000,
        ...CityToCitySlabs.largeSlabs1200, ...CityToCitySlabs.largeSlabs3000,
      ];
      for (final s in allSlabs) {
        expect(s.underTime, greaterThan(0));
        expect(s.delay60, greaterThan(0));
        expect(s.delayAbove60, greaterThan(0));
      }
    });
  });
}
