import 'package:flutter/material.dart';
import '../../core/services/digilocker_service.dart';
import 'express_dashboard_page.dart';

/// Shown when DigiLocker verification completes successfully via deep link.
/// Cannot be dismissed with back button — must tap "Continue".
class VerificationSuccessScreen extends StatefulWidget {
  final String userName;

  const VerificationSuccessScreen({super.key, required this.userName});

  @override
  State<VerificationSuccessScreen> createState() =>
      _VerificationSuccessScreenState();
}

class _VerificationSuccessScreenState
    extends State<VerificationSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _showContinue = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Show "Continue" button after 1.2s
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showContinue = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    // Refresh status from backend to confirm
    await DigiLockerService().getStatus();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ExpressDashboardPage()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated green checkmark
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF16A34A)
                                .withValues(alpha: 0.25),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF16A34A),
                        size: 64,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Faded-in text
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        const Text(
                          "Identity Verified!",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (widget.userName.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Welcome, ${widget.userName}",
                            style: const TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF27F0D),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          "Your identity has been securely verified\nvia DigiLocker",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Continue button (delayed appearance)
                  AnimatedOpacity(
                    opacity: _showContinue ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF27F0D),
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: const Color(0xFFF27F0D)
                              .withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _showContinue ? _handleContinue : null,
                        child: const Text(
                          "Continue",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
