import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_provider.dart';
import 'journey_mode_schedule_page.dart';
import '../../core/services/map_service.dart';
import '../../core/services/pricing_service.dart';
import '../../core/services/pricing_engine.dart';
import '../../core/models/pricing_result.dart';
import '../../core/widgets/google_attribution.dart';
import '../../core/services/map_marker_factory.dart';
import '../../core/services/location_validation_service.dart';
import '../../core/services/journey_draft_service.dart';
import '../../core/providers/journey_draft_provider.dart';


class PostJourneyPage extends StatefulWidget {
  final Map<String, dynamic>? initialDraftData;
  final String? draftId;

  const PostJourneyPage({super.key, this.initialDraftData, this.draftId});

  @override
  State<PostJourneyPage> createState() => _PostJourneyPageState();
}

class _PostJourneyPageState extends State<PostJourneyPage> {
  // Location data
  Map<String, dynamic>? _fromLocation;
  Map<String, dynamic>? _toLocation;
  final List<Map<String, dynamic>> _viaCities = []; // Optional via/waypoint cities

  // Map Controls — mutable reference, NOT Completer
  GoogleMapController? _googleMapController;
  final Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _fullRouteCoordinates = [];
  final List<LatLng> _animatedRouteCoordinates = [];
  Timer? _routeAnimator;
  bool _isLoadingRoute = false;
  String? _encodedPolyline;

  // Route info
  double? _distanceKM;
  String? _durationStr;
  int? _durationSeconds;
  LatLngBounds? _pendingBounds;

  // Pricing / Earnings state
  Map<ParcelSize, PricingResult>? _earningsPreview;
  final PricingService _pricingService = PricingService();

  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDraftData != null) {
      final draft = widget.initialDraftData!;
      if (draft['origin'] != null && draft['origin_lat'] != null && draft['origin_lng'] != null) {
        _fromLocation = {
          'name': draft['origin'],
          'lat': draft['origin_lat'],
          'lng': draft['origin_lng'],
        };
      }
      if (draft['destination'] != null && draft['dest_lat'] != null && draft['dest_lng'] != null) {
        _toLocation = {
          'name': draft['destination'],
          'lat': draft['dest_lat'],
          'lng': draft['dest_lng'],
        };
      }
      if (draft['_display'] != null && draft['_display']['via_cities_data'] != null) {
        final List viaList = draft['_display']['via_cities_data'];
        for (var v in viaList) {
          _viaCities.add(Map<String, dynamic>.from(v));
        }
      }
      if (_fromLocation != null && _toLocation != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchRouteAndAnimate();
        });
      }
      
      Future.microtask(() {
        if (mounted) {
          context.read<JourneyDraftProvider>().initialize(
            initialData: widget.initialDraftData,
            id: widget.draftId,
          );
        }
      });
    } else {
      Future.microtask(() {
        if (mounted) {
          context.read<JourneyDraftProvider>().clear();
        }
      });
    }
  }

  Future<void> _showDraftModal() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 48, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF05A4F).withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.save_as_outlined, color: Color(0xFFF05A4F), size: 32),
            ),
            const SizedBox(height: 24),
            const Text("Save as Draft?", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            const Text("Your journey details are not complete. Save them as a draft and continue later?", textAlign: TextAlign.center, style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 15, color: Color(0xFF64748B), height: 1.5)),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context); // Discard and exit
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Discard", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _saveAsDraftAndExit();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFFF05A4F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text("Save Draft", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _saveAsDraftAndExit() async {
    final draftData = {
      'origin_lat': _fromLocation?['lat'],
      'origin_lng': _fromLocation?['lng'],
      'dest_lat': _toLocation?['lat'],
      'dest_lng': _toLocation?['lng'],
      '_display': {
        'via_cities_data': _viaCities.map((c) => {
          'name': c['name'],
          'lat': (c['lat'] as num).toDouble(),
          'lng': (c['lng'] as num).toDouble(),
        }).toList(),
      }
    };
    
    await JourneyDraftService().saveDraft(
      existingDraftId: widget.draftId,
      currentStep: 1,
      completionPercentage: 12.5,
      draftData: draftData,
      origin: _fromLocation?['name'],
      destination: _toLocation?['name'],
    );
    
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _routeAnimator?.cancel();
    _googleMapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _googleMapController = controller;
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
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted && _googleMapController != null) {
        _googleMapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 60),
        );
      }
    } else {
      _pendingBounds = bounds;
    }
  }

  // ─────────────────────────────────────────────────────────
  //  GOOGLE MAPS: Fetch Route & Animate Polyline
  // ─────────────────────────────────────────────────────────
  Future<void> _fetchRouteAndAnimate() async {
    if (_fromLocation == null || _toLocation == null) return;

    // CRITICAL: Cast to double — fixes world-zoomed polyline bug
    final originLat = (_fromLocation!['lat'] as num).toDouble();
    final originLng = (_fromLocation!['lng'] as num).toDouble();
    final destLat = (_toLocation!['lat'] as num).toDouble();
    final destLng = (_toLocation!['lng'] as num).toDouble();

    // Single batched setState — markers + state reset in one frame
    setState(() {
      _isLoadingRoute = true;
      _markers.clear();
      _polylines.clear();
      _animatedRouteCoordinates.clear();
      _distanceKM = null;
      _durationStr = null;
      _durationSeconds = null;

      // Add markers immediately using centralized factory
      _markers.add(MapMarkerFactory.createPickupMarker(
        position: LatLng(originLat, originLng),
        title: _fromLocation!['name'] ?? 'Origin',
        markerId: 'origin',
      ));
      _markers.add(MapMarkerFactory.createDropMarker(
        position: LatLng(destLat, destLng),
        title: _toLocation!['name'] ?? 'Destination',
        markerId: 'destination',
      ));
      for (int i = 0; i < _viaCities.length; i++) {
        final vLat = (_viaCities[i]['lat'] as num).toDouble();
        final vLng = (_viaCities[i]['lng'] as num).toDouble();
        _markers.add(MapMarkerFactory.createViaMarker(
          position: LatLng(vLat, vLng),
          index: i,
          title: _viaCities[i]['name'] ?? 'Via',
        ));
      }
    });

    // 2. Build waypoints list
    List<LatLng>? waypoints;
    if (_viaCities.isNotEmpty) {
      waypoints = _viaCities.map((c) => LatLng(
        (c['lat'] as num).toDouble(),
        (c['lng'] as num).toDouble(),
      )).toList();
    }

    // 3. Fetch route via centralized service
    final result = await MapService.getDirections(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      waypoints: waypoints,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      _distanceKM = result.distanceKm;
      _durationStr = result.durationText;
      _durationSeconds = result.durationValueSeconds;
      _fullRouteCoordinates = result.polylinePoints;
      _encodedPolyline = result.encodedPolyline;

      // Trigger earnings preview calculation
      _calculateEarningsPreview();

      // 4. Fit map to route bounds
      if (result.bounds != null) {
        await _fitBounds(result.bounds!);
      }

      // 5. Animate polyline drawing
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
              color: const Color(0xFFF05A4F),
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



  // ─────────────────────────────────────────────────────────
  //  EARNINGS PREVIEW CALCULATION
  // ─────────────────────────────────────────────────────────
  Future<void> _calculateEarningsPreview() async {
    if (_fromLocation == null || _toLocation == null) return;

    try {
      final originLat = (_fromLocation!['lat'] as num).toDouble();
      final originLng = (_fromLocation!['lng'] as num).toDouble();
      final destLat = (_toLocation!['lat'] as num).toDouble();
      final destLng = (_toLocation!['lng'] as num).toDouble();

      final allPrices = await _pricingService.calculateAllSizes(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        originCity: _fromLocation?['name']?.toString(),
        destCity: _toLocation?['name']?.toString(),
      );

      if (!mounted) return;
      setState(() {
        _earningsPreview = allPrices;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Earnings preview error: $e');
    }
  }


  // ─────────────────────────────────────────────────────────
  //  LOCATION SEARCH MODAL (Bottom Sheet)
  // ─────────────────────────────────────────────────────────
  void _showLocationSearch(bool isFrom) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TravelerLocationSearchModal(
        isFrom: isFrom,
        onSelect: (location) async {
          // India-only validation
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          final capturedCtx = context; // capture before async
          final isValid = await LocationValidationService.isCoordinatesInIndia(lat, lng);
          if (!isValid) {
            if (capturedCtx.mounted) {
              LocationValidationService.showIndiaOnlyRestrictionDialog(capturedCtx);
            }
            return;
          }
          setState(() {
            if (isFrom) {
              _fromLocation = location;
            } else {
              _toLocation = location;
            }
          });
          _fetchRouteAndAnimate();
        },
      ),
    );
  }


  void _showViaSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TravelerLocationSearchModal(
        isFrom: false,
        onSelect: (location) async {
          // India-only validation
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          final capturedCtx = context; // capture before async
          final isValid = await LocationValidationService.isCoordinatesInIndia(lat, lng);
          if (!isValid) {
            if (capturedCtx.mounted) {
              LocationValidationService.showIndiaOnlyRestrictionDialog(capturedCtx);
            }
            return;
          }
          setState(() {
            _viaCities.add(location);
          });
          _fetchRouteAndAnimate();
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  OPEN IN GOOGLE MAPS — Launch external Google Maps with route
  // ─────────────────────────────────────────────────────────
  Future<void> _openInGoogleMaps() async {
    if (_fromLocation == null || _toLocation == null) return;

    final oLat = (_fromLocation!['lat'] as num).toDouble();
    final oLng = (_fromLocation!['lng'] as num).toDouble();
    final dLat = (_toLocation!['lat'] as num).toDouble();
    final dLng = (_toLocation!['lng'] as num).toDouble();

    String urlStr = 'https://www.google.com/maps/dir/?api=1'
        '&origin=$oLat,$oLng'
        '&destination=$dLat,$dLng'
        '&travelmode=driving';

    if (_viaCities.isNotEmpty) {
      final wps = _viaCities.map((c) {
        final lat = (c['lat'] as num).toDouble();
        final lng = (c['lng'] as num).toDouble();
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

  // ─────────────────────────────────────────────────────────
  //  SUBMIT & NAVIGATE
  // ─────────────────────────────────────────────────────────
  Future<void> _submitJourney() async {
    if (_fromLocation == null || _toLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both origin and destination cities.')),
      );
      return;
    }

    final uid = AuthService().currentUser?.uid;
    final provider = Provider.of<AppProvider>(context, listen: false);
    final profile = provider.userProfile;
    final driverName = profile != null && profile['full_name'] != null ? profile['full_name'] : 'Traveler';
    // Fix: Use 'profile_image_url' (normalized key from UserProfileProvider/SupabaseService)
    final avatarUrl = profile?['profile_image_url']?.toString() ?? '';

    // DB-safe fields that match the journeys table schema exactly
    final journeyData = {
      'driver_id': uid,
      'origin': _fromLocation!['name'],
      'destination': _toLocation!['name'],
      'origin_lat': _fromLocation!['lat'],
      'origin_lng': _fromLocation!['lng'],
      'destination_lat': _toLocation!['lat'],
      'destination_lng': _toLocation!['lng'],
      'distance_km': _distanceKM,  // numeric, not string
      'duration_text': _durationStr,
      'duration_seconds': _durationSeconds,
      'route_polyline': _encodedPolyline,
      'status': 'active',
      'price_small': _earningsPreview?[ParcelSize.small]?.price,
      'price_medium': _earningsPreview?[ParcelSize.medium]?.price,
      'price_large': _earningsPreview?[ParcelSize.large]?.price,
      'pricing_type': _earningsPreview?[ParcelSize.medium]?.pricingType.name ?? 'slab',
    };

    // Display-only metadata (NOT inserted into DB — used by UI pages in the flow)
    final displayMeta = {
      'driver_name': driverName,
      'driver_avatar_url': avatarUrl,
      'via_cities': _viaCities.map((c) => c['name']).toList(),
      'earnings_small': _earningsPreview?[ParcelSize.small]?.price,
      'earnings_medium': _earningsPreview?[ParcelSize.medium]?.price,
      'earnings_large': _earningsPreview?[ParcelSize.large]?.price,
      // Full via city data with coordinates for Step 8 map markers & Google Maps URL
      'via_cities_data': _viaCities.map((c) => {
        'name': c['name'],
        'lat': (c['lat'] as num).toDouble(),
        'lng': (c['lng'] as num).toDouble(),
      }).toList(),
    };

    // Merge: journeyData for DB insert + displayMeta for UI display
    final fullJourneyData = {
      ...journeyData, 
      '_display': displayMeta,
      if (widget.draftId != null) 'draft_id': widget.draftId,
    };

    final providerConfig = Provider.of<JourneyDraftProvider>(context, listen: false);
    providerConfig.updateData(fullJourneyData);

    Navigator.push(context,
      MaterialPageRoute(
        builder: (_) => JourneyModeSchedulePage(journeyData: providerConfig.draftData),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_fromLocation != null || _toLocation != null) {
          await _showDraftModal();
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
                      onTap: () async {
                        if (_fromLocation != null || _toLocation != null) {
                          await _showDraftModal();
                        } else {
                          Navigator.pop(context);
                        }
                      },
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
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 40),
                      child: Text(
                        "Select Your Route",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// Progress Steps Indicator
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "Step 1 of 7",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                      Text(
                        "Route Details",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(7, (index) {
                      return Expanded(
                        child: Container(
                          height: 6,
                          margin: EdgeInsets.only(right: index < 6 ? 6 : 0),
                          decoration: BoxDecoration(
                            color: index < 1 ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  children: [
                    // ─── Route Details Card ───
                    Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Route Details",
                            style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // From City
                          _buildLocationTile(
                            label: "From City",
                            hint: "Search starting city...",
                            icon: Icons.trip_origin,
                            iconColor: const Color(0xFF2563EB),
                            location: _fromLocation,
                            onTap: () => _showLocationSearch(true),
                          ),
                          const SizedBox(height: 20),

                          // To City
                          _buildLocationTile(
                            label: "To City",
                            hint: "Search destination...",
                            icon: Icons.location_on,
                            iconColor: Colors.red.shade500,
                            location: _toLocation,
                            onTap: () => _showLocationSearch(false),
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 20),

                          // Route Type — Via Cities (Optional)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Via Cities (Optional)",
                                      style: TextStyle(
                                        fontFamily: "Plus Jakarta Sans",
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _showViaSearch(),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add, size: 16, color: Color(0xFFF05A4F)),
                                            SizedBox(width: 4),
                                            Text(
                                              "Add Stop",
                                              style: TextStyle(
                                                fontFamily: "Plus Jakarta Sans",
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFF05A4F),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_viaCities.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFF1F5F9)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.alt_route, color: Color(0xFF94A3B8), size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "Direct route · No stops added",
                                          style: TextStyle(
                                            fontFamily: "Plus Jakarta Sans",
                                            fontSize: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ..._viaCities.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final city = entry.value;
                                return Container(
                                  margin: EdgeInsets.only(top: idx == 0 ? 0 : 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.circle, size: 10, color: Color(0xFF22C55E)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          city['name'] ?? 'Via City',
                                          style: const TextStyle(
                                            fontFamily: "Plus Jakarta Sans",
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() => _viaCities.removeAt(idx));
                                          _fetchRouteAndAnimate();
                                        },
                                        child: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ─── Google Map Preview ───
                    if (_fromLocation != null || _toLocation != null)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
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
                                  _fromLocation != null ? _fromLocation!['lat'] : 20.5937,
                                  _fromLocation != null ? _fromLocation!['lng'] : 78.9629,
                                ),
                                zoom: 5,
                              ),
                              markers: _markers,
                              polylines: _polylines,
                              myLocationEnabled: true,
                              myLocationButtonEnabled: false,
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
                              mapToolbarEnabled: false,
                              onMapCreated: _onMapCreated,
                              onTap: (_) => _openInGoogleMaps(),
                            ),
                            if (_isLoadingRoute)
                              Container(
                                color: Colors.white.withValues(alpha: 0.7),
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(
                                  color: Color(0xFFF05A4F),
                                ),
                              ),
                          ],
                        ),
                      ),

                    // ─── Distance & Duration Pill ───
                    if (_distanceKM != null && _durationStr != null && !_isLoadingRoute)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, left: 24, right: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.straighten, size: 16, color: Color(0xFFF05A4F)),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${_distanceKM!.toStringAsFixed(1)} KM",
                                    style: const TextStyle(
                                      fontFamily: "Plus Jakarta Sans",
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF05A4F),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(width: 1, height: 16, color: const Color(0xFFF05A4F).withValues(alpha: 0.3)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.timer, size: 16, color: Color(0xFFF05A4F)),
                                  const SizedBox(width: 6),
                                  Text(
                                    _durationStr!,
                                    style: const TextStyle(
                                      fontFamily: "Plus Jakarta Sans",
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF05A4F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ─── Route Summary Card ───
                    if (_fromLocation != null && _toLocation != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.directions_car, color: Color(0xFFF05A4F), size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Route Preview",
                                        style: TextStyle(
                                          fontFamily: "Plus Jakarta Sans",
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.schedule, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            _durationStr ?? "Calculating...",
                                            style: const TextStyle(
                                              fontFamily: "Plus Jakarta Sans",
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Column(
                                  children: [
                                    Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFCBD5E1), width: 2), shape: BoxShape.circle)),
                                    Container(width: 2, height: 24, color: const Color(0xFFE2E8F0)),
                                    Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFF05A4F), shape: BoxShape.circle)),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fromLocation!['name'] ?? "Origin",
                                        style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _toLocation!['name'] ?? "Destination",
                                        style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      
      /// Bottom Action Bar
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.white,
              Colors.white.withValues(alpha: 0.9),
              Colors.white.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF05A4F),
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: const Color(0xFFF37A72),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward),
                  ],
                ),
          ),
        ),
      ),
    ));
  }

  // ─────────────────────────────────────────────────────────
  //  LOCATION TILE WIDGET
  // ─────────────────────────────────────────────────────────
  Widget _buildLocationTile({
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required Map<String, dynamic>? location,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: "Plus Jakarta Sans",
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: location == null ? const Color(0xFFF8FAFC) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: location != null ? const Color(0xFFF05A4F).withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    location != null ? location['name'] : hint,
                    style: TextStyle(
                      fontFamily: "Plus Jakarta Sans",
                      fontSize: 16,
                      fontWeight: location != null ? FontWeight.bold : FontWeight.w500,
                      color: location != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ═══════════════════════════════════════════════════════════
///  TRAVELER LOCATION SEARCH MODAL
///  Real-time Google Places Autocomplete + GPS Detection
/// ═══════════════════════════════════════════════════════════
class _TravelerLocationSearchModal extends StatefulWidget {
  final bool isFrom;
  final Function(Map<String, dynamic>) onSelect;

  const _TravelerLocationSearchModal({
    required this.isFrom,
    required this.onSelect,
  });

  @override
  State<_TravelerLocationSearchModal> createState() => _TravelerLocationSearchModalState();
}

class _TravelerLocationSearchModalState extends State<_TravelerLocationSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;  // Inline search indicator (not full-screen blocker)
  bool _isSelectingPlace = false;  // Separate flag for place selection
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
        _isSearching = false;
      });
      return;
    }

    // Show inline indicator immediately (keeps results visible)
    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final result = await MapService.getAutocomplete(query);
      if (mounted) {
        setState(() {
          final unique = <dynamic>[];
          final seen = <String>{};
          for (final p in result.predictions) {
            final pid = p['place_id'] as String?;
            if (pid != null && !seen.contains(pid)) {
              seen.add(pid);
              unique.add(p);
            }
          }
          _predictions = unique.take(9).toList();
          _isSearching = false;
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
    // Dismiss modal IMMEDIATELY — fetch coordinates in background
    setState(() => _isSelectingPlace = true);
    
    // Fire-and-forget: fetch then callback
    MapService.getPlaceDetails(placeId).then((location) {
      if (location != null) {
        widget.onSelect({
          'name': mainText,
          'city': '',
          'lat': location.lat,
          'lng': location.lng,
          'placeId': placeId,
        });
      }
    });
    
    // Close sheet immediately — no waiting for network
    Navigator.pop(context);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isSelectingPlace = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Enable in Settings.');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 10));

      final location = await MapService.reverseGeocode(position.latitude, position.longitude);
      if (!mounted) return;
      if (location != null) {
        widget.onSelect({
          'name': location.name,
          'city': 'Detected',
          'lat': location.lat,
          'lng': location.lng,
          'placeId': location.placeId,
        });
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not determine address. Please search manually.'),
          ),
        );
        setState(() => _isSelectingPlace = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: ${e.toString().replaceAll('Exception: ', '')}'),
          ),
        );
        setState(() => _isSelectingPlace = false);
      }
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
                  widget.isFrom ? Icons.trip_origin : Icons.location_on,
                  color: widget.isFrom ? const Color(0xFF2563EB) : Colors.red,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.isFrom ? "Set Origin City" : "Set Destination City",
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
              style: const TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: "Search city or area...",
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF05A4F))),
                      )
                    : IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _predictions.clear());
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
            child: _isSelectingPlace
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFF05A4F)),
                        SizedBox(height: 12),
                        Text("Getting location...", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF64748B))),
                      ],
                    ),
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
                                leading: const Icon(Icons.my_location, color: Color(0xFF2563EB)),
                                title: const Text(
                                  "Use Current Location",
                                  style: TextStyle(
                                    fontFamily: "Plus Jakarta Sans",
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                onTap: _useCurrentLocation,
                              );
                            }
                            final item = _predictions[index - 1];
                            final mainText = item['structured_formatting']['main_text'];
                            final secondaryText = item['structured_formatting']['secondary_text'] ?? '';
                            return ListTile(
                              leading: const Icon(Icons.place, color: Color(0xFF64748B)),
                              title: Text(
                                mainText,
                                style: const TextStyle(
                                  fontFamily: "Plus Jakarta Sans",
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                secondaryText,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              onTap: () => _fetchPlaceDetails(item['place_id'], mainText),
                            );
                          },
                        ),
                      ),
                      if (_predictions.isNotEmpty) const GoogleAttribution(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
