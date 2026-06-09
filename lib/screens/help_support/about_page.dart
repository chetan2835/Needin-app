import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          "About Needin Express",
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Image.asset('assets/images/needin_logo.png', errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_shipping, size: 48, color: Color(0xFFF05A4F))),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Needin Express",
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Version 2.4.0",
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                "Needin Express is a technology-enabled delivery facilitation service that connects users with independent delivery partners for travel-based, same-day or time-bound deliveries.\n\nOur platform leverages existing journeys to facilitate fast, efficient, and cost-effective parcel deliveries. Whether you are sending a document across the city or a package to another state, Needin Express makes it happen.",
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  color: Color(0xFF475569),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              "© 2024 Viec Carry India Pvt Ltd.\nAll rights reserved.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                color: Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
