import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/providers/user_profile_provider.dart';
import 'service_selection_page.dart';
import 'profile_setup_page.dart';

// ── Constants ────────────────────────────────────────────────────────────────
/// Maximum wrong OTP attempts before the user is forced to resend.
const int _kMaxWrongAttempts = 5;

/// Resend cooldown in seconds.
const int _kResendCooldownSeconds = 30;

class OtpPage extends StatefulWidget {
  /// Display string shown to user, e.g. "+916367445454"
  final String phoneNumber;

  /// Raw 10-digit phone number without country code, e.g. "6367445454"
  final String phone10;

  /// Request ID returned by MSG91 sendOTP. Used for verifyOTP and retryOTP.
  final String reqId;

  final bool isReset;

  const OtpPage({
    super.key,
    required this.phoneNumber,
    required this.phone10,
    required this.reqId,
    this.isReset = false,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  List<String> otpDigits = ["", "", "", "", "", ""];
  int currentIndex = 0;

  // ── State flags ────────────────────────────────────────────────────────────
  bool _isVerifying = false;   // blocks duplicate verify taps
  bool _isResending = false;   // blocks duplicate resend taps
  bool _isBlocked = false;     // true after _kMaxWrongAttempts failures

  // Current reqId — may change after retry
  late String _reqId;

  // Wrong attempt counter
  int _wrongAttempts = 0;

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Resend countdown timer
  int _resendSeconds = _kResendCooldownSeconds;
  Timer? _resendTimer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _reqId = widget.reqId;
    debugPrint('====================================================');
    debugPrint('MSG91_TRACE: OTP PAGE RECEIVED REQID: $_reqId');
    _startResendTimer();
  }

  void _startResendTimer() {
    setState(() {
      _resendSeconds = _kResendCooldownSeconds;
      _canResend = false;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── Verify OTP ─────────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (currentIndex < 6) {
      _showSnack('Please enter the complete 6-digit code.');
      return;
    }

    // Guard: already verifying
    if (_isVerifying) return;

    // Guard: blocked after too many wrong attempts
    if (_isBlocked) {
      _showSnack(
        'Too many incorrect attempts. Please request a new OTP.',
        error: true,
      );
      return;
    }

    // Guard: empty reqId — OTP session was never initialized
    // This should NOT happen if login_page reqId guard is working correctly.
    if (_reqId.isEmpty) {
      debugPrint('OTP_PAGE: ❌ _verifyOtp called with empty _reqId — login_page guard may have failed!');
      _showSnack(
        'OTP session not found. Please go back and request a new OTP.',
        error: true,
      );
      return;
    }

    setState(() { _isVerifying = true; });

    final otp = otpDigits.join();

    try {
      final userId = await AuthService().verifyOTP(
        reqId: _reqId,
        otp: otp,
        phone10: widget.phone10,
      );

      if (!mounted) return;

      if (userId != null) {
        // Reset state — OTP correct
        setState(() {
          _isVerifying = false;
          _wrongAttempts = 0;
        });
        await _onOtpVerified(userId);
      } else {
        _wrongAttempts++;
        final remaining = _kMaxWrongAttempts - _wrongAttempts;

        if (!mounted) return;
        setState(() { _isVerifying = false; });

        if (_wrongAttempts >= _kMaxWrongAttempts) {
          // Block further attempts — force resend
          setState(() { _isBlocked = true; });
          _showSnack(
            'Too many incorrect attempts. Please request a new OTP.',
            error: true,
          );
        } else {
          _showSnack(
            'Incorrect code. $remaining attempt${remaining == 1 ? "" : "s"} remaining.',
            error: true,
          );
        }

        // Clear digits so user can re-enter
        _otpController.clear();
        setState(() {
          otpDigits = ["", "", "", "", "", ""];
          currentIndex = 0;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _isVerifying = false; });
      _showSnack('An error occurred. Please try again.', error: true);
    }
  }

  // ── Profile Lookup & Navigation ────────────────────────────────────────────
  Future<void> _onOtpVerified(String userId) async {
    final formattedPhone = widget.phoneNumber; // '+916367445454'

    // Try to load existing profile (returning user)
    try {
      Map<String, dynamic>? profile;

      // Primary: look up by firebase_uid (= phone-as-uid)
      try {
        final rows = await SupabaseService().client
            .rpc('get_profile_by_firebase_uid', params: {'p_firebase_uid': userId});
        if (rows != null && rows is List && rows.isNotEmpty) {
          profile = Map<String, dynamic>.from(rows.first as Map);
        }
      } catch (_) {}

      // Fallback: look up by phone number (covers pre-migration profiles)
      if (profile == null) {
        try {
          final rows = await SupabaseService().client
              .rpc('get_profile_by_phone', params: {'p_phone': formattedPhone});
          if (rows != null && rows is List && rows.isNotEmpty) {
            profile = Map<String, dynamic>.from(rows.first as Map);
          }
        } catch (_) {}
      }

      if (profile != null) {
        // ── RETURNING USER ────────────────────────────────────────────────────
        await LocalStorageService.saveUserSession(
          userId: userId,
          fullName: profile['full_name']?.toString() ?? '',
          phone: formattedPhone,
          photoUrl: profile['profile_image_url']?.toString() ??
              profile['avatar_url']?.toString(),
          role: profile['role']?.toString() ?? 'user',
        );

        // Link firebase_uid if profile was found by phone (fire-and-forget)
        SupabaseService().client.rpc('upsert_profile_by_firebase_uid', params: {
          'p_firebase_uid': userId,
          'p_phone': formattedPhone,
        }).catchError((_) {});

        if (!mounted) return;
        final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
        await profileProvider.loadProfile();

        if (!mounted) return;
        _showWelcomeBackDialog();
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        Navigator.pop(context); // pop dialog

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ServiceSelectionPage()),
          (route) => false,
        );
        return;
      }
    } catch (e) {
      debugPrint('OTP_PAGE: Profile lookup error: ${e.runtimeType}');
    }

    if (!mounted) return;

    // ── NEW USER ──────────────────────────────────────────────────────────────
    await LocalStorageService.saveUserSession(
      userId: userId,
      fullName: '',
      phone: formattedPhone,
      role: 'user',
    );

    // Create profile stub so phone is linked from the start (fire-and-forget)
    SupabaseService().client.rpc('upsert_profile_by_firebase_uid', params: {
      'p_firebase_uid': userId,
      'p_phone': formattedPhone,
    }).catchError((e) {
      debugPrint('OTP_PAGE: Could not create profile stub: ${e.runtimeType}');
    });

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ProfileSetupPage()),
      (route) => false,
    );
  }

  // ── Resend OTP ─────────────────────────────────────────────────────────────
  Future<void> _resendOtp() async {
    // Guard: timer not elapsed
    if (!_canResend) return;

    // Guard: already in-flight
    if (_isResending) return;

    setState(() { _isResending = true; });

    final result = await AuthService().retryOTP(widget.phone10, reqId: _reqId);

    if (!mounted) return;
    setState(() { _isResending = false; });

    if (result.success) {
      if (result.reqId != null && result.reqId!.isNotEmpty) {
        _reqId = result.reqId!;
      }
      // Reset attempt counter on successful resend
      setState(() {
        _wrongAttempts = 0;
        _isBlocked = false;
      });
      _startResendTimer();
      _showSnack('OTP resent successfully.');
    } else {
      _showSnack(
        result.errorMessage ?? 'Failed to resend OTP. Please try again.',
        error: true,
      );
    }
  }

  // ── UI Helpers ─────────────────────────────────────────────────────────────
  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFEF4444) : null,
      ),
    );
  }

  void _showWelcomeBackDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 64),
            SizedBox(height: 16),
            Text(
              'Welcome Back!',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Loading your profile...',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              /// Back Arrow
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                "Verify Phone",
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  height: 1.25,
                ),
              ),

              const SizedBox(height: 12),

              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    height: 1.625,
                  ),
                  children: [
                    const TextSpan(text: "Enter the 6-digit code sent to\n"),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              /// OTP Boxes
              Stack(
                children: [
                  Positioned.fill(
                    child: TextField(
                      controller: _otpController,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      showCursor: false,
                      enabled: !_isVerifying && !_isBlocked,
                      style: const TextStyle(color: Colors.transparent),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                      ),
                      onChanged: (value) {
                        setState(() {
                          for (int i = 0; i < 6; i++) {
                            otpDigits[i] = i < value.length ? value[i] : "";
                          }
                          currentIndex = value.length;
                        });
                        if (value.length == 6 && !_isVerifying && !_isBlocked) {
                          _verifyOtp();
                        }
                      },
                    ),
                  ),
                  IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        final isFocused = index == currentIndex && !_isBlocked;
                        return Container(
                          width: 48,
                          height: 58,
                          decoration: BoxDecoration(
                            color: _isBlocked
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isBlocked
                                  ? const Color(0xFFEF4444)
                                  : isFocused
                                      ? const Color(0xFFF05A4F)
                                      : const Color(0xFFE2E8F0),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              otpDigits[index],
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Attempt warning
              if (_wrongAttempts > 0 && !_isBlocked)
                Center(
                  child: Text(
                    '${_kMaxWrongAttempts - _wrongAttempts} attempt${_kMaxWrongAttempts - _wrongAttempts == 1 ? "" : "s"} remaining',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      color: Color(0xFFF97316),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              /// Resend section
              Center(
                child: _canResend
                    ? GestureDetector(
                        onTap: _isResending ? null : _resendOtp,
                        child: _isResending
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFF05A4F),
                                ),
                              )
                            : const Text(
                                "Resend Code",
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF05A4F),
                                ),
                              ),
                      )
                    : RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                          children: [
                            const TextSpan(text: "Resend code in "),
                            TextSpan(
                              text: "0:${_resendSeconds.toString().padLeft(2, '0')}",
                              style: const TextStyle(color: Color(0xFFF05A4F)),
                            ),
                          ],
                        ),
                      ),
              ),

              const Spacer(),

              /// Verify & Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isBlocked
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFFF05A4F),
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: const Color(0xFFF37A72),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  onPressed: (_isVerifying || _isBlocked) ? null : _verifyOtp,
                  child: _isVerifying
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isBlocked ? "Request New OTP" : "Verify & Continue",
                          style: const TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
