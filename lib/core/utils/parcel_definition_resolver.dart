import 'package:flutter/material.dart';

class ParcelCategoryInfo {
  final String title;
  final String maxWeight;
  final String dimensions;
  final String examples;
  final IconData icon;
  final Color color;
  final List<String> bulletPoints;
  final String? importantNote;

  ParcelCategoryInfo({
    required this.title,
    required this.maxWeight,
    required this.dimensions,
    required this.examples,
    required this.icon,
    required this.color,
    required this.bulletPoints,
    this.importantNote,
  });
}

class ParcelDefinitionResolver {
  static bool isFlightMode(String? travelMode) {
    return travelMode?.toLowerCase() == 'flight';
  }

  static String getModalTitle(String? travelMode) {
    if (isFlightMode(travelMode)) {
      return "Flight Parcel Definition";
    }
    return "Standard Parcel Definition";
  }

  static String getModalSubtitle(String? travelMode) {
    if (isFlightMode(travelMode)) {
      return "Choose the right parcel category based on strict airline limits for weight and dimensions.";
    }
    return "This applies to Car, Bike, Bus, Train and other standard transport modes. Choose the right parcel category based on your parcel size, dimensions, and weight.";
  }

  static ParcelCategoryInfo getSmallParcelInfo(String? travelMode) {
    if (isFlightMode(travelMode)) {
      return ParcelCategoryInfo(
        title: "Small Parcel",
        maxWeight: "Max 1kg",
        dimensions: "≤ 12 × 12 × 12 in",
        examples: "Examples: Keys, Documents, Envelopes",
        icon: Icons.mail_outline,
        color: const Color(0xFF16A34A),
        bulletPoints: [
          "Maximum weight: up to 1 kg",
          "Maximum dimensions: ≤ 12 × 12 × 12 inches",
        ],
        importantNote: "Important:\nAll three dimensions (Length, Width, Height) must EACH remain within 12 inches.\nIf any side exceeds 12 inches OR weight exceeds 1 kg, the parcel automatically moves to the next category.",
      );
    } else {
      return ParcelCategoryInfo(
        title: "Small Parcel",
        maxWeight: "Max 2kg",
        dimensions: "≤ 12 × 12 × 12 in",
        examples: "Examples: Keys, Documents, Envelopes, Small accessories",
        icon: Icons.mail_outline,
        color: const Color(0xFF16A34A),
        bulletPoints: [
          "Maximum weight: up to 2 kg",
          "Maximum dimensions: ≤ 12 × 12 × 12 inches",
        ],
        importantNote: "Important:\nAll three dimensions (L × W × H) must individually remain within 12 inches.\nWeight must not exceed 2 kg.\nIf ANY side exceeds 12 inches OR weight exceeds 2 kg, the parcel will automatically move to the next category.",
      );
    }
  }

  static ParcelCategoryInfo getMediumParcelInfo(String? travelMode) {
    if (isFlightMode(travelMode)) {
      return ParcelCategoryInfo(
        title: "Medium Parcel",
        maxWeight: "Max 3kg",
        dimensions: "≤ 18 × 18 × 18 in",
        examples: "Examples: Laptop bags, Medium boxes",
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFFF59E0B),
        bulletPoints: [
          "Maximum weight: up to 3 kg",
          "Maximum dimensions: ≤ 18 × 18 × 18 inches",
        ],
        importantNote: "Important:\nAll three dimensions must EACH remain within 18 inches.\nIf any side exceeds 18 inches OR weight exceeds 3 kg, the parcel moves to the Large category.",
      );
    } else {
      return ParcelCategoryInfo(
        title: "Medium Parcel",
        maxWeight: "Max 5kg",
        dimensions: "≤ 24 × 24 × 24 in",
        examples: "Examples: Laptop bags, Medium boxes, Clothing packages",
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFFF59E0B),
        bulletPoints: [
          "Maximum weight: up to 5 kg",
          "Maximum dimensions: ≤ 24 × 24 × 24 inches",
        ],
        importantNote: "Important:\nAll three dimensions (L × W × H) must individually remain within 24 inches.\nWeight must not exceed 5 kg.\nIf ANY side exceeds 24 inches OR weight exceeds 5 kg, the parcel will automatically move to the Large Parcel category.",
      );
    }
  }

  static ParcelCategoryInfo getLargeParcelInfo(String? travelMode) {
    if (isFlightMode(travelMode)) {
      return ParcelCategoryInfo(
        title: "Large Parcel",
        maxWeight: "Max 5kg",
        dimensions: "Cabin-safe items",
        examples: "Examples: Cabin luggage, Guitars (if allowed)",
        icon: Icons.luggage_outlined,
        color: const Color(0xFFF05A4F),
        bulletPoints: [
          "Maximum weight: up to 5 kg",
          "Must fit within standard airline cabin bag limits",
        ],
        importantNote: "Important:\nFlight travelers generally cannot carry checked luggage for sending parcels. Thus, the absolute maximum weight is 5 kg.\nIf your parcel exceeds this, it cannot be sent via Flight.",
      );
    } else {
      return ParcelCategoryInfo(
        title: "Large Parcel",
        maxWeight: "Max 25kg",
        dimensions: "Any parcel exceeding Medium limits",
        examples: "Examples: Large boxes, Suitcases, Heavy packages",
        icon: Icons.luggage_outlined,
        color: const Color(0xFFF05A4F),
        bulletPoints: [
          "Any dimension exceeds 24 inches",
          "OR Weight exceeds 5 kg",
        ],
        importantNote: null,
      );
    }
  }

  static List<ParcelCategoryInfo> getAllCategories(String? travelMode) {
    return [
      getSmallParcelInfo(travelMode),
      getMediumParcelInfo(travelMode),
      getLargeParcelInfo(travelMode),
    ];
  }

  /// Calculates the parcel category by independently checking dimensions and weight,
  /// then returning the highest applicable category.
  static String calculateCategory(String? travelMode, double lengthIn, double widthIn, double heightIn, double weightKg) {
    bool flight = isFlightMode(travelMode);

    int dimCategory = 1; // 1 = Small, 2 = Medium, 3 = Large, 4 = Invalid
    int weightCategory = 1;

    if (flight) {
      // Dimensions
      if (lengthIn > 18 || widthIn > 18 || heightIn > 18) {
        dimCategory = 4; // Invalid for flight
      } else if (lengthIn > 12 || widthIn > 12 || heightIn > 12) {
        dimCategory = 2; // Medium (up to 18x18x18)
      } else {
        dimCategory = 1; // Small (<=12x12x12)
      }

      // Weight
      if (weightKg > 5) {
        weightCategory = 4; // Invalid for flight
      } else if (weightKg > 3) {
        weightCategory = 3; // Large (3-5 kg)
      } else if (weightKg > 1) {
        weightCategory = 2; // Medium (1-3 kg)
      } else {
        weightCategory = 1; // Small (<=1 kg)
      }
    } else {
      // Non-Flight (Car, Bike, Bus, Train)
      // Dimensions
      if (lengthIn > 24 || widthIn > 24 || heightIn > 24) {
        dimCategory = 3; // Large (>24)
      } else if (lengthIn > 12 || widthIn > 12 || heightIn > 12) {
        dimCategory = 2; // Medium (<=24)
      } else {
        dimCategory = 1; // Small (<=12)
      }

      // Weight
      if (weightKg > 25) {
        weightCategory = 4; // Absolute limit
      } else if (weightKg > 5) {
        weightCategory = 3; // Large (>5 kg)
      } else if (weightKg > 2) {
        weightCategory = 2; // Medium (2-5 kg)
      } else {
        weightCategory = 1; // Small (<=2 kg)
      }
    }

    // System automatically takes the highest category
    int finalCategory = dimCategory > weightCategory ? dimCategory : weightCategory;

    if (finalCategory >= 4) return 'Invalid';
    if (finalCategory == 3) return 'Large';
    if (finalCategory == 2) return 'Medium';
    return 'Small';
  }
}
