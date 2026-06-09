import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'parcel_size_selection_page.dart';
import '../help_support/terms_of_service_page.dart';
import '../../core/utils/parcel_definition_resolver.dart';
import 'package:provider/provider.dart';
import '../../core/providers/journey_draft_provider.dart';


class SpaceWeightPage extends StatefulWidget {
  final Map<String, dynamic> journeyData;

  const SpaceWeightPage({super.key, required this.journeyData});

  @override
  State<SpaceWeightPage> createState() => _SpaceWeightPageState();
}

class _SpaceWeightPageState extends State<SpaceWeightPage> {
  String _selectedUnit = 'in';
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _lengthFocus = FocusNode();
  final FocusNode _widthFocus = FocusNode();
  final FocusNode _heightFocus = FocusNode();

  String _selectedWeight = '10kg';
  bool _smartDefaultsApplied = false;
  bool _acceptsFragile = false;
  bool _hasScrolledToBottom = false;

  bool get _isFlightMode => (widget.journeyData['travel_mode'] ?? 'road') == 'flight';

  static const List<Map<String, dynamic>> _defaultWeightOptions = [
    {'title': 'Up to 2 kg', 'subtitle': 'Documents, letters, small items', 'icon': Icons.description, 'value': '2kg'},
    {'title': 'Up to 5 kg', 'subtitle': 'Small parcels, shoes, electronics', 'icon': Icons.redeem, 'value': '5kg'},
    {'title': 'Up to 25 kg', 'subtitle': 'Large suitcase, equipment', 'icon': Icons.luggage, 'value': '25kg'},
  ];

  static const List<Map<String, dynamic>> _flightWeightOptions = [
    {'title': 'Up to 1 kg', 'subtitle': 'Documents, letters, keys', 'icon': Icons.description, 'value': '1kg'},
    {'title': 'Up to 3 kg', 'subtitle': 'Small parcels, accessories', 'icon': Icons.redeem, 'value': '3kg'},
    {'title': 'Up to 5 kg', 'subtitle': 'Cabin-safe items only', 'icon': Icons.inventory_2, 'value': '5kg'},
  ];

  List<Map<String, dynamic>> get _weightOptions => _isFlightMode ? _flightWeightOptions : _defaultWeightOptions;

  double get _maxDimensionLimit => _isFlightMode ? 18.0 : (_selectedUnit == 'in' ? 72.0 : 6.0);

  @override
  void initState() {
    super.initState();
    _applySmartDefaults();
    _lengthController.addListener(_onFieldChanged);
    _widthController.addListener(_onFieldChanged);
    _heightController.addListener(_onFieldChanged);

    _lengthFocus.addListener(_scrollToFocused);
    _widthFocus.addListener(_scrollToFocused);
    _heightFocus.addListener(_scrollToFocused);
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _lengthFocus.removeListener(_scrollToFocused);
    _widthFocus.removeListener(_scrollToFocused);
    _heightFocus.removeListener(_scrollToFocused);
    _lengthFocus.dispose();
    _widthFocus.dispose();
    _heightFocus.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (maxScroll > 0 && currentScroll >= maxScroll * 0.70) {
        if (!_hasScrolledToBottom) {
          setState(() {
            _hasScrolledToBottom = true;
          });
        }
      }
    }
  }

  void _scrollToFocused() {
    setState(() {}); // Rebuild to highlight input borders
    if (_lengthFocus.hasFocus || _widthFocus.hasFocus || _heightFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        BuildContext? ctx;
        if (_lengthFocus.hasFocus) {
          ctx = _lengthFocus.context;
        } else if (_widthFocus.hasFocus) {
          ctx = _widthFocus.context;
        } else if (_heightFocus.hasFocus) {
          ctx = _heightFocus.context;
        }
        
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            alignment: 0.28,
          );
        }
      });
    }
  }

  void _onFieldChanged() {
    _clampField(_lengthController);
    _clampField(_widthController);
    _clampField(_heightController);
    setState(() {});
  }

  void _clampField(TextEditingController controller) {
    if (controller.text.isEmpty) return;
    double? val = double.tryParse(controller.text);
    if (val == null) return;

    double maxLimit = _maxDimensionLimit;
    if (val > maxLimit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final newText = maxLimit.toStringAsFixed(maxLimit == maxLimit.truncateToDouble() ? 0 : 1);
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFlightMode
                ? 'For flight travel, dimensions cannot exceed 18 inches and weight cannot exceed 5 kg.'
                : 'Maximum allowed dimension is 72 inches.'),
            backgroundColor: const Color(0xFFC44840),
            duration: const Duration(seconds: 2),
          ),
        );
      });
    }
  }

  void _convertAndClampValues(String newUnit) {
    void convertField(TextEditingController controller) {
      if (controller.text.isEmpty) return;
      double? val = double.tryParse(controller.text);
      if (val == null) return;
      
      if (newUnit == 'in') { // ft -> in
        val = val * 12;
      } else { // in -> ft
        val = val / 12;
      }
      
      double maxLimit = newUnit == 'in' ? 72.0 : 6.0;
      if (val > maxLimit) val = maxLimit;
      
      controller.text = val.toStringAsFixed(val == val.truncateToDouble() ? 0 : 1);
    }
    
    convertField(_lengthController);
    convertField(_widthController);
    convertField(_heightController);
  }

  void _applySmartDefaults() {
    final mode = widget.journeyData['travel_mode'] ?? 'road';
    switch (mode) {
      case 'flight':
        _selectedUnit = 'in'; // Flight: inches only
        _lengthController.text = '18';
        _widthController.text = '14';
        _heightController.text = '8';
        _selectedWeight = '5kg';
        break;
      case 'train':
        _lengthController.text = '24';
        _widthController.text = '16';
        _heightController.text = '10';
        _selectedWeight = '25kg';
        break;
      case 'bus':
        _lengthController.text = '20';
        _widthController.text = '14';
        _heightController.text = '8';
        _selectedWeight = '5kg';
        break;
      case 'bike':
        _lengthController.text = '12';
        _widthController.text = '8';
        _heightController.text = '6';
        _selectedWeight = '5kg';
        break;
      default:
        _lengthController.text = '24';
        _widthController.text = '16';
        _heightController.text = '12';
        _selectedWeight = '25kg';
    }
    _smartDefaultsApplied = true;
  }

  String get _travelModeLabel {
    switch (widget.journeyData['travel_mode'] ?? 'road') {
      case 'flight': return 'Flight';
      case 'train': return 'Train';
      case 'bus': return 'Bus';
      case 'bike': return 'Bike / Truck';
      default: return 'Car';
    }
  }

  bool get _isFormValid {
    final l = double.tryParse(_lengthController.text);
    final w = double.tryParse(_widthController.text);
    final h = double.tryParse(_heightController.text);
    
    final maxLimit = _maxDimensionLimit;
    
    return l != null && l > 0 && l <= maxLimit &&
           w != null && w > 0 && w <= maxLimit &&
           h != null && h > 0 && h <= maxLimit;
  }

  bool get _canContinue {
    if (!_isFormValid) return false;
    if (!_scrollController.hasClients) return true;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 100) return true;
    return _hasScrolledToBottom;
  }



  Future<void> _submitJourney() async {
    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all dimension fields to continue.')),
      );
      return;
    }

    final weightTitle = _weightOptions.firstWhere((o) => o['value'] == _selectedWeight)['title'];
    final numericKg = {
      '1kg': 1.0, '2kg': 2.0, '3kg': 3.0, '5kg': 5.0, '25kg': 25.0,
    }[_selectedWeight] ?? 5.0;

    final l = double.parse(_lengthController.text);
    final w = double.parse(_widthController.text);
    final h = double.parse(_heightController.text);
    
    double lengthIn = _selectedUnit == 'in' ? l : l * 12;
    double widthIn = _selectedUnit == 'in' ? w : w * 12;
    double heightIn = _selectedUnit == 'in' ? h : h * 12;

    String parcelCategory = ParcelDefinitionResolver.calculateCategory(widget.journeyData['travel_mode'], lengthIn, widthIn, heightIn, numericKg);
    String capacityLabel = weightTitle;
    List<String> supportedCategories = [];
    double priceMin = 0;
    double priceMax = 0;

    if (parcelCategory == 'Invalid') {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid dimensions or weight for selected travel mode.')));
       return;
    }
    
    final provider = Provider.of<JourneyDraftProvider>(context, listen: false);
    final finalJourneyData = <String, dynamic>{};

    if (_isFlightMode) {
      if (parcelCategory == 'Small') {
         supportedCategories = ['Small'];
         priceMin = 449; priceMax = 449;
      } else if (parcelCategory == 'Medium') {
         supportedCategories = ['Small', 'Medium'];
         priceMin = 649; priceMax = 649;
      } else if (parcelCategory == 'Large') {
         supportedCategories = ['Small', 'Medium', 'Large'];
         priceMin = 949; priceMax = 949;
      }
      finalJourneyData['pricing_source'] = 'flight_rules';
    } else {
      if (parcelCategory == 'Small') {
        capacityLabel = 'Up to ${numericKg.toInt()} kg';
        supportedCategories = ['Small'];
      } else if (parcelCategory == 'Medium') {
        capacityLabel = 'Up to ${numericKg.toInt()} kg';
        supportedCategories = ['Small', 'Medium'];
      } else if (parcelCategory == 'Large') {
        capacityLabel = 'Up to ${numericKg.toInt()} kg';
        supportedCategories = ['Small', 'Medium', 'Large'];
      }
      finalJourneyData['pricing_source'] = 'non_flight_rules';
    }

    finalJourneyData['parcel_category'] = parcelCategory.toLowerCase();
    finalJourneyData['capacity_label'] = capacityLabel;
    finalJourneyData['supported_categories'] = supportedCategories;
    finalJourneyData['category_locked'] = true;
    finalJourneyData['length_in'] = lengthIn;
    finalJourneyData['width_in'] = widthIn;
    finalJourneyData['height_in'] = heightIn;
    finalJourneyData['weight_kg'] = numericKg;
    if (_isFlightMode) {
      finalJourneyData['price_min'] = priceMin;
      finalJourneyData['price_max'] = priceMax;
    }

    finalJourneyData['capacity'] = capacityLabel;
    finalJourneyData['capacity_kg'] = numericKg;
    finalJourneyData['dimensions'] = "${l.toStringAsFixed(0)}x${w.toStringAsFixed(0)}x${h.toStringAsFixed(0)} $_selectedUnit";
    finalJourneyData['dimension_length'] = l;
    finalJourneyData['dimension_width'] = w;
    finalJourneyData['dimension_height'] = h;
    finalJourneyData['dimension_unit'] = _selectedUnit;
    finalJourneyData['accepts_fragile'] = _acceptsFragile;
    
    provider.updateData(finalJourneyData);

    Navigator.push(context,
      MaterialPageRoute(
        builder: (_) => ParcelSizeSelectionPage(journeyData: provider.draftData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              color: Colors.white,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40, color: Colors.transparent,
                      child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      "Available Space & Weight",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // Progress
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Step 3 of 7", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                        child: const Text("Required", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 6, width: double.infinity,
                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(3)),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft, widthFactor: 0.43,
                      child: Container(decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(3))),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Available Luggage Space", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        IconButton(
                          icon: const Icon(Icons.info_outline, color: Color(0xFF94A3B8)),
                          onPressed: _showSpaceInfoModal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Unit Toggle — disabled for Flight (inches only)
                    if (!_isFlightMode)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            _buildUnitTab("Inches (in)", 'in'),
                            _buildUnitTab("Feet (ft)", 'ft'),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 16),
                            SizedBox(width: 8),
                            Text("Unit: Inches (in) — required for flight", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Dimension Inputs
                    _buildDimensionInput(
                      label: "Length", hint: "Longest side", controller: _lengthController, icon: Icons.straighten,
                      focusNode: _lengthFocus, textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_widthFocus),
                    ),
                    const SizedBox(height: 14),
                    _buildDimensionInput(
                      label: "Width", hint: "Front to back", controller: _widthController, icon: Icons.swap_horiz,
                      focusNode: _widthFocus, textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_heightFocus),
                    ),
                    const SizedBox(height: 14),
                    _buildDimensionInput(
                      label: "Height", hint: "Top to bottom", controller: _heightController, icon: Icons.height,
                      focusNode: _heightFocus, textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        FocusScope.of(context).unfocus();
                        Future.delayed(const Duration(milliseconds: 150), () {
                          if (!mounted) return;
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOutCubic,
                            );
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        _isFlightMode
                            ? "Maximum allowed: 18 inches per dimension (flight restriction)"
                            : "Larger dimensions (> 24 inches) classify as Large parcel",
                        style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Helper Example
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Example: A laptop bag is approximately 15 × 10 × 3 inches",
                              style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    // SECTION: Fragile Preference
                    _buildFragileToggle(),
                    const SizedBox(height: 16),

                    // SECTION 2: Weight Capacity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Maximum Weight Capacity", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        IconButton(
                          icon: const Icon(Icons.info_outline, color: Color(0xFF94A3B8)),
                          onPressed: _showWeightInfoModal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    ..._weightOptions.map((weight) {
                      final isSelected = _selectedWeight == weight['value'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedWeight = weight['value'] as String),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF05A4F).withValues(alpha: 0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? const Color(0xFFF05A4F) : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFF05A4F) : const Color(0xFFF05A4F).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(weight['icon'] as IconData, color: isSelected ? Colors.white : const Color(0xFFF05A4F), size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(weight['title'] as String, style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFFF05A4F) : const Color(0xFF0F172A))),
                                    const SizedBox(height: 2),
                                    Text(weight['subtitle'] as String, style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: isSelected ? const Color(0xFFF05A4F).withValues(alpha: 0.8) : const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(width: 20, height: 20, decoration: const BoxDecoration(color: Color(0xFFF05A4F), shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 14))
                              else
                                Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE2E8F0), width: 2))),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            
            // Realtime Category Indicator & Continue Button
            Container(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isFormValid && !_canContinue)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        "Scroll to review and continue",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF05A4F),
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 56, width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canContinue ? const Color(0xFFF05A4F) : const Color(0xFFCBD5E1),
                        foregroundColor: Colors.white,
                        elevation: _canContinue ? 4 : 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                      ),
                      onPressed: _canContinue ? _submitJourney : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            !_isFormValid 
                                ? "Fill all dimensions to continue" 
                                : (!_canContinue ? "Scroll to review and continue" : "Continue"),
                            style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (_canContinue) ...[const SizedBox(width: 8), const Icon(Icons.arrow_forward, size: 20)],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }



  Widget _buildUnitTab(String label, String value) {
    final isActive = _selectedUnit == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedUnit != value) {
            _convertAndClampValues(value);
            setState(() => _selectedUnit = value);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : [],
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500, color: isActive ? const Color(0xFFF05A4F) : const Color(0xFF64748B))),
        ),
      ),
    );
  }

  void _showSpaceInfoModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 48, height: 6, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(3))),
            ),
            const SizedBox(height: 24),
            const Text(
              "Available Space",
              style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            const Text(
              "We use your available space to match you with suitable parcels. You will only receive requests that fit your capacity.",
              style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF475569), height: 1.5),
            ),
            const SizedBox(height: 20),
            if (_smartDefaultsApplied)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Smart defaults set for $_travelModeLabel travel. Adjust if needed.",
                        style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            _buildLuggageVisual(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05A4F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Got It", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeightInfoModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 48, height: 6, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(3))),
            ),
            const SizedBox(height: 24),
            const Text(
              "Weight Capacity",
              style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            const Text(
              "Select the maximum extra weight you're comfortable carrying in your luggage. We'll use this to filter parcels and ensure they don't exceed your selected limits.",
              style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF475569), height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05A4F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Got It", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLuggageVisual() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF7ED), Color(0xFFFEF2F2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF05A4F).withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Luggage icon with dimension arrows
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: const Color(0xFFF05A4F).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.luggage, color: Color(0xFFF05A4F), size: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dimensionGuide("↔", "Length", "Longest side"),
                const SizedBox(height: 8),
                _dimensionGuide("↕", "Height", "Top to bottom"),
                const SizedBox(height: 8),
                _dimensionGuide("↗", "Width", "Front to back"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dimensionGuide(String arrow, String label, String desc) {
    return Row(
      children: [
        Text(arrow, style: const TextStyle(fontSize: 16, color: Color(0xFFF05A4F))),
        const SizedBox(width: 8),
        Text("$label ", style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        Text("— $desc", style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildDimensionInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required FocusNode focusNode,
    required TextInputAction textInputAction,
    required Function(String) onSubmitted,
  }) {
    final hasValue = controller.text.isNotEmpty && (double.tryParse(controller.text) ?? 0) > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            children: [
              Text(label.toUpperCase(), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B), letterSpacing: 0.5)),
              const SizedBox(width: 6),
              Text("($hint)", style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 11, color: Color(0xFF94A3B8))),
              const Spacer(),
              if (hasValue) const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 16),
            ],
          ),
        ),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hasValue ? const Color(0xFF16A34A).withValues(alpha: 0.3) : focusNode.hasFocus ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(icon, color: focusNode.hasFocus ? const Color(0xFF2563EB) : const Color(0xFFF05A4F).withValues(alpha: 0.5), size: 24),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: textInputAction,
                  onSubmitted: onSubmitted,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(hintText: "0", hintStyle: TextStyle(color: Color(0xFFCBD5E1)), border: InputBorder.none, contentPadding: EdgeInsets.zero),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 16),
                child: Text(_selectedUnit, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8))),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildFragileToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.wine_bar,
              color: Color(0xFFF05A4F),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Fragile Item",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Handle with extra care",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _acceptsFragile,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFF05A4F),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE2E8F0),
            onChanged: (value) {
              HapticFeedback.lightImpact();
              if (value) {
                _showFragileNoticePopup();
              } else {
                setState(() {
                  _acceptsFragile = false;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  void _showFragileNoticePopup() {
    setState(() {
      _acceptsFragile = true;
    });
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _buildFragileNoticeDialog(context);
      },
    );
  }

  Widget _buildFragileNoticeDialog(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF05A4F), size: 32),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Fragile Item Notice",
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "Please ensure you are not sending any prohibited item. Please read the Terms of Service before continuing.",
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05A4F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TermsOfServicePage()),
                  );
                },
                child: const Text(
                  "Read Terms of Service",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  "Continue",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
