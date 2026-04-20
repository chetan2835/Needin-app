import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'sender_parcel_info_page.dart';
import '../../core/services/map_service.dart';
import '../../core/services/pricing_service.dart';
import '../../core/data/pricing_slabs.dart';
import '../../core/models/pricing_result.dart';
import '../../core/widgets/pricing_display_card.dart';
import '../../core/widgets/google_attribution.dart';

class SenderSearchTravelersPage extends StatefulWidget {
  const SenderSearchTravelersPage({super.key});

  @override
  State<SenderSearchTravelersPage> createState() =>
      _SenderSearchTravelersPageState();
}

class _SenderSearchTravelersPageState extends State<SenderSearchTravelersPage>
    with TickerProviderStateMixin {
  String _selectedSize = 'medium';
  final TextEditingController _weightController = TextEditingController();

  Map<String, dynamic>? _pickupLocation;
  Map<String, dynamic>? _dropLocation;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int? _finalTimestamp;

  double? _distanceKM;
  String? _durationStr;

  // Pricing state
  PricingResult? _currentPricing;
  Map<ParcelSize, PricingResult>? _allSizePrices;
  bool _isPricingLoading = false;
  final PricingService _pricingService = PricingService();

  // Map Controls — use mutable reference, NOT Completer (fixes rebuild bug)
  GoogleMapController? _googleMapController;
  final Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _fullRouteCoordinates = [];
  final List<LatLng> _animatedRouteCoordinates = [];
  Timer? _routeAnimator;
  bool _isLoadingRoute = false;

  // Pending bounds to apply when map is ready
  LatLngBounds? _pendingBounds;

  @override
  void dispose() {
    _weightController.dispose();
    _routeAnimator?.cancel();
    _googleMapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _googleMapController = controller;
    // If we have pending bounds from a route fetch, apply them now
    if (_pendingBounds != null) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _googleMapController != null) {
          _googleMapController!.moveCamera(
            CameraUpdate.newLatLngBounds(_pendingBounds!, 60),
          );
          _pendingBounds = null;
        }
      });
    }
  }

  Future<void> _fitBounds(LatLngBounds bounds) async {
    if (_googleMapController != null) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted && _googleMapController != null) {
        _googleMapController!.moveCamera(
          CameraUpdate.newLatLngBounds(bounds, 60),
        );
      }
    } else {
      _pendingBounds = bounds;
    }
  }

  Future<void> _fetchRouteAndAnimate() async {
    if (_pickupLocation == null || _dropLocation == null) return;

    // CRITICAL: Cast to double — fixes world-zoomed polyline bug
    final originLat = (_pickupLocation!['lat'] as num).toDouble();
    final originLng = (_pickupLocation!['lng'] as num).toDouble();
    final destLat = (_dropLocation!['lat'] as num).toDouble();
    final destLng = (_dropLocation!['lng'] as num).toDouble();

    debugPrint('\n📍 [Sender Route] $originLat,$originLng → $destLat,$destLng');

    setState(() {
      _isLoadingRoute = true;
      _markers.clear();
      _polylines.clear();
      _animatedRouteCoordinates.clear();
      _distanceKM = null;
      _durationStr = null;
    });

    // 1. Add Markers
    setState(() {
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(originLat, originLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: _pickupLocation!['name'] ?? 'Pickup'),
      ));
      _markers.add(Marker(
        markerId: const MarkerId('drop'),
        position: LatLng(destLat, destLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: _dropLocation!['name'] ?? 'Drop'),
      ));
    });

    // 2. Fetch route via centralized service
    final result = await MapService.getDirections(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      _distanceKM = result.distanceKm;
      _durationStr = result.durationText;
      _fullRouteCoordinates = result.polylinePoints;

      // Trigger pricing calculation
      _calculatePricing();

      // 3. Fit map to route bounds
      if (result.bounds != null) {
        await _fitBounds(result.bounds!);
      }

      // 4. Animate polyline drawing
      _routeAnimator?.cancel();
      int drawIndex = 0;
      int step = (_fullRouteCoordinates.length / 50).ceil().clamp(1, 10);

      _routeAnimator = Timer.periodic(const Duration(milliseconds: 15), (timer) {
        if (!mounted) { timer.cancel(); return; }
        if (drawIndex >= _fullRouteCoordinates.length) {
          timer.cancel();
          setState(() => _isLoadingRoute = false);
          return;
        }
        setState(() {
          _animatedRouteCoordinates.addAll(
            _fullRouteCoordinates.skip(drawIndex).take(step),
          );
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route_line'),
              color: const Color(0xFFF27F0D),
              width: 5,
              points: List.from(_animatedRouteCoordinates),
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          };
        });
        drawIndex += step;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Route error: ${result.error}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  // ── PRICING CALCULATION ──
  Future<void> _calculatePricing() async {
    if (_pickupLocation == null || _dropLocation == null) return;

    setState(() => _isPricingLoading = true);

    final originLat = (_pickupLocation!['lat'] as num).toDouble();
    final originLng = (_pickupLocation!['lng'] as num).toDouble();
    final destLat = (_dropLocation!['lat'] as num).toDouble();
    final destLng = (_dropLocation!['lng'] as num).toDouble();

    final parcelSize = _selectedSize == 'small'
        ? ParcelSize.small
        : _selectedSize == 'large'
            ? ParcelSize.large
            : ParcelSize.medium;

    try {
      // Fetch all 3 sizes in one API call (shared route data)
      final allPrices = await _pricingService.calculateAllSizes(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        originCity: _pickupLocation?['name']?.toString(),
        destCity: _dropLocation?['name']?.toString(),
      );

      if (!mounted) return;
      setState(() {
        _allSizePrices = allPrices;
        _currentPricing = allPrices[parcelSize];
        _isPricingLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPricingLoading = false);
      debugPrint('Pricing error: $e');
    }
  }

  void _onParcelSizeChanged(String newSize) {
    setState(() {
      _selectedSize = newSize;
      if (_allSizePrices != null) {
        final parcelSize = newSize == 'small'
            ? ParcelSize.small
            : newSize == 'large'
                ? ParcelSize.large
                : ParcelSize.medium;
        _currentPricing = _allSizePrices![parcelSize];
      }
    });
  }

  void _showLocationSearch(bool isPickup) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationSearchModal(
        isPickup: isPickup,
        onSelect: (location) {
          setState(() {
            if (isPickup) {
              _pickupLocation = location;
            } else {
              _dropLocation = location;
            }
          });
          _fetchRouteAndAnimate();
        },
      ),
    );
  }

  void _showLocationBottomSheet(LatLng location, PlaceLocation place) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              place.name,
              style: const TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              place.address,
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 13,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.trip_origin, size: 18),
                    label: const Text('Set as Pickup'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF27F0D),
                      side: const BorderSide(color: Color(0xFFF27F0D)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _pickupLocation = {
                          'name': place.name,
                          'city': '',
                          'lat': place.lat,
                          'lng': place.lng,
                          'placeId': place.placeId,
                        };
                      });
                      _fetchRouteAndAnimate();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.location_on, size: 18),
                    label: const Text('Set as Drop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF27F0D),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _dropLocation = {
                          'name': place.name,
                          'city': '',
                          'lat': place.lat,
                          'lng': place.lng,
                          'placeId': place.placeId,
                        };
                      });
                      _fetchRouteAndAnimate();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDateTimePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DateTimePickerModal(
        initialDate: _selectedDate,
        initialTime: _selectedTime,
        onSelect: (date, time, timestamp) {
          setState(() {
            _selectedDate = date;
            _selectedTime = time;
            _finalTimestamp = timestamp;
          });
        },
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
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.centerLeft,
                      child: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const Text(
                    "Send Your Parcel",
                    style: TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            /// Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    /// Route Details Container
                    _buildSectionContainer(
                      title: "Route Details",
                      icon: Icons.map,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 17,
                            top: 40,
                            bottom: 40,
                            child: Container(
                              width: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFF27F0D),
                                    Colors.red.shade500,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLocationTile(
                                label: "Pickup Location",
                                icon: Icons.radio_button_checked,
                                iconColor: const Color(0xFFF27F0D),
                                location: _pickupLocation,
                                hint: "Search pickup address...",
                                onTap: () => _showLocationSearch(true),
                              ),
                              const SizedBox(height: 16),
                              _buildLocationTile(
                                label: "Drop Location",
                                icon: Icons.location_on,
                                iconColor: Colors.red.shade500,
                                location: _dropLocation,
                                hint: "Search drop address...",
                                onTap: () => _showLocationSearch(false),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    /// Full Map Viewer
                    if (_pickupLocation != null || _dropLocation != null)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(top: 16),
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(
                                  _pickupLocation != null
                                      ? _pickupLocation!['lat']
                                      : 20.5937,
                                  _pickupLocation != null
                                      ? _pickupLocation!['lng']
                                      : 78.9629,
                                ),
                                zoom: 11,
                              ),
                              markers: _markers,
                              polylines: _polylines,
                              myLocationEnabled: true,
                              myLocationButtonEnabled: true,
                              zoomControlsEnabled: false,
                              mapToolbarEnabled: false,
                              onMapCreated: _onMapCreated,
                              onTap: (LatLng tappedLocation) async {
                                final place = await MapService.reverseGeocode(
                                  tappedLocation.latitude,
                                  tappedLocation.longitude,
                                );
                                if (place != null && mounted) {
                                  _showLocationBottomSheet(tappedLocation, place);
                                }
                              },
                            ),
                            if (_isLoadingRoute)
                              Container(
                                color: Colors.white.withValues(alpha: 0.7),
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(
                                  color: Color(0xFFF27F0D),
                                ),
                              ),
                          ],
                        ),
                      ),

                    if (_distanceKM != null &&
                        _durationStr != null &&
                        !_isLoadingRoute)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF27F0D,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.timer,
                                    size: 14,
                                    color: Color(0xFFF27F0D),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "$_durationStr (${_distanceKM!.toStringAsFixed(1)} KM)",
                                    style: const TextStyle(
                                      fontFamily: "Plus Jakarta Sans",
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF27F0D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── LIVE PRICING CARD ──
                    if (_isPricingLoading ||
                        (_currentPricing != null && _distanceKM != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: PricingDisplayCard(
                          pricing: _currentPricing,
                          isLoading: _isPricingLoading,
                          allSizePrices: _allSizePrices,
                          selectedSize: _selectedSize == 'small'
                              ? ParcelSize.small
                              : _selectedSize == 'large'
                                  ? ParcelSize.large
                                  : ParcelSize.medium,
                          onSizeChanged: (size) {
                            _onParcelSizeChanged(size.name);
                          },
                        ),
                      ),

                    const SizedBox(height: 16),

                    /// Premium Schedule Calendar Tool
                    _buildSectionContainer(
                      title: "Schedule",
                      icon: Icons.schedule,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showDateTimePicker();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedDate == null
                                ? const Color(0xFFFAFAFA)
                                : const Color(
                                    0xFFF27F0D,
                                  ).withValues(alpha: 0.05),
                            border: Border.all(
                              color: _selectedDate == null
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFFF27F0D),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedDate != null
                                        ? DateFormat(
                                            'EEEE, MMM d, yyyy',
                                          ).format(_selectedDate!)
                                        : "Pick a date & time",
                                    style: TextStyle(
                                      fontFamily: "Plus Jakarta Sans",
                                      fontSize: 16,
                                      color: _selectedDate != null
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_selectedTime != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      "At ${_selectedTime!.format(context)}",
                                      style: const TextStyle(
                                        fontFamily: "Plus Jakarta Sans",
                                        fontSize: 13,
                                        color: Color(0xFFF27F0D),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// Size & Weight
                    _buildSectionContainer(
                      title: "Parcel Specs",
                      icon: Icons.inventory_2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildSizeOption(
                                  'small',
                                  Icons.key,
                                  'Small',
                                  'Keys, Docs',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSizeOption(
                                  'medium',
                                  Icons.shopping_bag,
                                  'Medium',
                                  'Shoebox',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSizeOption(
                                  'large',
                                  Icons.luggage,
                                  'Large',
                                  'Suitcase',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _weightController,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                hintText: "Est. Weight",
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: const Text(
                                      "kg",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
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
            ),
          ],
        ),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF27F0D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              // Send perfectly constructed JSON to the next page
              final Map<String, dynamic> initialData = {
                'pickup_city':
                    _pickupLocation?['city'] ?? _pickupLocation?['name'],
                'pickup_lat': _pickupLocation?['lat'],
                'pickup_lng': _pickupLocation?['lng'],
                'drop_city': _dropLocation?['city'] ?? _dropLocation?['name'],
                'drop_lat': _dropLocation?['lat'],
                'drop_lng': _dropLocation?['lng'],
                'distanceKM': _distanceKM,
                'duration': _durationStr,
                'weight_estimate': _weightController.text,
                'size': _selectedSize,
                'price': _currentPricing?.price,
                'pricing_type': _currentPricing?.pricingType.name,
                'pricing_breakdown': _currentPricing?.breakdown.toJson(),
                'date': _selectedDate?.toIso8601String(),
                'time': _selectedTime?.format(context),
                'timestamp': _finalTimestamp,
              };
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SenderParcelInfoPage(parcelData: initialData),
                ),
              );
            },
            child: const Text(
              "CONTINUE",
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFF27F0D)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildLocationTile({
    required String label,
    required IconData icon,
    required Color iconColor,
    Map<String, dynamic>? location,
    required String hint,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 40, bottom: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 1,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Row(
            children: [
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: location == null
                        ? const Color(0xFFFAFAFA)
                        : Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    location != null ? location['name'] : hint,
                    style: TextStyle(
                      fontWeight: location != null
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: location != null
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSizeOption(
    String value,
    IconData icon,
    String title,
    String subtitle,
  ) {
    bool isSelected = _selectedSize == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _onParcelSizeChanged(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF27F0D).withValues(alpha: 0.05)
              : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF27F0D)
                : const Color(0xFFE2E8F0),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? const Color(0xFFF27F0D)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? const Color(0xFFF27F0D)
                    : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

}

/// ---------------------------------------------------------
/// LOCATION AUTOCOMPLETE API MODAL
/// Connects precisely to Google Places API -> Google Geocode
/// ---------------------------------------------------------
class LocationSearchModal extends StatefulWidget {
  final bool isPickup;
  final Function(Map<String, dynamic>) onSelect;

  const LocationSearchModal({
    super.key,
    required this.isPickup,
    required this.onSelect,
  });

  @override
  State<LocationSearchModal> createState() => _LocationSearchModalState();
}

class _LocationSearchModalState extends State<LocationSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  List<dynamic> _predictions = [];

  @override
  void initState() {
    super.initState();
    MapService.startNewSearchSession(); // Reset billing session on modal open
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
            SnackBar(content: Text('API: ${result.error}'), backgroundColor: Colors.red),
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
      debugPrint('✅ [Place Selected] ${location.name} → ${location.lat}, ${location.lng}');
      widget.onSelect({
        'name': mainText,
        'city': '',
        'lat': location.lat,
        'lng': location.lng,
        'placeId': placeId,
      });
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch location details. Try again.')),
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

      final location = await MapService.reverseGeocode(position.latitude, position.longitude);
      if (location != null && mounted) {
        widget.onSelect({
          'name': location.name,
          'city': 'Detected',
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
            content: Text("Failed to detect GPS location. Check permissions."),
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
                  color: widget.isPickup ? const Color(0xFFF27F0D) : Colors.red,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.isPickup ? "Set Pickup" : "Set Drop",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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
              decoration: InputDecoration(
                hintText: "Search city or area...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
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
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF27F0D)),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _predictions.length + 1,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return ListTile(
                                leading: const Icon(
                                  Icons.my_location,
                                  color: Color(0xFF2563EB),
                                ),
                                title: const Text(
                                  "Use Current Location",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                onTap: _useCurrentLocation,
                              );
                            }
                            final item = _predictions[index - 1];
                            final mainText =
                                item['structured_formatting']['main_text'];
                            final secondaryText =
                                item['structured_formatting']['secondary_text'] ?? '';
                            return ListTile(
                              leading: const Icon(
                                Icons.place,
                                color: Color(0xFF64748B),
                              ),
                              title: Text(
                                mainText,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                secondaryText,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () =>
                                  _fetchPlaceDetails(item['place_id'], mainText),
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

/// ---------------------------------------------------------
/// PREMIUM CALENDAR MODAL
/// Keeps the amazing custom layout intact
/// ---------------------------------------------------------
class DateTimePickerModal extends StatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final Function(DateTime date, TimeOfDay time, int timestamp) onSelect;

  const DateTimePickerModal({
    super.key,
    this.initialDate,
    this.initialTime,
    required this.onSelect,
  });

  @override
  State<DateTimePickerModal> createState() => _DateTimePickerModalState();
}

class _DateTimePickerModalState extends State<DateTimePickerModal> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  final PageController _monthController = PageController();
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedTime = widget.initialTime ?? TimeOfDay.now();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  void _onQuickSelect(int daysAdd) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedDate = DateTime.now().add(Duration(days: daysAdd));
      _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
    });
  }

  List<String> get _timeSlots {
    List<String> slots = [];
    final now = DateTime.now();
    final isToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    for (int h = 0; h < 24; h++) {
      for (int m = 0; m < 60; m += 15) {
        if (isToday && (h < now.hour || (h == now.hour && m <= now.minute))) {
          continue;
        }
        slots.add(
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
        );
      }
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "When?",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildChip("Today", 0),
                const SizedBox(width: 8),
                _buildChip("Tomorrow", 1),
                const SizedBox(width: 8),
                _buildChip("In 2 Days", 2),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_currentMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(
                        () => _currentMonth = DateTime(
                          _currentMonth.year,
                          _currentMonth.month - 1,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(
                        () => _currentMonth = DateTime(
                          _currentMonth.year,
                          _currentMonth.month + 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                  .map(
                    (d) => SizedBox(
                      width: 32,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _monthController,
              itemBuilder: (context, index) => _buildMonthGrid(_currentMonth),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Time",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _timeSlots.length,
                    itemBuilder: (context, index) {
                      final slot = _timeSlots[index];
                      bool isSelected =
                          _selectedTime.format(context) == slot ||
                          (slot ==
                              '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}');
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(
                            () => _selectedTime = TimeOfDay(
                              hour: int.parse(slot.split(':')[0]),
                              minute: int.parse(slot.split(':')[1]),
                            ),
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFE2E8F0),
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            slot,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF27F0D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  final dt = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                    _selectedTime.hour,
                    _selectedTime.minute,
                  );
                  widget.onSelect(
                    _selectedDate,
                    _selectedTime,
                    dt.millisecondsSinceEpoch ~/ 1000,
                  );
                  Navigator.pop(context);
                },
                child: const Text(
                  "Save Schedule",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(DateTime month) {
    int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    int firstWeekday = DateTime(month.year, month.month, 1).weekday % 7;
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: daysInMonth + firstWeekday,
      itemBuilder: (context, index) {
        if (index < firstWeekday) return const SizedBox();
        int day = index - firstWeekday + 1;
        DateTime date = DateTime(month.year, month.month, day);
        bool isPast = date.isBefore(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        );
        bool isSelected =
            _selectedDate.year == date.year &&
            _selectedDate.month == date.month &&
            _selectedDate.day == date.day;
        return GestureDetector(
          onTap: isPast
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedDate = date);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF27F0D) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              day.toString(),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isPast
                    ? const Color(0xFFCBD5E1)
                    : (isSelected ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChip(String label, int daysAdd) {
    DateTime target = DateTime.now().add(Duration(days: daysAdd));
    bool isSel =
        _selectedDate.year == target.year &&
        _selectedDate.month == target.month &&
        _selectedDate.day == target.day;
    return GestureDetector(
      onTap: () => _onQuickSelect(daysAdd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
          border: Border.all(
            color: isSel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isSel ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
