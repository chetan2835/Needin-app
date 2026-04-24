import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/supabase_service.dart';
import '../auth/set_new_mpin_screen.dart';
import '../onboarding/account_details_screen.dart';

class OtpPage extends StatefulWidget {
  final String phoneNumber;

  const OtpPage({super.key, required this.phoneNumber});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  // Store the 6 digits
  List<String> otpDigits = ["", "", "", "", "", ""];
  int currentIndex = 0;
  bool _isLoading = false;

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (currentIndex < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter 6 digit code')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final otp = otpDigits.join();
    String? userId;
    
    if (kDebugMode && (defaultTargetPlatform == TargetPlatform.windows || 
                       defaultTargetPlatform == TargetPlatform.macOS || 
                       defaultTargetPlatform == TargetPlatform.linux)) {
      // Bypass Firebase Auth for desktop mock
      await Future.delayed(const Duration(seconds: 1)); // Simulate network
      userId = "mock-desktop-user-id";
    } else {
      final userCredential = await AuthService().verifyOTP(otp);
      userId = userCredential?.user?.uid;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (userId != null) {
      final profile = await SupabaseService().getUserProfile(userId);
      if (!mounted) return;

      if (profile == null) {
        // Profile does not exist (registration was incomplete)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AccountDetailsScreen()),
          (route) => false,
        );
      } else {
        // Profile exists, proceed to set new MPIN (or login)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SetNewMpinScreen(
              userId: userId!,
              phoneNumber: widget.phoneNumber,
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP or verification failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // gray-50
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              /// Back Arrow Header
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)), // slate-200
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back,
                      color: Color(0xFF0F172A), // slate-900
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              /// Title
              const Text(
                "Verify Phone",
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 30, // 3xl
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A), // slate-900
                  height: 1.25,
                ),
              ),

              const SizedBox(height: 12),

              /// Description
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    color: Color(0xFF64748B), // slate-500
                    height: 1.625,
                  ),
                  children: [
                    const TextSpan(text: "Enter the 6-digit code sent to\n"),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600, // semibold
                        color: Color(0xFF0F172A), // slate-900
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
                        if (value.length == 6) {
                          _verifyOtp();
                        }
                      },
                    ),
                  ),
                  IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        bool isFocused = index == currentIndex;
                        return Container(
                          width: 48, // slightly smaller to fit 6 on screen
                          height: 58, 
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC), // slate-50
                            borderRadius: BorderRadius.circular(12), // rounded-xl
                            border: Border.all(
                              color: isFocused
                                  ? const Color(0xFFF27F0D) // primary edge
                                  : const Color(0xFFE2E8F0), // slate-200
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              otpDigits[index],
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 24, // 2xl
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A), // slate-900
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              /// Resend Code text
              Center(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16, // base
                      fontWeight: FontWeight.w500, // medium
                      color: Color(0xFF64748B), // slate-500
                    ),
                    children: [
                      TextSpan(text: "Resend code in "),
                      TextSpan(
                        text: "0:29",
                        style: TextStyle(color: Color(0xFFF27F0D)), // primary
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              /// Verify & Continue Button
              SizedBox(
                width: double.infinity,
                height: 56, // py-4
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF27F0D),
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: const Color(0xFFFBD38D), // orange-200 roughly
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32), // full
                    ),
                  ),
                  onPressed: _isLoading ? null : _verifyOtp,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Verify & Continue",
                          style: TextStyle(
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
