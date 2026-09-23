import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../providers/api_provider.dart';
import 'add_court_screen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class ManageVenueScreen extends ConsumerWidget {
  final dynamic venue;
  const ManageVenueScreen({super.key, required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueDetailsAsync = ref.watch(venueDetailsProvider(venue['id']));

    return Scaffold(
      appBar: AppBar(title: Text('إدارة: ')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.neonBlue,
        foregroundColor: Colors.black,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddCourtScreen(venueId: venue['id']))),
        icon: const Icon(Icons.add),
        label: const Text('إضافة غرفة/ملعب'),
      ),
      body: venueDetailsAsync.when(
        data: (details) {
          final courts = details['courts'] as List;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المعلومات الأساسية', style: TextStyle(color: AppTheme.neonBlue, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('الموقع: '),
                      Text('ساعات العمل:  - '),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('الملاعب والغرف ()', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              if (courts.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد ملاعب أو غرف مضافة حتى الآن.', style: TextStyle(color: Colors.grey)))),
              ...courts.map((c) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text(' -  ج.م/ساعة'),
                  trailing: const Icon(Icons.edit, color: Colors.white54),
                  onTap: () {
                    // TODO: Edit court screen if needed
                  },
                ),
              )),
            ],
          );
        },
        loading: () => const Center(child: SpinKitPulse(color: AppTheme.neonBlue, size: 50.0)),
        error: (e, _) => Center(child: Text('خطأ: ')),
      ),
    );
  }
}
