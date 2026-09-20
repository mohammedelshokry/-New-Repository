import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme/app_theme.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? selectedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حدد الموقع على الخريطة'),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: Colors.white,
        actions: [
          if (selectedLocation != null)
            IconButton(
              icon: const Icon(Icons.check, color: AppTheme.neonBlue),
              onPressed: () => Navigator.pop(context, selectedLocation),
            )
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: const LatLng(30.0444, 31.2357), // Cairo default
          initialZoom: 13,
          onTap: (tapPosition, point) {
            setState(() {
              selectedLocation = point;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.spotaia.app',
          ),
          if (selectedLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: selectedLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
