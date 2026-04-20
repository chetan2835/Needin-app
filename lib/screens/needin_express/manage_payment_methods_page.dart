import 'package:flutter/material.dart';

class ManagePaymentMethodsPage extends StatelessWidget {
  const ManagePaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5), // background-light
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7F5).withValues(alpha: 0.95),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF181411)), // text-main
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Payment Methods",
          style: TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF181411), // text-main
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF27F0D), // primary
              textStyle: const TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text("Edit"),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Saved Cards
                _buildSectionTitle("Saved Cards"),
                const SizedBox(height: 16),
                _buildVisaCard(),
                const SizedBox(height: 16),
                _buildMastercard(),
                const SizedBox(height: 32),

                /// UPI IDs
                _buildSectionTitle("UPI IDs"),
                const SizedBox(height: 16),
                _buildUpiOption("john.doe@okicici", "Google Pay", Icons.g_mobiledata, Colors.grey.shade50), // Using placeholder icon
                const SizedBox(height: 12),
                _buildUpiOption("9876543210@ybl", "PhonePe", Icons.account_balance_wallet, const Color(0xFF5F259F)), // Using placeholder icon
                const SizedBox(height: 32),

                /// Bank Accounts
                Row(
                  children: [
                    _buildSectionTitle("Bank Accounts"),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        "Payouts",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildBankAccount(),
                const SizedBox(height: 32),

                /// Security Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      "Payments secured by Stripe",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          /// Floating Add Button Area
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFFF8F7F5),
                    const Color(0xFFF8F7F5).withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF27F0D), // primary
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 8,
                  shadowColor: const Color(0xFFF27F0D).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text(
                  "Add New Method",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: "Plus Jakarta Sans",
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: Color(0xFF181411), // text-main
      ),
    );
  }

  Widget _buildVisaCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -28, // Pulls the badge above
            left: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF27F0D),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: const Text(
                "DEFAULT",
                style: TextStyle(
                  fontFamily: "Plus Jakarta Sans",
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(
                          child: Text(
                            "VISA",
                            style: TextStyle(
                                color: Colors.indigo,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Visa",
                            style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF181411),
                            ),
                          ),
                          Text(
                            "Personal",
                            style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8A7560), // text-sub
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: true,
                    onChanged: (val) {},
                    activeThumbColor: const Color(0xFFF27F0D),
                    activeTrackColor: const Color(0xFFF27F0D).withValues(alpha: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "CARD NUMBER",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8A7560),
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "•••• 4242",
                        style: TextStyle(
                          fontFamily: "monospace",
                          fontSize: 18,
                          letterSpacing: 2,
                          color: Color(0xFF181411),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text(
                        "EXPIRES",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8A7560),
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "12/25",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF181411),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMastercard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                          const SizedBox(width: 2),
                          Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Mastercard",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF181411),
                        ),
                      ),
                      Text(
                        "Business",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8A7560),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: false,
                onChanged: (val) {},
                activeThumbColor: const Color(0xFFF27F0D),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "CARD NUMBER",
                    style: TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A7560),
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "•••• 8899",
                    style: TextStyle(
                      fontFamily: "monospace",
                      fontSize: 18,
                      letterSpacing: 2,
                      color: Color(0xFF181411),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text(
                    "EXPIRES",
                    style: TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A7560),
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "09/24",
                    style: TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF181411),
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

  Widget _buildUpiOption(String id, String label, IconData icon, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Icon(icon, color: bgColor == const Color(0xFF5F259F) ? Colors.white : Colors.blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id,
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF181411),
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 12,
                    color: Color(0xFF8A7560),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.radio_button_unchecked, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildBankAccount() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Colors.green, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_balance, color: Colors.red),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Text(
                      "HDFC Bank",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF181411),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.verified, color: Colors.green, size: 14),
                  ],
                ),
                const Text(
                  "Checking •••• 1122",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 12,
                    color: Color(0xFF8A7560),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
