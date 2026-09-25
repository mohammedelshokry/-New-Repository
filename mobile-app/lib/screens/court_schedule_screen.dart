import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../providers/api_provider.dart';
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
      return st.year == _selectedDate.year &&
          st.month == _selectedDate.month &&
          st.day == _selectedDate.day &&
          (b['status'] == 'CONFIRMED' ||
              b['status'] == 'ATTENDANCE_CONFIRMED' ||
              b['status'] == 'PENDING');
    }).toList();

    // Sort by time
    dailyBookings.sort((a, b) =>
        DateTime.parse(a['startTime']).compareTo(DateTime.parse(b['startTime'])));

    int openHour = 10;
    int closeHour = 23;
    if (widget.venue != null) {
      openHour = int.tryParse(widget.venue['openTime']?.split(':')[0] ?? '10') ?? 10;
      closeHour = int.tryParse(widget.venue['closeTime']?.split(':')[0] ?? '23') ?? 23;
    }
    if (closeHour <= openHour) { closeHour += 24; }

    // Build schedule as list of maps
    final List<Map<String, dynamic>> scheduleList = [];
    for (int i = openHour; i < closeHour; i++) {
      for (int min in [0, 30]) {
        final realHour = i % 24;
        final isNextDay = i >= 24;
        final targetDate = isNextDay
            ? _selectedDate.add(const Duration(days: 1))
            : _selectedDate;

        bool isBooked = false;
        dynamic matchedBooking;

        final slotStart = DateTime(
            targetDate.year, targetDate.month, targetDate.day, realHour, min);
        final slotEnd = slotStart.add(const Duration(minutes: 30));

        for (var b in dailyBookings) {
          final st = DateTime.parse(b['startTime']).toLocal();
          final et = DateTime.parse(b['endTime']).toLocal();

          if (st.isBefore(slotEnd) && et.isAfter(slotStart)) {
            isBooked = true;
            matchedBooking = b;
            break;
          }
        }

        final timeStr = DateFormat('h:mm a')
            .format(DateTime(2023, 1, 1, realHour, min))
            .replaceAll('AM', 'ص')
            .replaceAll('PM', 'م');

        scheduleList.add({
          'timeStr': timeStr,
          'isBooked': isBooked,
          'matchedBooking': matchedBooking,
          'slotStart': slotStart,
          'slotEnd': slotEnd,
        });
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
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddCourtScreen(
                            venueId: widget.venue['id'],
                            venueCategory:
                                widget.venue['category'] ?? 'كرة قدم',
                            existingCourt: widget.court,
                          )));
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Date picker strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: AppTheme.surfaceDark,
            child: SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 14, // 2 weeks
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index));
                  final isSelected = date.day == _selectedDate.day &&
                      date.month == _selectedDate.month;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedDate = date;
                    }),
                    child: Container(
                      width: 60,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.neonBlue
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.white24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(DateFormat('E').format(date),
                              style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.bold)),
                          Text('${date.day}',
                              style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Manual booking hint
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.neonBlue.withValues(alpha: 0.08),
            child: const Text(
              '💡 اضغط على أي وقت متاح لحجزه يدوياً',
              style: TextStyle(color: AppTheme.neonBlue, fontSize: 13),
            ),
          ),

          // Time slot list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scheduleList.length,
              itemBuilder: (context, index) {
                final item = scheduleList[index];
                final isBooked = item['isBooked'] as bool;
                final timeStr = item['timeStr'] as String;
                final matchedBooking = item['matchedBooking'];
                final statusLabel = isBooked
                    ? 'محجوز (${matchedBooking?['status'] ?? ''})'
                    : 'متاح — اضغط للحجز اليدوي';

                return Card(
                  color: isBooked
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.green.withValues(alpha: 0.12),
                  child: ListTile(
                    leading: Icon(
                        isBooked ? Icons.lock : Icons.touch_app,
                        color: isBooked ? Colors.red : Colors.green),
                    title: Text('$timeStr',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(statusLabel,
                        style: TextStyle(
                            color:
                                isBooked ? Colors.redAccent : Colors.green,
                            fontSize: 12)),
                    onTap: isBooked
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppTheme.surfaceDark,
                                title: const Text('حجز يدوي',
                                    style: TextStyle(color: Colors.white)),
                                content: Text(
                                    'هل تريد حجز $timeStr يدوياً لمنع الحجز من خارج التطبيق؟',
                                    style: const TextStyle(
                                        color: Colors.white70)),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('إلغاء')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('تأكيد الحجز',
                                          style: TextStyle(
                                              color: AppTheme.neonBlue))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                final dio = ref.read(dioProvider);
                                final slotStart =
                                    item['slotStart'] as DateTime;
                                final slotEnd = item['slotEnd'] as DateTime;
                                await dio.post('/bookings', data: {
                                  'courtId': widget.court['id'],
                                  'startTime': slotStart.toUtc().toIso8601String(),
                                  'endTime': slotEnd.toUtc().toIso8601String(),
                                  'isManual': true,
                                });
                                ref.invalidate(venueDetailsProvider(widget.venue['id']));
                                ref.invalidate(venuesProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'تم الحجز اليدوي بنجاح ✅')));
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('خطأ أثناء الحجز: $e')));
                                }
                              }
                            }
                          },
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
