import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';
import 'dart:convert';

String getFullUrl(String url) {
  if (url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  if (url.startsWith('/')) return 'http://192.168.1.10:3001$url';
  return 'http://192.168.1.10:3001/$url';
}


class CourtBookingScreen extends ConsumerStatefulWidget {
  final dynamic court;
  final dynamic venue;
  const CourtBookingScreen({super.key, required this.court, required this.venue});

  @override
  ConsumerState<CourtBookingScreen> createState() => _CourtBookingScreenState();
}

class _CourtBookingScreenState extends ConsumerState<CourtBookingScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  double _durationHours = 1.0;
  bool _isLoading = false;

  List<Map<String, dynamic>> _generateTimeSlots() {
    final bookings = widget.court['bookings'] as List? ?? [];
    List<Map<String, dynamic>> slots = [];
    int openHour = 10;
    int closeHour = 23;
    if (widget.venue != null) {
      openHour = int.tryParse(widget.venue['openTime']?.split(':')[0] ?? '10') ?? 10;
      closeHour = int.tryParse(widget.venue['closeTime']?.split(':')[0] ?? '23') ?? 23;
    }
    if (closeHour <= openHour) closeHour += 24; // Handle past midnight

    for (int i = openHour; i < closeHour; i++) {
      for (int min in [0, 30]) {
        final realHour = i % 24;
        final isNextDay = i >= 24;
        final targetDate = isNextDay ? _selectedDate.add(const Duration(days: 1)) : _selectedDate;
        final slotStart = DateTime(targetDate.year, targetDate.month, targetDate.day, realHour, min);

        // Skip past times
        if (slotStart.isBefore(DateTime.now())) continue;

        bool isBooked = false;
        final slotEnd = slotStart.add(const Duration(minutes: 30));
        for (var b in bookings) {
          if (b['status'] == 'REJECTED' || b['status'] == 'CANCELLED') continue;

          final bSt = DateTime.parse(b['startTime']).toLocal();
          final bEt = DateTime.parse(b['endTime']).toLocal();

          // Check for overlap
          if (slotStart.isBefore(bEt) && slotEnd.isAfter(bSt)) {
            isBooked = true;
            break;
          }
        }

        final timeStr = DateFormat('h:mm a').format(DateTime(2023, 1, 1, realHour, min)).replaceAll('AM', 'ص').replaceAll('PM', 'م');
        slots.add({'val': '${realHour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}', 'label': timeStr, 'isBooked': isBooked, 'absMin': (i * 60) + min});
      }
    }
    return slots;
  }

  Future<void> _bookCourt() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار وقت')));
      return;
    }
    setState(() => _isLoading = true);
    
    try {
      final parts = _selectedTime!.split(':');
      int selectedHour = int.parse(parts[0]);
      int selectedMin = int.parse(parts[1]);

      int openHour = 10;
      int closeHour = 23;
      if (widget.venue != null) {
        openHour = int.tryParse(widget.venue['openTime']?.split(':')[0] ?? '10') ?? 10;
        closeHour = int.tryParse(widget.venue['closeTime']?.split(':')[0] ?? '23') ?? 23;
      }
      if (closeHour <= openHour) closeHour += 24;

      bool isNextDay = false;
      if (selectedHour < openHour && closeHour > 24) isNextDay = true;

      final targetDate = isNextDay ? _selectedDate.add(const Duration(days: 1)) : _selectedDate;
      final start = DateTime(targetDate.year, targetDate.month, targetDate.day, selectedHour, selectedMin);
      final durationMinutes = (_durationHours * 60).toInt();
      final end = start.add(Duration(minutes: durationMinutes));

      final dio = ref.read(dioProvider);
      await dio.post('/bookings', data: {
        'courtId': widget.court['id'],
        'startTime': start.toIso8601String(),
        'endTime': end.toIso8601String(),
      });
      
      ref.invalidate(myBookingsProvider);
      ref.invalidate(venuesProvider);
      ref.invalidate(venueDetailsProvider(widget.court['venueId']));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الحجز بنجاح')));
        Navigator.pop(context);
      }
    } catch (e) {
      String errorMsg = 'حدث خطأ غير معروف';
      if (e is DioException && e.response?.data != null && e.response?.data['error'] != null) {
        errorMsg = e.response!.data['error'];
      } else {
        errorMsg = e.toString();
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحجز: $errorMsg')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> images = [];
    if (widget.court['images'] is List) images = List<String>.from(widget.court['images']);
    
    Map<String, dynamic> amenities = {};
    if (widget.court['amenities'] is Map) {
      amenities = widget.court['amenities'];
    } else if (widget.court['amenities'] is String && (widget.court['amenities'] as String).isNotEmpty) {
      try { amenities = jsonDecode(widget.court['amenities']); } catch(e){}
    }

    final slots = _generateTimeSlots();

    return Scaffold(
      appBar: AppBar(title: Text(widget.court['name'])),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (images.isNotEmpty)
              CarouselSlider(
                options: CarouselOptions(height: 250.0, enableInfiniteScroll: false, enlargeCenterPage: true),
                items: images.map((url) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(getFullUrl(url), fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => Container(color: Colors.grey)),
                )).toList(),
              )
            else
              Container(height: 250, color: Colors.grey, child: const Icon(Icons.image, size: 50)),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.court['pricePerHour']} ج.م/ساعة', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.neonOrange)),
                  const SizedBox(height: 16),
                  
                  const Text('مواصفات وتجهيزات:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.neonBlue)),
                  const SizedBox(height: 8),
                  if (amenities.isNotEmpty) ...[
                    if (widget.court['category'] == 'بلايستيشن' && amenities['psConsole'] != null) Text('الجهاز: ${amenities['psConsole']}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    if (widget.court['category'] == 'بلايستيشن' && amenities['psRoomType'] != null) Text('النوع: ${amenities['psRoomType']}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    if (widget.court['category'] == 'بادل' && amenities['courtType'] != null) Text('النوع: ${amenities['courtType']}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    if (widget.court['category'] == 'كرة قدم' && amenities['footballSize'] != null) Text('المساحة: ${amenities['footballSize']}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    if (widget.court['category'] == 'بلياردو' && amenities['billiardsType'] != null) Text('النوع: ${amenities['billiardsType']}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    Text(amenities['isAirConditioned'] == true ? 'مكيف ❄️' : 'غير مكيف', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    if ((widget.court['category'] == 'كرة قدم' || widget.court['category'] == 'بادل') && amenities['ballIncluded'] == true) const Text('كرة مجانية مع الحجز ⚽', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                  const SizedBox(height: 24),

                  const Text('تاريخ الحجز:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 14, // 2 weeks
                      itemBuilder: (context, index) {
                        final date = DateTime.now().add(Duration(days: index));
                        final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
                        return GestureDetector(
                          onTap: () => setState(() { _selectedDate = date; _selectedTime = null; }),
                          child: Container(
                            width: 60, margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.neonBlue : AppTheme.surfaceDark,
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
                  
                  const SizedBox(height: 24),
                  const Text('الوقت المتاح:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12, runSpacing: 12,
                    children: slots.map((timeMap) {
                      final timeVal = timeMap['val'] as String;
                      final timeLabel = timeMap['label'];
                      final isBooked = timeMap['isBooked'] == true;
                      final absMin = timeMap['absMin'] as int;
                      
                      bool isSelected = false;
                      if (_selectedTime != null) {
                        // Find the selected slot's absMin
                        final selSlot = slots.firstWhere((s) => s['val'] == _selectedTime, orElse: () => slots.first);
                        final selAbsMin = selSlot['absMin'] as int;
                        
                        int durationMinutes = (_durationHours * 60).toInt();
                        int selEndAbsMin = selAbsMin + durationMinutes;
                        
                        if (absMin >= selAbsMin && absMin < selEndAbsMin) {
                          isSelected = true;
                        }
                      }
                      
                      return ChoiceChip(
                        label: Text(isBooked ? '$timeLabel (محجوز)' : timeLabel, style: TextStyle(color: isBooked ? Colors.white54 : (isSelected ? Colors.black : Colors.white))),
                        selected: isSelected && !isBooked,
                        onSelected: isBooked ? null : (val) {
                          setState(() {
                            if (val) {
                              _selectedTime = timeVal;
                            } else {
                              _selectedTime = null;
                            }
                          });
                        },
                        selectedColor: AppTheme.neonOrange,
                        backgroundColor: isBooked ? Colors.grey.withValues(alpha: 0.3) : AppTheme.surfaceDark,
                        disabledColor: Colors.red.withValues(alpha: 0.2),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                  const Text('مدة الحجز:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: AppTheme.surfaceDark, borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<double>(
                        value: _durationHours,
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceDark,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        items: [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0, 6.0].map((val) {
                          return DropdownMenuItem<double>(
                            value: val,
                            child: Text('$val ساعة'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _durationHours = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _bookCourt,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonBlue, foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('تأكيد الحجز', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
