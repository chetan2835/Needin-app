import 'package:flutter/material.dart';
import 'flexibility_options_page.dart';

class SpaceWeightPage extends StatefulWidget {
  final Map<String, dynamic> journeyData;

  const SpaceWeightPage({super.key, required this.journeyData});

  @override
  State<SpaceWeightPage> createState() => _SpaceWeightPageState();
}

class _SpaceWeightPageState extends State<SpaceWeightPage> {
  String _selectedUnit = 'in'; // 'in' or 'ft'
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _depthController = TextEditingController();
  
  String _selectedWeight = '10kg';
  final bool _isLoading = false;

  final List<Map<String, dynamic>> _weightOptions = [
    {
      'title': 'Up to 1 kg', 
      'subtitle': 'Documents, letters, keys', 
      'icon': Icons.description, 
      'value': '1kg'
    },
    {
      'title': 'Up to 5 kg', 
      'subtitle': 'Small parcels, shoes, electronics', 
      'icon': Icons.redeem, 
      'value': '5kg'
    },
    {
      'title': 'Up to 10 kg', 
      'subtitle': 'Medium box, laptop bag', 
      'icon': Icons.inventory_2, 
      'value': '10kg'
    },
    {
      'title': 'Up to 25 kg', 
      'subtitle': 'Large suitcase, equipment', 
      'icon': Icons.luggage, 
      'value': '25kg'
    },
    {
      'title': 'Above 25 kg', 
      'subtitle': 'Cargo, freight, heavy items', 
      'icon': Icons.pallet, 
      'value': 'above25kg'
    },
  ];

  @override
  void dispose() {
    _heightController.dispose();
    _widthController.dispose();
    _depthController.dispose();
    super.dispose();
  }

  Future<void> _submitJourney() async {
    final finalJourneyData = Map<String, dynamic>.from(widget.journeyData);
    
    // Get the readable title for capacity (display-only)
    final weightTitle = _weightOptions.firstWhere((o) => o['value'] == _selectedWeight)['title'];
    finalJourneyData['capacity'] = weightTitle; // Display-only field

    // Map to schema-correct capacity_kg (numeric)
    final numericKg = {
      '1kg': 1, '5kg': 5, '10kg': 10, '25kg': 25, 'above25kg': 30,
    }[_selectedWeight] ?? 10;
    finalJourneyData['capacity_kg'] = numericKg;

    // Add dimensions if provided
    final h = _heightController.text.trim();
    final w = _widthController.text.trim();
    final d = _depthController.text.trim();
    if (h.isNotEmpty || w.isNotEmpty || d.isNotEmpty) {
      final dimensions = "${h.isEmpty ? '0' : h}x${w.isEmpty ? '0' : w}x${d.isEmpty ? '0' : d} $_selectedUnit";
      finalJourneyData['dimensions'] = dimensions;
    }

    Navigator.push(context,
      MaterialPageRoute(
        builder: (_) => FlexibilityOptionsPage(journeyData: finalJourneyData),
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
              color: Colors.white,
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
                    child: Text(
                      "Space & Capacity",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            /// Progress Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Step 5 & 6 of 11",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF27F0D),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "Optional",
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF27F0D),
                          ),
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
                      widthFactor: 0.55,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF27F0D),
                          borderRadius: BorderRadius.circular(3),
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
                    /// SPACE DIMENSIONS SECTION
                    const Text(
                      "Dimensions",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "How much space do you have available? This helps us find the right packages for you.",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Unit Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), // Gray-100
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedUnit = 'in'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedUnit == 'in' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _selectedUnit == 'in' 
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Inches (in)",
                                  style: TextStyle(
                                    fontFamily: "Plus Jakarta Sans",
                                    fontSize: 14,
                                    fontWeight: _selectedUnit == 'in' ? FontWeight.w600 : FontWeight.w500,
                                    color: _selectedUnit == 'in' ? const Color(0xFFF27F0D) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedUnit = 'ft'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedUnit == 'ft' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _selectedUnit == 'ft' 
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Feet (ft)",
                                  style: TextStyle(
                                    fontFamily: "Plus Jakarta Sans",
                                    fontSize: 14,
                                    fontWeight: _selectedUnit == 'ft' ? FontWeight.w600 : FontWeight.w500,
                                    color: _selectedUnit == 'ft' ? const Color(0xFFF27F0D) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dimension Inputs
                    _buildDimensionInput(label: "Height", controller: _heightController, icon: Icons.height, unit: _selectedUnit),
                    const SizedBox(height: 16),
                    _buildDimensionInput(label: "Width", controller: _widthController, icon: Icons.straighten, unit: _selectedUnit),
                    const SizedBox(height: 16),
                    _buildDimensionInput(label: "Depth", controller: _depthController, icon: Icons.check_box_outline_blank, unit: _selectedUnit),
                    const SizedBox(height: 24),

                    // Dimension Helper Note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF27F0D).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF27F0D).withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info, color: Color(0xFFF27F0D), size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "Accurate dimensions help avoid issues during pickup. You can estimate if you don't have exact measurements.",
                              style: TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 13,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    const Divider(color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 32),

                    /// WEIGHT CAPACITY SECTION
                    const Text(
                      "Approx Weight Capacity",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "How much extra weight can you carry in your luggage?",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Weight List
                    ..._weightOptions.map((weight) {
                      final isSelected = _selectedWeight == weight['value'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedWeight = weight['value'] as String;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF27F0D).withValues(alpha: 0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFFE2E8F0),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFFF27F0D).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  weight['icon'] as IconData,
                                  color: isSelected ? Colors.white : const Color(0xFFF27F0D),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      weight['title'] as String,
                                      style: TextStyle(
                                        fontFamily: "Plus Jakarta Sans",
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      weight['subtitle'] as String,
                                      style: TextStyle(
                                        fontFamily: "Plus Jakarta Sans",
                                        fontSize: 12,
                                        color: isSelected ? const Color(0xFFF27F0D).withValues(alpha: 0.8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF27F0D),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                                )
                              else
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

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
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            onPressed: _isLoading ? null : _submitJourney,
            child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  "Continue",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildDimensionInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: "Plus Jakarta Sans",
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(icon, color: const Color(0xFFF27F0D).withValues(alpha: 0.5), size: 24),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    hintText: "0",
                    hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 16),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
