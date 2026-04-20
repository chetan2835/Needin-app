import 'package:flutter/material.dart';
import 'onboarding2.dart';
import '../login/login_page.dart';
import '../../core/widgets/fade_slide_in.dart';

class Onboarding1 extends StatelessWidget {
  const Onboarding1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      body: SafeArea(
        child: Column(
          children: [
            /// Skip Button
            Padding(
              padding: const EdgeInsets.only(top: 24.0, right: 24.0),
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
                      color: Color(0xFFF27F0D),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
                          /// Image with decorative background
                          SizedBox(
                            height: 380,
                            width: double.infinity,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Decorative blur behind image
                                Container(
                                  width: 280,
                                  height: 280,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFF27F0D).withValues(alpha: 0.12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFFF27F0D).withValues(alpha: 0.15),
                                        blurRadius: 80,
                                        spreadRadius: 30,
                                      ),
                                    ],
                                  ),
                                ),
                                // Illustration
                                Image.network(
                                  "https://lh3.googleusercontent.com/aida-public/AB6AXuBoQd6VfjZkWp5Ylf-7UZj-Zaj9wgU925X4vGjbnSMiJal1D1VFPBXb2WiillehGMAlMkceqZS1BsKz1dGb3wibblDF2ZgMPArCenBFVpMotTdRi1cU1PnifIqNCVBTJUS3b86mzl8DltUISk9QtweLPM9yN8kIzIaPTyUnRdxz7FHwT2fvJpoNngXgE9hxaamaYYSqcNMiwE8HK5OXkKSXWhH5LGrSci-E8SPOpV1TIorx_kz6QCUzu72UNoS1JeIUq29dbJ0U7w",
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Title
                          const Text(
                            "Travel and Earn",
                            style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              height: 1.25,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),

                          // Description
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              "Turn your journeys into earnings by delivering parcels along your route.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
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

            /// Footer Section (Dots & Next Button)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  // Progress Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 10,
                        width: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF27F0D),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 10,
                        width: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0), // slate-200
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 10,
                        width: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 10,
                        width: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Next Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF27F0D),
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: Color(0xFFF27F0D).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(context,
                          MaterialPageRoute(builder: (_) => Onboarding2()),
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
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            size: 22,
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