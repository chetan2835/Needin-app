import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class DateTimePickerModal extends StatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final Function(DateTime date, TimeOfDay time, int timestamp) onSelect;

  const DateTimePickerModal({
    super.key,
    this.initialDate,
    this.initialTime,
    required this.onSelect,
  });

  @override
  State<DateTimePickerModal> createState() => _DateTimePickerModalState();
}

class _DateTimePickerModalState extends State<DateTimePickerModal> {
  late DateTime _selectedDate;
  final PageController _monthController = PageController();
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    if (_selectedDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) {
      _selectedDate = DateTime.now();
    }
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }



  TimeOfDay _getNearestValidFutureTime() {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
        
    if (isToday) {
      int h = widget.initialTime?.hour ?? now.hour;
      int m = widget.initialTime?.minute ?? now.minute;
      
      if (h < now.hour || (h == now.hour && m < now.minute)) {
         h = now.hour;
         m = now.minute;
      }
      
      int extraMinutes = m % 5;
      if (extraMinutes != 0) {
        m += (5 - extraMinutes);
      }
      if (m >= 60) {
        m -= 60;
        h += 1;
      }
      if (h >= 24) {
        return const TimeOfDay(hour: 0, minute: 0);
      }
      return TimeOfDay(hour: h, minute: m);
    } else {
      return widget.initialTime ?? TimeOfDay.now();
    }
  }

  Future<void> _proceedToTimePicker() async {
    final initialTime = _getNearestValidFutureTime();
    
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF05A4F),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      if (!mounted) return;
      final dt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      final now = DateTime.now();
      final nowWithoutSeconds = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      
      if (dt.isBefore(nowWithoutSeconds)) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('Please select a valid future time.'),
             backgroundColor: Color(0xFFC44840),
           )
        );
        _proceedToTimePicker();
        return;
      }
      
      widget.onSelect(
        _selectedDate,
        pickedTime,
        dt.millisecondsSinceEpoch ~/ 1000,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Pick a Date",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_currentMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(
                        () => _currentMonth = DateTime(
                          _currentMonth.year,
                          _currentMonth.month - 1,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(
                        () => _currentMonth = DateTime(
                          _currentMonth.year,
                          _currentMonth.month + 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                  .map(
                    (d) => SizedBox(
                      width: 32,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _monthController,
              itemBuilder: (context, index) => _buildMonthGrid(_currentMonth),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05A4F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _proceedToTimePicker,
                child: const Text(
                  "Next: Pick Time",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(DateTime month) {
    int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    int firstWeekday = DateTime(month.year, month.month, 1).weekday % 7;
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: daysInMonth + firstWeekday,
      itemBuilder: (context, index) {
        if (index < firstWeekday) return const SizedBox();
        int day = index - firstWeekday + 1;
        DateTime date = DateTime(month.year, month.month, day);
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);
        DateTime maxDate = today.add(const Duration(days: 15));
        
        bool isPast = date.isBefore(today);
        bool isBeyondLimit = date.isAfter(maxDate);
        bool isDisabled = isPast || isBeyondLimit;
        bool isSelected =
            _selectedDate.year == date.year &&
            _selectedDate.month == date.month &&
            _selectedDate.day == date.day;
        return GestureDetector(
          onTap: isDisabled
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  setState(() { 
                     _selectedDate = date;
                  });
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF05A4F) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              day.toString(),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isDisabled
                    ? const Color(0xFFCBD5E1)
                    : (isSelected ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ),
        );
      },
    );
  }


}
