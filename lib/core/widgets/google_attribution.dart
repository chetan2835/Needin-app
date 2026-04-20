import 'package:flutter/material.dart';

/// Official Google Maps attribution widget.
/// REQUIRED by Google Maps Platform Terms of Service.
/// Must be shown at the bottom of any autocomplete results list.
class GoogleAttribution extends StatelessWidget {
  final bool useDarkLogo;

  const GoogleAttribution({
    super.key,
    this.useDarkLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use white logo on dark theme, dark logo on light theme
    final logoPath = (isDark || !useDarkLogo)
        ? 'assets/images/google/google_logo_white_2x.png'
        : 'assets/images/google/google_logo_dark_2x.png';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Image.asset(
          logoPath,
          height: 18,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
