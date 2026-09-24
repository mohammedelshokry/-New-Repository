import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import 'add_court_screen.dart';
import 'package:intl/intl.dart';

class CourtScheduleScreen extends ConsumerStatefulWidget {
  final dynamic venue;
  final dynamic court;
  const CourtScheduleScreen({super.key, required this.venue, required this.court});

  @override
  ConsumerState<CourtScheduleScreen> createState() => _CourtScheduleScreenState();
}

class _CourtScheduleScreenState extends ConsumerState<CourtScheduleScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final bookings = widget.court['bookings'] as List? ?? [];
    
    // Filter bookings for selected date
    final dailyBookings = bookings.where((b) {
      final st = DateTime.parse(b['startTime']).toLocal();
      return st.year == _selectedDate.year && st.month == _selectedDate.month && st.day == _selectedDate.day && (b['status'] == 'CONFIRMED' || b['status'] == 'ATTENDANCE_CONFIRMED' || b['status'] == 'PENDING');
    }).toList();
    
    // Sort by time
    dailyBookings.sort((a, b) => DateTime.parse(a['startTime']).compareTo(DateTime.parse(b['startTime'])));

    int openHour = 10;
    int closeHour = 23;
    if (widget.venue != null) {
      openHour = int.tryParse(widget.venue['openTime']?.split(':')[0] ?? '10') ?? 10;
      closeHour = int.tryParse(widget.venue['closeTime']?.split(':')[0] ?? '23') ?? 23;
    }
    if (closeHour <= openHour) closeHour += 24;

    List<String> scheduleList = [];
    for (int i = openHour; i < closeHour; i++) {
      final realHour = i % 24;
      final isNextDay = i >= 24;
      final targetDate = isNextDay ? _selectedDate.add(const Duration(days: 1)) : _selectedDate;
      
      bool isBooked = false;
      dynamic matchedBooking;
      
      for (var b in dailyBookings) {
        final st = DateTime.parse(b['startTime']).toLocal();
        final et = DateTime.parse(b['endTime']).toLocal();
        final hourStart = DateTime(targetDate.year, targetDate.month, targetDate.day, realHour, 0);
        
        if (st.isBefore(hourStart.add(const Duration(hours: 1))) && et.isAfter(hourStart)) {
          isBooked = true;
          matchedBooking = b;
          break;
        }
      }
      
      final timeStr = DateFormat('h:mm a').format(DateTime(2023, 1, 1, realHour, 0)).replaceAll('AM', 'ص').replaceAll('PM', 'م');
      
      if (isBooked) {
        scheduleList.add('$timeStr - محجوز (${matchedBooking['status']})');
      } else {
        scheduleList.add('$timeStr - متاح');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.court['name']),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppTheme.neonBlue),
            tooltip: 'تعديل الغرفة',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AddCourtScreen(
                venueId: widget.venue['id'], 
                venueCategory: widget.venue['category'] ?? 'كرة قدم',
                existingCourt: widget.court,
              )));
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: AppTheme.surfaceDark,
            child: SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 14, // 2 weeks
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index));
                  final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
                  return GestureDetector(
                    onTap: () => setState(() { _selectedDate = date; }),
                    child: Container(
                      width: 60, margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.neonBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? Colors.transparent : Colors.white24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(DateFormat('E').format(date), style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                          Text('${date.day}', style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scheduleList.length,
              itemBuilder: (context, index) {
                final item = scheduleList[index];
                final isBooked = item.contains('محجوز');
                return Card(
                  color: isBooked ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                  child: ListTile(
                    leading: Icon(isBooked ? Icons.lock : Icons.lock_open, color: isBooked ? Colors.red : Colors.green),
                    title: Text(item, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
