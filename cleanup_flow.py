import re

with open('lib/screens/needin_express/sender_search_travelers_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace imports
content = re.sub(
    r"import 'sender_parcel_info_page\.dart';\nimport '../../core/services/map_service\.dart';\nimport '../../core/services/pricing_service\.dart';\nimport '../../core/data/pricing_slabs\.dart';\nimport '../../core/models/pricing_result\.dart';\nimport '../../core/widgets/pricing_display_card\.dart';",
    "import 'sender_traveler_search_results_page.dart';\nimport '../../core/services/map_service.dart';",
    content
)

# Replace imports if previous missed because of formatting
content = content.replace("import 'sender_parcel_info_page.dart';", "import 'sender_traveler_search_results_page.dart';")
content = content.replace("import '../../core/services/pricing_service.dart';", "")
content = content.replace("import '../../core/data/pricing_slabs.dart';", "")
content = content.replace("import '../../core/models/pricing_result.dart';", "")
content = content.replace("import '../../core/widgets/pricing_display_card.dart';", "")

# Remove state variables related to parcel size, weight, pricing
content = re.sub(r"String _selectedSize = 'medium';\n\s*final TextEditingController _weightController = TextEditingController\(\);\n", "", content)
content = re.sub(r"// Pricing state\n\s*PricingResult\? _currentPricing;\n\s*Map<ParcelSize, PricingResult>\? _allSizePrices;\n\s*bool _isPricingLoading = false;\n\s*final PricingService _pricingService = PricingService\(\);\n", "", content)

# Remove _weightController.dispose()
content = re.sub(r"_weightController\.dispose\(\);\n\s*", "", content)

# Remove _calculatePricing call
content = re.sub(r"// Trigger pricing calculation\n\s*_calculatePricing\(\);\n", "", content)

# Remove _calculatePricing and _onParcelSizeChanged methods
# They start at "// ── PRICING CALCULATION ──" and end before "@override\n  Widget build"
content = re.sub(r"// ── PRICING CALCULATION ──.*?@override\s+Widget build", "@override\n  Widget build", content, flags=re.DOTALL)

# Remove PricingDisplayCard block
content = re.sub(r"// ── LIVE PRICING CARD ──.*?const SizedBox\(height: 16\);", "", content, flags=re.DOTALL)

# Remove Size & Weight block
content = re.sub(r"/// Size & Weight.*?const SizedBox\(height: 100\);", "const SizedBox(height: 100);", content, flags=re.DOTALL)

# Replace BottomSheet button
new_button = """SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.search, size: 24),
            label: const Text(
              "Search",
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF05A4F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              if (_pickupLocation == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select pickup location')));
                return;
              }
              if (_dropLocation == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select drop location')));
                return;
              }
              if (_selectedDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select journey date')));
                return;
              }
              
              final Map<String, dynamic> initialData = {
                'pickup_city': _pickupLocation?['city'] ?? _pickupLocation?['name'],
                'pickup_lat': _pickupLocation?['lat'],
                'pickup_lng': _pickupLocation?['lng'],
                'drop_city': _dropLocation?['city'] ?? _dropLocation?['name'],
                'drop_lat': _dropLocation?['lat'],
                'drop_lng': _dropLocation?['lng'],
                'distanceKM': _distanceKM,
                'duration': _durationStr,
                'date': _selectedDate?.toIso8601String(),
                'time': _selectedTime?.format(context),
                'timestamp': _finalTimestamp,
              };
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SenderTravelerSearchResultsPage(parcelData: initialData),
                ),
              );
            },
          ),
        )"""

content = re.sub(r"SizedBox\(\n\s*height: 56,\n\s*width: double\.infinity,\n\s*child: ElevatedButton\([\s\S]*?child: const Text\([\s\S]*?\"CONTINUE\",[\s\S]*?\),\n\s*\),\n\s*\)", new_button, content)

with open('lib/screens/needin_express/sender_search_travelers_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
