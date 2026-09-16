import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_provider.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  void _showAddPitchDialog() {
    final nameCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String surface = 'Artificial Grass';
    bool indoor = false;

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
                    labelText: 'سعر الساعة (ج.م)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'وصف الملعب والمرافق',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: surface,
                  decoration: const InputDecoration(
                    labelText: 'نوع الأرضية',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Artificial Grass', child: Text('نجيل صناعي')),
                    DropdownMenuItem(value: 'Natural Grass', child: Text('نجيل طبيعي')),
                    DropdownMenuItem(value: 'Blue Turf', child: Text('بادل (ترتان أزرق)')),
                    DropdownMenuItem(value: 'Hardwood', child: Text('باركيه صالة مغطاة')),
                    DropdownMenuItem(value: 'Cloth', child: Text('طاولة بلياردو / سنوكر')),
                  ],
                  onChanged: (val) => setModalState(() => surface = val ?? surface),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('ملعب مغطى / داخلي (Indoor)'),
                  value: indoor,
                  onChanged: (val) => setModalState(() => indoor = val),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || locCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('من فضلك أكمل البيانات المطلوبة')),
                      );
                      return;
                    }

                    final dio = ref.read(dioProvider);
                    try {
                      await dio.post('/pitches', data: {
                        'name': nameCtrl.text.trim(),
                        'location': locCtrl.text.trim(),
                        'pricePerHour': double.tryParse(priceCtrl.text.trim()) ?? 150,
                        'description': descCtrl.text.trim(),
                        'surface': surface,
                        'indoor': indoor,
                        'amenities': ['إضاءة ليلية', 'غرف تبديل ملابس', 'موقف سيارات'],
                        'images': [
                          'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?q=80&w=800&auto=format&fit=crop'
                        ],
                      });

                      if (!mounted) return;
                      Navigator.pop(ctx);
                      ref.invalidate(pitchesProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تمت إضافة الملعب بنجاح!')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('فشل إضافة الملعب: $e')),
                      );
                    }
                  },
                  child: const Text('حفظ ونشر الملعب', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final pitchesAsync = ref.watch(pitchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('لوحة تحكم الملعب - مرحباً ${user?['name'] ?? ''}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تسجيل خروج',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(currentUserProvider.notifier).state = null,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        onPressed: _showAddPitchDialog,
        icon: const Icon(Icons.add),
        label: const Text('إضافة ملعب'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _statCard('حساب المالك', user?['phone'] ?? '', Icons.person, Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard('حالة الحساب', 'نشط ومعتمد', Icons.verified, Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'الملاعب المتاحة على المنصة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            pitchesAsync.when(
              data: (pitches) => ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pitches.length,
                itemBuilder: (context, index) {
                  final p = pitches[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          p['images']?[0] ?? '',
                          width: 60, height: 60, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.stadium, size: 40),
                        ),
                      ),
                      title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${p['location']} • ${p['surface']}'),
                      trailing: Text(
                        '${p['pricePerHour']} ج.م/ساعة',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('خطأ في التحميل: $err'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String val, IconData icon, Color col) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: col.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: col, size: 24),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: col)),
        ],
      ),
    );
  }
}
