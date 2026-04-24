import 'package:flutter/material.dart';

class UIUtils {
  // Colors
  static const Color primary = Color(0xFFF27F0D);
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
