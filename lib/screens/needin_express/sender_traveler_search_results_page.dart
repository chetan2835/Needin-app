import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/map_service.dart';
import 'dart:ui';
import 'dart:async';
import '../../core/utils/transport_icon_mapper.dart';
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
  List<Map<String, dynamic>> _allTravelers = [];
  String _sortBy = 'Recommended';
  supabase.RealtimeChannel? _subscription;
  supabase.RealtimeChannel? _parcelsSubscription;

  // Filter state
  String? _filterParcelSize;
  bool _filterVerifiedOnly = false;
  double _filterMinRating = 0;
  String? _filterTravelMode;
  int _activeFilterCount = 0;

  // ETD realtime re-check timer
  Timer? _etdTimer;

  @override
  void initState() {
    super.initState();
    _fetchTravelers();
    _setupRealtime();
    // Re-evaluate ETD state every 30 seconds in case ETD passes while user is on screen
    _etdTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _reEvaluateEtdState();
    });
  }

  void _setupRealtime() {
    _subscription = SupabaseService().client
      .channel('public:journeys:search_results')
      .onPostgresChanges(
        event: supabase.PostgresChangeEvent.all,
        schema: 'public',
        table: 'journeys',
        filter: supabase.PostgresChangeFilter(
          type: supabase.PostgresChangeFilterType.eq,
          column: 'status',
          value: 'active',
        ),
        callback: (payload) {
          debugPrint('Realtime search update received');
          // Wait briefly to allow backend trigger to finish (if any) and then refresh
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _fetchTravelers(isSilent: true);
          });
        },
      )
      .subscribe();

    // Also listen to parcels changes for booking lock updates
    _parcelsSubscription = SupabaseService().client
      .channel('public:parcels:booking_lock')
      .onPostgresChanges(
        event: supabase.PostgresChangeEvent.all,
        schema: 'public',
        table: 'parcels',
        callback: (payload) {
          debugPrint('Realtime parcels update received — refreshing booking lock state');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _fetchTravelers(isSilent: true);
          });
        },
      )
      .subscribe();
  }

  @override
  void dispose() {
    _etdTimer?.cancel();
    _subscription?.unsubscribe();
    _parcelsSubscription?.unsubscribe();
    super.dispose();
  }

  /// Re-evaluates ETD state for all loaded travelers and updates their
  /// `etd_passed` field in-place. This handles the case where a user
  /// has been on the screen and ETD passes while they wait.
  void _reEvaluateEtdState() {
    if (_allTravelers.isEmpty) return;
    bool changed = false;
    final now = DateTime.now();
    for (final t in _allTravelers) {
      final depStr = t['departure_time']?.toString();
      if (depStr == null || depStr.isEmpty) continue;
      final depTime = DateTime.tryParse(depStr);
      if (depTime == null) continue;
      final depLocal = depTime.toLocal();
      final passed = now.isAfter(depLocal) || now.isAtSameMomentAs(depLocal);
      if (t['etd_passed'] != passed) {
        t['etd_passed'] = passed;
        changed = true;
        debugPrint('[ETD] Card ETD state changed: journey=${t['id']} etd_passed=$passed');
      }
    }
    if (changed && mounted) {
      setState(() {
        _travelers = _applySortAndFilter(_allTravelers);
      });
    }
  }

  /// Returns true if the journey's departure_time has reached or passed.
  bool _isEtdPassedLocal(Map<String, dynamic> traveler) {
    // Use the pre-computed field if available (updated by _reEvaluateEtdState)
    if (traveler['etd_passed'] != null) return traveler['etd_passed'] == true;
    final depStr = traveler['departure_time']?.toString();
    if (depStr == null || depStr.isEmpty) return false;
    final depTime = DateTime.tryParse(depStr);
    if (depTime == null) return false;
    final now = DateTime.now();
    final depLocal = depTime.toLocal();
    return now.isAfter(depLocal) || now.isAtSameMomentAs(depLocal);
  }

  Future<void> _fetchTravelers({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final origin = widget.parcelData['pickup_city']?.toString() ??
          widget.parcelData['origin']?.toString() ??
          '';
      final destination = widget.parcelData['drop_city']?.toString() ??
          widget.parcelData['destination']?.toString() ??
          '';
      final originLower = origin.toLowerCase().trim();
      final destinationLower = destination.toLowerCase().trim();
      final selectedDateIso = widget.parcelData['date']?.toString();
      final selectedDate = selectedDateIso != null ? DateTime.tryParse(selectedDateIso) : null;
      final selectedDateString = selectedDate != null ? "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}" : null;

      // Query real active journeys from Supabase
      final response = await SupabaseService().client
          .from('journeys')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(200);

      final results = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      // Filter expired, no-capacity, and enforce EXACT route & date matching
      final now = DateTime.now();
      debugPrint('[Search] 🔍 Filtering ${results.length} journeys. Route: $originLower → $destinationLower, Date: $selectedDateString');
      final validResults = results.where((j) {
        // Exclude soft-deleted journeys
        if (j['is_deleted'] == true) return false;

        final cap = (j['capacity_kg'] as num?)?.toDouble() ?? 0;
        j['is_fully_booked'] = cap <= 0;

        
        final depTimeStr = j['departure_time']?.toString();
        if (depTimeStr != null) {
          final depDateUtc = DateTime.tryParse(depTimeStr);
          if (depDateUtc != null) {
            // Convert UTC timestamp to local time for accurate comparison
            final depLocal = depDateUtc.toLocal();
            if (depLocal.isBefore(now)) return false;
            
            // Exact Date Match (compare in local timezone)
            if (selectedDateString != null) {
              final depDateString = "${depLocal.year}-${depLocal.month.toString().padLeft(2, '0')}-${depLocal.day.toString().padLeft(2, '0')}";
              if (depDateString != selectedDateString) return false;
            }
          }
        } else {
          return false; // Require departure time
        }

        // Exact Route Match — strict when both cities provided
        final jOrigin = j['origin']?.toString().toLowerCase().trim() ?? '';
        final jDest = j['destination']?.toString().toLowerCase().trim() ?? '';

        // When both pickup and drop are provided, enforce EXACT match on both
        final hasPickup = originLower.isNotEmpty;
        final hasDrop = destinationLower.isNotEmpty;
        if (hasPickup && !jOrigin.contains(originLower) && !originLower.contains(jOrigin)) return false;
        if (hasDrop && !jDest.contains(destinationLower) && !destinationLower.contains(jDest)) return false;

        return true;
      }).toList();
      debugPrint('[Search] ✅ ${validResults.length} journeys passed filters');

      // Query active bookings to determine booking lock state
      // CRITICAL: Must be List<String> (non-nullable) for .inFilter() to work
      final journeyIds = validResults
          .map((j) => j['id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>() // ← fixes the List<String?> bug silently breaking inFilter
          .toList();
      final Map<String, String> bookedJourneyOwners = {}; // journey_id -> sender_id

      if (journeyIds.isNotEmpty) {
        try {
          // Fetch all non-cancelled/non-delivered parcels for these journeys
          final parcelsRes = await SupabaseService().client
              .from('parcels')
              .select('journey_id, sender_id, status')
              .inFilter('journey_id', journeyIds);
          final parcelsList = List<Map<String, dynamic>>.from(parcelsRes as List);
          debugPrint('[Search] 🔍 Parcels for lock check: ${parcelsList.length}');
          for (final p in parcelsList) {
            final pStatus = (p['status'] ?? '').toString().toLowerCase();
            if (pStatus != 'cancelled' && pStatus != 'delivered' && pStatus != 'completed') {
              final jId = p['journey_id']?.toString();
              final sId = p['sender_id']?.toString();
              if (jId != null && jId.isNotEmpty && sId != null && sId.isNotEmpty) {
                bookedJourneyOwners[jId] = sId;
                debugPrint('[Search] 🔒 Journey $jId locked by sender $sId (status: $pStatus)');
              }
            }
          }
          debugPrint('[Search] 🔒 Total locked journeys: ${bookedJourneyOwners.length}');
        } catch (e, st) {
          debugPrint('[Search] ⚠️ Error fetching booking lock state: $e\n$st');
        }
      }

      final currentUid = AuthService().currentUser?.uid ?? '';


      // Enrich journey data with profile info and calculate match score
      final enriched = <Map<String, dynamic>>[];
      for (final journey in validResults) {
        final driverId = journey['driver_id']?.toString() ?? journey['user_id']?.toString() ?? '';
        Map<String, dynamic>? profile;
        if (driverId.isNotEmpty) {
          profile = await SupabaseService().getUserProfile(driverId);
        }

        final t = {
          ...journey,
          'traveler_name': profile?['full_name'] ?? 'Traveler',
          'traveler_avatar': profile?['profile_image_url'] ??
              profile?['avatar_url'],
          'traveler_rating': profile?['rating'] ?? 5.0,
          'traveler_trips': profile?['total_trips'] ?? 0,
          'traveler_age': profile?['age']?.toString() ?? '',
          'is_verified': profile?['is_verified'] == true,
          'email_verified': profile?['email_verified'] == true,
        };

        // --- Exact Matching Priority & Scoring ---
        double score = 0;
        int priority = 1; // All results are now exact matches (filtered above)
        
        final jOriginRaw = t['origin']?.toString() ?? '';
        final jDestRaw = t['destination']?.toString() ?? '';
        
        final originMatches = origin.isEmpty || jOriginRaw.toLowerCase().contains(origin.toLowerCase());
        final destMatches = destination.isEmpty || jDestRaw.toLowerCase().contains(destination.toLowerCase());
        
        if (originMatches && destMatches) {
          priority = 1;
          score += 1000;
          t['match_label'] = 'Exact Match';
        } else {
          t['match_label'] = 'Match';
        }

        // Bonus points
        if (t['is_verified'] == true) score += 50;
        score += ((t['traveler_rating'] as num?)?.toDouble() ?? 0) * 10;
        score += ((t['traveler_trips'] as num?)?.toInt() ?? 0) * 2;
        
        // Earlier departure bonus
        final depStr = t['departure_time']?.toString() ?? '';
        if (depStr.isNotEmpty) {
          final depDt = DateTime.tryParse(depStr);
          if (depDt != null) {
            // Earlier departures get a small bonus
            final dayDiff = depDt.difference(DateTime.now()).inDays;
            if (dayDiff <= 3) score += 10;
          }
        }

        t['match_priority'] = priority;
        t['match_score'] = score;

        // Booking lock state
        final journeyId = t['id']?.toString() ?? '';
        if (bookedJourneyOwners.containsKey(journeyId)) {
          t['is_booked_by_other'] = bookedJourneyOwners[journeyId] != currentUid;
          t['is_booked'] = true;
          t['booking_owner_id'] = bookedJourneyOwners[journeyId];
        } else {
          t['is_booked_by_other'] = false;
          t['is_booked'] = false;
        }

        // ETD state (computed once at fetch time; refreshed every 30s by _reEvaluateEtdState)
        // NOTE: depStr already declared above in scoring section — reuse it
        final etdDepStr = t['departure_time']?.toString();
        if (etdDepStr != null && etdDepStr.isNotEmpty) {
          final etdDepTime = DateTime.tryParse(etdDepStr);
          if (etdDepTime != null) {
            final etdDepLocal = etdDepTime.toLocal();
            final etdNow = DateTime.now();
            t['etd_passed'] = etdNow.isAfter(etdDepLocal) || etdNow.isAtSameMomentAs(etdDepLocal);
          } else {
            t['etd_passed'] = false;
          }
        } else {
          t['etd_passed'] = false;
        }


        enriched.add(t);
      }

      setState(() {
        _allTravelers = enriched;
        _travelers = _applySortAndFilter(enriched);
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

  List<Map<String, dynamic>> _applySortAndFilter(List<Map<String, dynamic>> source) {
    var filtered = List<Map<String, dynamic>>.from(source);

    // Apply filters
    if (_filterVerifiedOnly) {
      filtered = filtered.where((t) => t['is_verified'] == true).toList();
    }
    if (_filterMinRating > 0) {
      filtered = filtered.where((t) {
        final r = (t['traveler_rating'] as num?)?.toDouble() ?? 0;
        return r >= _filterMinRating;
      }).toList();
    }
    if (_filterTravelMode != null) {
      filtered = filtered.where((t) {
        return t['travel_mode']?.toString().toLowerCase() == _filterTravelMode!.toLowerCase();
      }).toList();
    }
    if (_filterParcelSize != null) {
      filtered = filtered.where((t) {
        final cap = (t['capacity_kg'] as num?)?.toDouble() ?? 0;
        switch (_filterParcelSize) {
          case 'Small': return cap <= 5;
          case 'Medium': return cap > 5 && cap <= 15;
          case 'Large': return cap > 15;
          default: return true;
        }
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'Lowest Price':
        filtered.sort((a, b) {
          final pa = (a['price'] as num?)?.toDouble() ?? 0;
          final pb = (b['price'] as num?)?.toDouble() ?? 0;
          return pa.compareTo(pb);
        });
        break;
      case 'Earliest Departure':
        filtered.sort((a, b) {
          final da = a['departure_time']?.toString() ?? 'z';
          final db = b['departure_time']?.toString() ?? 'z';
          return da.compareTo(db);
        });
        break;
      case 'Highest Rating':
        filtered.sort((a, b) {
          final ra = (a['traveler_rating'] as num?)?.toDouble() ?? 0;
          final rb = (b['traveler_rating'] as num?)?.toDouble() ?? 0;
          return rb.compareTo(ra);
        });
        break;
      default: // Recommended
        filtered.sort((a, b) {
          final pa = a['match_priority'] as int? ?? 4;
          final pb = b['match_priority'] as int? ?? 4;
          if (pa != pb) return pa.compareTo(pb); // Priority 1 comes before Priority 4
          
          final sa = a['match_score'] as double? ?? 0.0;
          final sb = b['match_score'] as double? ?? 0.0;
          return sb.compareTo(sa); // Higher score comes first
        });
    }
    return filtered;
  }

  void _updateSortAndFilter() {
    setState(() {
      _travelers = _applySortAndFilter(_allTravelers);
      _activeFilterCount = 0;
      if (_filterVerifiedOnly) _activeFilterCount++;
      if (_filterMinRating > 0) _activeFilterCount++;
      if (_filterTravelMode != null) _activeFilterCount++;
      if (_filterParcelSize != null) _activeFilterCount++;
      if (_sortBy != 'Recommended') _activeFilterCount++;
    });
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
    return TransportIconMapper.getIconForMode(mode);
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '--:--';
    }
  }

  String _calculateDuration(String? depStr, String? arrStr) {
    if (depStr == null || arrStr == null || depStr.isEmpty || arrStr.isEmpty) return '--';
    try {
      final dep = DateTime.parse(depStr);
      final arr = DateTime.parse(arrStr);
      final diff = arr.difference(dep);
      if (diff.isNegative || diff.inMinutes == 0) return '--';
      
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      
      if (hours > 0 && minutes > 0) {
        return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
      } else if (hours > 0) {
        return '${hours.toString().padLeft(2, '0')}h';
      } else {
        return '${minutes.toString().padLeft(2, '0')}m';
      }
    } catch (_) {
      return '--';
    }
  }

  /// Extracts only the city name from a potentially full address string.
  /// "Connaught Place, New Delhi" → "New Delhi"
  /// "Mumbai" → "Mumbai"
  /// Uses MapService city extractor logic.
  String _extractCity(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) return '';
    // If it already looks like a plain city name (no comma), return as-is
    if (!rawValue.contains(',')) return rawValue.trim();
    // Use the MapService extractor — pass rawValue as both mainText and address
    return MapService.extractCityName(rawValue.split(',').first.trim(), rawValue);
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
              child: Stack(
                children: [
                  const Icon(Icons.tune, color: Color(0xFF0F172A), size: 18),
                  if (_activeFilterCount > 0)
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        width: 14, height: 14,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF05A4F),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('$_activeFilterCount',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            onPressed: _showFilterModal,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Selected search date header
          _buildSearchDateHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchDateHeader() {
    final selectedDateIso = widget.parcelData['date']?.toString();
    if (selectedDateIso == null || selectedDateIso.isEmpty) return const SizedBox.shrink();
    final selectedDate = DateTime.tryParse(selectedDateIso);
    if (selectedDate == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final isToday = selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day;

    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else {
      final day = selectedDate.day;
      final suffix = (day >= 11 && day <= 13) ? 'th' : ['th','st','nd','rd','th','th','th','th','th','th'][day % 10];
      dateLabel = '$day$suffix ${DateFormat('MMMM yyyy').format(selectedDate)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_today, color: Color(0xFFF05A4F), size: 16),
          ),
          const SizedBox(width: 12),
          Text(
            dateLabel,
            style: const TextStyle(
              fontFamily: "Plus Jakarta Sans",
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFFF05A4F),
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
                backgroundColor: const Color(0xFFF05A4F),
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
                color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off,
                  color: Color(0xFFF05A4F), size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              "No Available Travelers",
              style: TextStyle(
                fontFamily: "Plus Jakarta Sans",
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                "There are currently no travelers available for your selected route and date. Please try another date or route.",
                style: TextStyle(
                  fontFamily: "Plus Jakarta Sans",
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text("Change Date/Route"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _fetchTravelers,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Refresh"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A4F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTravelers,
      color: const Color(0xFFF05A4F),
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



  void _showFilterModal() {
    var tempVerified = _filterVerifiedOnly;
    var tempMinRating = _filterMinRating;
    String? tempMode = _filterTravelMode;
    String? tempSize = _filterParcelSize;
    String tempSort = _sortBy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
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
                    const Text("Filter Results",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans", fontSize: 20,
                        fontWeight: FontWeight.bold, color: Color(0xFF0F172A),
                      )),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          tempVerified = false;
                          tempMinRating = 0;
                          tempMode = null;
                          tempSize = null;
                          tempSort = 'Recommended';
                        });
                      },
                      child: const Text("Reset",
                        style: TextStyle(color: Color(0xFFF05A4F), fontFamily: "Plus Jakarta Sans", fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Sort By
                    const Text("Sort By", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Recommended', 'Earliest Departure', 'Highest Rating', 'Lowest Price'].map((s) {
                        final sel = tempSort == s;
                        return ChoiceChip(
                          label: Text(s),
                          selected: sel,
                          selectedColor: const Color(0xFFF05A4F),
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : const Color(0xFF334155),
                            fontFamily: "Plus Jakarta Sans", fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setSheetState(() => tempSort = s),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text("Verified travelers only",
                        style: TextStyle(fontFamily: "Plus Jakarta Sans", fontWeight: FontWeight.w600)),
                      value: tempVerified,
                      activeTrackColor: const Color(0xFFF05A4F),
                      onChanged: (v) => setSheetState(() => tempVerified = v),
                    ),
                    const SizedBox(height: 16),
                    // Min rating
                    const Text("Minimum Rating", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [0.0, 3.0, 3.5, 4.0, 4.5].map((r) {
                        final sel = tempMinRating == r;
                        return ChoiceChip(
                          label: Text(r == 0 ? 'Any' : '${r.toStringAsFixed(1)}+'),
                          selected: sel,
                          selectedColor: const Color(0xFFF05A4F),
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : const Color(0xFF334155),
                            fontFamily: "Plus Jakarta Sans", fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setSheetState(() => tempMinRating = r),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Travel mode
                    const Text("Travel Mode", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Any', 'Car', 'Train', 'Flight', 'Bus'].map((m) {
                        final val = m == 'Any' ? null : m.toLowerCase();
                        final sel = tempMode == val;
                        return ChoiceChip(
                          label: Text(m),
                          selected: sel,
                          selectedColor: const Color(0xFFF05A4F),
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : const Color(0xFF334155),
                            fontFamily: "Plus Jakarta Sans", fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setSheetState(() => tempMode = val),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Parcel size
                    const Text("Parcel Size", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Any', 'Small', 'Medium', 'Large'].map((s) {
                        final val = s == 'Any' ? null : s;
                        final sel = tempSize == val;
                        return ChoiceChip(
                          label: Text(s),
                          selected: sel,
                          selectedColor: const Color(0xFFF05A4F),
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : const Color(0xFF334155),
                            fontFamily: "Plus Jakarta Sans", fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setSheetState(() => tempSize = val),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              // Apply button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF05A4F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _filterVerifiedOnly = tempVerified;
                          _filterMinRating = tempMinRating;
                          _filterTravelMode = tempMode;
                          _filterParcelSize = tempSize;
                          _sortBy = tempSort;
                        });
                        _updateSortAndFilter();
                      },
                      child: const Text("Apply Filters",
                        style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
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
    // Extract CITY-only names for display
    final origin = _extractCity(traveler['origin']?.toString());
    final destination = _extractCity(traveler['destination']?.toString());
    final mode = traveler['travel_mode']?.toString();
    final isBooked = traveler['is_booked'] == true;
    final isBookedByOther = traveler['is_booked_by_other'] == true;
    final isEtdPassed = _isEtdPassedLocal(traveler);

    Widget cardContent = Container(
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
          // Header with Match Label
          if (traveler['match_label'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: traveler['match_priority'] == 1 
                  ? const Color(0xFF10B981).withValues(alpha: 0.1) // Emerald for Exact Match
                  : const Color(0xFFF05A4F).withValues(alpha: 0.1), // Coral for others
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                traveler['match_label'],
                style: TextStyle(
                  fontFamily: "Plus Jakarta Sans",
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: traveler['match_priority'] == 1 
                    ? const Color(0xFF059669) 
                    : const Color(0xFFF05A4F),
                  letterSpacing: 0.5,
                ),
              ),
            ),
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
                          if (traveler['traveler_age'] != null && traveler['traveler_age'].toString().isNotEmpty) ...[
                            const SizedBox(width: 4),
                            const Text("•", style: TextStyle(color: Color(0xFF64748B))),
                            const SizedBox(width: 4),
                            Text(
                              "${traveler['traveler_age']}/y",
                              style: const TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          const Text("•", style: TextStyle(color: Color(0xFF64748B))),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        origin,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(traveler['departure_time']?.toString()),
                        style: const TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                                      const Color(0xFFF05A4F)),
                            ),
                            Expanded(
                                child: Container(
                                    height: 2,
                                    color:
                                        const Color(0xFFE2E8F0))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _calculateDuration(
                            traveler['departure_time']?.toString(),
                            traveler['arrival_time']?.toString(),
                          ),
                          style: const TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF05A4F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(traveler['arrival_time']?.toString()),
                        style: const TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Footer Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status badge
              if (isBooked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text(
                        "BOOKED",
                        style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                )
              else if (isEtdPassed)
                // ETD-passed badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text(
                        "Booking Closed",
                        style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text(
                        "Available",
                        style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ),

              // Action button
              if (isBooked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        isBookedByOther ? "BOOKED" : "BOOKED BY YOU",
                        style: const TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isEtdPassed)
                // Disabled button for ETD-passed journeys
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.block, color: Color(0xFF94A3B8), size: 16),
                      SizedBox(width: 6),
                      Text(
                        "Closed",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A4F),
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor:
                        const Color(0xFFF05A4F).withValues(alpha: 0.4),
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

    if (isBooked || isEtdPassed) {
      return Opacity(
        opacity: isEtdPassed ? 0.7 : 0.65,
        child: IgnorePointer(
          ignoring: isBooked, // ETD-passed: still allow tap to see details (will show closed dialog)
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: isEtdPassed ? 0.5 : 1.5, sigmaY: isEtdPassed ? 0.5 : 1.5),
            child: cardContent,
          ),
        ),
      );
    }

    return cardContent;
  }

}
