import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteMapPreviewPage extends StatefulWidget {
  const RouteMapPreviewPage({super.key});

  @override
  State<RouteMapPreviewPage> createState() => _RouteMapPreviewPageState();
}

class _RouteMapPreviewPageState extends State<RouteMapPreviewPage> {
  GoogleMapController? _mapController;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(41.8781, -87.6298), // Chicago
    zoom: 6.0,
  );

  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('start'),
      position: LatLng(41.8781, -87.6298),
      infoWindow: InfoWindow(title: 'Chicago, IL (Departing)'),
    ),
    const Marker(
      markerId: MarkerId('end'),
      position: LatLng(42.3314, -83.0458),
      infoWindow: InfoWindow(title: 'Detroit, MI (Arriving)'),
    ),
  };

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            /// Header Section
            Container(
              color: Colors.white,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF181410)),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          "Select Your Route",
                          style: TextStyle(
                            fontFamily: "Inter",
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF181410),
                          ),
                        ),
                        const SizedBox(width: 48), // Spacer to balance back button
                      ],
                    ),
                  ),
                  
                  /// Progress Steps
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              "Step 4 of 11",
                              style: TextStyle(
                                fontFamily: "Inter",
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFFF8000), // primary
                              ),
                            ),
                            Text(
                              "Route Details",
                              style: TextStyle(
                                fontFamily: "Inter",
                                fontSize: 12,
                                color: Color(0xFF9CA3AF), // gray-400
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(8, (index) {
                            return Expanded(
                              child: Container(
                                margin: EdgeInsets.only(right: index < 7 ? 6.0 : 0),
                                height: 6,
                                decoration: BoxDecoration(
                                  color: index < 4 ? const Color(0xFFFF8000) : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            /// Map Area
            Expanded(
              child: Stack(
                children: [
                  /// Google Map
                  GoogleMap(
                    initialCameraPosition: _initialPosition,
                    markers: _markers,
                    onMapCreated: (controller) => _mapController = controller,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                  /// Semi-transparent overlay to match design
                  Container(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),

                  /// Instruction Toast
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: const Color(0xFFFF8000).withValues(alpha: 0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.gesture, color: Color(0xFFFF8000), size: 16),
                            SizedBox(width: 8),
                            Text(
                              "Drag the route line to adjust",
                              style: TextStyle(
                                fontFamily: "Inter",
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4B5563), // gray-600
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  /// Map Controls
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Column(
                      children: [
                        FloatingActionButton(
                          mini: true,
                          heroTag: "btn1",
                          backgroundColor: Colors.white,
                          onPressed: () {
                            _mapController?.animateCamera(
                              CameraUpdate.newCameraPosition(_initialPosition),
                            );
                          },
                          child: const Icon(Icons.my_location, color: Color(0xFFFF8000)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                            ],
                          ),
                          child: Column(
                            children: [
                                IconButton(
                                  icon: const Icon(Icons.add, color: Color(0xFF374151)),
                                  onPressed: () {
                                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                                  },
                                ),
                                Container(height: 1, width: 40, color: Colors.grey.shade100),
                                IconButton(
                                  icon: const Icon(Icons.remove, color: Color(0xFF374151)),
                                  onPressed: () {
                                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// Bottom Sheet
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            /// Drag Handle
                            Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 4),
                              child: Container(
                                width: 48,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  /// Route Info Card
                                  Row(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF8000).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.directions_car, color: Color(0xFFFF8000), size: 32),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Chicago to Detroit",
                                              style: TextStyle(
                                                fontFamily: "Inter",
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF181410),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: const [
                                                Icon(Icons.schedule, size: 16, color: Color(0xFF181410)),
                                                SizedBox(width: 4),
                                                Text(
                                                  "4h 15m",
                                                  style: TextStyle(
                                                    fontFamily: "Inter",
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF181410),
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Text("•", style: TextStyle(color: Colors.grey)),
                                                SizedBox(width: 8),
                                                Icon(Icons.straighten, size: 16, color: Color(0xFF181410)),
                                                SizedBox(width: 4),
                                                Text(
                                                  "280 miles",
                                                  style: TextStyle(
                                                    fontFamily: "Inter",
                                                    fontSize: 14,
                                                    color: Color(0xFF181410),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Color(0xFFFF8000)),
                                        onPressed: () {},
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Container(height: 1, width: double.infinity, color: Colors.grey.shade100),
                                  const SizedBox(height: 20),

                                  /// Waypoints List
                                  Row(
                                    children: [
                                      Column(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.grey.shade300, width: 2),
                                              color: Colors.white,
                                            ),
                                          ),
                                          Container(height: 24, width: 2, color: Colors.grey.shade200),
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: const Color(0xFFFF8000), width: 2),
                                              color: const Color(0xFFFF8000),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text.rich(
                                              TextSpan(
                                                text: "Departing from ",
                                                style: const TextStyle(fontFamily: "Inter", fontSize: 14, color: Color(0xFF6B7280)),
                                                children: const [
                                                  TextSpan(text: "Chicago, IL", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text.rich(
                                              TextSpan(
                                                text: "Arriving at ",
                                                style: const TextStyle(fontFamily: "Inter", fontSize: 14, color: Color(0xFF6B7280)),
                                                children: const [
                                                  TextSpan(text: "Detroit, MI", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  /// Primary Action
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF8000),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 56),
                                      elevation: 8,
                                      shadowColor: const Color(0xFFFF8000).withValues(alpha: 0.3),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {},
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Text(
                                          "Continue",
                                          style: TextStyle(
                                            fontFamily: "Inter",
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
