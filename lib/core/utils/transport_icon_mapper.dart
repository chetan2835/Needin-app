import 'package:flutter/material.dart';

class TransportIconMapper {
  /// Returns the appropriate icon for a given transport mode string.
  /// Handles aliases, whitespace, and capitalization.
  static IconData getIconForMode(String? mode) {
    if (mode == null) return Icons.directions_car; // Fallback

    final normalized = mode.toLowerCase().trim();

    switch (normalized) {
      // Air Travel
      case 'flight':
      case 'airplane':
      case 'air':
        return Icons.flight;

      // Road Travel
      case 'road':
      case 'car':
      case 'taxi':
      case 'cab':
        return Icons.directions_car;

      // Bus
      case 'bus':
        return Icons.directions_bus;

      // Train
      case 'train':
      case 'rail':
        return Icons.train;

      // Motorcycle
      case 'bike':
      case 'motorcycle':
        return Icons.two_wheeler;

      // Bicycle
      case 'bicycle':
      case 'cycle':
        return Icons.pedal_bike;

      // Ship
      case 'ship':
      case 'ferry':
      case 'boat':
        return Icons.directions_boat;

      // Default
      default:
        return Icons.commute; // Generic travel icon
    }
  }
}
