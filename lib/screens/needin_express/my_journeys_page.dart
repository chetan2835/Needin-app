import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import 'journey_detail_page.dart';
import 'post_journey_page.dart';

class MyJourneysPage extends StatefulWidget {
  const MyJourneysPage({super.key});

  @override
  State<MyJourneysPage> createState() => _MyJourneysPageState();
}

class _MyJourneysPageState extends State<MyJourneysPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allJourneys = [];
  bool _isLoading = true;
  String? _filterMode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadJourneys();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadJourneys() async {
    setState(() => _isLoading = true);
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid != null) {
        _allJourneys = await SupabaseService().getUserJourneys(uid);
      }
    } catch (e) {
      debugPrint("Error loading journeys: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _activeJourneys {
    var list = _allJourneys.where((j) {
      final status = j['status']?.toString().toLowerCase() ?? '';
      return status == 'active' || status == 'live' || status == 'in_progress';
    }).toList();
    return _applyFilter(list);
  }

  List<Map<String, dynamic>> get _completedJourneys {
    var list = _allJourneys.where((j) => j['status']?.toString().toLowerCase() == 'completed').toList();
    return _applyFilter(list);
  }

  List<Map<String, dynamic>> get _draftJourneys {
    var list = _allJourneys.where((j) => j['status']?.toString().toLowerCase() == 'draft').toList();
    return _applyFilter(list);
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> list) {
    if (_filterMode != null) {
      list = list.where((j) => j['travel_mode']?.toString().toLowerCase() == _filterMode!.toLowerCase()).toList();
    }
    return list;
  }

  String _getStatusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'live':
        return 'Live';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'draft':
        return 'Draft';
      default:
        return 'Upcoming';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'live':
        return const Color(0xFF16A34A);
      case 'in_progress':
        return const Color(0xFFF27F0D);
      case 'completed':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Color _getStatusBgColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'live':
        return const Color(0xFFDCFCE7);
      case 'in_progress':
        return const Color(0xFFFFF7ED);
      case 'completed':
        return const Color(0xFFF1F5F9);
      default:
        return const Color(0xFFEFF6FF);
    }
  }

  IconData _getTravelIcon(String? mode) {
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

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '--';
    try {
      final dt = DateTime.parse(isoDate);
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      final ampm = dt.hour >= 12 ? "PM" : "AM";
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      return "${months[dt.month - 1]} ${dt.day}, ${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
    } catch (_) {
      return isoDate;
    }
  }

  String _getEarnings(Map<String, dynamic> j) {
    final small = j['price_small'];
    final large = j['price_large'];
    if (small != null && large != null) return "₹$small";
    final medium = j['price_medium'];
    if (medium != null) return "₹$medium";
    return "₹--";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        "My Journeys",
                        style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Filter button
                      PopupMenuButton<String?>(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _filterMode != null ? const Color(0xFFF27F0D).withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Icon(
                            Icons.filter_list,
                            color: _filterMode != null ? const Color(0xFFF27F0D) : const Color(0xFF64748B),
                            size: 20,
                          ),
                        ),
                        onSelected: (val) => setState(() => _filterMode = val),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: null, child: Text("All Modes")),
                          const PopupMenuItem(value: "car", child: Text("Car")),
                          const PopupMenuItem(value: "flight", child: Text("Flight")),
                          const PopupMenuItem(value: "train", child: Text("Train")),
                          const PopupMenuItem(value: "bus", child: Text("Bus")),
                          const PopupMenuItem(value: "bike", child: Text("Bike")),
                        ],
                      ),
                      const SizedBox(width: 4),
                      // Notification bell
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: const Icon(Icons.notifications_none, color: Color(0xFF64748B), size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))],
                ),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF0F172A),
                unselectedLabelColor: const Color(0xFF94A3B8),
                labelStyle: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(text: "Active (${_activeJourneys.length})"),
                  Tab(text: "Completed (${_completedJourneys.length})"),
                  Tab(text: "Drafts (${_draftJourneys.length})"),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFF27F0D)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildJourneyList(_activeJourneys),
                        _buildJourneyList(_completedJourneys),
                        _buildJourneyList(_draftJourneys),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostJourneyPage())),
        backgroundColor: const Color(0xFFF27F0D),
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildJourneyList(List<Map<String, dynamic>> journeys) {
    if (journeys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.luggage_outlined, size: 64, color: const Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            const Text("No journeys found", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
            const SizedBox(height: 8),
            const Text("Post a journey to see it here", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFFCBD5E1))),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF27F0D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostJourneyPage())),
              child: const Text("Post a Journey", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJourneys,
      color: const Color(0xFFF27F0D),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
        itemCount: journeys.length,
        itemBuilder: (context, index) {
          final journey = journeys[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + index * 80),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _buildJourneyCard(journey),
          );
        },
      ),
    );
  }

  Widget _buildJourneyCard(Map<String, dynamic> journey) {
    final status = journey['status']?.toString();
    final origin = journey['origin'] ?? 'Unknown';
    final destination = journey['destination'] ?? 'Unknown';
    final travelMode = journey['travel_mode']?.toString();
    final departureTime = journey['departure_time']?.toString();
    final journeyId = journey['id']?.toString() ?? '--';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => JourneyDetailPage(journeyData: journey),
            transitionDuration: const Duration(milliseconds: 350),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              );
            },
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Status + ID + Price
            Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: _getStatusColor(status))),
                    const SizedBox(width: 6),
                    Text(_getStatusLabel(status), style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusColor(status))),
                  ]),
                ),
                const SizedBox(width: 8),
                Text("ID: #${journeyId.length > 5 ? journeyId.substring(0, 5) : journeyId}", style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 11, color: Color(0xFF94A3B8))),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF27F0D).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.account_balance_wallet, size: 14, color: Color(0xFFF27F0D)),
                    const SizedBox(width: 4),
                    Text(_getEarnings(journey), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF27F0D))),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Route
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF94A3B8), width: 2))),
                  Container(height: 28, width: 1.5, color: const Color(0xFFE2E8F0)),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF27F0D))),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("From", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(origin, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      const Text("To", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(destination, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom info
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(_formatDate(departureTime), style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF64748B))),
                  ]),
                  Row(children: [
                    Icon(_getTravelIcon(travelMode), size: 16, color: const Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(travelMode ?? 'Road', style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
