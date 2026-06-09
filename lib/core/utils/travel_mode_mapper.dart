import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════════
///  TRAVEL MODE MAPPER — Centralized mode-to-label mapping
///
///  Converts internal DB storage values (e.g. "road", "bike")
///  to user-facing display labels (e.g. "Car", "Bike / Truck / Auto")
///  and provides the correct icon for each mode.
///
///  Rules:
///   - Never display raw DB values like "road" to the user.
///   - All mode-related display MUST go through this utility.
///   - Used in: My Journeys, Confirm Journey, Journey Posted Success,
///              Traveler Details, Search Results, Step 2 preview.
/// ════════════════════════════════════════════════════════════════

class TravelModeMapper {
  // ── DB value → Display label ──────────────────────────────────
  static const Map<String, String> _labelMap = {
    'road': 'Car',
    'car': 'Car',
    'driving': 'Car',
    'taxi': 'Car',
    'cab': 'Car',
    'bike': 'Bike / Truck / Auto',
    'motorcycle': 'Bike / Truck / Auto',
    'truck': 'Bike / Truck / Auto',
    'auto': 'Bike / Truck / Auto',
    'two_wheeler': 'Bike / Truck / Auto',
    'bus': 'Bus',
    'train': 'Train',
    'rail': 'Train',
    'transit': 'Train',
    'flight': 'Flight',
    'airplane': 'Flight',
    'air': 'Flight',
    'ship': 'Ship / Ferry',
    'ferry': 'Ship / Ferry',
    'boat': 'Ship / Ferry',
  };

  // ── Display label → DB storage value ─────────────────────────
  static const Map<String, String> _apiKeyMap = {
    'Car': 'road',
    'Bike / Truck / Auto': 'bike',
    'Bus': 'bus',
    'Train': 'train',
    'Flight': 'flight',
    'Ship / Ferry': 'ship',
  };

  // ── DB value → Icon ──────────────────────────────────────────
  static const Map<String, IconData> _iconMap = {
    'road': Icons.directions_car,
    'car': Icons.directions_car,
    'driving': Icons.directions_car,
    'taxi': Icons.directions_car,
    'cab': Icons.directions_car,
    'bike': Icons.two_wheeler,
    'motorcycle': Icons.two_wheeler,
    'truck': Icons.local_shipping,
    'auto': Icons.electric_rickshaw,
    'two_wheeler': Icons.two_wheeler,
    'bus': Icons.directions_bus,
    'train': Icons.train,
    'rail': Icons.train,
    'transit': Icons.train,
    'flight': Icons.flight,
    'airplane': Icons.flight,
    'air': Icons.flight,
    'ship': Icons.directions_boat,
    'ferry': Icons.directions_boat,
    'boat': Icons.directions_boat,
  };

  /// Get the user-facing display label for a DB travel mode value.
  /// Examples:
  ///   "road" → "Car"
  ///   "bike" → "Bike / Truck / Auto"
  ///   "flight" → "Flight"
  static String getLabel(String? mode) {
    if (mode == null || mode.trim().isEmpty) return 'Car';
    final normalized = mode.toLowerCase().trim();
    return _labelMap[normalized] ?? _capitalize(mode);
  }

  /// Get the icon for a DB travel mode value.
  static IconData getIcon(String? mode) {
    if (mode == null || mode.trim().isEmpty) return Icons.directions_car;
    final normalized = mode.toLowerCase().trim();
    return _iconMap[normalized] ?? Icons.commute;
  }

  /// Convert a user-facing display label back to the DB storage key.
  /// Examples:
  ///   "Car" → "road"
  ///   "Bus" → "bus"
  static String toApiKey(String? displayLabel) {
    if (displayLabel == null || displayLabel.trim().isEmpty) return 'road';
    return _apiKeyMap[displayLabel] ?? displayLabel.toLowerCase().trim();
  }

  /// Returns true if this mode is "road/car" type
  static bool isRoadMode(String? mode) {
    if (mode == null) return true;
    final normalized = mode.toLowerCase().trim();
    return normalized == 'road' || normalized == 'car' || normalized == 'driving';
  }

  /// Returns true if this mode is "flight"
  static bool isFlightMode(String? mode) {
    if (mode == null) return false;
    final normalized = mode.toLowerCase().trim();
    return normalized == 'flight' || normalized == 'airplane' || normalized == 'air';
  }

  /// Returns true if this mode is "train"
  static bool isTrainMode(String? mode) {
    if (mode == null) return false;
    final normalized = mode.toLowerCase().trim();
    return normalized == 'train' || normalized == 'rail' || normalized == 'transit';
  }

  /// Returns true if this mode is "bus"
  static bool isBusMode(String? mode) {
    if (mode == null) return false;
    return mode.toLowerCase().trim() == 'bus';
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  /// Returns an ordered list of all available display modes with their icons.
  static List<Map<String, dynamic>> getAllModes() => [
    {'label': 'Car', 'dbValue': 'road', 'icon': Icons.directions_car},
    {'label': 'Bike / Truck / Auto', 'dbValue': 'bike', 'icon': Icons.local_shipping},
    {'label': 'Bus', 'dbValue': 'bus', 'icon': Icons.directions_bus},
    {'label': 'Train', 'dbValue': 'train', 'icon': Icons.train},
    {'label': 'Flight', 'dbValue': 'flight', 'icon': Icons.flight},
  ];
}
