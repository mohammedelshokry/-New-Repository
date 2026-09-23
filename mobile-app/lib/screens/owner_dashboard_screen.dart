import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../providers/api_provider.dart';
import 'manage_venue_screen.dart';
import 'add_venue_screen.dart';
import 'edit_profile_screen.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddPitchDialog() {
    final nameCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final mapCtrl = TextEditingController();
    TimeOfDay openTime = const TimeOfDay(hour: 14, minute: 0);
    TimeOfDay closeTime = const TimeOfDay(hour: 2, minute: 0);
    
    String surface = 'Artificial Grass';
    String category = 'Football';
    bool indoor = false;
    XFile? selectedImage;
    Uint8List? imageBytes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'إضافة ملعب جديد',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الملعب',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.stadium),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الموقع (مثال: المعادي، القاهرة)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'السعر في الساعة (جنيه)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    try {
                      final dio = ref.read(dioProvider);
                      await dio.post('/pitches', data: {
                        'name': nameCtrl.text,
                        'location': locCtrl.text,
                        'pricePerHour': double.tryParse(priceCtrl.text) ?? 200,
                        'category': category,
                        'surface': surface,
                        'indoor': indoor,
                        'openTime': '${openTime.hour.toString().padLeft(2,'0')}:${openTime.minute.toString().padLeft(2,'0')}',
                        'closeTime': '${closeTime.hour.toString().padLeft(2,'0')}:${closeTime.minute.toString().padLeft(2,'0')}',
                        'images': 'https://images.unsplash.com/photo-1575361204480-aadea25e6e68?auto=format&fit=crop&q=80&w=800',
                        'description': descCtrl.text,
                        'googleMapsLink': mapCtrl.text,
                        'amenities': 'كرة، حمامات، كشافات'
                      });
                      ref.refresh(venuesProvider);
                      if (mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                    }
                  },
                  child: const Text('إضافة الملعب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _updateBookingStatus(String id, String status) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/bookings/$id/status', data: {'status': status});
      ref.refresh(myBookingsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'CONFIRMED' ? 'تم تأكيد الحجز' : 'تم رفض الحجز')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Widget _buildBookingCard(dynamic b, {required bool isPending}) {
    final st = DateTime.parse(b['startTime']).toLocal();
    final et = DateTime.parse(b['endTime']).toLocal();
    
    return Card(
      color: AppTheme.surfaceLighter,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${b['user']['name']} - ${b['pitch']['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('${st.year}-${st.month.toString().padLeft(2,'0')}-${st.day.toString().padLeft(2,'0')} | ${st.hour}:00 - ${et.hour}:00', style: const TextStyle(color: AppTheme.neonBlue)),
              trailing: Text('${b['ownerAmount']} ج.م', style: const TextStyle(color: AppTheme.neonOrange, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            if (isPending)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _updateBookingStatus(b['id'], 'REJECTED'),
                    child: const Text('رفض', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonBlue, foregroundColor: Colors.black),
                    onPressed: () => _updateBookingStatus(b['id'], 'CONFIRMED'),
                    child: const Text('قبول الحجز', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final pitchesAsync = ref.watch(venuesProvider);
    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('لوحة تحكم الملعب - مرحباً ${user?['name'] ?? ''}'),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
              tooltip: 'تسجيل خروج',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('jwt_token');
                ref.read(currentUserProvider.notifier).state = null;
                // GoRouter will redirect to auth because of main.dart wrapper or redirect logic
                if (context.mounted) {
                   context.go('/auth');
                }
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.neonBlue,
          labelColor: AppTheme.neonBlue,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'الملاعب', icon: Icon(Icons.stadium)),
            Tab(text: 'طلبات الحجز', icon: Icon(Icons.calendar_month)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddVenueScreen())),
        icon: const Icon(Icons.add),
        label: const Text('إضافة ملعب'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Pitches
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _statCard('حساب المالك', user?['phone'] ?? '', Icons.person, Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('حالة الحساب', 'نشط ومعتمد', Icons.verified, Colors.green)),
                  ],
                ),
                const SizedBox(height: 24),
                pitchesAsync.when(
                  data: (pitches) {
                    final ownerVenues = pitches.where((p) => p['ownerId'] == user?['id']).toList();
                    if (ownerVenues.isEmpty) return const Center(child: Text('لا توجد ملاعب. قم بإضافة ملعب جديد.'));
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ownerVenues.length,
                      itemBuilder: (context, index) {
                        final p = ownerVenues[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageVenueScreen(venue: p))),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                (p['images'] is List && (p['images'] as List).isNotEmpty) ? p['images'][0] : (p['images'] is String && (p['images'] as String).isNotEmpty && !(p['images'] as String).startsWith('[')) ? p['images'] : 'https://images.unsplash.com/photo-1575361204480-aadea25e6e68?auto=format&fit=crop&q=80&w=800',
                                width: 60, height: 60, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.stadium, size: 40),
                              ),
                            ),
                            title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${p['location']} • ${p['surface']}'),
                            trailing: Text('${p['pricePerHour']} ج.م/ساعة', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: SpinKitPulse(color: AppTheme.neonBlue, size: 50.0)),
                  error: (err, _) => Text('خطأ في التحميل: $err'),
                ),
              ],
            ),
          ),
          // Tab 2: Bookings
          bookingsAsync.when(
            data: (bookings) {
              if (bookings.isEmpty) return const Center(child: Text('لا توجد حجوزات', style: TextStyle(color: Colors.white)));
              
              final pending = bookings.where((b) => b['status'] == 'PENDING').toList();
              final confirmed = bookings.where((b) => b['status'] == 'CONFIRMED').toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (pending.isNotEmpty) ...[
                    const Text('طلبات قيد الانتظار', style: TextStyle(color: AppTheme.neonOrange, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...pending.map((b) => _buildBookingCard(b, isPending: true)),
                    const SizedBox(height: 20),
                  ],
                  const Text('حجوزات مؤكدة', style: TextStyle(color: AppTheme.neonBlue, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (confirmed.isEmpty) const Text('لا توجد حجوزات مؤكدة', style: TextStyle(color: Colors.grey)),
                  ...confirmed.map((b) => _buildBookingCard(b, isPending: false)),
                ],
              );
            },
            loading: () => const Center(child: SpinKitPulse(color: AppTheme.neonBlue, size: 50.0)),
            error: (e, st) => Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.white))),
          ),
        ],
      ),
    );
  }
}
