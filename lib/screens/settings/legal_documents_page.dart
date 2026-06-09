import 'package:flutter/material.dart';
import '../../core/constants/legal_documents_content.dart';
import 'legal_document_viewer_page.dart';

class LegalDocumentsPage extends StatelessWidget {
  const LegalDocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Legal Documents',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDocCard(
            context: context,
            title: 'Terms and Conditions',
            icon: Icons.gavel_rounded,
            content: LegalDocumentsContent.termsAndConditions,
            date: 'MAY 06, 2026',
          ),
          _buildDocCard(
            context: context,
            title: 'Privacy Policy',
            icon: Icons.privacy_tip_rounded,
            content: LegalDocumentsContent.privacyPolicy,
            date: 'MAY 06, 2026',
          ),
          _buildDocCard(
            context: context,
            title: 'Needin Express Delivery Agreement',
            icon: Icons.local_shipping_rounded,
            content: LegalDocumentsContent.expressDeliveryAgreement,
            date: 'MAY 06, 2026',
          ),
          _buildDocCard(
            context: context,
            title: 'Cancellation & Refund Policy',
            icon: Icons.assignment_return_rounded,
            content: LegalDocumentsContent.cancellationPolicy,
            date: 'MAY 06, 2026',
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String content,
    required String date,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LegalDocumentViewerPage(
                  title: title,
                  markdownContent: content,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: const Color(0xFFF05A4F)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last updated: $date',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
