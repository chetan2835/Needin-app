import 'package:flutter/material.dart';
import 'package:needin_app/screens/login/login_page.dart';

class OnboardingTravelEarnPage extends StatelessWidget {
  const OnboardingTravelEarnPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text(
              "Skip",
              style: TextStyle(
                fontFamily: "Inter",
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B5E52), // text-sub
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    // Illustration Placeholder
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F7F5),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.flight_takeoff,
                          size: 100,
                          color: const Color(0xFFFF8000).withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      "Travel & Earn",
                      style: TextStyle(
                        fontFamily: "Inter",
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF181410), // text-main
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Make your empty luggage space work for you. Carry parcels on your route and earn money.",
                      style: TextStyle(
                        fontFamily: "Inter",
                        fontSize: 16,
                        color: Color(0xFF6B5E52), // text-sub
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 24, height: 6, decoration: BoxDecoration(color: const Color(0xFFFF8000), borderRadius: BorderRadius.circular(9999))),
                      const SizedBox(width: 8),
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFFE7E0DA), borderRadius: BorderRadius.circular(9999))),
                      const SizedBox(width: 8),
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFFE7E0DA), borderRadius: BorderRadius.circular(9999))),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8000), // primary
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: const Text(
                      "Next",
                      style: TextStyle(
                        fontFamily: "Inter",
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
