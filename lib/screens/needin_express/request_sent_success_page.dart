import 'package:flutter/material.dart';

class RequestSentSuccessPage extends StatelessWidget {
  const RequestSentSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7), // green-100
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.check_circle, size: 80, color: Color(0xFF16A34A)), // green-600
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "Request Sent Successfully",
                        style: TextStyle(
                          fontFamily: "Inter",
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF181410),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Your delivery request has been forwarded to the traveler. You will be notified once they accept it.",
                        style: TextStyle(
                          fontFamily: "Inter",
                          fontSize: 16,
                          color: Color(0xFF6B5E52),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8000),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text(
                  "Return to Dashboard",
                  style: TextStyle(
                    fontFamily: "Inter",
                    fontSize: 18,
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
