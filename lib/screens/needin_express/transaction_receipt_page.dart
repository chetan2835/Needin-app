import 'package:flutter/material.dart';
import 'express_dashboard_page.dart';

class TransactionReceiptPage extends StatelessWidget {
  const TransactionReceiptPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8), // background-light
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF0F172A)), // slate-900
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const ExpressDashboardPage()),
              (Route<dynamic> route) => route.isFirst,
            );
          },
        ),
        title: const Text(
          "Transaction Receipt",
          style: TextStyle(
            fontFamily: "Inter",
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A), // slate-900
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, color: Color(0xFF137FEC)), // primary
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                /// Hero Amount Section
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // slate-100
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)), // slate-200
                  ),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.network(
                        "https://lh3.googleusercontent.com/aida-public/AB6AXuARG33VmErLLShJXWOAxevkfuB-Rvu-q1_b_7v2G_DnaOZnALVZ8qt7g-QmeSgt42ser0ZkO8Mzr6PHw_SE8TrsroPppYw1R14v4PXxUoJnznDxUwj_WPh-NFlLevmoT8XdjiqwdM6Q6dADvFacYk8ViQwHlDnVHx0pKxOXiccLseQaMX3HC_aB76Sp394CS9n3xyDg0xbYHeAdbGhF7ET7qJV4ENVo3c8viAKGkEsp6I2kens9OTzxFJDDPvocO8xzcYtT_-pEgw",
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "₹449.00",
                  style: TextStyle(
                    fontFamily: "Inter",
                    fontSize: 36, // 4xl
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: Color(0xFF0F172A), // slate-900
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Paid to NEEDIN EXPRESS",
                  style: TextStyle(
                    fontFamily: "Inter",
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B), // slate-500
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4), // green-50
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: const Color(0xFFDCFCE7)), // green-100
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18), // green-600
                      SizedBox(width: 8),
                      Text(
                        "Payment Successful",
                        style: TextStyle(
                          fontFamily: "Inter",
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D), // green-700
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                /// Receipt Card
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC), // slate-50
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)), // slate-100
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildRow("Payment Method", Icons.credit_card, "Visa •••• 4242", ""),
                            const SizedBox(height: 20),
                            _buildRow("Date", Icons.calendar_today, "Oct 24, 2023", "10:30 AM"),
                            const SizedBox(height: 20),
                            _buildRow("Transaction ID", Icons.receipt_long, "TRX-89304921", "", showCopy: true),
                            const SizedBox(height: 20),
                            _buildRow("Type", Icons.category, "Delivery Fee", ""),
                          ],
                        ),
                      ),
                      /// Divider with cutouts
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: -12,
                            top: -12,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF6F7F8), // background-light
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -12,
                            top: -12,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF6F7F8), // background-light
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const Divider(
                            color: Color(0xFFCBD5E1), // slate-300
                            thickness: 1,
                            height: 1,
                          ), // A bit hacky, normally requires custom clipper but this works
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              "Total Paid",
                              style: TextStyle(
                                fontFamily: "Inter",
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B), // slate-500
                              ),
                            ),
                            Text(
                              "₹449.00",
                              style: TextStyle(
                                fontFamily: "Inter",
                                fontSize: 18, // lg
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A), // slate-900
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                /// Additional Help
                TextButton.icon(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF137FEC), // primary
                    textStyle: const TextStyle(
                      fontFamily: "Inter",
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.help, size: 18),
                  label: const Text("Need help with this transaction?"),
                ),
              ],
            ),
          ),

          /// Sticky Footer Action
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))), // slate-100
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF137FEC), // primary
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    elevation: 8,
                    shadowColor: const Color(0xFF137FEC).withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.download),
                  label: const Text(
                    "Download Receipt",
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, IconData icon, String valueTop, String valueBottom, {bool showCopy = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF94A3B8)), // slate-400
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: "Inter",
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B), // slate-500
              ),
            ),
          ],
        ),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  valueTop,
                  style: const TextStyle(
                    fontFamily: "Inter",
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A), // slate-900
                  ),
                ),
                if (valueBottom.isNotEmpty)
                  Text(
                    valueBottom,
                    style: const TextStyle(
                      fontFamily: "Inter",
                      fontSize: 12,
                      color: Color(0xFF64748B), // slate-500
                    ),
                  ),
              ],
            ),
            if (showCopy) ...[
              const SizedBox(width: 4),
              Icon(Icons.content_copy, size: 16, color: const Color(0xFF137FEC)), // primary
            ],
          ],
        ),
      ],
    );
  }
}
