import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/api_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.sports_soccer, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              _selectedIndex == 0 ? 'الملاعب المتاحة' : (_selectedIndex == 1 ? 'مجتمع اللاعبين' : 'حسابي'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'تسجيل خروج',
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => ref.read(currentUserProvider.notifier).state = null,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.stadium_outlined), selectedIcon: Icon(Icons.stadium), label: 'الملاعب'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'مطلوب لاعب'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
      body: _selectedIndex == 0
          ? _buildPitchesTab()
          : (_selectedIndex == 1 ? _buildMatchesTab() : _buildProfileTab(user)),
    );
  }

  Widget _buildPitchesTab() {
    final pitchesAsync = ref.watch(pitchesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(pitchesProvider),
      child: pitchesAsync.when(
        data: (pitches) => ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: pitches.length,
          itemBuilder: (context, index) {
            final pitch = pitches[index];
            final images = pitch['images'] as List? ?? [];
            final imgUrl = images.isNotEmpty ? images[0] : '';

            return Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: InkWell(
                onTap: () => context.push('/pitch/${pitch['id']}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.network(
                      imgUrl,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.sports_soccer, size: 50, color: Colors.grey),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  pitch['name'] ?? '',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${pitch['pricePerHour']} ج.م/ساعة',
                                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(pitch['location'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            children: [
                              Chip(
                                label: Text(pitch['surface'] ?? '', style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              if (pitch['indoor'] == true)
                                Chip(
                                  label: const Text('صالة مغطاة', style: TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.blue.shade50,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 50, color: Colors.grey),
                const SizedBox(height: 12),
                Text('تعذر الاتصال بالسيرفر: $err', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                  onPressed: () => ref.refresh(pitchesProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchesTab() {
    final matchesAsync = ref.watch(matchRequestsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(matchRequestsProvider),
      child: matchesAsync.when(
        data: (matches) => matches.isEmpty
            ? const Center(child: Text('لا توجد طلبات لاعبين حالياً'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final m = matches[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(m['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                                child: Text('ناقص ${m['missingSpots']} لاعبين', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(m['description'] ?? '', style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('حصة الفرد: ${m['costPerSpot']} ج.م', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ElevatedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('تواصل مع المنظم: ${m['creator']?['phone'] ?? ''}')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text('انضم للمباراة', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('خطأ في تحميل المباريات: $err')),
      ),
    );
  }

  Widget _buildProfileTab(Map<String, dynamic>? user) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: Colors.green.shade100,
            child: Icon(Icons.person, size: 50, color: Colors.green.shade800),
          ),
          const SizedBox(height: 16),
          Text(user?['name'] ?? 'مستخدم', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(user?['phone'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          Chip(
            label: Text(user?['role'] == 'OWNER' ? 'صاحب ملعب / منشأة' : 'لاعب'),
            backgroundColor: Colors.green.shade50,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل خروج'),
              onPressed: () => ref.read(currentUserProvider.notifier).state = null,
            ),
          ),
        ],
      ),
    );
  }
}
