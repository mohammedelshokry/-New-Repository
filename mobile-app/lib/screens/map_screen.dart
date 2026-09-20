import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pitchesAsync = ref.watch(pitchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملاعب القريبة', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: pitchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ: $err')),
        data: (pitches) {
          // Default center: Cairo, Egypt
          final MapController mapController = MapController();
          return FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: const LatLng(30.0444, 31.2357),
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.spotaia.app',
              ),
              MarkerLayer(
                markers: pitches.where((p) => p['location'] != null).map((pitch) {
                  // Assume location is stored as "lat,lng" string or we just fake it for now if not available
                  // Let's generate a slight offset from Cairo for demo purposes if not available
                  double lat = 30.0444 + (pitch['id'].hashCode % 100) / 1000.0;
                  double lng = 31.2357 + (pitch['name'].hashCode % 100) / 1000.0;
                  
                  return Marker(
                    point: LatLng(lat, lng),
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: AppTheme.surfaceLighter,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                          builder: (ctx) => _buildPitchCard(context, pitch, lat, lng),
                        );
                      },
                      child: const Icon(Icons.location_on, color: AppTheme.neonBlue, size: 40),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPitchCard(BuildContext context, Map<String, dynamic> pitch, double lat, double lng) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(pitch['name'] ?? 'ملعب', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.neonBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text('${pitch['pricePerHour']} ج.م / ساعة', style: const TextStyle(color: AppTheme.neonBlue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_city, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text(pitch['city'] ?? 'مدينة', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonBlue,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/pitch/${pitch['id']}');
                  },
                  icon: const Icon(Icons.sports_soccer),
                  label: const Text('احجز الآن'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceLighter,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                icon: const Icon(Icons.directions),
                label: const Text('الاتجاهات'),
              ),
            ],
          )
        ],
      ),
    );
  }
}
