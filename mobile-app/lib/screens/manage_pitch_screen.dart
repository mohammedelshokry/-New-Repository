import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_provider.dart';

class ManagePitchScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> pitch;
  const ManagePitchScreen({super.key, required this.pitch});

  @override
  ConsumerState<ManagePitchScreen> createState() => _ManagePitchScreenState();
}

class _ManagePitchScreenState extends ConsumerState<ManagePitchScreen> {
  DateTime selectedDate = DateTime.now();

  void _addManualBooking() {
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إضافة حجز يدوي (أوفلاين)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                title: Text(startTime == null ? 'اختر وقت البداية' : 'البداية: ${startTime!.format(context)}'),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 16, minute: 0));
                  if (t != null) setModalState(() => startTime = t);
                },
              ),
              ListTile(
                title: Text(endTime == null ? 'اختر وقت النهاية' : 'النهاية: ${endTime!.format(context)}'),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 17, minute: 0));
                  if (t != null) setModalState(() => endTime = t);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF121212), foregroundColor: Colors.white),
                onPressed: () async {
                  if (startTime == null || endTime == null) return;
                  
                  final startDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, startTime!.hour, startTime!.minute);
                  final endDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, endTime!.hour, endTime!.minute);
                  
                  try {
                    final dio = ref.read(dioProvider);
                    await dio.post('/bookings', data: {
                      'pitchId': widget.pitch['id'],
                      'startTime': startDt.toIso8601String(),
                      'endTime': endDt.toIso8601String(),
                      'isManual': true,
                    });
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ref.invalidate(pitchesProvider);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حجز الميعاد يدوياً بنجاح وإغلاقه أمام اللاعبين!')));
                    setState(() {}); // Refresh bookings
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ: الميعاد محجوز بالفعل أو غير متاح')));
                  }
                },
                child: const Text('تأكيد الحجز اليدوي'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<dynamic>> _fetchBookings() async {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/bookings');
    final List all = res.data;
    return all.where((b) => b['pitchId'] == widget.pitch['id']).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة: ${widget.pitch['name']}'),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManualBooking,
        icon: const Icon(Icons.block),
        label: const Text('حجز يدوي'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _fetchBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final bookings = snapshot.data ?? [];
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ساعات العمل: ${widget.pitch['openTime']} إلى ${widget.pitch['closeTime']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('إجمالي التقييمات: ${widget.pitch['rating']} ⭐ (${widget.pitch['totalReviews']} تقييم)'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('حجوزات الملعب:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (bookings.isEmpty) const Text('لا يوجد حجوزات حتى الآن.'),
              ...bookings.map((b) {
                final st = DateTime.parse(b['startTime']).toLocal();
                final et = DateTime.parse(b['endTime']).toLocal();
                final isManual = b['isManual'] == true;
                return Card(
                  color: isManual ? Colors.orange.shade50 : Colors.green.shade50,
                  child: ListTile(
                    leading: Icon(isManual ? Icons.back_hand : Icons.phone_android, color: isManual ? Colors.orange : Colors.green),
                    title: Text('${st.day}/${st.month} - من ${st.hour}:${st.minute.toString().padLeft(2, '0')} إلى ${et.hour}:${et.minute.toString().padLeft(2, '0')}'),
                    subtitle: Text(isManual ? 'حجز يدوي (أوفلاين)' : 'حجز إلكتروني (${b['user']?['name'] ?? ''})'),
                    trailing: Text('${b['price']} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ],
          );
        }
      ),
    );
  }
}