import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/services/map_service.dart';

class JourneyDetailPage extends StatefulWidget {
  final Map<String, dynamic> journeyData;

  const JourneyDetailPage({super.key, required this.journeyData});

  @override
  State<JourneyDetailPage> createState() => _JourneyDetailPageState();
}

class _JourneyDetailPageState extends State<JourneyDetailPage>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLngBounds? _bounds;

  late AnimationController _staggerController;
  late List<Animation<double>> _fades;
  late List<Animation<Offset>> _slides;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // 7 staggered sections
    _fades = List.generate(7, (i) {
      final start = i * 0.12;
      final end = (start + 0.35).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOut)),
      );
    });
    _slides = List.generate(7, (i) {
      final start = i * 0.12;
      final end = (start + 0.35).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
        CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOutCubic)),
      );
    });

    _staggerController.forward();
    _setupMap();
  }

  void _setupMap() {
    final d = widget.journeyData;
    final oLat = (d['origin_lat'] as num?)?.toDouble();
    final oLng = (d['origin_lng'] as num?)?.toDouble();
    final dLat = (d['dest_lat'] as num?)?.toDouble() ?? (d['destination_lat'] as num?)?.toDouble();
    final dLng = (d['dest_lng'] as num?)?.toDouble() ?? (d['destination_lng'] as num?)?.toDouble();

    if (oLat != null && oLng != null && dLat != null && dLng != null) {
      _markers = {
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(oLat, oLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: 'Origin', snippet: d['origin'] ?? ''),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(dLat, dLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination', snippet: d['destination'] ?? ''),
        ),
      };

      final polyline = d['route_polyline'];
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

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Not set';
    try {
      final dt = DateTime.parse(isoDate);
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      final ampm = dt.hour >= 12 ? "PM" : "AM";
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      return "${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour12:${dt.minute.toString().padLeft(2, '0')} $ampm";
    } catch (_) {
      return isoDate;
    }
  }

  IconData _getTravelIcon(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'flight': return Icons.flight;
      case 'train': return Icons.train;
      case 'bus': return Icons.directions_bus;
      case 'bike': return Icons.two_wheeler;
      default: return Icons.directions_car;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'live': return 'Live';
      case 'in_progress': return 'In Progress';
      case 'completed': return 'Completed';
      case 'draft': return 'Draft';
      default: return 'Active';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'live': return const Color(0xFF16A34A);
      case 'in_progress': return const Color(0xFFF27F0D);
      case 'completed': return const Color(0xFF64748B);
      default: return const Color(0xFF3B82F6);
    }
  }

  String _getEarnings() {
    final d = widget.journeyData;
    final small = d['price_small'];
    final large = d['price_large'];
    if (small != null && large != null) return "₹$small–₹$large";
    final medium = d['price_medium'];
    if (medium != null) return "₹$medium+";
    return "₹--";
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.journeyData;
    final origin = d['origin'] ?? 'Unknown';
    final destination = d['destination'] ?? 'Unknown';
    final status = d['status']?.toString();
    final travelMode = d['travel_mode'] ?? 'Road';
    final departureTime = d['departure_time']?.toString();
    final distanceKm = d['distance_km'];
    final durationText = d['duration_text'] ?? d['estimated_duration'];
    final weightCap = d['capacity_kg']?.toString() ?? d['capacity']?.toString() ?? d['weight_capacity']?.toString() ?? 'Not set';
    final dimensions = d['dimensions'] ?? 'Not set';
    final pFlex = d['pickup_flexibility'] ?? 'Not set';
    final dFlex = d['dropoff_flexibility'] ?? 'Not set';
    final parcelSizesRaw = d['acceptable_parcel_sizes'] ?? '';
    final List<String> parcelSizes = parcelSizesRaw.toString().split(', ').where((s) => s.isNotEmpty).toList();
    final additionalNotes = d['additional_notes'];
    final journeyId = d['id']?.toString() ?? '--';
    final hasMapData = _markers.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Sliver App Bar with Map ──
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFFFAFAFA),
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                ),
                child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF0F172A)),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                ),
                child: const Icon(Icons.share, size: 18, color: Color(0xFF0F172A)),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: hasMapData
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
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (_bounds != null) {
                          Future.delayed(const Duration(milliseconds: 300), () {
                            controller.animateCamera(CameraUpdate.newLatLngBounds(_bounds!, 50));
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
                            Icon(Icons.map_outlined, size: 48, color: Color(0xFFCBD5E1)),
                            SizedBox(height: 8),
                            Text("Route Map", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Section 0: Status + Route ──
                _stagger(0, Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status + ID
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: _getStatusColor(status))),
                              const SizedBox(width: 6),
                              Text(_getStatusLabel(status), style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.bold, color: _getStatusColor(status))),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Text("Journey #${journeyId.length > 8 ? journeyId.substring(0, 8) : journeyId}", style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF94A3B8))),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Route
                      Row(
                        children: [
                          Column(children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFF27F0D), width: 2), color: Colors.white)),
                            Container(height: 36, width: 2, color: const Color(0xFFE2E8F0)),
                            Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF27F0D))),
                          ]),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("ORIGIN", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8), letterSpacing: 1)),
                                const SizedBox(height: 2),
                                Text(origin, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                const SizedBox(height: 18),
                                const Text("DESTINATION", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8), letterSpacing: 1)),
                                const SizedBox(height: 2),
                                Text(destination, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Distance + Duration row
                      if (distanceKm != null || durationText != null) ...[
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 12),
                        Row(children: [
                          if (distanceKm != null) ...[
                            const Icon(Icons.straighten, size: 16, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Text("${(distanceKm as num).toStringAsFixed(1)} km", style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            const SizedBox(width: 20),
                          ],
                          if (durationText != null) ...[
                            const Icon(Icons.schedule, size: 16, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Text(durationText.toString(), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          ],
                        ]),
                      ],
                    ],
                  ),
                )),
                const SizedBox(height: 16),

                // ── Section 1: Logistics ──
                _stagger(1, _buildSection(
                  title: "Logistics Details",
                  icon: Icons.inventory_2,
                  child: Column(children: [
                    _buildDetailTile(Icons.calendar_today, "Departure", _formatDate(departureTime)),
                    _buildDetailTile(_getTravelIcon(travelMode), "Travel Mode", travelMode),
                    _buildDetailTile(Icons.monitor_weight, "Weight Capacity", "$weightCap kg"),
                    _buildDetailTile(Icons.luggage, "Space Type", dimensions),
                  ]),
                )),
                const SizedBox(height: 16),

                // ── Section 2: Preferences ──
                _stagger(2, _buildSection(
                  title: "Preferences",
                  icon: Icons.tune,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailTile(Icons.location_on, "Pickup Flexibility", pFlex),
                      _buildDetailTile(Icons.pin_drop, "Drop-off Flexibility", dFlex),
                      const SizedBox(height: 12),
                      const Text("Parcel Sizes Accepted", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: parcelSizes.isEmpty
                            ? [_buildChip("All Sizes")]
                            : parcelSizes.map((s) => _buildChip(s)).toList(),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 16),

                // ── Section 3: Notes ──
                if (additionalNotes != null && additionalNotes.toString().isNotEmpty) ...[
                  _stagger(3, _buildSection(
                    title: "Additional Notes",
                    icon: Icons.description,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Text(
                        '"$additionalNotes"',
                        style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF475569), height: 1.5),
                      ),
                    ),
                  )),
                  const SizedBox(height: 16),
                ],

                // ── Section 4: Earnings ──
                _stagger(4, Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFFF27F0D).withValues(alpha: 0.08), const Color(0xFFF27F0D).withValues(alpha: 0.02)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF27F0D).withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("EST. EARNINGS", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: const Color(0xFFF27F0D).withValues(alpha: 0.8))),
                        const SizedBox(height: 4),
                        const Text("Based on capacity filled", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF94A3B8))),
                      ]),
                      Text(_getEarnings(), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFFF27F0D))),
                    ],
                  ),
                )),
                const SizedBox(height: 16),

                // ── Section 5: Created Date ──
                if (d['created_at'] != null)
                  _stagger(5, Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(),
                    child: Row(children: [
                      const Icon(Icons.access_time, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Text("Posted on ${_formatDate(d['created_at']?.toString())}", style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, color: Color(0xFF94A3B8))),
                    ]),
                  )),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stagger(int index, Widget child) {
    if (index >= _fades.length) return child;
    return FadeTransition(
      opacity: _fades[index],
      child: SlideTransition(position: _slides[index], child: child),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF1F5F9)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFF27F0D)),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 11, color: Color(0xFF94A3B8))),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          ]),
        ),
      ]),
    );
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF27F0D).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF27F0D).withValues(alpha: 0.2)),
      ),
      child: Text(text, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF27F0D))),
    );
  }
}
