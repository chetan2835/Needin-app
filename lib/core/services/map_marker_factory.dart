import 'package:google_maps_flutter/google_maps_flutter.dart';

// ══════════════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — MAP MARKER FACTORY v1.0
//  Centralized marker creation with consistent brand colors.
//
//  Color System:
//  🔵 Pickup / Origin  → Blue  (#2563EB)  → hueAzure (210°)
//  🔴 Drop / Destination → Red  (#EF4444) → hueRed (0°)
//  🟢 Via Stops         → Green (#22C55E) → hueGreen (120°)
//
//  Google Maps BitmapDescriptor uses HSL hue values:
//  - Blue:  BitmapDescriptor.hueAzure = 210.0
//  - Red:   BitmapDescriptor.hueRed   = 0.0
//  - Green: BitmapDescriptor.hueGreen = 120.0
//
//  These are the closest available default marker hues to the
//  brand colors #2563EB, #EF4444, and #22C55E respectively.
// ══════════════════════════════════════════════════════════════════════

class MapMarkerFactory {
  // ── Brand Colors ──
  /// Pickup/Origin marker color: #2563EB (Blue)
  static const pickupColorHex = 0xFF2563EB;

  /// Drop/Destination marker color: #EF4444 (Red)
  static const dropColorHex = 0xFFEF4444;

  /// Via Stop marker color: #22C55E (Green)
  static const viaColorHex = 0xFF22C55E;

  // ── Hue Values for Default Markers ──
  /// Azure hue (210°) — closest to #2563EB blue
  static const double pickupHue = BitmapDescriptor.hueAzure; // 210.0

  /// Red hue (0°) — matches #EF4444 red
  static const double dropHue = BitmapDescriptor.hueRed; // 0.0

  /// Green hue (120°) — closest to #22C55E green
  static const double viaHue = BitmapDescriptor.hueGreen; // 120.0

  /// Creates a Pickup/Origin marker (🔵 Blue).
  static Marker createPickupMarker({
    required LatLng position,
    String? title,
    String? snippet,
    String markerId = 'origin',
  }) {
    return Marker(
      markerId: MarkerId(markerId),
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(pickupHue),
      infoWindow: InfoWindow(
        title: title ?? 'Pickup',
        snippet: snippet ?? '',
      ),
    );
  }

  /// Creates a Drop/Destination marker (🔴 Red).
  static Marker createDropMarker({
    required LatLng position,
    String? title,
    String? snippet,
    String markerId = 'destination',
  }) {
    return Marker(
      markerId: MarkerId(markerId),
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(dropHue),
      infoWindow: InfoWindow(
        title: title ?? 'Destination',
        snippet: snippet ?? '',
      ),
    );
  }

  /// Creates a Via Stop marker (🟢 Green).
  static Marker createViaMarker({
    required LatLng position,
    required int index,
    String? title,
    String? snippet,
  }) {
    return Marker(
      markerId: MarkerId('via_$index'),
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(viaHue),
      infoWindow: InfoWindow(
        title: title ?? 'Via Stop ${index + 1}',
        snippet: snippet ?? '',
      ),
    );
  }

  /// Returns the BitmapDescriptor for pickup markers (🔵 Blue).
  static BitmapDescriptor get pickupIcon =>
      BitmapDescriptor.defaultMarkerWithHue(pickupHue);

  /// Returns the BitmapDescriptor for drop markers (🔴 Red).
  static BitmapDescriptor get dropIcon =>
      BitmapDescriptor.defaultMarkerWithHue(dropHue);

  /// Returns the BitmapDescriptor for via markers (🟢 Green).
  static BitmapDescriptor get viaIcon =>
      BitmapDescriptor.defaultMarkerWithHue(viaHue);
}
