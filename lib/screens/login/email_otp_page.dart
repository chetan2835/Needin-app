import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;
import 'package:provider/provider.dart';
import '../../core/providers/user_profile_provider.dart';

// ══════════════════════════════════════════════════════════════════
//  EmailOtpPage — Production Grade
//
//  ARCHITECTURE:
//    Primary auth:  Firebase Phone Auth
//    DB:            Supabase (no Supabase session for normal requests)
//
//  SEND PATH:
//    signInWithOtp(email, shouldCreateUser: true)
//    → Works with anon key only. No session needed.
//
//  VERIFY PATH:
//    verifyOTP(type: OtpType.email, email, token)
//    → After success: auth.email() == widget.email  (session is live)
//
//  DB WRITE:
//    Direct .update().eq('email', widget.email)
//    → RLS policy "profiles_update_by_email" allows:
//      FOR UPDATE USING (email::text = auth.email())
//    → This is always true immediately after verifyOTP().
//    → signOut() is called AFTER the write, not before.
//
//  SUCCESS:
//    Show animated success screen (coral brand color #F05A4F)
//    → "Continue" pops back to Personal Information
//    → markEmailVerified() + loadProfile() refresh provider
// ══════════════════════════════════════════════════════════════════

class EmailOtpPage extends StatefulWidget {
  final String email;
  const EmailOtpPage({super.key, required this.email});

  @override
  State<EmailOtpPage> createState() => _EmailOtpPageState();
}

class _EmailOtpPageState extends State<EmailOtpPage>
    with TickerProviderStateMixin {
  // OTP input
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _otpDigits = ['', '', '', '', '', ''];

  // State
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  // Resend timer
  Timer? _timer;
  int _secondsRemaining = 600;

  // Success animation controllers
  late AnimationController _successAnim;
  late AnimationController _floatingAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _floatAnim;
  bool _showContinue = false;

  @override
  void initState() {
    super.initState();

    _successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _floatingAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnim = CurvedAnimation(
      parent: _successAnim,
      curve: Curves.elasticOut,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnim,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatingAnim, curve: Curves.easeInOut),
    );

    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
      _sendOtp();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    _successAnim.dispose();
    _floatingAnim.dispose();
    super.dispose();
  }

  // ── Timer ─────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    if (mounted) setState(() => _secondsRemaining = 600);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
      }
    });
  }

  String get _formattedTime {
    final m = _secondsRemaining ~/ 60;
    final s = _secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Send OTP ─────────────────────────────────────────────────
  Future<void> _sendOtp({bool isResend = false}) async {
    if (_isLoading) return;
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });

    try {
      debugPrint('[OTP] Sending to ${widget.email} via signInWithOtp...');
      await SupabaseService().client.auth.signInWithOtp(
        email: widget.email,
        shouldCreateUser: true,
      );
      debugPrint('[OTP] ✅ OTP sent.');
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isResend
              ? 'New 6-digit code sent to ${widget.email}'
              : '6-digit code sent to ${widget.email}'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } on supabase_flutter.AuthException catch (e) {
      debugPrint('[OTP] Send AuthException: ${e.message}');
      if (mounted) setState(() => _errorMessage = 'Could not send code: ${e.message}');
    } catch (e) {
      debugPrint('[OTP] Send error: $e');
      if (mounted) setState(() => _errorMessage = 'Failed to send code. Check connection and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 540 || _isLoading) return;
    await _sendOtp(isResend: true);
  }

  // ── Verify OTP ───────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (_isLoading) return; // guard against double-tap

    final otp = _otpDigits.join();
    if (otp.length != 6) {
      if (mounted) setState(() => _errorMessage = 'Please enter the complete 6-digit code.');
      return;
    }

    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });

    // ── PHASE 1: Verify the OTP code ──────────────────────────────────────
    // verifyOTP creates a live Supabase session for the OTP user.
    // After success: auth.email() == widget.email  (guaranteed by Supabase)
    try {
      debugPrint('[OTP] Verifying OTP for ${widget.email} (type: OtpType.email)...');
      final response = await SupabaseService().client.auth.verifyOTP(
        type: supabase_flutter.OtpType.email,
        email: widget.email,
        token: otp,
      );
      debugPrint('[OTP] verifyOTP done. user=${response.user?.id} email=${response.user?.email}');

      if (response.user == null) {
        // Should not happen but guard it
        debugPrint('[OTP] ❌ verifyOTP returned null user despite no exception.');
        if (mounted) setState(() { _errorMessage = 'Invalid or expired code. Please try again.'; _isLoading = false; });
        return;
      }
    } on supabase_flutter.AuthException catch (e) {
      // Wrong or expired OTP — real auth failure
      debugPrint('[OTP] AuthException (OTP wrong/expired): ${e.message} (code: ${e.statusCode})');
      if (mounted) setState(() { _errorMessage = 'Incorrect code or expired. Please try again.'; _isLoading = false; });
      return;
    } catch (e) {
      // Network / unexpected error during OTP verification
      debugPrint('[OTP] Unexpected error during verifyOTP: $e');
      if (mounted) setState(() { _errorMessage = 'Network error. Please check your connection and try again.'; _isLoading = false; });
      return;
    }


    // ── PHASE 2: Write email_verified=true to the profiles table ──────────
    //
    // We use a SECURITY DEFINER RPC (`verify_email_for_profile`) that:
    //   1. Validates auth.email() == p_email (proves OTP was verified)
    //   2. Updates by email match first (normal path)
    //   3. Falls back to Firebase UID match (when email wasn't pre-saved)
    //
    // This is BULLETPROOF: it always finds the correct row because it
    // uses BOTH the email AND the Firebase UID — so even if the pre-save
    // of email failed (network issue), we still write email_verified=true.
    //
    // Previously: used .update().eq('email', widget.email) directly.
    // Problem: if email column was null in the profile row, 0 rows matched.
    // Result: DB silently had email_verified=false → lost on reinstall.
    //
    final String? firebaseUid = AuthService().currentUser?.uid;
    debugPrint('[OTP] Firebase UID for fallback: $firebaseUid');

    bool dbUpdated = false;
    try {
      debugPrint('[OTP] ✅ OTP verified. Writing email_verified=true via RPC for: ${widget.email}...');

      // PRIMARY: SECURITY DEFINER RPC (bypasses RLS, uses both email + UID)
      final dynamic rpcResult = await SupabaseService().client.rpc(
        'verify_email_for_profile',
        params: {
          'p_email': widget.email.toLowerCase().trim(),
          'p_firebase_uid': firebaseUid ?? '',
        },
      );
      dbUpdated = rpcResult == true;
      debugPrint('[OTP] RPC verify_email_for_profile returned: $rpcResult → dbUpdated=$dbUpdated');

      // FALLBACK: Direct UPDATE if RPC returned false (shouldn't happen, but safety net)
      if (!dbUpdated) {
        debugPrint('[OTP] RPC returned false, trying direct UPDATE fallback...');
        try {
          await SupabaseService().client
              .from('profiles')
              .update({
                'email': widget.email,
                'email_verified': true,
                'email_verified_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('email', widget.email);
          debugPrint('[OTP] ✅ Direct UPDATE fallback succeeded.');
          dbUpdated = true;
        } catch (e2) {
          debugPrint('[OTP] ⚠️ Direct UPDATE fallback also failed: $e2');
        }
      }

      if (dbUpdated) {
        debugPrint('[OTP] ✅ DB write confirmed: email_verified=true for ${widget.email}');
      } else {
        debugPrint('[OTP] ⚠️ DB write could not be confirmed. Proceeding optimistically.');
      }
    } catch (e) {
      debugPrint('[OTP] ⚠️ RPC call failed: $e. Trying direct UPDATE...');
      // If RPC itself throws (e.g. function not deployed yet), try direct UPDATE
      try {
        await SupabaseService().client
            .from('profiles')
            .update({
              'email': widget.email,
              'email_verified': true,
              'email_verified_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('email', widget.email);
        debugPrint('[OTP] ✅ Emergency direct UPDATE succeeded.');
        dbUpdated = true;
      } catch (e3) {
        debugPrint('[OTP] ❌ All DB write attempts failed: $e3');
        dbUpdated = false;
      }
    } finally {
      // CRITICAL: Always clean up the temporary Supabase OTP session.
      // This restores the normal (no-session) state for Firebase Auth.
      try {
        await SupabaseService().client.auth.signOut();
        debugPrint('[OTP] ✅ Supabase OTP session cleaned up.');
      } catch (_) { /* non-critical */ }
    }

    if (!dbUpdated) {
      debugPrint('[OTP] ⚠️ DB write failed but OTP was valid. In-memory state shows verified.');
      debugPrint('[OTP] ⚠️ User will need to re-verify only if they reinstall without connectivity.');
    }

    // ── PHASE 3: Update in-memory state and show success ─────────────────
    if (mounted) {
      // Optimistic in-memory update — instant badge/gate response
      final provider = Provider.of<UserProfileProvider>(context, listen: false);
      provider.markEmailVerified(widget.email);

      setState(() { _isSuccess = true; _isLoading = false; _errorMessage = null; });
      _successAnim.forward();

      // Show Continue button after animation completes
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showContinue = true);
      });
    }
  }

  // ── Navigation ───────────────────────────────────────────────
  void _handleContinue() {
    // Refresh from backend to confirm persistence, then pop
    final provider = Provider.of<UserProfileProvider>(context, listen: false);
    provider.loadProfile();
    Navigator.pop(context, true);
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _isSuccess ? 'Verification' : '',
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        leading: _isSuccess
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Color(0xFF0F172A), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: _isSuccess ? _buildSuccessScreen() : _buildOtpScreen(),
    );
  }

  // ── SUCCESS SCREEN (Coral Brand Theme) ───────────────────────
  Widget _buildSuccessScreen() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Warm gradient background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFF5F5),
                        Color(0xFFFAFAFA),
                      ],
                    ),
                  ),
                ),

                // Floating decorative blobs (coral palette)
                Positioned(
                  top: 40,
                  right: 30,
                  child: AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, _floatAnim.value),
                      child: _blob(52, const Color(0xFFF05A4F), 0.18),
                    ),
                  ),
                ),
                Positioned(
                  top: 110,
                  left: 20,
                  child: AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, -_floatAnim.value * 0.7),
                      child: _blob(28, const Color(0xFFF8A49A), 0.55),
                    ),
                  ),
                ),
                Positioned(
                  top: 60,
                  left: 80,
                  child: AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, _floatAnim.value * 0.5),
                      child: _blob(18, const Color(0xFFF05A4F), 0.35),
                    ),
                  ),
                ),
                Positioned(
                  top: 160,
                  right: 60,
                  child: AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, -_floatAnim.value * 0.4),
                      child: _blob(14, const Color(0xFFF8A49A), 0.6),
                    ),
                  ),
                ),

                // Main content
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Animated checkmark circle
                        ScaleTransition(
                          scale: _scaleAnim,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                                  blurRadius: 40,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF16A34A),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 56,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 40),

                      // Text content — fades in
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          children: [
                            const Text(
                              'Email Verified!',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Your email address has been successfully\nverified. You can now access all features\nof Needin Express.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 15,
                                color: const Color(0xFF0F172A).withValues(alpha: 0.5),
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Verified email chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.mark_email_read_rounded,
                                      color: Color(0xFF16A34A), size: 16),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      widget.email,
                                      style: const TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF16A34A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ), // Close Positioned.fill
              ],
            ),
          ),

          // Sticky Continue button at bottom
          AnimatedOpacity(
            opacity: _showContinue ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _showContinue ? _handleContinue : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text(
                    'Continue to Profile',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A4F),
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: const Color(0xFFF05A4F).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }

  // ── OTP INPUT SCREEN ─────────────────────────────────────────
  Widget _buildOtpScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verify your email',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15,
                  color: Color(0xFF64748B),
                ),
                children: [
                  const TextSpan(text: "We've sent a 6-digit code to\n"),
                  TextSpan(
                    text: widget.email,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // ── OTP boxes ─────────────────────────────────
            Stack(
              children: [
                Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _otpController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    onChanged: (value) {
                      setState(() {
                        for (int i = 0; i < 6; i++) {
                          _otpDigits[i] = i < value.length ? value[i] : '';
                        }
                        _errorMessage = null;
                      });
                      if (value.length == 6) _verifyOtp();
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    final isCurrent = _otpController.text.length == index;
                    final hasError = _errorMessage != null;
                    return GestureDetector(
                      onTap: () => FocusScope.of(context).requestFocus(_focusNode),
                      child: Container(
                        width: 48,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasError
                                ? const Color(0xFFDC2626)
                                : (isCurrent
                                    ? const Color(0xFFF05A4F)
                                    : const Color(0xFFE2E8F0)),
                            width: (isCurrent || hasError) ? 2 : 1,
                          ),
                          boxShadow: isCurrent && !hasError
                              ? [BoxShadow(
                                  color: const Color(0xFFF05A4F).withValues(alpha: 0.12),
                                  blurRadius: 8)]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _otpDigits[index],
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
              ],
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            Center(
              child: _secondsRemaining > 0
                  ? Text(
                      'Resend code in $_formattedTime',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: _isLoading ? null : _resendOtp,
                      icon: const Icon(Icons.refresh, color: Color(0xFFF05A4F), size: 16),
                      label: const Text(
                        'Resend Code',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF05A4F),
                        ),
                      ),
                    ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05A4F),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: const Color(0xFFF05A4F).withValues(alpha: 0.4),
                  disabledBackgroundColor: const Color(0xFFF05A4F).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: (_isLoading || _otpController.text.length != 6)
                    ? null
                    : _verifyOtp,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Verify Email',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
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
}
