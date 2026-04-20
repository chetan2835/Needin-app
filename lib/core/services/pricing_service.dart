// ══════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — PRICING SERVICE v3.0 (Backend-First)
//  This is the ONLY class the UI should call for pricing.
//
//  Architecture: Flutter → Supabase Edge Function → Response
//  The backend is the SINGLE SOURCE OF TRUTH.
//  Local calculation is used ONLY as offline fallback.
// ══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/pricing_slabs.dart';
import '../models/pricing_result.dart';
import 'pricing_engine.dart';
import 'map_service.dart';

class PricingService {
  static final PricingService _instance = PricingService._internal();
  factory PricingService() => _instance;
  PricingService._internal();

  // ── Route + Price Cache (prevents redundant calls) ──
  final Map<String, _CachedPrice> _priceCache = {};
  static const int _maxCacheSize = 50;
  static const Duration _cacheTTL = Duration(minutes: 15);

  // ── Supabase Edge Function URL ──
  String get _edgeFunctionUrl {
    final supabaseUrl = Supabase.instance.client.rest.url.replaceAll('/rest/v1', '');
    return '$supabaseUrl/functions/v1/calculate-price';
  }

  // ══════════════════════════════════════════════════════════════
  //  MAIN API: Calculate price via backend
  // ══════════════════════════════════════════════════════════════

  /// Calculate price for a route via the backend pricing engine.
  /// This is the primary entry point for all pricing calculations.
  ///
  /// Flow:
  /// 1. Check cache → return if fresh
  /// 2. Call backend Edge Function
  /// 3. Parse structured response
  /// 4. Cache result
  /// 5. Return PricingResult
  ///
  /// On failure, falls back to local calculation.
  Future<PricingResult> calculatePrice({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required ParcelSize parcelSize,
    TravelMode travelMode = TravelMode.car,
    TimePerformance timePerformance = TimePerformance.underTime,
    String? originCity,
    String? destCity,
  }) async {
    debugPrint('══════════════════════════════════════');
    debugPrint('PRICING SERVICE v3: Backend-first calculation');
    debugPrint('  From: $originLat, $originLng');
    debugPrint('  To: $destLat, $destLng');
    debugPrint('  Size: ${parcelSize.name}, Mode: ${travelMode.name}');

    // ── Step 1: Check cache ──
    final cacheKey = _buildCacheKey(
      originLat, originLng, destLat, destLng,
      parcelSize, travelMode, timePerformance,
    );

    final cached = _priceCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      debugPrint('📦 PRICE CACHE HIT');
      return cached.result;
    }

    // ── Step 2: Call backend ──
    try {
      final result = await _callBackendPricingEngine(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        parcelSize: _sizeToString(parcelSize),
        travelMode: _modeToString(travelMode),
        timePerformance: _perfToString(timePerformance),
      );

      if (result.isSuccess) {
        _addToCache(cacheKey, result);
        debugPrint('💰 BACKEND PRICE: ₹${result.price}');
        return result;
      }

      debugPrint('⚠️ Backend returned error: ${result.error}');
      // Fall through to local fallback
    } catch (e) {
      debugPrint('❌ Backend call failed: $e');
      // Fall through to local fallback
    }

    // ── Step 3: Local fallback (offline mode) ──
    debugPrint('🔄 Falling back to local pricing engine...');
    return _localFallback(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      parcelSize: parcelSize,
      travelMode: travelMode,
      timePerformance: timePerformance,
      originCity: originCity,
      destCity: destCity,
    );
  }

  /// Get all 3 parcel size prices for a route (for UI comparison cards)
  /// Makes a single route API call, then 3 pricing calls
  Future<Map<ParcelSize, PricingResult>> calculateAllSizes({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    TravelMode travelMode = TravelMode.car,
    TimePerformance timePerformance = TimePerformance.underTime,
    String? originCity,
    String? destCity,
  }) async {
    final results = <ParcelSize, PricingResult>{};

    // Fire all 3 requests concurrently
    final futures = <ParcelSize, Future<PricingResult>>{};
    for (final size in ParcelSize.values) {
      futures[size] = calculatePrice(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        parcelSize: size,
        travelMode: travelMode,
        timePerformance: timePerformance,
        originCity: originCity,
        destCity: destCity,
      );
    }

    for (final entry in futures.entries) {
      try {
        results[entry.key] = await entry.value;
      } catch (e) {
        results[entry.key] = PricingResult.error('Failed: $e');
      }
    }

    return results;
  }

  /// Quick price estimate without API calls (uses haversine + local engine)
  PricingResult estimatePrice({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required ParcelSize parcelSize,
    TravelMode travelMode = TravelMode.car,
  }) {
    final straightLineKm = _haversineDistance(
      originLat, originLng, destLat, destLng,
    );
    final estimatedRoadKm = straightLineKm * 1.3;
    final estimatedSeconds = (estimatedRoadKm / 50 * 3600).round();
    final hours = estimatedSeconds ~/ 3600;
    final mins = (estimatedSeconds % 3600) ~/ 60;
    final durationText = hours > 0 ? '$hours hr $mins min' : '$mins min';

    final isSameCity = PricingEngine.detectSameCity(estimatedRoadKm);

    return PricingEngine.calculate(
      distanceKm: estimatedRoadKm,
      durationText: durationText,
      durationSeconds: estimatedSeconds,
      parcelSize: parcelSize,
      travelMode: travelMode,
      isSameCity: isSameCity,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  BACKEND API CALL
  // ══════════════════════════════════════════════════════════════

  Future<PricingResult> _callBackendPricingEngine({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String parcelSize,
    required String travelMode,
    required String timePerformance,
  }) async {
    final url = Uri.parse(_edgeFunctionUrl);

    final requestBody = {
      'origin_lat': originLat,
      'origin_lng': originLng,
      'destination_lat': destLat,
      'destination_lng': destLng,
      'parcel_size': parcelSize,
      'travel_mode': travelMode,
      'time_performance': timePerformance,
    };

    debugPrint('🌐 Calling backend: $url');
    debugPrint('   Body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'apikey': Supabase.instance.client.rest.headers['apikey'] ?? '',
        'Authorization': 'Bearer ${Supabase.instance.client.rest.headers['apikey'] ?? ''}',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 15));

    debugPrint('📡 Backend response: ${response.statusCode}');

    if (response.statusCode != 200) {
      final errBody = jsonDecode(response.body);
      return PricingResult.error(errBody['error']?.toString() ?? 'Backend error ${response.statusCode}');
    }

    final json = jsonDecode(response.body);

    // ── Parse backend response into PricingResult ──
    return _parseBackendResponse(json);
  }

  PricingResult _parseBackendResponse(Map<String, dynamic> json) {
    final breakdown = json['breakdown'] as Map<String, dynamic>? ?? {};

    PricingType pricingType;
    switch (json['pricing_type']?.toString()) {
      case 'same_city':
        pricingType = PricingType.sameCity;
        break;
      case 'flight':
        pricingType = PricingType.flight;
        break;
      case 'slab':
      default:
        pricingType = PricingType.slab;
    }

    return PricingResult(
      price: (json['price'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      duration: json['duration']?.toString() ?? '',
      pricingType: pricingType,
      parcelSizeLabel: json['parcel_size']?.toString() ?? '',
      travelModeLabel: json['travel_mode']?.toString() ?? '',
      etrSeconds: (json['etr_seconds'] as num?)?.toInt() ?? 0,
      etrText: json['etr_text']?.toString() ?? '',
      breakdown: PricingBreakdown(
        basePrice: (breakdown['base_price'] as num?)?.toInt() ?? 0,
        slabRange: breakdown['slab_range']?.toString() ?? '',
        timeMultiplier: (breakdown['time_multiplier'] as num?)?.toDouble() ?? 1.0,
        timePerformanceLabel: breakdown['time_performance']?.toString() ?? '',
        routeType: breakdown['route_type']?.toString() ?? '',
        finalReason: breakdown['final_reason']?.toString() ?? '',
        flightCategory: breakdown['flight_category']?.toString(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  LOCAL FALLBACK (Offline Mode)
  // ══════════════════════════════════════════════════════════════

  Future<PricingResult> _localFallback({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required ParcelSize parcelSize,
    required TravelMode travelMode,
    required TimePerformance timePerformance,
    String? originCity,
    String? destCity,
  }) async {
    // Try Google Maps first
    RouteInfo? routeInfo;
    try {
      final directions = await MapService.getDirections(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
      );

      if (directions.isSuccess) {
        routeInfo = RouteInfo(
          distanceKm: directions.distanceKm,
          durationText: directions.durationText,
          durationSeconds: _parseDurationToSeconds(directions.durationText),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Local Google Maps call failed: $e');
    }

    // Haversine fallback
    if (routeInfo == null) {
      final straightKm = _haversineDistance(originLat, originLng, destLat, destLng);
      final estimatedKm = straightKm * 1.3;
      final estimatedSec = (estimatedKm / 50 * 3600).round();
      final hours = estimatedSec ~/ 3600;
      final mins = (estimatedSec % 3600) ~/ 60;
      routeInfo = RouteInfo(
        distanceKm: estimatedKm,
        durationText: hours > 0 ? '$hours hr $mins min' : '$mins min',
        durationSeconds: estimatedSec,
      );
    }

    final isSameCity = PricingEngine.detectSameCity(
      routeInfo.distanceKm,
      originCity: originCity,
      destCity: destCity,
    );

    return PricingEngine.calculate(
      distanceKm: routeInfo.distanceKm,
      durationText: routeInfo.durationText,
      durationSeconds: routeInfo.durationSeconds,
      parcelSize: parcelSize,
      travelMode: travelMode,
      isSameCity: isSameCity,
      timePerformance: timePerformance,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  UTILITIES
  // ══════════════════════════════════════════════════════════════

  String _buildCacheKey(
    double lat1, double lng1, double lat2, double lng2,
    ParcelSize size, TravelMode mode, TimePerformance perf,
  ) {
    return '${lat1.toStringAsFixed(3)},${lng1.toStringAsFixed(3)}'
        '->${lat2.toStringAsFixed(3)},${lng2.toStringAsFixed(3)}'
        ':${size.name}:${mode.name}:${perf.name}';
  }

  void _addToCache(String key, PricingResult result) {
    if (_priceCache.length >= _maxCacheSize) {
      _priceCache.remove(_priceCache.keys.first);
    }
    _priceCache[key] = _CachedPrice(result: result, cachedAt: DateTime.now());
  }

  void clearCache() {
    _priceCache.clear();
    debugPrint('🗑️ Price cache cleared');
  }

  int _parseDurationToSeconds(String durationText) {
    int totalSeconds = 0;
    final parts = durationText.toLowerCase().split(' ');
    for (int i = 0; i < parts.length - 1; i += 2) {
      final value = int.tryParse(parts[i]) ?? 0;
      final unit = parts[i + 1];
      if (unit.startsWith('hr') || unit.startsWith('hour')) {
        totalSeconds += value * 3600;
      } else if (unit.startsWith('min')) {
        totalSeconds += value * 60;
      } else if (unit.startsWith('sec')) {
        totalSeconds += value;
      } else if (unit.startsWith('day')) {
        totalSeconds += value * 86400;
      }
    }
    return totalSeconds > 0 ? totalSeconds : 3600;
  }

  static double _haversineDistance(
    double lat1, double lon1, double lat2, double lon2,
  ) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * 3.14159265359 / 180.0;

  static String _sizeToString(ParcelSize size) {
    switch (size) {
      case ParcelSize.small: return 'small';
      case ParcelSize.medium: return 'medium';
      case ParcelSize.large: return 'large';
    }
  }

  static String _modeToString(TravelMode mode) {
    switch (mode) {
      case TravelMode.bike: return 'bike';
      case TravelMode.car: return 'road';
      case TravelMode.train: return 'train';
      case TravelMode.bus: return 'bus';
      case TravelMode.flight: return 'flight';
    }
  }

  static String _perfToString(TimePerformance perf) {
    switch (perf) {
      case TimePerformance.underTime: return 'under_time';
      case TimePerformance.delayUpTo60: return 'delay_60';
      case TimePerformance.delayAbove60: return 'delay_above_60';
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  INTERNAL CLASSES
// ══════════════════════════════════════════════════════════════

class RouteInfo {
  final double distanceKm;
  final String durationText;
  final int durationSeconds;

  RouteInfo({
    required this.distanceKm,
    required this.durationText,
    required this.durationSeconds,
  });
}

class _CachedPrice {
  final PricingResult result;
  final DateTime cachedAt;

  _CachedPrice({required this.result, required this.cachedAt});

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > PricingService._cacheTTL;
}
