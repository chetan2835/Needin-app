import 'package:flutter/material.dart';
import 'onboarding3.dart';
import '../login/login_page.dart';
import '../../core/widgets/fade_slide_in.dart';

class Onboarding2 extends StatelessWidget {
  const Onboarding2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// Skip Button
            Padding(
              padding: const EdgeInsets.only(top: 24.0, right: 24.0, bottom: 8.0),
              child: Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(
                            builder: (_) => LoginPage()));
                  },
                  child: const Text(
                    "Skip",
                    style: TextStyle(
                      color: Color(0xFF64748B), // slate-500
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
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
                          /// Illustration
                          SizedBox(
                            height: 320,
                            width: double.infinity,
                            child: Image.network(
                              "https://lh3.googleusercontent.com/aida-public/AB6AXuCCKr1EYMnMt2qGL7HQcbJM2HkG07KTD31OLCjLCjvoxn1_5zjlpmNiXq6K5ndgt8C0UDMg9MokZdH0WJRtpukaxR920uhwnOMF-kLv2ewbaA2QJQJh7H25P74peuM5y2oi_hCJHp1Nnkb8-qkmFNP4Im6VMEtveGyM-YjWpDae6QsyQ8tFruFgfxhG53dhBrK4amhpqBj1sWb8_q-yrdU1_sqUEcr4lR7_bJncwKH_rLCbu0nTOSR1EQQhoqoRQMy5FqmnyVWelg",
                              fit: BoxFit.contain,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Title
                          const Text(
                            "Reliable Parcel Delivery",
                            style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),

                          // Description
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              "Find verified travelers to carry your packages safely and quickly to any city.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
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

            /// Bottom Controls
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                children: [
                  // Pagination Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 8,
                        width: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0), // slate-200
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 8,
                        width: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF27F0D), // primary
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFF27F0D).withValues(alpha: 0.3),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 8,
                        width: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 8,
                        width: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Primary Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF27F0D),
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: Color(0xFFF27F0D).withValues(alpha: 0.25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), // xl
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(context,
                          MaterialPageRoute(builder: (_) => Onboarding3()),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Next",
                            style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 18,
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
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}