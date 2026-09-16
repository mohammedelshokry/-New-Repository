import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_provider.dart';

class PitchDetailsScreen extends ConsumerWidget {
  final String pitchId;
  const PitchDetailsScreen({super.key, required this.pitchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(pitchDetailsProvider(pitchId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الملعب'),
      ),
      body: detailsAsync.when(
        data: (pitch) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.network(
                  pitch['images'][0],
                  height: 250,
                  fit: BoxFit.cover,
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pitch['name'], style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(pitch['description'], style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      const Text('المرافق المتاحة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Wrap(
                        spacing: 8.0,
                        children: (pitch['amenities'] as List).map((a) => Chip(label: Text(a.toString()))).toList(),
                      ),
                      const SizedBox(height: 24),
                      const Text('المواعيد المتاحة اليوم:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _generateTimeSlots(context, pitch['bookings'] as List),
                      )
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ: $err')),
      ),
      bottomNavigationBar: detailsAsync.hasValue ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحويلك لصفحة الدفع (فودافون كاش / إنستاباي)...')));
          },
          child: const Text('احجز الآن (دفع عربون)', style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
      ) : null,
    );
  }

  List<Widget> _generateTimeSlots(BuildContext context, List bookings) {
    // Basic logic for generating slots from 14:00 to 22:00
    List<Widget> slots = [];
    for (int hour = 14; hour <= 22; hour++) {
      String time = '$hour:00';
      bool isBooked = bookings.any((b) {
        final start = DateTime.parse(b['startTime']).toLocal();
        return start.hour == hour;
      });
      slots.add(_buildTimeSlot(context, time, !isBooked));
    }
    return slots;
  }

  Widget _buildTimeSlot(BuildContext context, String time, bool available) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: available ? Colors.green.shade100 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: available ? Colors.green : Colors.grey),
      ),
      child: Text(
        time,
        style: TextStyle(
          color: available ? Colors.green.shade800 : Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          decoration: available ? TextDecoration.none : TextDecoration.lineThrough,
        ),
      ),
    );
  }
}
