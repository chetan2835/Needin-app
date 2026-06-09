import 'package:intl/intl.dart';

/// Centralized formatter for earnings/price values.
///
/// Handles:
/// - Removing unnecessary `.0` decimals
/// - Adding comma separators for Indian numbering (₹1,339)
/// - Providing a range string like "₹669 – ₹1,339"
/// - Providing a single value string like "₹429"
class EarningsFormatter {
  static final _indianFormat = NumberFormat.decimalPattern('en_IN');

  /// Format a single numeric value to a clean string with ₹ symbol.
  /// Removes `.0` decimals when not needed, adds comma separators.
  ///
  /// Example: 1339.0 → "₹1,339", 99.5 → "₹99.5"
  static String formatSingle(dynamic value) {
    if (value == null) return '₹--';
    final num n = value is num ? value : num.tryParse(value.toString()) ?? 0;
    // Remove trailing .0
    final String formatted = n == n.toInt() 
        ? _indianFormat.format(n.toInt()) 
        : _indianFormat.format(n);
    return '₹$formatted';
  }

  /// Format without ₹ symbol (just the number).
  static String formatNumber(dynamic value) {
    if (value == null) return '--';
    final num n = value is num ? value : num.tryParse(value.toString()) ?? 0;
    return n == n.toInt() 
        ? _indianFormat.format(n.toInt()) 
        : _indianFormat.format(n);
  }

  /// Get earnings display from a journey data map.
  /// Returns range format: "₹669 – ₹1,339" or single: "₹429"
  static String getEarningsRange(Map<String, dynamic> data) {
    final small = data['price_small'];
    final large = data['price_large'];
    if (small != null && large != null) {
      final smallVal = small is num ? small : num.tryParse(small.toString());
      final largeVal = large is num ? large : num.tryParse(large.toString());
      if (smallVal != null && largeVal != null && smallVal != largeVal) {
        return '${formatSingle(smallVal)} – ${formatSingle(largeVal)}';
      }
      return formatSingle(smallVal ?? largeVal);
    }
    final medium = data['price_medium'];
    if (medium != null) return formatSingle(medium);
    return '₹--';
  }

  /// Get earnings for display on a journey card (single price).
  /// Shows the small parcel price for consistency.
  static String getCardEarnings(Map<String, dynamic> data) {
    final small = data['price_small'];
    if (small != null) return formatSingle(small);
    final medium = data['price_medium'];
    if (medium != null) return formatSingle(medium);
    final large = data['price_large'];
    if (large != null) return formatSingle(large);
    return '₹--';
  }

  /// Get earnings text from display metadata or journey data.
  /// Used in confirm journey and detail pages.
  static String getEarningsFromDisplay(Map<String, dynamic> journeyData) {
    final display = journeyData['_display'] as Map<String, dynamic>?;
    final small = display?['earnings_small'] ?? journeyData['price_small'];
    final large = display?['earnings_large'] ?? journeyData['price_large'];
    if (small != null && large != null) {
      final smallVal = small is num ? small : num.tryParse(small.toString());
      final largeVal = large is num ? large : num.tryParse(large.toString());
      if (smallVal != null && largeVal != null && smallVal != largeVal) {
        return '${formatSingle(smallVal)} – ${formatSingle(largeVal)}';
      }
      return formatSingle(smallVal ?? largeVal);
    }
    final medium = display?['earnings_medium'] ?? journeyData['price_medium'];
    if (medium != null) return '${formatSingle(medium)}+';
    return '₹2,500+';
  }
}
