import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.sports_soccer, color: Color(0xFF00E5FF)),
            const SizedBox(width: 8),
            Text(
              _selectedIndex == 0 ? 'الملاعب المتاحة' : (_selectedIndex == 1 ? 'مجتمع اللاعبين' : (_selectedIndex == 2 ? 'قائمة المتصدرين' : 'حسابي')),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF121212),
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
        destinations: [
          NavigationDestination(icon: const Icon(Icons.stadium_outlined), selectedIcon: const Icon(Icons.stadium).animate().scale(duration: 300.ms, curve: Curves.easeOutBack), label: 'الملاعب'),
          NavigationDestination(icon: const Icon(Icons.groups_outlined), selectedIcon: const Icon(Icons.groups).animate().scale(duration: 300.ms, curve: Curves.easeOutBack), label: 'مطلوب لاعب'),
          NavigationDestination(icon: const Icon(Icons.emoji_events_outlined), selectedIcon: const Icon(Icons.emoji_events).animate().scale(duration: 300.ms, curve: Curves.easeOutBack), label: 'الترتيب'),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person).animate().scale(duration: 300.ms, curve: Curves.easeOutBack), label: 'حسابي'),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
              child: child,
            ),
          );
        },
        child: _selectedIndex == 0
            ? KeyedSubtree(key: const ValueKey(0), child: _buildPitchesTab())
            : (_selectedIndex == 1 
                ? KeyedSubtree(key: const ValueKey(1), child: _buildMatchesTab()) 
                : (_selectedIndex == 2 
                    ? KeyedSubtree(key: const ValueKey(2), child: _buildLeaderboardTab()) 
                    : KeyedSubtree(key: const ValueKey(3), child: _buildProfileTab(context, ref, user)))),
      ),
    );
  }

  Widget _buildPitchesTab() {
    final pitchesAsync = ref.watch(pitchesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(pitchesProvider),
      child: pitchesAsync.when(
        loading: () => ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: 4,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade900,
                highlightColor: Colors.grey.shade800,
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        error: (err, stack) => Center(
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
        data: (pitches) {
          final filteredPitches = _selectedCategory == 'All' 
              ? pitches 
              : pitches.where((p) => p['category'] == _selectedCategory).toList();
              
          return Column(
            children: [
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: ['All', 'Football', 'Padel', 'PlayStation'].map((cat) {
                    final isSelected = _selectedCategory == cat;
                    final label = cat == 'All' ? 'الكل' : (cat == 'Football' ? 'ملاعب قدم' : (cat == 'Padel' ? 'بادل' : 'بلايستيشن'));
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setState(() => _selectedCategory = cat);
                        },
                        selectedColor: const Color(0xFF00E5FF).withOpacity(0.2),
                        labelStyle: TextStyle(color: isSelected ? const Color(0xFF00E5FF) : Colors.white),
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12.0),
                  itemCount: filteredPitches.length,
                  itemBuilder: (context, index) {
                    final pitch = filteredPitches[index];
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
                            Hero(
                              tag: 'pitch_image_',
                              child: Image.network(
                              imgUrl,
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 180,
                                color: Colors.grey.shade900,
                                child: const Icon(Icons.sports_soccer, size: 50, color: Colors.grey),
                              ),
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
                                      Expanded(child: Text(pitch['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      Text('${pitch['pricePerHour']} ج.م/ساعة', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 16)),
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
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.stars, size: 16, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text('+ نقطة لكل ساعة', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
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
                                          backgroundColor: Colors.blue.withOpacity(0.1),
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
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatchesTab() {
    final matchesAsync = ref.watch(matchRequestsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateMatchDialog(),
        backgroundColor: const Color(0xFF00E5FF),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('طلب لاعبين', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(matchRequestsProvider),
        child: matchesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('خطأ: $err')),
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
                                  decoration: BoxDecoration(color: const Color(0xFFFF9100).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text('ناقص ${m['missingSpots']} لاعبين', style: const TextStyle(color: Color(0xFFFF9100), fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(m['description'] ?? '', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('حصة الفرد: ${m['costPerSpot']} ج.م', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00E5FF),
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('تم إرسال طلب الانضمام')),
                                    );
                                  },
                                  child: const Text('انضمام'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(leaderboardProvider),
      child: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ: $err')),
        data: (users) => users.isEmpty
            ? const Center(child: Text('لا يوجد لاعبين حتى الآن'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final u = users[index];
                  final bool isTop3 = index < 3;
                  Color rankColor = Colors.grey;
                  if (index == 0) rankColor = const Color(0xFFFFD700); // Gold
                  if (index == 1) rankColor = const Color(0xFFC0C0C0); // Silver
                  if (index == 2) rankColor = const Color(0xFFCD7F32); // Bronze
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: isTop3 ? 4 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isTop3 ? BorderSide(color: rankColor.withOpacity(0.5), width: 1.5) : BorderSide.none,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('#${index + 1}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isTop3 ? rankColor : Colors.grey)),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            backgroundColor: isTop3 ? rankColor.withOpacity(0.2) : const Color(0xFF00E5FF).withOpacity(0.1),
                            backgroundImage: u['profilePic'] != null && u['profilePic'] != '' ? NetworkImage(u['profilePic']) : null,
                            child: (u['profilePic'] == null || u['profilePic'] == '') ? Icon(Icons.person, color: isTop3 ? rankColor : const Color(0xFF00E5FF)) : null,
                          ),
                        ],
                      ),
                      title: Text(u['name'] ?? 'لاعب', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(u['level'] ?? 'BRONZE', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stars, color: Colors.amber, size: 20),
                          Text('${u['points']}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ).animate().fade(duration: 400.ms, delay: (100 * index).ms).slideX(begin: 0.1);
                },
              ),
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, WidgetRef ref, Map<String, dynamic>? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: const Color(0xFF00E5FF).withOpacity(0.1),
            child: const Icon(Icons.person, size: 50, color: Color(0xFF00E5FF)),
          ),
          const SizedBox(height: 16),
          Text(user?['name'] ?? 'مستخدم', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(user?['phone'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          Chip(
            label: Text(user?['role'] == 'OWNER' ? 'صاحب ملعب / منشأة' : 'لاعب'),
            backgroundColor: const Color(0xFF00E5FF).withOpacity(0.1),
            side: BorderSide.none,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('تعديل الحساب'),
            onPressed: () => _showEditProfileDialog(context, ref, user),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00E5FF),
              side: const BorderSide(color: Color(0xFF00E5FF)),
            ),
          ),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('حجوزاتي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, child) {
              final bookingsAsync = ref.watch(myBookingsProvider);
              return bookingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('خطأ: $e'),
                data: (bookings) => bookings.isEmpty
                    ? const Padding(padding: EdgeInsets.all(20), child: Text('لم تقم بأي حجز بعد.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: bookings.length,
                        itemBuilder: (context, index) {
                          final b = bookings[index];
                          final pitchName = b['pitch']?['name'] ?? 'ملعب';
                          final start = DateTime.tryParse(b['startTime'] ?? '')?.toLocal();
                          final end = DateTime.tryParse(b['endTime'] ?? '')?.toLocal();
                          final dateStr = start != null ? "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}" : '';
                          final timeStr = start != null && end != null ? "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}" : '';
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const Icon(Icons.sports_soccer, color: Color(0xFF00E5FF)),
                              title: Text(pitchName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(dateStr + '\n' + timeStr),
                              trailing: Text("${b['price']} ج.م", style: const TextStyle(color: Color(0xFFFF9100), fontWeight: FontWeight.bold)),
                              isThreeLine: true,
                            ),
                          ).animate().fade(duration: 400.ms, delay: (100 * index).ms).slideX(begin: 0.1);
                        },
                      ),
              );
            },
          ),
          const SizedBox(height: 32),
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

  
  void _showCreateMatchDialog() {
    String title = '';
    String desc = '';
    String spots = '1';
    String cost = '50';
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('إضافة طلب لاعبين', style: TextStyle(color: Color(0xFF00E5FF))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: const InputDecoration(labelText: 'العنوان (مثال: محتاجين 2 لاعيبة)'), onChanged: (v) => title = v),
              const SizedBox(height: 8),
              TextField(decoration: const InputDecoration(labelText: 'التفاصيل واسم الملعب'), onChanged: (v) => desc = v),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(decoration: const InputDecoration(labelText: 'العدد الناقص'), keyboardType: TextInputType.number, onChanged: (v) => spots = v)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(decoration: const InputDecoration(labelText: 'حصة الفرد (ج.م)'), keyboardType: TextInputType.number, onChanged: (v) => cost = v)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
            onPressed: () async {
              try {
                await ref.read(dioProvider).post('/match-requests', data: {
                  'title': title, 'description': desc, 'missingSpots': spots, 'costPerSpot': cost, 'matchTime': date.toIso8601String()
                });
                if (mounted) { Navigator.pop(ctx); ref.refresh(matchRequestsProvider); }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
              }
            },
            child: const Text('نشر الطلب'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, Map<String, dynamic>? user) {
    if (user == null) return;
    String name = user['name'] ?? '';
    String phone = user['phone'] ?? '';
    String profilePic = user['profilePic'] ?? '';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الحساب'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'الاسم'),
                controller: TextEditingController(text: name)..selection = TextSelection.collapsed(offset: name.length),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                controller: TextEditingController(text: phone)..selection = TextSelection.collapsed(offset: phone.length),
                onChanged: (v) => phone = v,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'رابط الصورة الشخصية'),
                controller: TextEditingController(text: profilePic)..selection = TextSelection.collapsed(offset: profilePic.length),
                onChanged: (v) => profilePic = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              try {
                final dio = ref.read(dioProvider);
                await dio.put('/users/me', data: {
                  'name': name,
                  'phone': phone,
                  'profilePic': profilePic,
                });
                if (context.mounted) Navigator.pop(ctx);
                ref.read(currentUserProvider.notifier).state = {
                  ...user,
                  'name': name,
                  'phone': phone,
                  'profilePic': profilePic,
                };
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ')));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
