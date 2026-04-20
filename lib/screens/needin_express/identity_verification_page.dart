import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/digilocker_service.dart';

/// Identity Verification entry screen.
/// Opens real DigiLocker OAuth2 in external browser — zero fake UI.
class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({super.key});

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends State<IdentityVerificationPage>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _isAlreadyVerified = false;
  bool _isServiceAvailable = true; // Controls "credentials pending" banner

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final status = await DigiLockerService().getStatus();
    if (mounted) {
      setState(() {
        _isAlreadyVerified = status.isVerified;
        _isServiceAvailable = status.isServiceAvailable;
      });
    }
  }

  Future<void> _startVerification() async {
    setState(() => _isLoading = true);
    try {
      final url = await DigiLockerService().initiateVerification();
      final uri = Uri.parse(url);

      if (!await canLaunchUrl(uri)) {
        _showError('Could not open DigiLocker. Please try again.');
        return;
      }

      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on DigiLockerException catch (e) {
      if (e.message == 'already_verified') {
        setState(() => _isAlreadyVerified = true);
      } else {
        _showError(e.message);
      }
    } catch (e) {
      _showError('Unable to connect. Please try again.');
    } finally {
      // ALWAYS reset loading state — never leave spinner stuck
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context, _isAlreadyVerified),
        ),
        title: const Text(
          "Identity Verification",
          style: TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: _isAlreadyVerified
            ? _buildVerifiedState()
            : _buildVerifyPrompt(),
      ),
      bottomNavigationBar: _isAlreadyVerified
          ? null
          : Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                border: const Border(
                  top: BorderSide(color: Color(0xFFF1F5F9)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
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
                    onPressed: _isLoading ? null : _startVerification,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_user,
                                  size: 20, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Verify with DigiLocker",
                                style: TextStyle(
                                  fontFamily: "Plus Jakarta Sans",
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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

  // ── Credentials pending banner ─────────────────────────────
  Widget _buildPendingBanner() {
    if (_isServiceAvailable) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // amber-100
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)), // amber-200
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "DigiLocker integration coming soon — credentials pending setup",
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF92400E), // amber-800
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Already-verified inline state ──────────────────────────
  Widget _buildVerifiedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.verified,
                    color: Color(0xFF16A34A), size: 48),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Identity Verified",
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your identity has been verified via DigiLocker.\nNo further action is needed.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF27F0D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Back to Profile",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main verification prompt ───────────────────────────────
  Widget _buildVerifyPrompt() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Credentials pending banner (auto-hides when service is available)
          _buildPendingBanner(),
          if (!_isServiceAvailable) const SizedBox(height: 16),

          // DigiLocker shield icon
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF27F0D).withValues(alpha: 0.15),
                  const Color(0xFFF27F0D).withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield,
              color: Color(0xFFF27F0D),
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Verify Your Identity",
            style: TextStyle(
              fontFamily: "Plus Jakarta Sans",
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "One-time verification using your DigiLocker account",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Plus Jakarta Sans",
              fontSize: 16,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 40),

          _buildFeatureBullet(
            Icons.fingerprint,
            "Aadhaar-based Authentication",
            "Securely verify with your Aadhaar linked to DigiLocker",
          ),
          const SizedBox(height: 12),
          _buildFeatureBullet(
            Icons.account_balance,
            "Government of India Verified",
            "Powered by MeitY — Ministry of Electronics & IT",
          ),
          const SizedBox(height: 12),
          _buildFeatureBullet(
            Icons.lock,
            "100% Secure — No Data on Device",
            "Your documents never leave DigiLocker servers",
          ),
          const SizedBox(height: 12),
          _buildFeatureBullet(
            Icons.speed,
            "Instant Verification",
            "Verified in under 60 seconds with real-time processing",
          ),

          const SizedBox(height: 40),

          // How it works
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "How it works",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                _buildStep("1", "Tap \"Verify with DigiLocker\" below"),
                const SizedBox(height: 12),
                _buildStep("2", "Sign in to your DigiLocker account in browser"),
                const SizedBox(height: 12),
                _buildStep("3", "Grant consent to share your identity document"),
                const SizedBox(height: 12),
                _buildStep("4", "Return to Needin — verification complete!"),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            "🔒 Powered by DigiLocker · Ministry of Electronics & IT",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Plus Jakarta Sans",
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBullet(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFF27F0D), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF27F0D),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: "Plus Jakarta Sans",
              fontSize: 14,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }
}
