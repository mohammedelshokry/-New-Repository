import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'court_booking_screen.dart';

class VenueDetailsScreen extends ConsumerWidget {
  final String venueId;
  const VenueDetailsScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueDetailsProvider(venueId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المكان', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: venueAsync.when(
        data: (venue) {
          final courts = venue['courts'] as List;
          List<String> images = [];
          if (venue['images'] is List) {
            images = List<String>.from(venue['images']);
          } else if (venue['images'] is String) {
            images = [venue['images']];
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (images.isNotEmpty)
                  CarouselSlider(
                    options: CarouselOptions(height: 300.0, autoPlay: true, viewportFraction: 1.0),
                    items: images.map((url) => Image.network(url, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => Container(color: Colors.grey))).toList(),
                  )
                else
                  Container(height: 300, color: Colors.grey, child: const Icon(Icons.business, size: 80)),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(venue['name'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppTheme.neonOrange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(venue['location'], style: const TextStyle(color: Colors.white70, fontSize: 16))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: AppTheme.neonBlue, size: 20),
                          const SizedBox(width: 8),
                          Text('مفتوح:  - ', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('عن المكان', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(venue['description'] ?? 'لا يوجد وصف', style: const TextStyle(color: Colors.white70, height: 1.5)),
                      const SizedBox(height: 24),
                      
                      const Text('الملاعب والغرف المتاحة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.neonBlue)),
                      const SizedBox(height: 16),
                      if (courts.isEmpty)
                        const Center(child: Text('لا توجد ملاعب أو غرف متاحة.', style: TextStyle(color: Colors.grey)))
                      else
                        ...courts.map((court) {
                          List<String> courtImages = [];
                          if (court['images'] is List) courtImages = List<String>.from(court['images']);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourtBookingScreen(court: court, venue: venue))),
                              borderRadius: BorderRadius.circular(16),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                                    child: courtImages.isNotEmpty 
                                      ? Image.network(courtImages[0], width: 120, height: 120, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 120, height: 120, color: Colors.grey))
                                      : Container(width: 120, height: 120, color: Colors.grey, child: const Icon(Icons.sports_soccer)),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(court['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                          const SizedBox(height: 4),
                                          Text(court['category'], style: const TextStyle(color: AppTheme.neonBlue)),
                                          const SizedBox(height: 8),
                                          Text(' ج.م/ساعة', style: const TextStyle(color: AppTheme.neonOrange, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: SpinKitPulse(color: AppTheme.neonBlue, size: 50.0)),
        error: (e, _) => Center(child: Text('خطأ: ')),
      ),
    );
  }
}
