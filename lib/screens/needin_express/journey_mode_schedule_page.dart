import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'space_weight_page.dart';
import '../../core/widgets/date_time_picker_modal.dart';
import '../../core/utils/travel_mode_mapper.dart';
import 'package:provider/provider.dart';
import '../../core/providers/journey_draft_provider.dart';


class JourneyModeSchedulePage extends StatefulWidget {
  final Map<String, dynamic> journeyData;

  const JourneyModeSchedulePage({super.key, required this.journeyData});

  @override
  State<JourneyModeSchedulePage> createState() =>
      _JourneyModeSchedulePageState();
}

class _JourneyModeSchedulePageState extends State<JourneyModeSchedulePage> {
  String _selectedMode = 'Car';
  DateTime? _departureTime;
  DateTime? _arrivalTime;

  // Travel mode list uses centralized mapper — icons and labels are consistent
  final List<Map<String, dynamic>> _travelModes = TravelModeMapper.getAllModes().map((m) => {
    'title': m['label'] as String,
    'dbValue': m['dbValue'] as String,
    'icon': m['icon'] as IconData,
  }).toList();

  static const Map<String, String> _modeApiMap = {
    'Car': 'road',
    'Bike / Truck / Auto': 'bike',
    'Bus': 'bus',
    'Train': 'train',
    'Flight': 'flight',
  };

  @override
  void initState() {
    super.initState();
    // Pre-fill from existing journeyData if editing
    final depStr = widget.journeyData['departure_datetime']?.toString() ?? widget.journeyData['departure_time']?.toString();
    final arrStr = widget.journeyData['estimated_arrival_datetime']?.toString() ?? widget.journeyData['arrival_time']?.toString();
    if (depStr != null && depStr.isNotEmpty) {
      try { _departureTime = DateTime.parse(depStr); } catch (_) {}
    }
    if (arrStr != null && arrStr.isNotEmpty) {
      try { _arrivalTime = DateTime.parse(arrStr); } catch (_) {}
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    DateTime? initialDate = _departureTime;
    TimeOfDay? initialTime = _departureTime != null ? TimeOfDay.fromDateTime(_departureTime!) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DateTimePickerModal(
        initialDate: initialDate,
        initialTime: initialTime,
        onSelect: (date, time, timestamp) {
          if (!mounted) return;
          setState(() {
            _departureTime = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
          });
        },
      ),
    );
  }

  Future<void> _pickArrivalDateTime() async {
    DateTime? initialDate = _arrivalTime ?? _departureTime;
    TimeOfDay? initialTime = _arrivalTime != null ? TimeOfDay.fromDateTime(_arrivalTime!) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DateTimePickerModal(
        initialDate: initialDate,
        initialTime: initialTime,
        onSelect: (date, time, timestamp) {
          if (!mounted) return;
          setState(() {
            _arrivalTime = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
          });
        },
      ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return "Not selected";
    return DateFormat("MMMM d, yyyy • h:mm a").format(dt);
  }

  Future<void> _submitJourney() async {
    if (_departureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an Estimated Time of Departure'),
        ),
      );
      return;
    }

    if (_arrivalTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your estimated arrival time.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final nowWithoutSeconds = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    if (_departureTime!.isBefore(nowWithoutSeconds)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid future time.'),
          backgroundColor: Color(0xFFF05A4F),
        ),
      );
      return;
    }

    if (_arrivalTime!.isBefore(_departureTime!) || _arrivalTime!.isAtSameMomentAs(_departureTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arrival time must be after departure time.'),
        ),
      );
      return;
    }

    final provider = Provider.of<JourneyDraftProvider>(context, listen: false);

    // Store exact local timestamps (without timezone conversion/Z)
    final depStr = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(_departureTime!);
    final arrStr = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(_arrivalTime!);
    
    provider.updateData({
      'travel_mode': _modeApiMap[_selectedMode] ?? 'road',
      'departure_datetime': depStr,
      'estimated_arrival_datetime': arrStr,
      'departure_time': depStr,
      'arrival_time': arrStr,
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpaceWeightPage(journeyData: provider.draftData),
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
                      child: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF0F172A),
                      ),
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
                        "Step 2 of 7",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                      Text(
                        "29% Completed",
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
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
                      widthFactor: 0.29,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
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
                        color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF05A4F).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFFF05A4F),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "You are posting an existing journey only.",
                              style: TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFF05A4F),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Travel Mode List
                    _buildTravelModeDropdown(),

                    const SizedBox(height: 8),

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
                      onTap: () => _pickDateTime(),
                      icon: Icons.calendar_today,
                    ),
                    const SizedBox(height: 20),

                    // Arrival Time
                    _buildDateTimePicker(
                      label: "Estimated Time of Arrival",
                      value: _arrivalTime,
                      onTap: () => _pickArrivalDateTime(),
                      icon: Icons.event_available,
                    ),
                    const SizedBox(height: 24),

                    // Helper Note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF05A4F).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(
                            Icons.info,
                            color: Color(0xFFF05A4F),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Please enter your expected departure and arrival times manually. These times will be visible to senders looking for travelers on your route.",
                              style: TextStyle(
                                fontFamily: "Plus Jakarta Sans",
                                fontSize: 14,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 100,
                    ), // Padding buffer for bottom action bar
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
              backgroundColor: const Color(0xFFF05A4F),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFFF37A72),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            onPressed: _submitJourney,
            child: Row(
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
                    color: value == null
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF0F172A),
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

  Widget _buildTravelModeDropdown() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMode,
          isExpanded: true,
          icon: const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(16),
          items: _travelModes.map((mode) {
            final isSelected = _selectedMode == mode['title'];
            return DropdownMenuItem<String>(
              value: mode['title'],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF05A4F) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        mode['icon'],
                        color: isSelected ? Colors.white : const Color(0xFFF05A4F),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      mode['title'],
                      style: TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFFF05A4F) : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null && newValue != _selectedMode) {
              setState(() {
                _selectedMode = newValue;
              });
            }
          },
          selectedItemBuilder: (BuildContext context) {
            return _travelModes.map<Widget>((mode) {
              return Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 16.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF05A4F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        mode['icon'],
                        color: const Color(0xFFF05A4F),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      mode['title'],
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
            }).toList();
          },
        ),
      ),
    );
  }
}
