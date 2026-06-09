import 'package:flutter/material.dart';

class LegalDocumentPage extends StatelessWidget {
  final String title;

  const LegalDocumentPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          "This is the official $title for Needin Express. \n\n"
          "1. Acceptance of Terms\n"
          "By accessing and using this service, you accept and agree to be bound by the terms and provision of this agreement.\n\n"
          "2. Provision of Services\n"
          "You agree and acknowledge that Needin Express is entitled to modify, improve or discontinue any of its services at its sole discretion and without notice to you even if it may result in you being prevented from accessing any information contained in it.\n\n"
          "3. Proprietary Rights\n"
          "You acknowledge and agree that Needin Express may contain proprietary and confidential information including trademarks, service marks and patents protected by intellectual property laws and international intellectual property treaties.",
          style: const TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontSize: 14,
            height: 1.6,
            color: Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
