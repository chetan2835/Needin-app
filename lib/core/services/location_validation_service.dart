import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ══════════════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — LOCATION VALIDATION SERVICE v1.0
//  Centralized India-only location restriction enforcement.
//
//  RULES:
//  - All selected locations must have country == "India" or
//    countryCode == "IN".
//  - Applied to: autocomplete selections, reverse geocoded
//    coordinates, GPS-based selections, edit/saved re-selections.
//  - Invalid selections are BLOCKED with a popup and the previous
//    valid value is preserved.
// ══════════════════════════════════════════════════════════════════════

class LocationValidationService {
  static final _supabase = Supabase.instance.client;

  static String get _apiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ??
      const String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  /// India's approximate bounding box for quick coordinate pre-check.
  /// Lat: 6.5° N – 37.1° N, Lng: 68.1° E – 97.4° E
  static const double _indiaMinLat = 6.5;
  static const double _indiaMaxLat = 37.1;
  static const double _indiaMinLng = 68.1;
  static const double _indiaMaxLng = 97.4;

  /// Quick bounding-box pre-check. Returns false if obviously outside India.
  /// This is NOT authoritative — still requires geocode confirmation for
  /// border regions (e.g. Nepal, Bhutan, Bangladesh share similar coords).
  static bool _isRoughlyInIndia(double lat, double lng) {
    return lat >= _indiaMinLat &&
        lat <= _indiaMaxLat &&
        lng >= _indiaMinLng &&
        lng <= _indiaMaxLng;
  }

  /// Validates whether given coordinates fall within India by reverse
  /// geocoding and checking the country component.
  ///
  /// Returns `true` if the location is in India, `false` otherwise.
  static Future<bool> isCoordinatesInIndia(double lat, double lng) async {
    // Quick bounding-box pre-filter
    if (!_isRoughlyInIndia(lat, lng)) {
      debugPrint(
          '🚫 [LocationValidation] Coordinates ($lat, $lng) outside India bounding box');
      return false;
    }

    try {
      Map<String, dynamic> data;

      if (kIsWeb) {
        final response = await _supabase.functions.invoke('maps-proxy', body: {
          'action': 'geocode',
          'origin': '$lat,$lng',
        });
        if (response.data is Map<String, dynamic>) {
          data = response.data as Map<String, dynamic>;
        } else if (response.data is String) {
          data = jsonDecode(response.data as String);
        } else {
          return false;
        }
      } else {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=$lat,$lng'
          '&key=$_apiKey'
          '&language=en',
        );
        final response =
            await http.get(url).timeout(const Duration(seconds: 8));
        data = jsonDecode(response.body);
      }

      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        return _checkCountryFromResults(data['results'] as List);
      }

      debugPrint(
          '⚠️ [LocationValidation] Geocode returned status: ${data['status']}');
      // If geocode fails, use bounding box result (already passed above)
      return true;
    } catch (e) {
      debugPrint('❌ [LocationValidation] Reverse geocode error: $e');
      // On error, fall back to bounding box result (already passed above)
      return true;
    }
  }

  /// Validates a place_id by fetching its details and checking the country
  /// address component.
  static Future<bool> isPlaceInIndia(String placeId) async {
    try {
      Map<String, dynamic> data;

      if (kIsWeb) {
        final response = await _supabase.functions.invoke('maps-proxy', body: {
          'action': 'details',
          'placeId': placeId,
        });
        if (response.data is Map<String, dynamic>) {
          data = response.data as Map<String, dynamic>;
        } else if (response.data is String) {
          data = jsonDecode(response.data as String);
        } else {
          return false;
        }
      } else {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=address_components,geometry'
          '&key=$_apiKey',
        );
        final response =
            await http.get(url).timeout(const Duration(seconds: 5));
        data = jsonDecode(response.body);
      }

      if (data['status'] == 'OK') {
        final result = data['result'] as Map<String, dynamic>?;
        if (result != null) {
          final addressComponents =
              result['address_components'] as List<dynamic>?;
          if (addressComponents != null) {
            return _isIndiaFromComponents(addressComponents);
          }

          // Fallback: check coordinates
          final geometry = result['geometry'] as Map<String, dynamic>?;
          if (geometry != null) {
            final loc = geometry['location'] as Map<String, dynamic>?;
            if (loc != null) {
              final lat = (loc['lat'] as num).toDouble();
              final lng = (loc['lng'] as num).toDouble();
              return await isCoordinatesInIndia(lat, lng);
            }
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ [LocationValidation] Place validation error: $e');
      return false;
    }
  }

  /// Checks address components for country = "India" / short_name = "IN".
  static bool _isIndiaFromComponents(List<dynamic> components) {
    for (final component in components) {
      final types =
          List<String>.from(component['types'] as List<dynamic>? ?? []);
      if (types.contains('country')) {
        final shortName =
            component['short_name']?.toString().toUpperCase() ?? '';
        final longName =
            component['long_name']?.toString().toLowerCase() ?? '';
        if (shortName == 'IN' || longName == 'india') {
          return true;
        }
        debugPrint(
            '🚫 [LocationValidation] Country mismatch: $shortName / $longName');
        return false;
      }
    }
    // No country component found — cannot confirm
    debugPrint('⚠️ [LocationValidation] No country component in results');
    return false;
  }

  /// Checks reverse geocode results for India.
  static bool _checkCountryFromResults(List<dynamic> results) {
    for (final result in results) {
      final addressComponents =
          result['address_components'] as List<dynamic>?;
      if (addressComponents != null) {
        for (final component in addressComponents) {
          final types =
              List<String>.from(component['types'] as List<dynamic>? ?? []);
          if (types.contains('country')) {
            final shortName =
                component['short_name']?.toString().toUpperCase() ?? '';
            final longName =
                component['long_name']?.toString().toLowerCase() ?? '';
            if (shortName == 'IN' || longName == 'india') {
              return true;
            }
            debugPrint(
                '🚫 [LocationValidation] Non-Indian country detected: $shortName ($longName)');
            return false;
          }
        }
      }
    }
    return false;
  }

  /// Shows the standardized India-only restriction dialog.
  ///
  /// Title: "Service Area Restriction"
  /// Message: "Select only Indian region. This service is available only
  ///           within Indian territory."
  /// Button: "OK"
  static Future<void> showIndiaOnlyRestrictionDialog(
      BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_off,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Service Area Restriction',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Select only Indian region. This service is available only within Indian territory.',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05A4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
