import 'package:flutter/material.dart';
import 'package:needin_app/screens/needin_express/express_dashboard_page.dart';

class VerificationStatusReviewingPage extends StatelessWidget {
  const VerificationStatusReviewingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF181410)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Verification Status",
          style: TextStyle(
            fontFamily: "Inter",
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF181410),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7), // amber-100
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.hourglass_empty, size: 64, color: Color(0xFFD97706)), // amber-600
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Verification Under Review",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181410),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "We are currently reviewing your documents. This process usually takes 1-2 business days. We will notify you once it's complete.",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 16,
                  color: Color(0xFF6B5E52),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8000),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const ExpressDashboardPage()),
                    (route) => false,
                  );
                },
                child: const Text(
                  "Back to Dashboard",
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
      ),
    );
  }
}
