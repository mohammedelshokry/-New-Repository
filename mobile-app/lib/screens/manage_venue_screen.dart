import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../providers/api_provider.dart';
import 'add_court_screen.dart';
import 'court_schedule_screen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class ManageVenueScreen extends ConsumerWidget {
  final dynamic venue;
  const ManageVenueScreen({super.key, required this.venue});

  
  String formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    try {
      final parts = time.split(':');
      final dt = DateTime(2023, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('h:mm a').format(dt).replaceAll('AM', 'ص').replaceAll('PM', 'م');
    } catch (_) {
      return time;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueDetailsAsync = ref.watch(venueDetailsProvider(venue['id']));

    return Scaffold(
      appBar: AppBar(title: Text('إدارة: ${venue['name']}')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.neonBlue,
        foregroundColor: Colors.black,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddCourtScreen(venueId: venue['id'], venueCategory: venue['category'] ?? 'كرة قدم'))),
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
                      Text('الموقع: ${details['location']}'),
                      Text('ساعات العمل: ${formatTime(details['openTime'])} - ${formatTime(details['closeTime'])}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('الملاعب والغرف (${courts.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              if (courts.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد ملاعب أو غرف مضافة حتى الآن.', style: TextStyle(color: Colors.grey)))),
              ...courts.map((c) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text('${c['category']} - ${c['pricePerHour']} ج.م/ساعة'),
                  trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => AddCourtScreen(venueId: venue['id'], venueCategory: venue['category'] ?? 'كرة قدم', existingCourt: c)));
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: AppTheme.surfaceDark,
                                        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red)),
                                        content: const Text('هل أنت متأكد من حذف هذه الغرفة/الملعب بشكل نهائي؟ سيتم حذف جميع الحجوزات المتعلقة بها.', style: TextStyle(color: Colors.white)),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('نعم، احذف', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        final dio = ref.read(dioProvider);
                                        await dio.delete('/courts/${c['id']}');
                                        ref.invalidate(venueDetailsProvider(venue['id']));
                                        ref.invalidate(venuesProvider);
                                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح')));
                                      } catch (e) {
                                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                                      }
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.calendar_month, color: AppTheme.neonBlue),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => CourtScheduleScreen(venue: details, court: c)));
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CourtScheduleScreen(venue: details, court: c)));
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
