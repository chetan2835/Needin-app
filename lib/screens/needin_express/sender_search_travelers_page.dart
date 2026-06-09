import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import 'sender_traveler_search_results_page.dart';
import '../../core/services/map_service.dart';
import '../../core/widgets/google_attribution.dart';
import '../../core/services/location_validation_service.dart';

/// ═══════════════════════════════════════════════════════════════
///  SEND YOUR PARCEL — Clean Search Form
///  3 fields only: Pickup · Drop · Date → Search → Results
///  Brand: Needin Coral (#F05A4F)
/// ═══════════════════════════════════════════════════════════════

// Needin brand coral — single source of truth for this flow
const Color _kCoral = Color(0xFFF05A4F);
const Color _kCoralLight = Color(0xFFFEF2F2);

class SenderSearchTravelersPage extends StatefulWidget {
  const SenderSearchTravelersPage({super.key});

  @override
  State<SenderSearchTravelersPage> createState() =>
      _SenderSearchTravelersPageState();
}

class _SenderSearchTravelersPageState extends State<SenderSearchTravelersPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _pickupLocation;
  Map<String, dynamic>? _dropLocation;
  DateTime? _selectedDate;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────

  bool get _isFormValid =>
      _pickupLocation != null &&
      _dropLocation != null &&
      _selectedDate != null;

  String get _dateDisplay {
    if (_selectedDate == null) return '';
    return DateFormat("EEEE, MMMM d, yyyy").format(_selectedDate!);
  }

  // ── Location Search Modal ───────────────────────────────────

  void _showLocationSearch(bool isPickup) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LocationSearchModal(
        isPickup: isPickup,
        onSelect: (location) async {
          // India-only validation
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          final scaffoldCtx = context; // capture before async
          final isValid =
              await LocationValidationService.isCoordinatesInIndia(lat, lng);
          if (!isValid) {
            if (scaffoldCtx.mounted) {
              LocationValidationService.showIndiaOnlyRestrictionDialog(scaffoldCtx);
            }
            return;
          }
          setState(() {
            if (isPickup) {
              _pickupLocation = location;
            } else {
              _dropLocation = location;
            }
          });
        },
      ),
    );
  }

  // ── Date Picker ─────────────────────────────────────────────

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxDate = today.add(const Duration(days: 15));
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate != null && _selectedDate!.isBefore(maxDate) ? _selectedDate! : today,
      firstDate: today,
      lastDate: maxDate, // ← Max 15 days from today
      helpText: 'Select Travel Date (Max 15 days ahead)',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _kCoral,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF0F172A),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _kCoral),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  // ── Search Action ───────────────────────────────────────────

  void _onSearch() {
    if (_pickupLocation == null) {
      _showValidation('Please select a pickup location');
      return;
    }
    if (_dropLocation == null) {
      _showValidation('Please select a drop location');
      return;
    }
    if (_selectedDate == null) {
      _showValidation('Please select a date');
      return;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    if (_selectedDate!.isBefore(todayStart)) {
      _showValidation('Please select a future date');
      return;
    }

    HapticFeedback.mediumImpact();

    final Map<String, dynamic> searchData = {
      'pickup_city': _pickupLocation?['city'] ?? _pickupLocation?['name'],
      'pickup_lat': _pickupLocation?['lat'],
      'pickup_lng': _pickupLocation?['lng'],
      'drop_city': _dropLocation?['city'] ?? _dropLocation?['name'],
      'drop_lat': _dropLocation?['lat'],
      'drop_lng': _dropLocation?['lng'],
      'date': _selectedDate?.toIso8601String(),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SenderTravelerSearchResultsPage(parcelData: searchData),
      ),
    );
  }

  void _showValidation(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _kCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── BUILD ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── App Bar ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.centerLeft,
                      child: const Icon(Icons.arrow_back,
                          color: Color(0xFF0F172A)),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      "Send Your Parcel",
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

            // ── Content ──
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero tagline
                      const Text(
                        "Find a traveler\nfor your parcel",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Enter your route and date to search available travelers.",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Form Card ──
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // ── Pickup ──
                            _buildLocationField(
                              label: "Pickup Location",
                              hint: "Where should the parcel be picked up?",
                              icon: Icons.radio_button_checked,
                              iconColor: _kCoral,
                              location: _pickupLocation,
                              onTap: () => _showLocationSearch(true),
                            ),

                            // Connector line
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 15, top: 0, bottom: 0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 2,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          _kCoral.withValues(alpha: 0.6),
                                          _kCoral.withValues(alpha: 0.2),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ── Drop ──
                            _buildLocationField(
                              label: "Drop Location",
                              hint: "Where should the parcel be delivered?",
                              icon: Icons.location_on,
                              iconColor: _kCoral,
                              location: _dropLocation,
                              onTap: () => _showLocationSearch(false),
                            ),

                            const SizedBox(height: 20),
                            const Divider(
                                height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 20),

                            // ── Date ──
                            _buildDateField(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 120), // buffer for bottom button
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Search CTA ──
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
            ),
          ],
        ),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.search, size: 22),
            label: const Text(
              "Search Travelers",
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFormValid
                  ? _kCoral
                  : const Color(0xFFCBD5E1),
              foregroundColor: Colors.white,
              elevation: _isFormValid ? 6 : 0,
              shadowColor: _kCoral.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _isFormValid ? _onSearch : () {
              _onSearch(); // will trigger validation messages
            },
          ),
        ),
      ),
    );
  }

  // ── Location Field Widget ───────────────────────────────────

  Widget _buildLocationField({
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    Map<String, dynamic>? location,
    required VoidCallback onTap,
  }) {
    final bool hasValue = location != null;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: hasValue
                  ? _kCoralLight
                  : const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasValue ? _kCoral : const Color(0xFF94A3B8),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: hasValue ? _kCoralLight : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasValue ? _kCoral.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    hasValue ? (location['name'] ?? hint) : hint,
                    style: TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 14,
                      fontWeight:
                          hasValue ? FontWeight.w600 : FontWeight.w400,
                      color: hasValue
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Date Field Widget ───────────────────────────────────────

  Widget _buildDateField() {
    final bool hasValue = _selectedDate != null;
    return GestureDetector(
      onTap: _pickDate,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: hasValue
                  ? _kCoralLight
                  : const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: _kCoral,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Date",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasValue ? _kCoral : const Color(0xFF94A3B8),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: hasValue ? _kCoralLight : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasValue ? _kCoral.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        hasValue ? _dateDisplay : "Select a date",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 14,
                          fontWeight:
                              hasValue ? FontWeight.w600 : FontWeight.w400,
                          color: hasValue
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: hasValue
                            ? _kCoral
                            : const Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
///  LOCATION AUTOCOMPLETE MODAL
///  Google Places API → clean suggestion list, no map preview
/// ═══════════════════════════════════════════════════════════════
class _LocationSearchModal extends StatefulWidget {
  final bool isPickup;
  final Function(Map<String, dynamic>) onSelect;

  const _LocationSearchModal({
    required this.isPickup,
    required this.onSelect,
  });

  @override
  State<_LocationSearchModal> createState() => _LocationSearchModalState();
}

class _LocationSearchModalState extends State<_LocationSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  List<dynamic> _predictions = [];

  @override
  void initState() {
    super.initState();
    MapService.startNewSearchSession();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.isEmpty) {
      setState(() {
        _predictions = [];
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isLoading = true);
      final result = await MapService.getAutocomplete(query);
      if (mounted) {
        setState(() {
          _predictions = result.predictions;
          _isLoading = false;
        });
        if (result.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('API: ${result.error}'),
                backgroundColor: Colors.red),
          );
        }
      }
    });
  }

  Future<void> _fetchPlaceDetails(String placeId, String mainText) async {
    setState(() => _isLoading = true);
    final location = await MapService.getPlaceDetails(placeId);
    if (!mounted) return;
    if (location != null) {
      // Extract city from the place name / structured_formatting
      // mainText is the 'main_text' from Google (usually the city or area name)
      // We'll use MapService.extractCityFromName to normalise it
      final cityName = MapService.extractCityName(mainText, location.address);
      debugPrint('✅ [Place Selected] city=$cityName | ${location.lat}, ${location.lng}');
      widget.onSelect({
        'name': cityName.isNotEmpty ? cityName : mainText,
        'city': cityName,
        'lat': location.lat,
        'lng': location.lng,
        'placeId': placeId,
      });
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not fetch location details. Try again.')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 4));

      final location =
          await MapService.reverseGeocode(position.latitude, position.longitude);
      if (location != null && mounted) {
        final cityName = MapService.extractCityName(location.name, location.address);
        widget.onSelect({
          'name': cityName.isNotEmpty ? cityName : location.name,
          'city': cityName,
          'lat': location.lat,
          'lng': location.lng,
          'placeId': location.placeId,
        });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Failed to detect GPS location. Check permissions."),
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  widget.isPickup
                      ? Icons.radio_button_checked
                      : Icons.location_on,
                  color: _kCoral,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.isPickup ? "Set Pickup" : "Set Drop",
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              cursorColor: _kCoral,
              decoration: InputDecoration(
                hintText: "Search city or area...",
                hintStyle: const TextStyle(
                  fontFamily: "Plus Jakarta Sans",
                  color: Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _predictions.clear();
                    });
                  },
                ),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kCoral, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _kCoral),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _predictions.length + 1,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return ListTile(
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _kCoralLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.my_location,
                                      color: _kCoral, size: 18),
                                ),
                                title: const Text(
                                  "Use Current Location",
                                  style: TextStyle(
                                    fontFamily: "Plus Jakarta Sans",
                                    fontWeight: FontWeight.bold,
                                    color: _kCoral,
                                  ),
                                ),
                                onTap: _useCurrentLocation,
                              );
                            }
                            final item = _predictions[index - 1];
                            final mainText = item['structured_formatting']
                                ['main_text'];
                            final secondaryText =
                                item['structured_formatting']
                                        ['secondary_text'] ??
                                    '';
                            return ListTile(
                              leading: const Icon(
                                Icons.place,
                                color: Color(0xFF64748B),
                              ),
                              title: Text(
                                mainText,
                                style: const TextStyle(
                                  fontFamily: "Plus Jakarta Sans",
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Text(
                                secondaryText,
                                style: const TextStyle(
                                  fontFamily: "Plus Jakarta Sans",
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              onTap: () => _fetchPlaceDetails(
                                  item['place_id'], mainText),
                            );
                          },
                        ),
                      ),
                      // Required by Google Maps Platform ToS
                      if (_predictions.isNotEmpty) const GoogleAttribution(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
