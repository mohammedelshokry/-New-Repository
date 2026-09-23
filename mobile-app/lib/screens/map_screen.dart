import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pitchesAsync = ref.watch(venuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('\u062e\u0631\u064a\u0637\u0629 \u0627\u0644\u0645\u0644\u0627\u0639\u0628', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: Colors.white,
      ),
      body: pitchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('\u062e\u0637\u0623: $err', style: const TextStyle(color: Colors.white)),
        ),
        data: (pitches) {
          final mappablePitches = pitches.where((p) {
            final loc = p['location'] as String? ?? '';
            final parts = loc.split(',');
            if (parts.length != 2) return false;
            final lat = double.tryParse(parts[0].trim());
            final lng = double.tryParse(parts[1].trim());
            return lat != null && lng != null;
          }).toList();

          return FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(30.0444, 31.2357),
              initialZoom: 11,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.spotaia.app',
              ),
              MarkerLayer(
                markers: mappablePitches.map((p) {
                  final parts = (p['location'] as String).split(',');
                  final lat = double.parse(parts[0].trim());
                  final lng = double.parse(parts[1].trim());
                  final pitchId = p['id'] as String;
                  final pitchName = p['name'] as String? ?? '\u0645\u0644\u0639\u0628';
                  return Marker(
                    point: LatLng(lat, lng),
                    width: 160,
                    height: 60,
                    child: GestureDetector(
                      onTap: () => context.push('/pitch/$pitchId'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.neonBlue,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.neonBlue.withOpacity(0.5),
                                  blurRadius: 8,
                                )
                              ],
                            ),
                            child: Text(
                              pitchName,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.location_on, color: AppTheme.neonOrange, size: 24),
                        ],
                      ),
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
}
