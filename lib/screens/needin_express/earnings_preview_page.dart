import 'package:flutter/material.dart';
import 'additional_notes_page.dart';

class EarningsPreviewPage extends StatefulWidget {
  final Map<String, dynamic> journeyData;

  const EarningsPreviewPage({super.key, required this.journeyData});

  @override
  State<EarningsPreviewPage> createState() => _EarningsPreviewPageState();
}

class _EarningsPreviewPageState extends State<EarningsPreviewPage> {
  final bool _isLoading = false;

  Future<void> _submitJourney() async {
    Navigator.push(context,
      MaterialPageRoute(
        builder: (_) => AdditionalNotesPage(journeyData: widget.journeyData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            /// Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      color: Colors.transparent,
                      child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 40),
                      child: Text(
                        "Post a Journey",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Progress Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          "Step 9 of 11",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          "81% Completed",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF27F0D),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.81,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF27F0D),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    /// Title Section
                    const Text(
                      "Estimated Earnings for This Journey",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Here is what you can earn based on current demand.",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 15,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    /// Pricing Cards Grid
                    _buildPricingCard(
                      isPopular: true,
                      title: "Small",
                      subtitle: "Documents, Keys",
                      icon: Icons.description,
                      price: widget.journeyData['earnings_small'] != null
                          ? "₹${widget.journeyData['earnings_small']}"
                          : "TBD",
                    ),
                    const SizedBox(height: 16),
                    _buildPricingCard(
                      isPopular: false,
                      title: "Medium",
                      subtitle: "Shoebox, Laptop",
                      icon: Icons.laptop_mac,
                      price: widget.journeyData['earnings_medium'] != null
                          ? "₹${widget.journeyData['earnings_medium']}"
                          : "TBD",
                    ),
                    const SizedBox(height: 16),
                    _buildPricingCard(
                      isPopular: false,
                      title: "Large",
                      subtitle: "Suitcase, Electronics",
                      icon: Icons.luggage,
                      price: widget.journeyData['earnings_large'] != null
                          ? "₹${widget.journeyData['earnings_large']}"
                          : "TBD",
                    ),

                    const SizedBox(height: 32),

                    /// Disclaimer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF27F0D).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF27F0D).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info, color: Color(0xFFF27F0D), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontFamily: "Plus Jakarta Sans",
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                  height: 1.5,
                                ),
                                children: [
                                  TextSpan(
                                    text: "Note: ",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF27F0D),
                                    ),
                                  ),
                                  TextSpan(
                                    text: "Prices are indicative. Final earnings depend on the specific items you choose to accept for delivery.",
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 100), // padding buffer
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA).withValues(alpha: 0.95),
          border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF27F0D),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFFF27F0D).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isLoading ? null : _submitJourney,
            child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  "Continue",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildPricingCard({
    required bool isPopular,
    required String title,
    required String subtitle,
    required IconData icon,
    required String price,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isPopular)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Most Popular",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF27F0D),
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF27F0D).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: const Color(0xFFF27F0D), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "/item",
                    style: TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
