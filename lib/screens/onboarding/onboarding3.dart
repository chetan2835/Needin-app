import 'package:flutter/material.dart';
import '../../core/widgets/fade_slide_in.dart';
import 'account_details_screen.dart';

class Onboarding3 extends StatelessWidget {
  const Onboarding3({super.key});

  Future<void> finishOnboarding(BuildContext context) async {
    if (context.mounted) {
      // Navigate to Account Details Screen instead of Login Page
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const AccountDetailsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5), // background-light
      body: SafeArea(
        child: Column(
          children: [
            /// Skip Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => finishOnboarding(context),
                  child: const Text(
                    "Skip",
                    style: TextStyle(
                      color: Color(0xFF8A7560), // text-secondary
                      fontSize: 14, // text-sm
                      fontWeight: FontWeight.bold,
                      fontFamily: "Plus Jakarta Sans",
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: FadeSlideIn(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          /// Illustration Area
                          SizedBox(
                            height: 320,
                            width: double.infinity,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Abstract Background Blob
                                Container(
                                  width: 256,
                                  height: 256,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
                                        blurRadius: 80,
                                        spreadRadius: 30,
                                      ),
                                    ],
                                  ),
                                ),
                                // Image container
                                Container(
                                  width: 320,
                                  height: 320,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFF3F4F6),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 2,
                                      ),
                                    ],
                                    image: const DecorationImage(
                                      image: NetworkImage(
                                        "https://lh3.googleusercontent.com/aida-public/AB6AXuDTpWikkQygLVt-YZUtZMTptcKpGmLDjkKxxLb7nyG4G3eVlDSmPj2PqIr7BExIp5XFolLryzaEcIN5skKaZj3ss6aa13koBOOF7su-iJdol8gh4yIfplpQgBk_q-op8NDvt53UxPxJMdVhcwd3pTTibYE8RCrw5P-ETgrw8Q_1qrcgGT-d53vGbwUM6Sy9yUvqxAJjjsuCBPrfaVcT9CYL67DPjN_UMrMaO8E2j9Xd52emcJ_sZZ99SQSl1v-egLe_CkYsYAX3UQ",
                                      ),
                                      fit: BoxFit.cover,
                                      opacity: 0.9,
                                    ),
                                  ),
                                ),
                                // Overlay Gradient & Icon
                                Container(
                                  width: 320,
                                  height: 320,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.8),
                                        Colors.transparent,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFF8F7F5),
                                          width: 4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.1),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.verified_user,
                                        color: Color(0xFFF27F0D),
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Typography
                          const Text(
                            "Secure & Verified",
                            style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF181411),
                              height: 1.25,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),

                          SizedBox(
                            width: 280,
                            child: const Text(
                              "Every traveler and sender is verified to ensure a safe community for everyone.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 16,
                                color: Color(0xFF8A7560),
                                height: 1.625,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            /// Footer / Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  // Pagination Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 6,
                        width: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB), // gray-300
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 6,
                        width: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 6,
                        width: 32, // Active Indicator
                        decoration: BoxDecoration(
                          color: const Color(0xFFF27F0D), // primary
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 6,
                        width: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Primary Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56, // py-4 roughly 56px with font
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF27F0D),
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shadowColor: const Color(0xFFF27F0D).withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), // xl
                        ),
                      ),
                      onPressed: () => finishOnboarding(context),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Get Started",
                            style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8), // Bottom Safe Area Spacer
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}