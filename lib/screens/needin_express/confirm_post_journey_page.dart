import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/map_service.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_provider.dart';
import 'journey_posted_success_page.dart';

class ConfirmPostJourneyPage extends StatefulWidget {
  final Map<String, dynamic> journeyData;

  const ConfirmPostJourneyPage({super.key, required this.journeyData});

  @override
  State<ConfirmPostJourneyPage> createState() => _ConfirmPostJourneyPageState();
}

class _ConfirmPostJourneyPageState extends State<ConfirmPostJourneyPage>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLngBounds? _bounds;

  // Staggered animation controllers
  late AnimationController _staggerController;
  late List<Animation<double>> _cardFades;
  late List<Animation<Offset>> _cardSlides;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Create staggered animations for 5 cards
    _cardFades = List.generate(5, (i) {
      final start = i * 0.15;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOut)),
      );
    });
    _cardSlides = List.generate(5, (i) {
      final start = i * 0.15;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOutCubic)),
      );
    });

    _staggerController.forward();
    _setupMap();
  }

  void _setupMap() {
    final data = widget.journeyData;
    final oLat = (data['origin_lat'] as num?)?.toDouble();
    final oLng = (data['origin_lng'] as num?)?.toDouble();
    final dLat = (data['dest_lat'] as num?)?.toDouble() ?? (data['destination_lat'] as num?)?.toDouble();
    final dLng = (data['dest_lng'] as num?)?.toDouble() ?? (data['destination_lng'] as num?)?.toDouble();

    if (oLat != null && oLng != null && dLat != null && dLng != null) {
      _markers = {
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(oLat, oLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: 'Origin', snippet: data['origin'] ?? ''),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(dLat, dLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination', snippet: data['destination'] ?? ''),
        ),
      };

      // Decode polyline if available
      final polyline = data['route_polyline'];
      if (polyline != null && polyline.toString().isNotEmpty) {
        final points = MapService.decodePolyline(polyline.toString());
        if (points.isNotEmpty) {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: const Color(0xFFF27F0D),
              width: 4,
            ),
          };
        }
      }

      // Calculate bounds
      final swLat = oLat < dLat ? oLat : dLat;
      final swLng = oLng < dLng ? oLng : dLng;
      final neLat = oLat > dLat ? oLat : dLat;
      final neLng = oLng > dLng ? oLng : dLng;
      _bounds = LatLngBounds(
        southwest: LatLng(swLat - 0.05, swLng - 0.05),
        northeast: LatLng(neLat + 0.05, neLng + 0.05),
      );
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _submitJourney() async {
    setState(() => _isLoading = true);

    try {
      final supabase = SupabaseService().client;
      final provider = Provider.of<AppProvider>(context, listen: false);
      final userId = AuthService().currentUser?.uid;

      final dbData = Map<String, dynamic>.from(widget.journeyData);

      // Ensure user_id
      if (userId != null) dbData['user_id'] = userId;
      dbData['driver_id'] = userId ?? dbData['driver_id'];

      // Set status to live
      dbData['status'] = 'active';

      // Remove display-only metadata before DB insert
      dbData.remove('_display');
      
      // Ensure timestamps
      dbData['created_at'] = DateTime.now().toIso8601String();

      await supabase.from('journeys').insert(dbData);

      if (mounted) {
        provider.loadDashboardData();
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => JourneyPostedSuccessPage(
              journeyData: widget.journeyData,
            ),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: child,
              );
            },
          ),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting journey: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getEarningsText() {
    final display = widget.journeyData['_display'] as Map<String, dynamic>?;
    final small = display?['earnings_small'] ?? widget.journeyData['price_small'];
    final large = display?['earnings_large'] ?? widget.journeyData['price_large'];
    if (small != null && large != null) return "₹$small–₹$large";
    final medium = display?['earnings_medium'] ?? widget.journeyData['price_medium'];
    if (medium != null) return "₹$medium+";
    return "₹2,500+";
  }

  String _formatDateTimeString(String? isoString) {
    if (isoString == null) return 'Not set';
    try {
      final dt = DateTime.parse(isoString);
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      final ampm = dt.hour >= 12 ? "PM" : "AM";
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      return "${months[dt.month - 1]} ${dt.day}, $hour12:$minute $ampm";
    } catch (e) {
      return isoString;
    }
  }

  IconData _getTravelModeIcon(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'flight': return Icons.flight;
      case 'train': return Icons.train;
      case 'bus': return Icons.directions_bus;
      case 'bike': return Icons.two_wheeler;
      default: return Icons.directions_car;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.journeyData;
    final origin = d['origin'] ?? 'Unknown Origin';
    final destination = d['destination'] ?? 'Unknown Destination';
    final departureTime = _formatDateTimeString(d['departure_time']);
    final travelMode = d['travel_mode'] ?? 'Car';
    final weightCap = d['capacity'] ?? d['weight_capacity'] ?? d['capacity_kg']?.toString() ?? 'Not set';
    final dimensions = d['dimensions'] ?? 'Not set';
    final pFlex = d['pickup_flexibility'] ?? 'Not set';
    final dFlex = d['dropoff_flexibility'] ?? 'Not set';
    final parcelSizesRaw = d['acceptable_parcel_sizes'] ?? '';
    final List<String> parcelSizes = parcelSizesRaw.toString().split(', ').where((s) => s.isNotEmpty).toList();
    final additionalNotes = d['additional_notes'];

    final hasMapData = _markers.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(width: 40, height: 40, color: Colors.transparent, child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A))),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 40),
                      child: Text("Confirm Journey", textAlign: TextAlign.center, style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                    // Progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("Step 11 of 11", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF27F0D))),
                        Text("Review Summary", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(3)),
                      child: Container(decoration: BoxDecoration(color: const Color(0xFFF27F0D), borderRadius: BorderRadius.circular(3))),
                    ),
                    const SizedBox(height: 24),

                    // ── CARD 0: Map + Route ──
                    _buildStaggeredCard(0, Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: hasMapData
                                ? GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: _markers.first.position,
                                      zoom: 5,
                                    ),
                                    markers: _markers,
                                    polylines: _polylines,
                                    zoomControlsEnabled: false,
                                    myLocationEnabled: false,
                                    myLocationButtonEnabled: false,
                                    mapToolbarEnabled: false,
                                    liteModeEnabled: true,
                                    onMapCreated: (controller) {
                                      _mapController = controller;
                                      if (_bounds != null) {
                                        Future.delayed(const Duration(milliseconds: 300), () {
                                          controller.animateCamera(CameraUpdate.newLatLngBounds(_bounds!, 40));
                                        });
                                      }
                                    },
                                  )
                                : Container(
                                    color: const Color(0xFFF1F5F9),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.map_outlined, size: 40, color: Color(0xFF94A3B8)),
                                          SizedBox(height: 8),
                                          Text("Route Preview", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF94A3B8))),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Column(
                                  children: [
                                    Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFF27F0D), width: 2), color: Colors.white)),
                                    Container(height: 32, width: 2, color: const Color(0xFFE2E8F0)),
                                    Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF27F0D))),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("ORIGIN", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B), letterSpacing: 1)),
                                      const SizedBox(height: 2),
                                      Text(origin, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      const SizedBox(height: 16),
                                      const Text("DESTINATION", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B), letterSpacing: 1)),
                                      const SizedBox(height: 2),
                                      Text(destination, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),

                    // ── CARD 1: Logistics ──
                    _buildStaggeredCard(1, _buildInfoCard(
                      title: "Logistics Details",
                      icon: Icons.inventory_2,
                      child: Column(
                        children: [
                          Row(children: [
                            Expanded(child: _buildDetailRow(Icons.calendar_today, "Departure", departureTime)),
                            Expanded(child: _buildDetailRow(_getTravelModeIcon(travelMode), "Travel Mode", travelMode)),
                          ]),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: _buildDetailRow(Icons.monitor_weight, "Weight Cap.", weightCap)),
                            Expanded(child: _buildDetailRow(Icons.luggage, "Space", dimensions)),
                          ]),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),

                    // ── CARD 2: Preferences ──
                    _buildStaggeredCard(2, _buildInfoCard(
                      title: "Preferences",
                      icon: Icons.tune,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text("Pickup/Drop Flexibility", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text("$pFlex / $dFlex", style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                              ]),
                              const Icon(Icons.location_on, color: Color(0xFF94A3B8), size: 24),
                            ],
                          ),
                          const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),
                          const Text("Parcel Sizes Accepted", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF64748B))),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: parcelSizes.isEmpty ? [const Text("None selected")] : parcelSizes.map((s) => _buildSizeChip(s)).toList(),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),

                    // ── CARD 3: Notes ──
                    if (additionalNotes != null && additionalNotes.toString().isNotEmpty) ...[
                      _buildStaggeredCard(3, _buildInfoCard(
                        title: "Additional Notes",
                        icon: Icons.description,
                        child: Text('"$additionalNotes"', style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF475569))),
                      )),
                      const SizedBox(height: 16),
                    ],

                    // ── CARD 4: Earnings ──
                    _buildStaggeredCard(4, Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF27F0D).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF27F0D).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("EST. EARNINGS", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: const Color(0xFFF27F0D).withValues(alpha: 0.8))),
                            const SizedBox(height: 4),
                            const Text("Based on capacity filled", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF64748B))),
                          ]),
                          Text(_getEarningsText(), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFF27F0D))),
                        ],
                      ),
                    )),
                    const SizedBox(height: 120),
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF27F0D),
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: const Color(0xFFF27F0D).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isLoading ? null : _submitJourney,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                        Text("POST JOURNEY", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ]),
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, color: Color(0xFF94A3B8)),
                children: [
                  TextSpan(text: "By posting, you agree to our "),
                  TextSpan(text: "Terms of Service", style: TextStyle(decoration: TextDecoration.underline, color: Color(0xFF475569))),
                  TextSpan(text: " & "),
                  TextSpan(text: "Privacy Policy", style: TextStyle(decoration: TextDecoration.underline, color: Color(0xFF475569))),
                  TextSpan(text: "."),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaggeredCard(int index, Widget child) {
    if (index >= _cardFades.length) return child;
    return FadeTransition(
      opacity: _cardFades[index],
      child: SlideTransition(position: _cardSlides[index], child: child),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        Row(children: [
          Icon(icon, size: 16, color: const Color(0xFF475569)),
          const SizedBox(width: 6),
          Expanded(child: Text(value, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Stack(
        children: [
          Positioned(top: 0, right: 0, child: Icon(Icons.edit, size: 16, color: const Color(0xFF94A3B8))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: const Color(0xFFF27F0D)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ]),
            const SizedBox(height: 16),
            child,
          ]),
        ],
      ),
    );
  }

  Widget _buildSizeChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Text(text, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
    );
  }
}
