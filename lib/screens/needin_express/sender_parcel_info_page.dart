import 'package:flutter/material.dart';
import 'sender_traveler_search_results_page.dart';
import '../../core/services/supabase_service.dart';

class SenderParcelInfoPage extends StatefulWidget {
  final Map<String, dynamic> parcelData;

  const SenderParcelInfoPage({super.key, required this.parcelData});

  @override
  State<SenderParcelInfoPage> createState() => _SenderParcelInfoPageState();
}

class _SenderParcelInfoPageState extends State<SenderParcelInfoPage> {
  String _selectedCategory = 'Books';
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  bool _isFragile = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Books', 'icon': Icons.menu_book},
    {'name': 'Grocery', 'icon': Icons.shopping_bag},
    {'name': 'Toys', 'icon': Icons.smart_toy},
    {'name': 'Electronics', 'icon': Icons.devices},
    {'name': 'Clothing', 'icon': Icons.checkroom},
    {'name': 'Documents', 'icon': Icons.description},
    {'name': 'Furniture', 'icon': Icons.chair},
    {'name': 'Other', 'icon': Icons.category},
  ];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (_isSubmitting) return; // double-tap shield

    final lText = _lengthController.text.trim();
    final wText = _widthController.text.trim();
    final hText = _heightController.text.trim();
    final weightText = _weightController.text.trim();

    if (lText.isEmpty || wText.isEmpty || hText.isEmpty || weightText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all dimensions and weight'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final l = double.tryParse(lText) ?? 0.0;
    final w = double.tryParse(wText) ?? 0.0;
    final h = double.tryParse(hText) ?? 0.0;
    final wgt = double.tryParse(weightText) ?? 0.0;

    if (wgt > 30) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wait! Maximum allowed parcel weight is 30 kg.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final maxDim = [l, w, h].reduce((a, b) => a > b ? a : b);
    if (maxDim > 60) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wait! Maximum allowed dimension is 60.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Create idempotency key securely without external package locally
      final idempotencyKey = DateTime.now().millisecondsSinceEpoch.toString() + (l + w + h + wgt).toString();

      // Remote validation against the strict parcel-engine on Edge Function
      final classificationResult = await SupabaseService().classifyParcel(
        length: l,
        width: w,
        height: h,
        weight: wgt,
        idempotencyKey: idempotencyKey,
      );

      final parcelCategory = classificationResult['category'];

      if (!mounted) return;

      final updatedData = Map<String, dynamic>.from(widget.parcelData);
      updatedData['user_assigned_category'] = _selectedCategory;
      updatedData['system_category'] = parcelCategory; // Verified by backend!
      updatedData['description'] = _descController.text.trim();
      updatedData['weight'] = wgt.toStringAsFixed(2); // Sanitize rounding logic
      updatedData['dimensions'] = "${l.toStringAsFixed(1)}x${w.toStringAsFixed(1)}x${h.toStringAsFixed(1)} in"; // Explicit units
      updatedData['is_fragile'] = _isFragile;
      updatedData['idempotency_key'] = idempotencyKey;

      Navigator.push(context,
        MaterialPageRoute(
          builder: (_) => SenderTravelerSearchResultsPage(parcelData: updatedData),
        ),
      );
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        // Clean up the ugly raw developer exception string into beautiful text
        if (errorMsg.contains('Parcel exceeds allowed limits')) {
          errorMsg = "Sorry! This parcel exceeds our maximum system limits (Max 30kg, 60in).";
        } else if (errorMsg.contains('details: {')) {
          final regex = RegExp(r'error:\s*([^}]+)');
          final match = regex.firstMatch(errorMsg);
          if (match != null) {
            errorMsg = match.group(1) ?? "A network error occurred";
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg.replaceAll('FunctionException', '').replaceAll('Exception:', '').trim()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            /// Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const Text(
                    "Parcel Information",
                    style: TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 40), // spacer for centering
                ],
              ),
            ),

            /// Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildProgressDot(true),
                      const SizedBox(width: 8),
                      _buildProgressDot(true, isCurrent: true), // Step 2
                      const SizedBox(width: 8),
                      _buildProgressDot(false),
                      const SizedBox(width: 8),
                      _buildProgressDot(false),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Step 2 of 4",
                    style: TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  )
                ],
              ),
            ),

            /// Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Category Selection
                    const Text(
                      "What are you sending?",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat['name'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = cat['name']!;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFF27F0D).withValues(alpha: 0.05) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFFE2E8F0),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  cat['icon'],
                                  size: 32,
                                  color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFF475569),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  cat['name']!,
                                  style: TextStyle(
                                    fontFamily: "Plus Jakarta Sans",
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    /// Description Section
                    const Text(
                      "Description",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Stack(
                        children: [
                          TextField(
                            controller: _descController,
                            maxLines: 4,
                            maxLength: 200,
                            style: const TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: const InputDecoration(
                              hintText: "e.g. A box of vintage books...",
                              hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                              counterText: "", // handled custom below
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          Positioned(
                            bottom: 12,
                            right: 16,
                            child: Text(
                              "${_descController.text.length}/200",
                              style: const TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    /// Measurements & Weight Section
                    const Text(
                      "Measurements & Weight",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Total Weight
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Total Weight",
                                style: TextStyle(
                                  fontFamily: "Plus Jakarta Sans",
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFAFA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: TextField(
                                  controller: _weightController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    fontFamily: "Plus Jakarta Sans",
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: "0",
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(12),
                                    suffixIcon: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Text(
                                        "kg",
                                        style: TextStyle(
                                          fontFamily: "Plus Jakarta Sans",
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    suffixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Dimensions
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Expanded(child: _buildDimensionInput("L", _lengthController)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildDimensionInput("W", _widthController)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildDimensionInput("H", _heightController)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    /// Fragile Toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.broken_image, color: Color(0xFFF27F0D), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    "Fragile Item",
                                    style: TextStyle(
                                      fontFamily: "Plus Jakarta Sans",
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Handle with care",
                                    style: TextStyle(
                                      fontFamily: "Plus Jakarta Sans",
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _isFragile,
                            onChanged: (val) => setState(() => _isFragile = val),
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFFF27F0D),
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: const Color(0xFFE2E8F0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    /// Prohibited items info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF), // blue-50
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDBEAFE)), // blue-100
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info, color: Color(0xFF2563EB), size: 20), // blue-600
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: const TextSpan(
                                    style: TextStyle(
                                      fontFamily: "Plus Jakarta Sans",
                                      fontSize: 14,
                                      color: Color(0xFF334155),
                                      height: 1.4,
                                    ),
                                    children: [
                                      TextSpan(text: "Please ensure you are not sending "),
                                      TextSpan(text: "prohibited items", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                                      TextSpan(text: " like explosives or flammables."),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {},
                                  child: const Text(
                                    "Read Policy",
                                    style: TextStyle(
                                      fontFamily: "Plus Jakarta Sans",
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 120), // padding for floating footer
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSubmitting ? null : _submitData,
            child: _isSubmitting 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  "SEND REQUEST",
                  style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold),
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDot(bool isFilled, {bool isCurrent = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 6,
      width: isCurrent ? 32 : 32,
      decoration: BoxDecoration(
        color: isFilled ? const Color(0xFFF27F0D) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildDimensionInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14),
            decoration: const InputDecoration(
              hintText: "in",
              hintStyle: TextStyle(color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }
}
