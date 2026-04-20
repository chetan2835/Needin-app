import 'package:flutter/material.dart';

class WeightCapacitySelectionPage extends StatefulWidget {
  const WeightCapacitySelectionPage({super.key});

  @override
  State<WeightCapacitySelectionPage> createState() => _WeightCapacitySelectionPageState();
}

class _WeightCapacitySelectionPageState extends State<WeightCapacitySelectionPage> {
  String _selectedCapacity = '10kg';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5), // background-light
      appBar: AppBar(
        backgroundColor: Colors.white, // surface-light
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF181410)), // text-main
          onPressed: () => Navigator.pop(context),
        ),
        title: const SizedBox.shrink(), // No title based on HTML, but has Cancel button
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              "Cancel",
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
      body: Stack(
        children: [
          Column(
            children: [
              /// Progress Indicator
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text(
                          "STEP 6 OF 11",
                          style: TextStyle(
                            fontFamily: "Inter",
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Color(0xFFFF8000), // primary
                          ),
                        ),
                        Text(
                          "55% completed",
                          style: TextStyle(
                            fontFamily: "Inter",
                            fontSize: 12,
                            color: Color(0xFF6B5E52), // text-sub
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7E0DA), // border-color
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 55,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF8000), // primary
                                borderRadius: BorderRadius.circular(9999),
                              ),
                            ),
                          ),
                          Expanded(flex: 45, child: Container()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              /// Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Approx Weight Capacity",
                        style: TextStyle(
                          fontFamily: "Inter",
                          fontSize: 28, // roughly 3xl
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF181410), // text-main
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "How much extra weight can you carry in your luggage?",
                        style: TextStyle(
                          fontFamily: "Inter",
                          fontSize: 14,
                          color: Color(0xFF6B5E52), // text-sub
                        ),
                      ),
                      const SizedBox(height: 32),

                      /// Selection List
                      _buildOption("1kg", "Up to 1 kg", "Documents, letters, keys", Icons.description),
                      const SizedBox(height: 12),
                      _buildOption("5kg", "Up to 5 kg", "Small parcels, shoes, electronics", Icons.redeem),
                      const SizedBox(height: 12),
                      _buildOption("10kg", "Up to 10 kg", "Medium box, laptop bag", Icons.widgets),
                      const SizedBox(height: 12),
                      _buildOption("25kg", "Up to 25 kg", "Large suitcase, equipment", Icons.luggage),
                      const SizedBox(height: 12),
                      _buildOption("above25kg", "Above 25 kg", "Cargo, freight, heavy items", Icons.pallet),
                    ],
                  ),
                ),
              ),
            ],
          ),

          /// Footer Action Area
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                border: const Border(top: BorderSide(color: Colors.transparent)),
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8000), // primary
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    elevation: 4,
                    shadowColor: const Color(0xFFFF8000).withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // rounded-lg
                    ),
                  ),
                  onPressed: () {},
                  child: const Text(
                    "Continue",
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

  Widget _buildOption(String value, String title, String subtitle, IconData icon) {
    final bool isSelected = _selectedCapacity == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCapacity = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF8000).withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12), // rounded-xl
          border: Border.all(
            color: isSelected ? const Color(0xFFFF8000) : const Color(0xFFE7E0DA), // primary or border-color
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            /// Icon Container
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFF8000) : const Color(0xFFFF8000).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : const Color(0xFFFF8000),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),

            /// Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF181410) : const Color(0xFF181410),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: "Inter",
                      fontSize: 12,
                      color: Color(0xFF6B5E52),
                    ),
                  ),
                ],
              ),
            ),

            /// Radio Button Circle
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF8000) : const Color(0xFFE7E0DA),
                  width: 2,
                ),
                color: isSelected ? const Color(0xFFFF8000) : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
