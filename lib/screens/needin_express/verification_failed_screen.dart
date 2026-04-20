import 'package:flutter/material.dart';

/// Shown when DigiLocker verification fails via deep link.
/// Maps failure reasons to human-readable messages.
class VerificationFailedScreen extends StatelessWidget {
  final String reason;

  const VerificationFailedScreen({super.key, required this.reason});

  String get _message {
    switch (reason) {
      case 'consent_denied':
        return 'You cancelled the DigiLocker verification.';
      case 'invalid_state':
        return 'This session is no longer valid. Please try again.';
      case 'session_expired':
        return 'Session timed out. Please try again.';
      case 'token_exchange_failed':
        return 'Verification failed. Please try again.';
      case 'database_error':
        return 'A server error occurred. Please try again.';
      case 'invalid_request':
        return 'Invalid request. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Color(0xFFDC2626),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  "Verification Failed",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),

                // Try Again
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF27F0D),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor:
                          const Color(0xFFF27F0D).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Try Again",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Skip for Now
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // Pop back to profile
                      Navigator.popUntil(
                          context, (route) => route.isFirst);
                    },
                    child: const Text(
                      "Skip for Now",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
