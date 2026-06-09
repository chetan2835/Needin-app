import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UIUtils {
  static String formatJourneyDateTime(String? isoDateString) {
    if (isoDateString == null || isoDateString.isEmpty) return 'Not selected';
    try {
      final dt = DateTime.parse(isoDateString).toLocal();
      String day = _getOrdinalDay(dt.day);
      String monthYearTime = DateFormat("MMMM yyyy, hh:mm a").format(dt);
      return "$day $monthYearTime";
    } catch (e) {
      return isoDateString; // Fallback
    }
  }

  static String _getOrdinalDay(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1: return '${day}st';
      case 2: return '${day}nd';
      case 3: return '${day}rd';
      default: return '${day}th';
    }
  }
  // Colors
  static const Color primary = Color(0xFFF05A4F);
  static const Color secondary = Color(0xFF1E293B);
  static const Color background = Color(0xFFFAFAFA);
  static const Color cardBg = Colors.white;
  static const Color textMain = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);

  // Common Border Radius
  static BorderRadius radiusM = BorderRadius.circular(12);
  static BorderRadius radiusL = BorderRadius.circular(16);
  static BorderRadius radiusXL = BorderRadius.circular(24);

  // SnackBars
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(context, message, success);
  }

  static void showError(BuildContext context, String message) {
    _showSnackBar(context, message, error);
  }

  static void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radiusM),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Loading Overlay
  static Widget loadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        color: primary,
        strokeWidth: 3,
      ),
    );
  }
}
