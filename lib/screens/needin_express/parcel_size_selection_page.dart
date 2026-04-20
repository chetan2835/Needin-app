import 'package:flutter/material.dart';
import 'earnings_preview_page.dart';

class ParcelSizeSelectionPage extends StatefulWidget {
  final Map<String, dynamic> journeyData;

  const ParcelSizeSelectionPage({super.key, required this.journeyData});

  @override
  State<ParcelSizeSelectionPage> createState() => _ParcelSizeSelectionPageState();
}

class _ParcelSizeSelectionPageState extends State<ParcelSizeSelectionPage> {
  bool _selectAll = false;
  bool _smallSelected = true;
  bool _mediumSelected = true;
  bool _largeSelected = false;
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _updateSelectAll();
  }

  void _onSelectAllChanged(bool value) {
    setState(() {
      _selectAll = value;
      _smallSelected = value;
      _mediumSelected = value;
      _largeSelected = value;
    });
  }

  void _updateSelectAll() {
    setState(() {
      _selectAll = _smallSelected && _mediumSelected && _largeSelected;
    });
  }

  Future<void> _submitJourney() async {
    if (!_smallSelected && !_mediumSelected && !_largeSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one parcel size.')),
      );
      return;
    }

    final finalJourneyData = Map<String, dynamic>.from(widget.journeyData);
    
    List<String> parcelSizes = [];
    if (_smallSelected) parcelSizes.add('Small');
    if (_mediumSelected) parcelSizes.add('Medium');
    if (_largeSelected) parcelSizes.add('Large');
    
    finalJourneyData['acceptable_parcel_sizes'] = parcelSizes.join(', ');

    Navigator.push(context,
      MaterialPageRoute(
        builder: (_) => EarningsPreviewPage(journeyData: finalJourneyData),
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
              color: const Color(0xFFFAFAFA).withValues(alpha: 0.95),
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
                      "Traveler Journey",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 16,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "Step 8 of 11",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        "72%",
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
                      widthFactor: 0.72,
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
                    const Text(
                      "What size parcel can you carry?",
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
                      "Select all sizes that fit in your luggage. We'll only show you requests that match your capacity.",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 15,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    /// All Categories Toggle
                    GestureDetector(
                      onTap: () => _onSelectAllChanged(!_selectAll),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _selectAll ? const Color(0xFFF27F0D).withValues(alpha: 0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectAll ? const Color(0xFFF27F0D) : const Color(0xFFE2E8F0),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.library_add_check, color: Color(0xFFF27F0D), size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    "All Parcel Categories",
                                    style: TextStyle(
                                      fontFamily: "Plus Jakarta Sans",
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Selects everything below",
                                    style: TextStyle(
                                      fontFamily: "Plus Jakarta Sans",
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectAll)
                              Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF27F0D),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 16),
                              )
                            else
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    /// Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Row(
                        children: [
                          Expanded(child: Container(height: 1, color: const Color(0xFFE2E8F0))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              "OR SELECT INDIVIDUALLY",
                              style: TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          Expanded(child: Container(height: 1, color: const Color(0xFFE2E8F0))),
                        ],
                      ),
                    ),

                    /// Small Parcel
                    _buildCheckboxCard(
                      title: "Small",
                      maxWeight: "Max 2kg",
                      subtitle: "Fits in a backpack (Envelope/Pouch)",
                      icon: Icons.mail,
                      isSelected: _smallSelected,
                      onChanged: (val) {
                        setState(() => _smallSelected = val);
                        _updateSelectAll();
                      },
                    ),
                    const SizedBox(height: 12),

                    /// Medium Parcel
                    _buildCheckboxCard(
                      title: "Medium",
                      maxWeight: "Max 5kg",
                      subtitle: "Fits in carry-on (Shoebox size)",
                      icon: Icons.inventory_2,
                      isSelected: _mediumSelected,
                      onChanged: (val) {
                        setState(() => _mediumSelected = val);
                        _updateSelectAll();
                      },
                    ),
                    const SizedBox(height: 12),

                    /// Large Parcel
                    _buildCheckboxCard(
                      title: "Large",
                      maxWeight: "Max 20kg",
                      subtitle: "Checked luggage required",
                      icon: Icons.luggage,
                      isSelected: _largeSelected,
                      onChanged: (val) {
                        setState(() => _largeSelected = val);
                        _updateSelectAll();
                      },
                    ),

                    const SizedBox(height: 100), // buffer
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

  Widget _buildCheckboxCard({
    required String title,
    required String maxWeight,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!isSelected),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF27F0D).withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFFE2E8F0),
            width: 2,
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
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9), // slate-100
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          maxWeight,
                          style: const TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569), // slate-600
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF27F0D) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
            ),
          ],
        ),
      ),
    );
  }
}
