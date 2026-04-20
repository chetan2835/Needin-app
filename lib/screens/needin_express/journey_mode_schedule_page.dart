import 'package:flutter/material.dart';
import 'space_weight_page.dart';

class JourneyModeSchedulePage extends StatefulWidget {
  final Map<String, dynamic> journeyData;

  const JourneyModeSchedulePage({super.key, required this.journeyData});

  @override
  State<JourneyModeSchedulePage> createState() => _JourneyModeSchedulePageState();
}

class _JourneyModeSchedulePageState extends State<JourneyModeSchedulePage> {
  String _selectedMode = 'Car';
  DateTime? _departureTime;
  DateTime? _arrivalTime;
  final bool _isLoading = false;

  final List<Map<String, dynamic>> _travelModes = [
    {'title': 'Car', 'icon': Icons.directions_car},
    {'title': 'Bike / Truck / Auto', 'icon': Icons.local_shipping},
    {'title': 'Bus', 'icon': Icons.directions_bus},
    {'title': 'Train', 'icon': Icons.train},
    {'title': 'Flight', 'icon': Icons.flight},
  ];

  Future<void> _pickDateTime(bool isDeparture) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFF27F0D)),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFFF27F0D)),
            ),
            child: child!,
          );
        },
      );
      if (time != null) {
        setState(() {
          if (isDeparture) {
            _departureTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          } else {
            _arrivalTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          }
        });
      }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return "Not selected";
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _submitJourney() async {
    if (_departureTime == null || _arrivalTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both departure and arrival times')),
      );
      return;
    }

    if (_arrivalTime!.isBefore(_departureTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arrival time cannot be before departure time')),
      );
      return;
    }

    final finalJourneyData = Map<String, dynamic>.from(widget.journeyData);
    // Map display labels to schema-standard travel_mode values
    final modeMap = {
      'Car': 'road',
      'Bike / Truck / Auto': 'bike',
      'Bus': 'bus',
      'Train': 'train',
      'Flight': 'flight',
    };
    finalJourneyData['travel_mode'] = modeMap[_selectedMode] ?? 'road';
    finalJourneyData['departure_time'] = _departureTime!.toIso8601String();
    finalJourneyData['arrival_time'] = _arrivalTime!.toIso8601String();

    Navigator.push(context,
      MaterialPageRoute(
        builder: (_) => SpaceWeightPage(journeyData: finalJourneyData),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              color: Colors.white,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                        "Post Journey",
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

            /// Progress Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "Step 2 & 3 of 11",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF27F0D),
                        ),
                      ),
                      Text(
                        "27% Completed",
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
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.27,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF27F0D),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
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
                    /// Travel Mode Selection
                    const Text(
                      "How are you travelling?",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF27F0D).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, color: Color(0xFFF27F0D), size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "You are posting an existing journey only.",
                              style: TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFF27F0D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Travel Mode List
                    ..._travelModes.map((mode) {
                      final isSelected = _selectedMode == mode['title'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMode = mode['title'];
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF27F0D).withValues(alpha: 0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFFE2E8F0),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  mode['icon'],
                                  color: isSelected ? Colors.white : const Color(0xFFF27F0D),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  mode['title'],
                                  style: TextStyle(
                                    fontFamily: "Plus Jakarta Sans",
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? const Color(0xFFF27F0D) : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF27F0D),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                                )
                              else
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 32),
                    const Divider(color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 32),

                    /// Journey Schedule
                    const Text(
                      "Journey Schedule",
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Departure Time
                    _buildDateTimePicker(
                      label: "Estimated Time of Departure",
                      value: _departureTime,
                      onTap: () => _pickDateTime(true),
                      icon: Icons.calendar_today,
                    ),
                    const SizedBox(height: 20),

                    // Arrival Time
                    _buildDateTimePicker(
                      label: "Estimated Time of Reach",
                      value: _arrivalTime,
                      onTap: () => _pickDateTime(false),
                      icon: Icons.event_available,
                    ),
                    const SizedBox(height: 24),

                    // Helper Note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF27F0D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF27F0D).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info, color: Color(0xFFF27F0D), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Note on timings",
                                  style: TextStyle(
                                    fontFamily: "Plus Jakarta Sans",
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Timings are approximate. There is no urgency or penalty for slight delays.",
                                  style: TextStyle(
                                    fontFamily: "Plus Jakarta Sans",
                                    fontSize: 14,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100), // Padding buffer for bottom action bar
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
            )
          ],
        ),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF27F0D),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFFFBD38D),
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
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required IconData icon,
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
          onTap: onTap,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateTime(value),
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 16,
                    color: value == null ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: const Color(0xFF94A3B8), size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
