import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/map_service.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_provider.dart';
import '../../core/providers/journey_draft_provider.dart';

import '../../core/constants/ui_utils.dart';
import '../../core/utils/earnings_formatter.dart';
import '../../core/utils/transport_icon_mapper.dart';
import '../../core/utils/travel_mode_mapper.dart';

import '../../core/widgets/email_verification_gate.dart';
import 'journey_posted_success_page.dart';
import '../../core/services/map_marker_factory.dart';
import 'legal_document_page.dart';
import 'journey_mode_schedule_page.dart';
import 'flexibility_options_page.dart';

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
        MapMarkerFactory.createPickupMarker(
          position: LatLng(oLat, oLng),
          title: 'Origin',
          snippet: data['origin'] ?? '',
          markerId: 'origin',
        ),
        MapMarkerFactory.createDropMarker(
          position: LatLng(dLat, dLng),
          title: 'Destination',
          snippet: data['destination'] ?? '',
          markerId: 'destination',
        ),
      };

      // Add via city markers (green) from display metadata
      final display = data['_display'] as Map<String, dynamic>?;
      final viaCitiesData = display?['via_cities_data'] as List?;
      if (viaCitiesData != null) {
        for (int i = 0; i < viaCitiesData.length; i++) {
          final via = viaCitiesData[i] as Map<String, dynamic>;
          final vLat = (via['lat'] as num).toDouble();
          final vLng = (via['lng'] as num).toDouble();
          _markers.add(MapMarkerFactory.createViaMarker(
            position: LatLng(vLat, vLng),
            index: i,
            title: via['name'] ?? 'Via',
          ));
        }
      }

      // Decode polyline if available
      final polyline = data['route_polyline'];
      if (polyline != null && polyline.toString().isNotEmpty) {
        final points = MapService.decodePolyline(polyline.toString());
        if (points.isNotEmpty) {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: const Color(0xFFF05A4F),
              width: 5,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          };
        }
      } else {
        // Fallback: fetch route with waypoints if encoded polyline was not passed
        List<LatLng>? waypoints;
        if (viaCitiesData != null && viaCitiesData.isNotEmpty) {
          waypoints = viaCitiesData.map((v) {
            final via = v as Map<String, dynamic>;
            return LatLng((via['lat'] as num).toDouble(), (via['lng'] as num).toDouble());
          }).toList();
        }
        _fetchRouteFallback(oLat, oLng, dLat, dLng, waypoints);
      }

      // Calculate bounds including via cities
      double swLat = oLat < dLat ? oLat : dLat;
      double swLng = oLng < dLng ? oLng : dLng;
      double neLat = oLat > dLat ? oLat : dLat;
      double neLng = oLng > dLng ? oLng : dLng;
      if (viaCitiesData != null) {
        for (final v in viaCitiesData) {
          final via = v as Map<String, dynamic>;
          final vLat = (via['lat'] as num).toDouble();
          final vLng = (via['lng'] as num).toDouble();
          if (vLat < swLat) swLat = vLat;
          if (vLng < swLng) swLng = vLng;
          if (vLat > neLat) neLat = vLat;
          if (vLng > neLng) neLng = vLng;
        }
      }
      _bounds = LatLngBounds(
        southwest: LatLng(swLat - 0.05, swLng - 0.05),
        northeast: LatLng(neLat + 0.05, neLng + 0.05),
      );
    }
  }

  Future<void> _fetchRouteFallback(double oLat, double oLng, double dLat, double dLng, List<LatLng>? waypoints) async {
    final result = await MapService.getDirections(
      originLat: oLat,
      originLng: oLng,
      destLat: dLat,
      destLng: dLng,
      waypoints: waypoints,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: result.polylinePoints,
            color: const Color(0xFFF05A4F),
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };
      });
    }
  }

  Future<void> _openInGoogleMaps() async {
    final data = widget.journeyData;
    final oLat = (data['origin_lat'] as num?)?.toDouble();
    final oLng = (data['origin_lng'] as num?)?.toDouble();
    final dLat = (data['dest_lat'] as num?)?.toDouble() ?? (data['destination_lat'] as num?)?.toDouble();
    final dLng = (data['dest_lng'] as num?)?.toDouble() ?? (data['destination_lng'] as num?)?.toDouble();

    if (oLat == null || oLng == null || dLat == null || dLng == null) return;

    String urlStr = 'https://www.google.com/maps/dir/?api=1'
        '&origin=$oLat,$oLng'
        '&destination=$dLat,$dLng'
        '&travelmode=driving';

    // Include via cities as waypoints
    final display = data['_display'] as Map<String, dynamic>?;
    final viaCitiesData = display?['via_cities_data'] as List?;
    if (viaCitiesData != null && viaCitiesData.isNotEmpty) {
      final wps = viaCitiesData.map((v) {
        final via = v as Map<String, dynamic>;
        final lat = (via['lat'] as num).toDouble();
        final lng = (via['lng'] as num).toDouble();
        return '$lat,$lng';
      }).join('|');
      urlStr += '&waypoints=$wps';
    }

    final url = Uri.parse(urlStr);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening in Google Maps…'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
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
      final supabaseService = SupabaseService();
      final provider = Provider.of<AppProvider>(context, listen: false);
      final firebaseUid = AuthService().currentUser?.uid;
      if (firebaseUid == null) throw Exception('Not authenticated. Please log in.');

      final raw = widget.journeyData;
      final parcelSizesRaw = raw['acceptable_parcel_sizes'];
      final List<String> parcelSizes = parcelSizesRaw is List
          ? List<String>.from(parcelSizesRaw)
          : parcelSizesRaw?.toString().split(', ').where((s) => s.isNotEmpty).toList() ?? [];

      // Convert the timezone-naive ISO strings to proper UTC for timestamptz storage.
      // The ETD step outputs strings like "2026-05-20T06:10:00" (local time, no offset).
      // PostgreSQL timestamptz would treat this as UTC — wrong! We must convert to UTC first.
      final rawDep = raw['departure_datetime']?.toString() ??
          raw['departure_time']?.toString() ?? DateTime.now().toIso8601String();
      final rawArr = raw['estimated_arrival_datetime']?.toString() ??
          raw['arrival_time']?.toString() ??
          DateTime.parse(rawDep).add(const Duration(hours: 12)).toIso8601String();

      // Parse as local time (since the user entered local time) then convert to UTC for storage
      DateTime depDt = DateTime.tryParse(rawDep) ?? DateTime.now();
      DateTime arrDt = DateTime.tryParse(rawArr) ?? depDt.add(const Duration(hours: 6));
      // If the parsed DateTime is not UTC (no Z suffix, no offset), treat it as local
      if (!rawDep.endsWith('Z') && !rawDep.contains('+')) {
        // It's a local time string — convert to UTC for correct timestamptz storage
        depDt = DateTime(depDt.year, depDt.month, depDt.day, depDt.hour, depDt.minute, depDt.second);
        depDt = depDt.toUtc(); // This subtracts the local offset (e.g., -5:30 for IST)
      }
      if (!rawArr.endsWith('Z') && !rawArr.contains('+')) {
        arrDt = DateTime(arrDt.year, arrDt.month, arrDt.day, arrDt.hour, arrDt.minute, arrDt.second);
        arrDt = arrDt.toUtc();
      }
      final departureIso = depDt.toIso8601String();
      final arrivalIso = arrDt.toIso8601String();

      // Final Payload — includes extended columns (added by migrations)
      final payload = <String, dynamic>{
        'driver_id': firebaseUid,
        'origin': raw['origin']?.toString() ?? '',
        'destination': raw['destination']?.toString() ?? '',
        'departure_time': departureIso,
        'arrival_time': arrivalIso,
        'status': 'active',
        'capacity_kg': (raw['capacity_kg'] as num?)?.toDouble() ?? double.tryParse(raw['capacity']?.toString() ?? '') ?? double.tryParse(raw['weight_capacity']?.toString() ?? '') ?? 0.0,
        'price_per_kg': (raw['price_per_kg'] as num?)?.toDouble() ?? 0.0,
        // Extended columns (require migrations to exist)
        'user_id': firebaseUid,
        'is_deleted': false,
        'acceptable_parcel_sizes': parcelSizes,
        'travel_mode': raw['travel_mode']?.toString() ?? 'road',
        'dimensions': raw['dimensions']?.toString(),
        'pickup_flexibility': raw['pickup_flexibility']?.toString(),
        'dropoff_flexibility': raw['dropoff_flexibility']?.toString(),
        'additional_notes': raw['additional_notes']?.toString(),
        'distance_km': (raw['distance_km'] as num?)?.toDouble(),
        'duration_text': raw['duration_text']?.toString() ?? raw['estimated_duration']?.toString(),
        'route_polyline': raw['route_polyline']?.toString(),
        'origin_lat': (raw['origin_lat'] as num?)?.toDouble(),
        'origin_lng': (raw['origin_lng'] as num?)?.toDouble(),
        'dest_lat': (raw['dest_lat'] as num?)?.toDouble() ?? (raw['destination_lat'] as num?)?.toDouble(),
        'dest_lng': (raw['dest_lng'] as num?)?.toDouble() ?? (raw['destination_lng'] as num?)?.toDouble(),
        'price_small': (raw['price_small'] as num?)?.toDouble(),
        'price_medium': (raw['price_medium'] as num?)?.toDouble(),
        'price_large': (raw['price_large'] as num?)?.toDouble(),
      }..removeWhere((_, v) => v == null);

      debugPrint('[Journey] 📦 Payload keys: ${payload.keys.toList()}');
      debugPrint('[Journey] 📦 Departure=$departureIso Arrival=$arrivalIso');

      final draftId = raw['draft_id']?.toString();

      debugPrint('[Journey] 🚀 Attempting insertion with driver_id $firebaseUid');
      
      Map<String, dynamic>? createdJourney;
      if (draftId != null) {
        // Update draft — then fetch it back to confirm
        await supabaseService.client.from('journeys').update(payload).eq('id', draftId);
        createdJourney = {'id': draftId, ...payload};
        debugPrint('[Journey] ✅ Draft updated: $draftId');
      } else {
        // Try full payload first; if schema error, retry with core-only columns
        try {
          createdJourney = await supabaseService.createJourneyAndReturn(payload);
        } catch (e) {
          final errStr = e.toString();
          debugPrint('[Journey] ⚠️ Full insert failed: $errStr');
          if (errStr.contains('PGRST204') || errStr.contains('schema cache') || errStr.contains('Could not find')) {
            // Retry with ONLY core columns that exist in init.sql
            debugPrint('[Journey] 🔄 Retrying with minimal payload...');
            final minimalPayload = <String, dynamic>{
              'driver_id': firebaseUid,
              'origin': raw['origin']?.toString() ?? '',
              'destination': raw['destination']?.toString() ?? '',
              'departure_time': departureIso,
              'arrival_time': arrivalIso,
              'status': 'active',
              'capacity_kg': (raw['capacity_kg'] as num?)?.toDouble() ?? 0.0,
              'price_per_kg': (raw['price_per_kg'] as num?)?.toDouble() ?? 0.0,
            };
            createdJourney = await supabaseService.createJourneyAndReturn(minimalPayload);
          } else {
            rethrow;
          }
        }
      }

      if (createdJourney == null) {
        throw Exception('Journey could not be saved. Please check your connection and try again.');
      }

      debugPrint('[Journey] ✅ Confirmed DB write: id=${createdJourney['id']}');

      if (mounted) {
        provider.loadDashboardData();
        // Clear the draft after successful post!
        Provider.of<JourneyDraftProvider>(context, listen: false).clear();
        
        // Pass confirmed journey data including the DB-generated ID to success page
        final confirmedData = {...widget.journeyData, ...createdJourney};
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => JourneyPostedSuccessPage(journeyData: confirmedData),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            ),
          ),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      debugPrint('[Journey] 💥 Fatal: $e');
      if (!mounted) return;
      
      final rawError = e.toString().replaceAll('Exception:', '').replaceAll('PostgrestException:', '').trim();
      String errorMessage = rawError;
      final eStr = e.toString().toLowerCase();
      
      if (eStr.contains('socket') || eStr.contains('network') || eStr.contains('timeout')) {
        errorMessage = 'Network connection failed. Please check your internet and try again.';
      } else if (eStr.contains('jwt')) {
        errorMessage = 'Session expired. Please log in again to post your journey.';
      } else if (eStr.contains('duplicate')) {
        errorMessage = 'This journey has already been posted.';
      } else if (eStr.contains('row-level security') || eStr.contains('rls') || eStr.contains('policy')) {
        errorMessage = 'Permission denied. Please log out and log in again.';
      }
      // For all other errors (column mismatch, schema, etc), show the raw error

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMessage,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  String _getEarningsText() {
    return EarningsFormatter.getEarningsFromDisplay(widget.journeyData);
  }

  String _formatDateTimeString(String? isoString) {
    if (isoString == null) return 'Not set';
    final str = UIUtils.formatJourneyDateTime(isoString);
    // Replace the comma separator with a newline
    return str.replaceFirst(', ', '\n');
  }

  IconData _getTravelModeIcon(String? mode) {
    return TransportIconMapper.getIconForMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.journeyData;
    final departureTime = _formatDateTimeString(d['departure_datetime'] ?? d['departure_time']);
    final arrivalTime = _formatDateTimeString(d['estimated_arrival_datetime'] ?? d['arrival_time']);
    final travelMode = d['travel_mode'] ?? 'road';
    final travelModeLabel = TravelModeMapper.getLabel(travelMode.toString());
    final weightCap = d['capacity'] ?? d['weight_capacity'] ?? d['capacity_kg']?.toString() ?? 'Not set';
    final dimensions = d['dimensions'] ?? 'Not set';
    final pFlex = d['pickup_flexibility'] ?? 'Not set';
    final dFlex = d['dropoff_flexibility'] ?? 'Not set';
    final parcelSizesRaw = d['acceptable_parcel_sizes'];
    final List<String> parcelSizes = parcelSizesRaw is List 
        ? List<String>.from(parcelSizesRaw) 
        : parcelSizesRaw?.toString().split(', ').where((s) => s.isNotEmpty).toList() ?? [];
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
                        Text("Step 7 of 7", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
                        Text("Review Summary", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(3)),
                      child: Container(decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(3))),
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
                                    zoomControlsEnabled: true,
                                    zoomGesturesEnabled: true,
                                    scrollGesturesEnabled: true,
                                    tiltGesturesEnabled: true,
                                    rotateGesturesEnabled: true,
                                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                                      Factory<OneSequenceGestureRecognizer>(
                                        () => EagerGestureRecognizer(),
                                      ),
                                    },
                                    myLocationEnabled: false,
                                    myLocationButtonEnabled: false,
                                    mapToolbarEnabled: false,
                                    onMapCreated: (controller) {
                                      _mapController = controller;
                                      if (_bounds != null) {
                                        Future.delayed(const Duration(milliseconds: 300), () {
                                          controller.animateCamera(CameraUpdate.newLatLngBounds(_bounds!, 40));
                                        });
                                      }
                                    },
                                    onTap: (_) => _openInGoogleMaps(),
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
                            child: _buildRouteStopsList(d),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),

                    // ── CARD 1: Logistics ──
                    _buildStaggeredCard(1, _buildInfoCard(
                      title: "Logistics Details",
                      icon: Icons.inventory_2,
                      onEdit: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JourneyModeSchedulePage(journeyData: widget.journeyData),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Row(children: [
                            Expanded(child: _buildDetailRow(Icons.calendar_today, "Departure", departureTime)),
                            Expanded(child: _buildDetailRow(Icons.event_available, "Arrival", arrivalTime)),
                          ]),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: _buildDetailRow(_getTravelModeIcon(travelMode.toString()), "Travel Mode", travelModeLabel)),
                            Expanded(child: _buildDetailRow(Icons.monitor_weight, "Weight Cap.", weightCap)),
                          ]),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: _buildDetailRow(Icons.luggage, "Space", dimensions)),
                            const Spacer(),
                          ]),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),

                    // ── CARD 2: Preferences ──
                    _buildStaggeredCard(2, _buildInfoCard(
                      title: "Preferences",
                      icon: Icons.tune,
                      onEdit: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FlexibilityOptionsPage(journeyData: widget.journeyData),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (TravelModeMapper.isFlightMode(travelMode.toString()))
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFF05A4F).withValues(alpha: 0.2)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.flight, color: Color(0xFFF05A4F), size: 16),
                                  SizedBox(width: 8),
                                  Expanded(child: Text("Flight mode: S≤1kg · M≤3kg · L≤5kg · max 18×18×18 in", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
                                ],
                              ),
                            ),
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
                        color: const Color(0xFF16A34A).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("EST. EARNINGS", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: const Color(0xFF16A34A).withValues(alpha: 0.8))),
                          const SizedBox(height: 4),
                          const Text("Based on capacity filled", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF64748B))),
                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(_getEarningsText(), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                          ),
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
              child: EmailVerificationGate(
                actionDescription: 'post a journey',
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A4F),
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: const Color(0xFFF05A4F).withValues(alpha: 0.4),
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
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, color: Color(0xFF94A3B8)),
                children: [
                  const TextSpan(text: "By posting, you agree to our "),
                  TextSpan(
                    text: "Terms of Service",
                    style: const TextStyle(decoration: TextDecoration.underline, color: Color(0xFF475569)),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LegalDocumentPage(title: 'Terms of Service')),
                      ),
                  ),
                  const TextSpan(text: " & "),
                  TextSpan(
                    text: "Privacy Policy",
                    style: const TextStyle(decoration: TextDecoration.underline, color: Color(0xFF475569)),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LegalDocumentPage(title: 'Privacy Policy')),
                      ),
                  ),
                  const TextSpan(text: "."),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 16, color: const Color(0xFF475569)),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(value, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required Widget child, VoidCallback? onEdit}) {
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
          if (onEdit != null)
            Positioned(
              top: 0,
              right: 0,
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.edit, size: 16, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: const Color(0xFFF05A4F)),
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

  /// Builds the route stops list: Origin → [Via Cities] → Destination
  Widget _buildRouteStopsList(Map<String, dynamic> d) {
    final origin = d['origin'] ?? 'Unknown Origin';
    final destination = d['destination'] ?? 'Unknown Destination';
    final display = d['_display'] as Map<String, dynamic>?;
    final viaCitiesData = display?['via_cities_data'] as List?;
    final hasVia = viaCitiesData != null && viaCitiesData.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: dots and connecting lines
        Column(
          children: [
            // Origin dot (hollow circle)
            Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFF05A4F), width: 2), color: Colors.white)),
            // Connector line to first stop
            Container(height: hasVia ? 28 : 32, width: 2, color: const Color(0xFFE2E8F0)),
            // Via city dots + connectors
            if (hasVia)
              ...viaCitiesData.expand((v) => [
                Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF22C55E))),
                Container(height: 28, width: 2, color: const Color(0xFFE2E8F0)),
              ]),
            // Destination dot (filled circle)
            Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF05A4F))),
          ],
        ),
        const SizedBox(width: 12),
        // Right column: text labels
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Origin
              const Text("ORIGIN", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B), letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(origin, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
              // Via cities
              if (hasVia)
                ...viaCitiesData.map((v) {
                  final via = v as Map<String, dynamic>;
                  final name = via['name']?.toString() ?? 'Via';
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("VIA", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF22C55E), letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text(name, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                }),
              // Destination
              Padding(
                padding: EdgeInsets.only(top: hasVia ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("DESTINATION", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B), letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(destination, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
