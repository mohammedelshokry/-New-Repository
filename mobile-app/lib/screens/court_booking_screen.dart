import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';
import 'dart:convert';

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
  bool _isLoading = false;

  List<String> _generateTimeSlots() {
    // simplified: ignoring venue open/close strictness for demo, but can be added
    List<String> slots = [];
    for (int i = 10; i <= 23; i++) {
      slots.add(':00');
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
      final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, int.parse(parts[0]), 0);
      final end = start.add(const Duration(hours: 1));

      final dio = ref.read(dioProvider);
      await dio.post('/bookings', data: {
        'courtId': widget.court['id'],
        'startTime': start.toIso8601String(),
        'endTime': end.toIso8601String(),
      });
      
      ref.refresh(myBookingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الحجز بنجاح')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحجز: ')));
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
                  child: Image.network(url, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => Container(color: Colors.grey)),
                )).toList(),
              )
            else
              Container(height: 250, color: Colors.grey, child: const Icon(Icons.image, size: 50)),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(' ج.م/ساعة', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.neonOrange)),
                  const SizedBox(height: 16),
                  
                  const Text('مواصفات وتجهيزات:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.neonBlue)),
                  const SizedBox(height: 8),
                  if (amenities.isNotEmpty) ...[
                    if (amenities['psConsole'] != null) Text('الجهاز: ', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    if (amenities['psRoomType'] != null) Text('النوع: ', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    if (amenities['footballSize'] != null) Text('المساحة: ', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    if (amenities['billiardsType'] != null) Text('النوع: ', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    Text(amenities['isAirConditioned'] == true ? 'مكيف ❄️' : 'غير مكيف', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    if (amenities['ballIncluded'] == true) const Text('كرة مجانية مع الحجز ⚽', style: TextStyle(color: Colors.white, fontSize: 16)),
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
                                Text('', style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
                    children: slots.map((time) {
                      final isSelected = _selectedTime == time;
                      return ChoiceChip(
                        label: Text(time),
                        selected: isSelected,
                        onSelected: (val) => setState(() => _selectedTime = val ? time : null),
                        selectedColor: AppTheme.neonOrange,
                        backgroundColor: AppTheme.surfaceDark,
                        labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
                      );
                    }).toList(),
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
