import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          "Frequently Asked Questions",
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFaqItem(
            "What is Needin Express?",
            "Needin Express connects users with travelers to facilitate same-day or time-bound parcel deliveries along their routes.",
          ),
          _buildFaqItem(
            "How are earnings calculated?",
            "Earnings depend on the size of the parcel. The estimated earnings are shown upfront before you accept a journey.",
          ),
          _buildFaqItem(
            "What items are prohibited?",
            "You cannot send illegal, hazardous, flammable, explosive, narcotic substances, cash, jewellery, or restricted goods.",
          ),
          _buildFaqItem(
            "What happens if the recipient is unavailable?",
            "The delivery partner will attempt to contact the recipient. If they remain unavailable, reattempt or return charges may apply.",
          ),
          _buildFaqItem(
            "Can I cancel my delivery request?",
            "You can cancel your request before the parcel is picked up. Once picked up, cancellation is not permitted.",
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        iconColor: const Color(0xFFF05A4F),
        collapsedIconColor: const Color(0xFF94A3B8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            answer,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
