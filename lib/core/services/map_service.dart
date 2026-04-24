import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_places_sdk_plus/google_places_sdk_plus.dart' hide LatLng, LatLngBounds;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// ══════════════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — PRODUCTION MAP SERVICE v2.0
//  Single source of truth for all Google Maps interactions.
//
//  Platform strategy:
//  - Web:     Supabase Edge Function proxy (maps-proxy) — avoids CORS
//  - Windows: Direct REST calls (no CORS restriction on native OS)
//  - Mobile:  Flutter Google Places SDK (native, zero REST calls)
//             + REST for Directions/Geocoding (no native SDK for these)
//
//  Key fixes from v1:
//  - Returns FULL prediction data (structured_formatting) from Places API
//  - No internal debounce (caller manages debounce — prevents double delay)
//  - Route caching with 10-minute TTL
//  - Proper session token lifecycle (renew after details fetch)
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

  PlaceLocation({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.placeId,
  });
}

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final String durationText;
  final LatLngBounds? bounds;
  final String? error;

  DirectionsResult({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationText,
    this.bounds,
    this.error,
  });

  bool get isSuccess => error == null && polylinePoints.isNotEmpty;
}

class MapService {
  static final _supabase = Supabase.instance.client;
  static FlutterGooglePlacesSdk? _placesSdk;
  static bool _sdkInitialized = false;

  // Session token for Autocomplete billing optimization
  static String _sessionToken = const Uuid().v4();

  // Route cache: "oLat,oLng->dLat,dLng" → DirectionsResult (10 min TTL)
  static final Map<String, _CachedRoute> _routeCache = {};
  static const int _cacheTtlMs = 10 * 60 * 1000;

  static String get apiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? const String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static void _initPlacesSdkIfNeeded() {
    if (!_sdkInitialized && !kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
      try {
        _placesSdk = FlutterGooglePlacesSdk(apiKey);
        _sdkInitialized = true;
        debugPrint('🗺️ [MapService] Places SDK initialized');
      } catch (e) {
        debugPrint('🗺️ [MapService] Places SDK init failed: $e');
      }
    }
  }

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
  //  1. PLACES AUTOCOMPLETE
  //  Returns FULL prediction maps including structured_formatting
  //  NO internal debounce — caller is responsible for debouncing
  // ════════════════════════════════════════════════════════════════

  static Future<PlacesResult> getAutocomplete(String query) async {
    if (query.trim().length < 2) return PlacesResult(predictions: []);

    try {
      if (kIsWeb) {
        // Web → Supabase Edge Function proxy
        final data = await _invokeProxy({
          'action': 'autocomplete',
          'query': query,
          'sessionToken': _sessionToken,
        });
        return _parseAutocompletePredictions(data);
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        // Windows Desktop → Direct REST (no CORS)
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=$apiKey'
          '&sessiontoken=$_sessionToken'
          '&language=en'
          '&types=geocode|establishment'
        );
        final response = await http.get(url).timeout(const Duration(seconds: 10));
        final data = jsonDecode(response.body);
        return _parseAutocompletePredictions(data);
      } else {
        // Native Mobile → Places SDK
        _initPlacesSdkIfNeeded();
        if (_placesSdk == null) {
          // SDK unavailable — fallback to REST
          final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=${Uri.encodeComponent(query)}'
            '&key=$apiKey'
            '&sessiontoken=$_sessionToken'
            '&language=en'
            '&types=geocode|establishment'
          );
          final response = await http.get(url).timeout(const Duration(seconds: 10));
          final data = jsonDecode(response.body);
          return _parseAutocompletePredictions(data);
        }

        final result = await _placesSdk!.findAutocompletePredictions(query);
        final preds = result.predictions.map((p) {
          // Build structured_formatting-compatible map from SDK result
          final desc = p.fullText ?? '';
          final parts = desc.split(', ');
          final mainText = parts.isNotEmpty ? parts[0] : desc;
          final secondaryText = parts.length > 1 ? parts.sublist(1).join(', ') : '';

          return <String, dynamic>{
            'place_id': p.placeId,
            'description': desc,
            'structured_formatting': {
              'main_text': mainText,
              'secondary_text': secondaryText,
            },
          };
        }).toList();
        return PlacesResult(predictions: preds);
      }
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
  //  2. PLACE DETAILS — Get coordinates from place_id
  //  Renews session token after fetch (Google billing session ends)
  // ════════════════════════════════════════════════════════════════

  static Future<PlaceLocation?> getPlaceDetails(String placeId) async {
    try {
      if (kIsWeb) {
        final data = await _invokeProxy({
          'action': 'details',
          'placeId': placeId,
        });
        if (data['status'] == 'OK') {
          _renewSessionToken();
          final result = data['result'];
          final loc = result['geometry']['location'];
          return PlaceLocation(
            name: result['name'] ?? result['formatted_address'] ?? 'Unknown',
            address: result['formatted_address'] ?? '',
            lat: (loc['lat'] as num).toDouble(),
            lng: (loc['lng'] as num).toDouble(),
            placeId: placeId,
          );
        }
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=geometry,formatted_address,name'
          '&key=$apiKey'
          '&sessiontoken=$_sessionToken'
        );
        final response = await http.get(url).timeout(const Duration(seconds: 10));
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          _renewSessionToken();
          final result = data['result'];
          final loc = result['geometry']['location'];
          return PlaceLocation(
            name: result['name'] ?? result['formatted_address'] ?? 'Unknown',
            address: result['formatted_address'] ?? '',
            lat: (loc['lat'] as num).toDouble(),
            lng: (loc['lng'] as num).toDouble(),
            placeId: placeId,
          );
        }
      } else {
        _initPlacesSdkIfNeeded();
        if (_placesSdk != null) {
          final result = await _placesSdk!.fetchPlace(
            placeId,
            fields: [PlaceField.Location, PlaceField.DisplayName, PlaceField.FormattedAddress],
          );
          final place = result.place;
          if (place != null && place.latLng != null) {
            _renewSessionToken();
            return PlaceLocation(
              name: place.displayName?.text ?? place.address ?? 'Unknown',
              address: place.address ?? '',
              lat: place.latLng!.lat,
              lng: place.latLng!.lng,
              placeId: placeId,
            );
          }
        } else {
          // SDK unavailable — fallback REST
          final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/details/json'
            '?place_id=$placeId'
            '&fields=geometry,formatted_address,name'
            '&key=$apiKey'
          );
          final response = await http.get(url).timeout(const Duration(seconds: 10));
          final data = jsonDecode(response.body);
          if (data['status'] == 'OK') {
            _renewSessionToken();
            final result = data['result'];
            final loc = result['geometry']['location'];
            return PlaceLocation(
              name: result['name'] ?? result['formatted_address'] ?? 'Unknown',
              address: result['formatted_address'] ?? '',
              lat: (loc['lat'] as num).toDouble(),
              lng: (loc['lng'] as num).toDouble(),
              placeId: placeId,
            );
          }
        }
      }
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
  //  4. REVERSE GEOCODING — LatLng → Address
  //  Used for "Use Current Location" and map tap features
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
        );
        final response = await http.get(url).timeout(const Duration(seconds: 8));
        data = jsonDecode(response.body);
      }

      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        final result = data['results'][0];
        return PlaceLocation(
          name: result['formatted_address'] ?? 'Current Location',
          address: result['formatted_address'] ?? '',
          lat: lat,
          lng: lng,
          placeId: result['place_id'] ?? 'gps',
        );
      }
      return null;
    } catch (e) {
      debugPrint('❌ [Reverse Geocode] Error: $e');
      return null;
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
      final points = decodePolyline(route['overview_polyline']['points']);

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

      debugPrint('✅ [Directions] ${(totalDistM / 1000).toStringAsFixed(1)} km, $durText, ${points.length} points');

      return DirectionsResult(
        polylinePoints: points,
        distanceKm: totalDistM / 1000.0,
        durationText: durText,
        bounds: latLngBounds,
      );
    }

    final errMsg = json['error_message'] ?? json['status'] ?? 'Route not found';
    debugPrint('❌ [Directions] API: $errMsg');
    return DirectionsResult(polylinePoints: [], distanceKm: 0, durationText: '', error: errMsg.toString());
  }

  static String _buildCacheKey(double oLat, double oLng, double dLat, double dLng, List<LatLng>? waypoints) {
    final base = '${oLat.toStringAsFixed(4)},${oLng.toStringAsFixed(4)}->${dLat.toStringAsFixed(4)},${dLng.toStringAsFixed(4)}';
    if (waypoints == null || waypoints.isEmpty) return base;
    final wps = waypoints.map((w) => '${w.latitude.toStringAsFixed(4)},${w.longitude.toStringAsFixed(4)}').join('|');
    return '$base|$wps';
  }
}

// Internal cache entry
class _CachedRoute {
  final DirectionsResult result;
  final int timestamp;
  _CachedRoute({required this.result, required this.timestamp});
}
