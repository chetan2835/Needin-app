import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/auth_service.dart';
import 'otp_page.dart';
import '../../core/widgets/fade_slide_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
  bool _isLoading = false;

  void _sendOtp() async {
    final phoneText = _phoneController.text.trim();
    if (phoneText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    final phonePattern = RegExp(r'[^0-9]');
    final cleanPhone = phoneText.replaceAll(phonePattern, '');

    if (cleanPhone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleanPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid mobile number starting with 6-9')),
      );
      return;
    }

    final formattedPhone = "+91$cleanPhone";

    setState(() {
      _isLoading = true;
    });

    AuthService().verifyPhoneNumber(
      phoneNumber: formattedPhone,
      codeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        Navigator.push(context,
          MaterialPageRoute(
            builder: (_) => OtpPage(phoneNumber: formattedPhone),
          ),
        );
      },
      verificationFailed: (error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send OTP: $error')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // gray-50 roughly
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: FadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),

                    // Icon Container
                    Container(
                      width: 64, // w-16
                      height: 64, // h-16
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1E3), // primary-light
                        borderRadius: BorderRadius.circular(16), // 2xl
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.local_shipping,
                          color: Color(0xFFF27F0D), // primary
                          size: 36, // 4xl
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Welcome Text
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 30, // 3xl
                          fontWeight: FontWeight.w800, // extrabold
                          color: Color(0xFF0F172A), // slate-900
                          height: 1.25,
                        ),
                        children: [
                          TextSpan(text: "Welcome to "),
                          TextSpan(
                            text: "NEEDIN",
                            style: TextStyle(color: Color(0xFFF27F0D)), // primary
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Description text
                    const Text(
                      "Enter your phone number to continue exploring journeys and sending parcels.",
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        color: Color(0xFF64748B), // slate-500
                        height: 1.625,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Label "PHONE NUMBER"
                    const Text(
                      "PHONE NUMBER",
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12, // text-xs
                        fontWeight: FontWeight.w600, // semibold
                        color: Color(0xFF64748B), // slate-500
                        letterSpacing: 0.5, // tracking-wider
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Input Row
                    Row(
                      children: [
                        // Country Code Dropdown Fake
                        Container(
                          width: 90,
                          height: 56, // py-4
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC), // slate-50
                            borderRadius: BorderRadius.circular(12), // xl
                            border: Border.all(color: const Color(0xFFE2E8F0)), // slate-200
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "+91",
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0F172A), // slate-900
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: Color(0xFF64748B), // slate-500
                                size: 20,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Phone Input Field
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC), // slate-50
                              borderRadius: BorderRadius.circular(12), // xl
                              border: Border.all(color: const Color(0xFFE2E8F0)), // slate-200
                            ),
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0F172A), // slate-900
                              ),
                              decoration: const InputDecoration(
                                hintText: "000 000 0000",
                                hintStyle: TextStyle(
                                    color: Color(0xFFCBD5E1)), // slate-300
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Send OTP Button -> Login with MPIN
                    SizedBox(
                      width: double.infinity,
                      height: 56, // py-4
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF27F0D),
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor:
                              const Color(0xFFF27F0D).withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), // xl
                          ),
                        ),
                        onPressed: _isLoading ? null : _sendOtp,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Login with OTP",
                                    style: TextStyle(
                                      fontFamily: "Plus Jakarta Sans",
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.lock_outline, size: 20),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Terms text
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12, // text-xs
                              color: Color(0xFF94A3B8), // slate-400
                              height: 1.5,
                            ),
                            children: [
                              TextSpan(
                                  text: "By continuing, you agree to our "),
                              TextSpan(
                                text: "Terms of Service",
                                style: TextStyle(
                                    color: Color(0xFFF27F0D)), // primary
                              ),
                              TextSpan(text: " and\n"),
                              TextSpan(
                                text: "Privacy Policy",
                                style: TextStyle(
                                    color: Color(0xFFF27F0D)), // primary
                              ),
                              TextSpan(text: "."),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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