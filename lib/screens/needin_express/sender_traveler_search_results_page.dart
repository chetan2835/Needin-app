import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import 'sender_traveler_profile_page.dart';

/// ══════════════════════════════════════════════════════════════
///  PRODUCTION: Real Traveler Search Results
///  Queries Supabase `journeys` table for active journeys
///  matching the sender's route. Zero hardcoded data.
/// ══════════════════════════════════════════════════════════════
class SenderTravelerSearchResultsPage extends StatefulWidget {
  final Map<String, dynamic> parcelData;

  const SenderTravelerSearchResultsPage({super.key, required this.parcelData});

  @override
  State<SenderTravelerSearchResultsPage> createState() =>
      _SenderTravelerSearchResultsPageState();
}

class _SenderTravelerSearchResultsPageState
    extends State<SenderTravelerSearchResultsPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _travelers = [];
  String _sortBy = 'Recommended';

  @override
  void initState() {
    super.initState();
    _fetchTravelers();
  }

  Future<void> _fetchTravelers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final origin = widget.parcelData['pickup_city'] ??
          widget.parcelData['origin'] ??
          '';
      final destination = widget.parcelData['drop_city'] ??
          widget.parcelData['destination'] ??
          '';

      // Query real journeys from Supabase
      final results = await SupabaseService().searchMatches(
        fromLocation: origin.toString(),
        toLocation: destination.toString(),
        type: 'journey',
      );

      if (!mounted) return;

      // Enrich journey data with profile info for display
      final enriched = <Map<String, dynamic>>[];
      for (final journey in results) {
        final driverId = journey['driver_id']?.toString() ?? '';
        Map<String, dynamic>? profile;
        if (driverId.isNotEmpty) {
          profile = await SupabaseService().getUserProfile(driverId);
        }

        enriched.add({
          ...journey,
          'traveler_name': profile?['full_name'] ?? 'Traveler',
          'traveler_avatar': profile?['profile_image_url'] ??
              profile?['avatar_url'],
          'traveler_rating': profile?['rating'] ?? 0.0,
          'traveler_trips': profile?['total_trips'] ?? 0,
          'is_verified': profile?['is_verified'] == true,
        });
      }

      setState(() {
        _travelers = enriched;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load travelers. Please try again.';
        _isLoading = false;
      });
      debugPrint('❌ Traveler search error: $e');
    }
  }

  String _formatTravelMode(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'flight':
        return 'Flight';
      case 'train':
        return 'Train';
      case 'bus':
        return 'Bus';
      case 'bike':
        return 'Bike';
      default:
        return 'Car';
    }
  }

  IconData _getTravelModeIcon(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'flight':
        return Icons.flight;
      case 'train':
        return Icons.train;
      case 'bus':
        return Icons.directions_bus;
      case 'bike':
        return Icons.two_wheeler;
      default:
        return Icons.directions_car;
    }
  }

  String _formatCapacity(dynamic capacityKg) {
    final kg = (capacityKg as num?)?.toDouble() ?? 0;
    return '${kg.toInt()}kg Available';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Flexible';
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day} ${months[dt.month]}, ${hour == 0 ? 12 : hour}:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return dateStr;
    }
  }

  String _getRouteCode(String? city) {
    if (city == null || city.isEmpty) return '???';
    // Generate 3-letter code from city name
    final clean = city.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    return clean.length >= 3 ? clean.substring(0, 3) : clean;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                )
              ],
            ),
            child: const Icon(Icons.arrow_back,
                color: Color(0xFF0F172A), size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              "Available Travelers",
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              _isLoading
                  ? "Searching..."
                  : "${_travelers.length} match${_travelers.length == 1 ? '' : 'es'} found",
              style: const TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                  )
                ],
              ),
              child: const Icon(Icons.tune,
                  color: Color(0xFF0F172A), size: 18),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Column(
            children: [
              Container(height: 1, color: const Color(0xFFE2E8F0)),
              Container(
                height: 55,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildFilterChip("Recommended",
                        isSelected: _sortBy == 'Recommended'),
                    const SizedBox(width: 8),
                    _buildFilterChip("Lowest Price",
                        isSelected: _sortBy == 'Lowest Price'),
                    const SizedBox(width: 8),
                    _buildFilterChip("Earliest Arrival",
                        isSelected: _sortBy == 'Earliest Arrival'),
                    const SizedBox(width: 8),
                    _buildFilterChip("Highest Rating",
                        isSelected: _sortBy == 'Highest Rating'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFFF27F0D),
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              "Finding travelers on your route...",
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                color: Colors.red.shade400, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchTravelers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF27F0D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (_travelers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off,
                  color: Color(0xFFF27F0D), size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              "No travelers found",
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "No one is traveling on this route yet.\nCheck back later or try a different route.",
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _fetchTravelers,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("Refresh"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF27F0D),
                side: const BorderSide(color: Color(0xFFF27F0D)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTravelers,
      color: const Color(0xFFF27F0D),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        itemCount: _travelers.length + 1, // +1 for bottom spacing
        itemBuilder: (context, index) {
          if (index == _travelers.length) {
            return const SizedBox(height: 80);
          }
          final traveler = _travelers[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildTravelerCard(context, traveler),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isSelected = false}) {
    return GestureDetector(
      onTap: () => setState(() => _sortBy = label),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF27F0D) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFFF27F0D)
                  : const Color(0xFFE2E8F0)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color:
                          const Color(0xFFF27F0D).withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildTravelerCard(
      BuildContext context, Map<String, dynamic> traveler) {
    final name = traveler['traveler_name'] ?? 'Traveler';
    final rating =
        (traveler['traveler_rating'] as num?)?.toStringAsFixed(1) ?? '0.0';
    final trips = traveler['traveler_trips'] ?? 0;
    final avatarUrl = traveler['traveler_avatar'];
    final isVerified = traveler['is_verified'] == true;
    final origin = traveler['origin']?.toString() ?? '';
    final destination = traveler['destination']?.toString() ?? '';
    final mode = traveler['travel_mode']?.toString();
    final capacityKg = traveler['capacity_kg'];
    final departureTime = traveler['departure_time']?.toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.1),
                                blurRadius: 2),
                          ],
                          color: const Color(0xFFE2E8F0),
                          image: avatarUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(avatarUrl),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: avatarUrl == null
                            ? Center(
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontFamily: "Plus Jakarta Sans",
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      if (isVerified)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified,
                                color: Colors.blue, size: 18),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: Color(0xFFFBBF24), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: const TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "($trips trips)",
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
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatTravelMode(mode),
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Route
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Text(
                      _getRouteCode(origin),
                      style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      origin.length > 12
                          ? '${origin.substring(0, 12)}...'
                          : origin,
                      style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 1),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Icon(_getTravelModeIcon(mode),
                            size: 14,
                            color: const Color(0xFF64748B)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                                child: Container(
                                    height: 2,
                                    color:
                                        const Color(0xFFE2E8F0))),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color:
                                        const Color(0xFFE2E8F0)),
                              ),
                              child: Icon(
                                  _getTravelModeIcon(mode),
                                  size: 14,
                                  color:
                                      const Color(0xFFF27F0D)),
                            ),
                            Expanded(
                                child: Container(
                                    height: 2,
                                    color:
                                        const Color(0xFFE2E8F0))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      _getRouteCode(destination),
                      style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      destination.length > 12
                          ? '${destination.substring(0, 12)}...'
                          : destination,
                      style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Details grid
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF27F0D)
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_month,
                          color: Color(0xFFF27F0D), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "DATE",
                          style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B)),
                        ),
                        Text(
                          _formatDate(departureTime),
                          style: const TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF27F0D)
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2,
                          color: Color(0xFFF27F0D), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "CAPACITY",
                          style: TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B)),
                        ),
                        Text(
                          _formatCapacity(capacityKg),
                          style: const TextStyle(
                              fontFamily: "Plus Jakarta Sans",
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Footer Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Available",
                    style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B)),
                  ),
                  Text(
                    "View pricing →",
                    style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF27F0D),
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor:
                      const Color(0xFFF27F0D).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SenderTravelerProfilePage(
                        travelerData: {
                          ...widget.parcelData,
                          ...traveler,
                        },
                      ),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Text(
                      "View Details",
                      style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_outlined, "Home", false),
              _buildNavItem(Icons.search, "Search", true),
              _buildNavItem(
                  Icons.cases_outlined, "My Trips", false),
              _buildNavItem(
                  Icons.person_outline, "Profile", false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(
          icon,
          color: isSelected
              ? const Color(0xFFF27F0D)
              : const Color(0xFF64748B),
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: "Plus Jakarta Sans",
            fontSize: 10,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? const Color(0xFFF27F0D)
                : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
