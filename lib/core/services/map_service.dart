import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// ══════════════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — PRODUCTION MAP SERVICE v3.0
//  Single source of truth for all Google Maps interactions.
//
//  CRITICAL FIX (v3.0): Removed google_places_sdk_plus native SDK
//  dependency entirely. All autocomplete and place details now use
//  the Google Places REST API (maps.googleapis.com) which requires
//  only the standard "Places API" to be enabled in GCP — NOT the
//  "Places API (New)". This eliminates the 9011 API_ERROR_AUTOCOMPLETE
//  error that occurred because the native SDK targets
//  places.googleapis.com (v1) which needs a separate API enablement.
//
//  Platform strategy:
//  - Web:     Supabase Edge Function proxy (maps-proxy) — avoids CORS
//  - Native:  Direct REST calls to maps.googleapis.com
//
//  Key features:
//  - Returns FULL prediction data (structured_formatting)
//  - No internal debounce (caller manages debounce)
//  - Route caching with 10-minute TTL
//  - Proper session token lifecycle (renew after details fetch)
//  - Reverse geocoding filters out Plus Codes for human-readable addresses
// ══════════════════════════════════════════════════════════════════════

class PlacesResult {
  final List<Map<String, dynamic>> predictions;
  final String? error;
  PlacesResult({required this.predictions, this.error});
}

class PlaceLocation {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String placeId;
  final String? countryCode; // ISO 3166-1 alpha-2 (e.g. 'IN')

  PlaceLocation({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.placeId,
    this.countryCode,
  });

  /// Whether this location is confirmed to be in India.
  bool get isInIndia => countryCode?.toUpperCase() == 'IN';
}

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final String durationText;
  final LatLngBounds? bounds;
  final String? error;
  final String? encodedPolyline;
  final int durationValueSeconds;

  DirectionsResult({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationText,
    this.bounds,
    this.error,
    this.encodedPolyline,
    this.durationValueSeconds = 0,
  });

  bool get isSuccess => error == null && polylinePoints.isNotEmpty;
}

class MapService {
  static final _supabase = Supabase.instance.client;

  // Session token for Autocomplete billing optimization
  static String _sessionToken = const Uuid().v4();

  // Route cache: "oLat,oLng->dLat,dLng" → DirectionsResult (10 min TTL)
  static final Map<String, _CachedRoute> _routeCache = {};
  static const int _cacheTtlMs = 10 * 60 * 1000;

  // Autocomplete cache: query → PlacesResult (5 min TTL, max 100)
  static final Map<String, _CachedAutocomplete> _autocompleteCache = {};
  static const int _autocompleteCacheTtlMs = 5 * 60 * 1000;

  // Place details cache: placeId → PlaceLocation (30 min TTL, max 200)
  static final Map<String, _CachedPlaceDetails> _placeDetailsCache = {};
  static const int _placeDetailsCacheTtlMs = 30 * 60 * 1000;

  static String get apiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? const String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static void _renewSessionToken() {
    _sessionToken = const Uuid().v4();
    debugPrint('🔑 [MapService] Session token renewed');
  }

  /// Call this when opening a new search modal.
  /// Resets the billing session so keystrokes are grouped correctly.
  static void startNewSearchSession() {
    _sessionToken = const Uuid().v4();
    debugPrint('🔑 [MapService] New search session started: $_sessionToken');
  }

  // ════════════════════════════════════════════════════════════════
  //  CITY NAME EXTRACTOR
  //  Given a Google Places main_text (e.g. "Connaught Place") and
  //  its formatted_address (e.g. "Connaught Place, New Delhi, Delhi"),
  //  returns the CITY-level name only.
  //  Priority: locality component → last meaningful part of address.
  // ════════════════════════════════════════════════════════════════

  static String extractCityName(String mainText, String formattedAddress) {
    // Try to extract city from formatted_address by splitting on comma
    // Google usually formats as: "Area, City, State, Country"
    final parts = formattedAddress
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // Remove last 2 parts which are typically State + Country (India)
    // e.g. ["Connaught Place", "New Delhi", "Delhi", "India"]
    //                                         ^ state  ^ country
    final filtered = parts.length >= 3
        ? parts.sublist(0, parts.length - 1) // remove "India"
        : parts;

    // Common Indian state/UT names to exclude
    const stateNames = {
      'Delhi', 'Maharashtra', 'Karnataka', 'Tamil Nadu', 'Gujarat', 'Rajasthan',
      'Uttar Pradesh', 'West Bengal', 'Madhya Pradesh', 'Andhra Pradesh',
      'Telangana', 'Bihar', 'Punjab', 'Haryana', 'Kerala', 'Odisha',
      'Assam', 'Jharkhand', 'Uttarakhand', 'Himachal Pradesh', 'Goa',
      'Chhattisgarh', 'Chandigarh', 'India', 'Puducherry', 'Sikkim',
      'Tripura', 'Meghalaya', 'Manipur', 'Nagaland', 'Mizoram', 'Arunachal Pradesh',
    };

    // Walk backwards: find first part that is NOT a state name
    // That is most likely the city name
    for (int i = filtered.length - 1; i >= 0; i--) {
      final part = filtered[i].trim();
      if (!stateNames.contains(part) && part.isNotEmpty) {
        return part;
      }
    }

    // If mainText itself looks like just a city name (no comma), return it
    if (!mainText.contains(',')) return mainText.trim();

    // Fallback: return first part of mainText before comma
    return mainText.split(',').first.trim();
  }

  // ════════════════════════════════════════════════════════════════
  //  1. PLACES AUTOCOMPLETE (REST API — all platforms)
  //  Uses maps.googleapis.com/maps/api/place/autocomplete/json
  //  Requires only standard "Places API" in GCP — NOT "Places API (New)"
  //  Returns FULL prediction maps including structured_formatting
  //  NO internal debounce — caller is responsible for debouncing
  // ════════════════════════════════════════════════════════════════

  static Future<PlacesResult> getAutocomplete(String query) async {
    if (query.trim().length < 2) return PlacesResult(predictions: []);

    // Cache check — return instantly for repeated queries
    final cacheKey = query.trim().toLowerCase();
    final cached = _autocompleteCache[cacheKey];
    if (cached != null && DateTime.now().millisecondsSinceEpoch - cached.timestamp < _autocompleteCacheTtlMs) {
      return cached.result;
    }

    try {
      Map<String, dynamic> data;

      if (kIsWeb) {
        data = await _invokeProxy({
          'action': 'autocomplete',
          'query': query,
          'sessionToken': _sessionToken,
          'components': 'country:in',
        });
      } else {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=$apiKey'
          '&sessiontoken=$_sessionToken'
          '&language=en'
          '&types=geocode|establishment'
          '&components=country:in'
        );
        final response = await http.get(url).timeout(const Duration(seconds: 5));
        data = jsonDecode(response.body);
      }

      final result = _parseAutocompletePredictions(data);

      // Cache successful results
      if (result.error == null) {
        _autocompleteCache[cacheKey] = _CachedAutocomplete(result: result, timestamp: DateTime.now().millisecondsSinceEpoch);
        if (_autocompleteCache.length > 100) {
          final oldest = _autocompleteCache.entries.reduce((a, b) => a.value.timestamp < b.value.timestamp ? a : b);
          _autocompleteCache.remove(oldest.key);
        }
      }

      return result;
    } catch (e) {
      debugPrint('❌ [Autocomplete] Error: $e');
      return PlacesResult(predictions: [], error: 'Search failed: $e');
    }
  }

  /// Parse raw Google API response into PlacesResult with FULL prediction data
  static PlacesResult _parseAutocompletePredictions(Map<String, dynamic> data) {
    if (data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS') {
      final rawPredictions = (data['predictions'] ?? []) as List;
      final preds = rawPredictions.map<Map<String, dynamic>>((p) {
        return <String, dynamic>{
          'place_id': p['place_id'],
          'description': p['description'],
          'structured_formatting': p['structured_formatting'] ?? {
            'main_text': p['description']?.toString().split(', ').first ?? '',
            'secondary_text': (p['description']?.toString().split(', ') ?? []).skip(1).join(', '),
          },
        };
      }).toList();
      return PlacesResult(predictions: preds);
    } else {
      final errMsg = data['error_message'] ?? data['status'] ?? 'Unknown error';
      debugPrint('❌ [Autocomplete] API returned: $errMsg');
      return PlacesResult(predictions: [], error: errMsg.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  2. PLACE DETAILS — Get coordinates from place_id (REST API)
  //  Uses maps.googleapis.com/maps/api/place/details/json
  //  Renews session token after fetch (Google billing session ends)
  // ════════════════════════════════════════════════════════════════

  static Future<PlaceLocation?> getPlaceDetails(String placeId) async {
    // Cache check — instant return for previously fetched places
    final cached = _placeDetailsCache[placeId];
    if (cached != null && DateTime.now().millisecondsSinceEpoch - cached.timestamp < _placeDetailsCacheTtlMs) {
      return cached.result;
    }

    try {
      Map<String, dynamic> data;

      if (kIsWeb) {
        data = await _invokeProxy({
          'action': 'details',
          'placeId': placeId,
        });
      } else {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=geometry,formatted_address,name'
          '&key=$apiKey'
          '&sessiontoken=$_sessionToken'
        );
        final response = await http.get(url).timeout(const Duration(seconds: 5));
        data = jsonDecode(response.body);
      }

      if (data['status'] == 'OK') {
        _renewSessionToken();
        final result = data['result'];
        final loc = result['geometry']['location'];
        final location = PlaceLocation(
          name: result['name'] ?? result['formatted_address'] ?? 'Unknown',
          address: result['formatted_address'] ?? '',
          lat: (loc['lat'] as num).toDouble(),
          lng: (loc['lng'] as num).toDouble(),
          placeId: placeId,
        );

        // Cache the result
        _placeDetailsCache[placeId] = _CachedPlaceDetails(result: location, timestamp: DateTime.now().millisecondsSinceEpoch);
        if (_placeDetailsCache.length > 200) {
          final oldest = _placeDetailsCache.entries.reduce((a, b) => a.value.timestamp < b.value.timestamp ? a : b);
          _placeDetailsCache.remove(oldest.key);
        }

        return location;
      }

      debugPrint('❌ [Place Details] API returned: ${data['status']} — ${data['error_message'] ?? ''}');
      return null;
    } catch (e) {
      debugPrint('❌ [Place Details] Error: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  3. DIRECTIONS — Route with polyline, distance, duration
  //  Always uses DRIVING mode for Time₁ (pricing ETR)
  //  Includes 10-minute in-memory route cache
  // ════════════════════════════════════════════════════════════════

  static Future<DirectionsResult> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    List<LatLng>? waypoints,
  }) async {
    // Check cache first
    final cacheKey = _buildCacheKey(originLat, originLng, destLat, destLng, waypoints);
    final cached = _routeCache[cacheKey];
    if (cached != null && DateTime.now().millisecondsSinceEpoch - cached.timestamp < _cacheTtlMs) {
      debugPrint('📦 [Directions] Cache HIT: $cacheKey');
      return cached.result;
    }

    try {
      String? wps;
      if (waypoints != null && waypoints.isNotEmpty) {
        wps = waypoints.map((p) => '${p.latitude},${p.longitude}').join('|');
      }

      Map<String, dynamic> data;

      if (kIsWeb) {
        data = await _invokeProxy({
          'action': 'directions',
          'origin': '$originLat,$originLng',
          'destination': '$destLat,$destLng',
          if (wps != null) 'waypoints': wps,
        });
      } else {
        String urlStr = 'https://maps.googleapis.com/maps/api/directions/json'
            '?origin=$originLat,$originLng'
            '&destination=$destLat,$destLng'
            '&mode=driving'
            '&alternatives=false'
            '&key=$apiKey';
        if (wps != null) urlStr += '&waypoints=$wps';

        final response = await http.get(Uri.parse(urlStr)).timeout(const Duration(seconds: 15));
        data = jsonDecode(response.body);
      }

      final result = _parseDirectionsData(data);

      // Cache successful results
      if (result.isSuccess) {
        _routeCache[cacheKey] = _CachedRoute(result: result, timestamp: DateTime.now().millisecondsSinceEpoch);
        // Evict old cache entries (keep max 50)
        if (_routeCache.length > 50) {
          final oldest = _routeCache.entries.reduce((a, b) => a.value.timestamp < b.value.timestamp ? a : b);
          _routeCache.remove(oldest.key);
        }
      }

      return result;
    } catch (e) {
      debugPrint('❌ [Directions] Error: $e');
      return DirectionsResult(polylinePoints: [], distanceKm: 0, durationText: '', error: 'Network error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  3b. MODE-AWARE DIRECTIONS — Accurate ETA per transport mode
  //
  //  Maps app travel modes to Google Directions API modes:
  //    Car / Road → driving
  //    Bus        → driving (transit not always available)
  //    Train      → transit (fallback to driving)
  //    Flight     → custom estimator (distance / 800 + buffers)
  //    Bike       → driving (similar road routes)
  //
  //  For Flight mode, we calculate:
  //    - Haversine distance between origin and destination
  //    - Average flight speed: 800 km/h
  //    - Buffer: 3h (check-in + security + boarding + baggage + transfer)
  // ════════════════════════════════════════════════════════════════

  static Future<DirectionsResult> getDirectionsForMode({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String travelMode,
    List<LatLng>? waypoints,
  }) async {
    final normalizedMode = travelMode.toLowerCase().trim();

    // ── Flight mode: custom estimator ──────────────────────
    if (normalizedMode == 'flight') {
      return _estimateFlightDuration(originLat, originLng, destLat, destLng);
    }

    // ── Train mode: try transit first, fallback to driving ──
    if (normalizedMode == 'train') {
      final transitResult = await _getDirectionsWithMode(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        googleMode: 'transit',
        transitMode: 'train',
        waypoints: waypoints,
      );
      if (transitResult.isSuccess) return transitResult;
      // Fallback to driving with 1.3x multiplier for train
      final drivingResult = await getDirections(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        waypoints: waypoints,
      );
      if (drivingResult.isSuccess) {
        final adjustedSeconds = (drivingResult.durationValueSeconds * 1.3).round();
        return DirectionsResult(
          polylinePoints: drivingResult.polylinePoints,
          distanceKm: drivingResult.distanceKm,
          durationText: _formatDuration(adjustedSeconds),
          bounds: drivingResult.bounds,
          encodedPolyline: drivingResult.encodedPolyline,
          durationValueSeconds: adjustedSeconds,
        );
      }
      return drivingResult;
    }

    // ── Bus mode: use driving (bus routes follow road mostly) ──
    if (normalizedMode == 'bus') {
      final drivingResult = await getDirections(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        waypoints: waypoints,
      );
      if (drivingResult.isSuccess) {
        // Buses are ~20% slower than cars on average
        final adjustedSeconds = (drivingResult.durationValueSeconds * 1.2).round();
        return DirectionsResult(
          polylinePoints: drivingResult.polylinePoints,
          distanceKm: drivingResult.distanceKm,
          durationText: _formatDuration(adjustedSeconds),
          bounds: drivingResult.bounds,
          encodedPolyline: drivingResult.encodedPolyline,
          durationValueSeconds: adjustedSeconds,
        );
      }
      return drivingResult;
    }

    // ── Car / Road / Bike / Default: use driving mode ──
    return getDirections(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      waypoints: waypoints,
    );
  }

  /// Internal: Fetch directions with a specific Google Maps mode
  static Future<DirectionsResult> _getDirectionsWithMode({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String googleMode,
    String? transitMode,
    List<LatLng>? waypoints,
  }) async {
    try {
      String? wps;
      if (waypoints != null && waypoints.isNotEmpty) {
        wps = waypoints.map((p) => '${p.latitude},${p.longitude}').join('|');
      }

      Map<String, dynamic> data;

      if (kIsWeb) {
        data = await _invokeProxy({
          'action': 'directions',
          'origin': '$originLat,$originLng',
          'destination': '$destLat,$destLng',
          'mode': googleMode,
          if (transitMode != null) 'transit_mode': transitMode,
          if (wps != null) 'waypoints': wps,
        });
      } else {
        String urlStr = 'https://maps.googleapis.com/maps/api/directions/json'
            '?origin=$originLat,$originLng'
            '&destination=$destLat,$destLng'
            '&mode=$googleMode'
            '&alternatives=false'
            '&key=$apiKey';
        if (transitMode != null) urlStr += '&transit_mode=$transitMode';
        if (wps != null) urlStr += '&waypoints=$wps';

        final response = await http.get(Uri.parse(urlStr)).timeout(const Duration(seconds: 15));
        data = jsonDecode(response.body);
      }

      return _parseDirectionsData(data);
    } catch (e) {
      debugPrint('❌ [Directions/$googleMode] Error: $e');
      return DirectionsResult(polylinePoints: [], distanceKm: 0, durationText: '', error: 'Network error: $e');
    }
  }

  /// Flight duration estimator using Haversine distance
  static DirectionsResult _estimateFlightDuration(
    double originLat, double originLng, double destLat, double destLng,
  ) {
    // Haversine distance calculation
    const double earthRadiusKm = 6371.0;
    final dLat = (destLat - originLat) * math.pi / 180.0;
    final dLng = (destLng - originLng) * math.pi / 180.0;
    final lat1 = originLat * math.pi / 180.0;
    final lat2 = destLat * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distanceKm = earthRadiusKm * c;

    // Flight speed: ~800 km/h average cruise
    final flightHours = distanceKm / 800.0;
    // Buffer: 3 hours (check-in: 1.5h + security: 0.5h + baggage: 0.5h + transfer: 0.5h)
    const bufferHours = 3.0;
    final totalHours = flightHours + bufferHours;
    final totalSeconds = (totalHours * 3600).round();

    return DirectionsResult(
      polylinePoints: [
        LatLng(originLat, originLng),
        LatLng(destLat, destLng),
      ],
      distanceKm: distanceKm,
      durationText: _formatDuration(totalSeconds),
      durationValueSeconds: totalSeconds,
    );
  }

  static String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '$hours hr $minutes min';
    if (hours > 0) return '$hours hr';
    return '$minutes min';
  }

  // ════════════════════════════════════════════════════════════════
  //  4. REVERSE GEOCODING — LatLng → Human-Readable Address
  //  Used for "Use Current Location" and map tap features
  //
  //  CRITICAL FIX: Filters results to skip Plus Code entries and
  //  return the best human-readable address. Google Geocoding API
  //  returns Plus Codes as the first result when no street address
  //  exists for that exact coordinate. We iterate through results
  //  to find the best match, prioritizing:
  //    1. Street addresses (street_address type)
  //    2. Points of interest / establishments
  //    3. Sublocality / locality
  //    4. Any result that does NOT contain a Plus Code
  //    5. Fallback: extract locality components manually
  // ════════════════════════════════════════════════════════════════

  static Future<PlaceLocation?> reverseGeocode(double lat, double lng) async {
    try {
      Map<String, dynamic> data;

      if (kIsWeb) {
        data = await _invokeProxy({
          'action': 'geocode',
          'origin': '$lat,$lng',
        });
      } else {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=$lat,$lng'
          '&key=$apiKey'
          '&language=en'
        );
        final response = await http.get(url).timeout(const Duration(seconds: 8));
        data = jsonDecode(response.body);
      }

      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        final results = data['results'] as List;

        // Strategy: Find the best human-readable result
        // Plus Codes contain a '+' in their formatted_address early on
        Map<String, dynamic>? bestResult;
        
        // Priority 1: Look for street_address, route, or establishment types
        for (final result in results) {
          final types = List<String>.from(result['types'] ?? []);
          if (types.contains('street_address') || 
              types.contains('route') ||
              types.contains('establishment') ||
              types.contains('point_of_interest')) {
            bestResult = result;
            break;
          }
        }

        // Priority 2: Look for sublocality or locality (neighborhood/city level)
        if (bestResult == null) {
          for (final result in results) {
            final types = List<String>.from(result['types'] ?? []);
            if (types.contains('sublocality') ||
                types.contains('sublocality_level_1') ||
                types.contains('locality')) {
              bestResult = result;
              break;
            }
          }
        }

        // Priority 3: Any result whose formatted_address does NOT contain a '+'
        // (Plus Codes always have '+' in them, e.g., "VQ29+9CX")
        if (bestResult == null) {
          for (final result in results) {
            final addr = result['formatted_address']?.toString() ?? '';
            // Plus Codes match pattern like "XXXX+XXX" — check first word
            final firstPart = addr.split(',').first.trim();
            if (!RegExp(r'^[A-Z0-9]{4,}\+[A-Z0-9]+').hasMatch(firstPart)) {
              bestResult = result;
              break;
            }
          }
        }

        // Priority 4: Just use the second result if first is a Plus Code
        if (bestResult == null && results.length > 1) {
          bestResult = results[1];
        }

        // Final fallback: use the first result
        bestResult ??= results[0];
        final Map<String, dynamic> selected = bestResult as Map<String, dynamic>;

        // Extract a clean display name
        String displayName = (selected['formatted_address'] ?? 'Current Location').toString();
        
        // If the display name still starts with a Plus Code, strip it
        final parts = displayName.split(', ');
        if (parts.isNotEmpty && RegExp(r'^[A-Z0-9]{4,}\+[A-Z0-9]+').hasMatch(parts[0].trim())) {
          // Remove the Plus Code prefix
          displayName = parts.skip(1).join(', ');
        }

        // Trim to a reasonable length for display
        if (displayName.length > 80) {
          final shortened = displayName.split(', ').take(3).join(', ');
          displayName = shortened;
        }

        return PlaceLocation(
          name: displayName.isNotEmpty ? displayName : 'Current Location',
          address: (selected['formatted_address'] ?? '').toString(),
          lat: lat,
          lng: lng,
          placeId: (selected['place_id'] ?? 'gps').toString(),
        );
      }

      debugPrint('❌ [Reverse Geocode] No results for $lat, $lng — status: ${data['status']}');
      return PlaceLocation(
        name: 'Current Location',
        address: '',
        lat: lat,
        lng: lng,
        placeId: 'gps_fallback',
      );
    } catch (e) {
      debugPrint('❌ [Reverse Geocode] Error: $e');
      return PlaceLocation(
        name: 'Current Location',
        address: '',
        lat: lat,
        lng: lng,
        placeId: 'gps_error',
      );
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  5. POLYLINE DECODER — Google's Encoded Polyline Algorithm
  // ════════════════════════════════════════════════════════════════

  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    debugPrint('🗺️ [Polyline] Decoded ${points.length} points');
    return points;
  }

  // ════════════════════════════════════════════════════════════════
  //  INTERNAL HELPERS
  // ════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> _invokeProxy(Map<String, dynamic> body) async {
    try {
      final response = await _supabase.functions.invoke('maps-proxy', body: body);
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      // If response.data is a string, try parsing it
      if (response.data is String) {
        return jsonDecode(response.data as String);
      }
      return {'status': 'ERROR', 'error_message': 'Invalid proxy response'};
    } catch (e) {
      debugPrint('❌ [Proxy] Error: $e');
      return {'status': 'ERROR', 'error_message': e.toString()};
    }
  }

  static DirectionsResult _parseDirectionsData(Map<String, dynamic> json) {
    if (json['status'] == 'OK' && (json['routes'] as List).isNotEmpty) {
      final route = json['routes'][0];
      final encodedPoly = route['overview_polyline']['points'] as String;
      final points = decodePolyline(encodedPoly);

      double totalDistM = 0;
      int totalDurS = 0;
      for (var leg in route['legs']) {
        totalDistM += (leg['distance']['value'] as num).toDouble();
        totalDurS += (leg['duration']['value'] as num).toInt();
      }

      final bounds = route['bounds'];
      final sw = bounds['southwest'];
      final ne = bounds['northeast'];
      final latLngBounds = LatLngBounds(
        southwest: LatLng((sw['lat'] as num).toDouble(), (sw['lng'] as num).toDouble()),
        northeast: LatLng((ne['lat'] as num).toDouble(), (ne['lng'] as num).toDouble()),
      );

      final hours = totalDurS ~/ 3600;
      final mins = (totalDurS % 3600) ~/ 60;
      final durText = hours > 0 ? '$hours hr $mins min' : '$mins min';

      return DirectionsResult(
        polylinePoints: points,
        distanceKm: totalDistM / 1000.0,
        durationText: durText,
        bounds: latLngBounds,
        encodedPolyline: encodedPoly,
        durationValueSeconds: totalDurS,
      );
    }

    final errMsg = json['error_message'] ?? json['status'] ?? 'Route not found';
    return DirectionsResult(polylinePoints: [], distanceKm: 0, durationText: '', error: errMsg.toString());
  }

  static String _buildCacheKey(double oLat, double oLng, double dLat, double dLng, List<LatLng>? waypoints) {
    final base = '${oLat.toStringAsFixed(4)},${oLng.toStringAsFixed(4)}->${dLat.toStringAsFixed(4)},${dLng.toStringAsFixed(4)}';
    if (waypoints == null || waypoints.isEmpty) return base;
    final wps = waypoints.map((w) => '${w.latitude.toStringAsFixed(4)},${w.longitude.toStringAsFixed(4)}').join('|');
    return '$base|$wps';
  }
}

// Internal cache entries
class _CachedRoute {
  final DirectionsResult result;
  final int timestamp;
  _CachedRoute({required this.result, required this.timestamp});
}

class _CachedAutocomplete {
  final PlacesResult result;
  final int timestamp;
  _CachedAutocomplete({required this.result, required this.timestamp});
}

class _CachedPlaceDetails {
  final PlaceLocation result;
  final int timestamp;
  _CachedPlaceDetails({required this.result, required this.timestamp});
}
