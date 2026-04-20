import 'package:flutter/material.dart';
import 'parcel_size_selection_page.dart';

class FlexibilityOptionsPage extends StatefulWidget {
  final Map<String, dynamic> journeyData;

  const FlexibilityOptionsPage({super.key, required this.journeyData});

  @override
  State<FlexibilityOptionsPage> createState() => _FlexibilityOptionsPageState();
}

class _FlexibilityOptionsPageState extends State<FlexibilityOptionsPage> {
  String _pickupFlexibility = 'Fixed Location';
  String _dropoffFlexibility = 'Fixed Location';
  final bool _isLoading = false;

  Future<void> _submitJourney() async {
    final finalJourneyData = Map<String, dynamic>.from(widget.journeyData);
    
    finalJourneyData['pickup_flexibility'] = _pickupFlexibility;
    finalJourneyData['dropoff_flexibility'] = _dropoffFlexibility;

    Navigator.push(context,
      MaterialPageRoute(
        builder: (_) => ParcelSizeSelectionPage(journeyData: finalJourneyData),
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
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
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
                        "Post Journey",
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
                          "Step 7 of 11",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          "63%",
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
                        widthFactor: 0.63,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF27F0D),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      "Pickup & Drop Flexibility",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 32),

                    /// Pickup Section
                    Row(
                      children: const [
                        Icon(Icons.inventory_2, color: Color(0xFFF27F0D), size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Pickup Flexibility",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildRadioCard(
                      title: "Fixed Location",
                      subtitle: "I can only pick up at the exact address specified.",
                      icon: Icons.location_on,
                      groupValue: _pickupFlexibility,
                      value: "Fixed Location",
                      onChanged: (val) => setState(() => _pickupFlexibility = val!),
                    ),
                    const SizedBox(height: 12),
                    _buildRadioCard(
                      title: "Nearby Area",
                      subtitle: "I am willing to travel within 5km for pickup.",
                      icon: Icons.near_me,
                      groupValue: _pickupFlexibility,
                      value: "Nearby Area",
                      onChanged: (val) => setState(() => _pickupFlexibility = val!),
                    ),

                    const SizedBox(height: 32),

                    /// Drop-off Section
                    Row(
                      children: const [
                        Icon(Icons.local_shipping, color: Color(0xFFF27F0D), size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Drop-off Flexibility",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildRadioCard(
                      title: "Fixed Location",
                      subtitle: "I can only drop off at the exact address specified.",
                      icon: Icons.pin_drop,
                      groupValue: _dropoffFlexibility,
                      value: "Fixed Location",
                      onChanged: (val) => setState(() => _dropoffFlexibility = val!),
                    ),
                    const SizedBox(height: 12),
                    _buildRadioCard(
                      title: "Nearby Area",
                      subtitle: "I am willing to travel within 5km for drop-off.",
                      icon: Icons.explore,
                      groupValue: _dropoffFlexibility,
                      value: "Nearby Area",
                      onChanged: (val) => setState(() => _dropoffFlexibility = val!),
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
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      "Continue",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildRadioCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String groupValue,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = groupValue == value;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF27F0D).withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFFCBD5E1),
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              icon,
              color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFF94A3B8),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
