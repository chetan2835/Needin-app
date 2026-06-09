import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../screens/needin_express/personal_info_page.dart';
import '../providers/user_profile_provider.dart';

class EmailVerificationGate extends StatelessWidget {
  final Widget child;
  final String actionDescription; // e.g., 'post a journey', 'book a traveler'

  const EmailVerificationGate({
    super.key,
    required this.child,
    required this.actionDescription,
  });

  void _showVerificationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VerificationBottomSheet(actionDescription: actionDescription),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, provider, _) {
        if (provider.isEmailVerified) {
          // If verified, render the child normally
          return child;
        }

        // If not verified, intercept taps
        return GestureDetector(
          onTap: () => _showVerificationBottomSheet(context),
          // We use AbsorbPointer to prevent child taps from executing
          child: AbsorbPointer(
            absorbing: true,
            child: child,
          ),
        );
      },
    );
  }
}

class _VerificationBottomSheet extends StatelessWidget {
  final String actionDescription;

  const _VerificationBottomSheet({required this.actionDescription});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_unread_outlined,
                color: Color(0xFFF05A4F),
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Verify Your Email",
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "You need to verify your email address before you can $actionDescription. This helps keep Needin a safe and trusted community.",
              style: const TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PersonalInfoPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05A4F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  "Verify Email Now",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Maybe Later",
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
    );
  }
}
