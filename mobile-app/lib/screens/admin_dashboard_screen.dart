import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';

String getFullUrl(String url) {
  if (url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  if (url.startsWith('/')) return 'http://192.168.1.10:3001$url';
  return 'http://192.168.1.10:3001/$url';
}


class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('لوحة الإدارة - مرحباً ${user?['name'] ?? ''}'),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تسجيل خروج',
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('jwt_token');
              ref.read(currentUserProvider.notifier).state = null;
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
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'الإحصائيات', icon: Icon(Icons.analytics_outlined)),
            Tab(text: 'المستخدمين', icon: Icon(Icons.group_outlined)),
            Tab(text: 'الملاعب', icon: Icon(Icons.stadium_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatsTab(),
          _buildUsersTab(),
          _buildPitchesTab(),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    final statsAsync = ref.watch(adminStatsProvider);
    return statsAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: AppTheme.neonBlue)),
      error: (e, st) => Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.white))),
      data: (stats) {
        return RefreshIndicator(
          onRefresh: () => ref.refresh(adminStatsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatCard('إجمالي المستخدمين', stats['totalUsers'].toString(), Icons.people, Colors.blue),
              _buildStatCard('إجمالي الملاعب', stats['totalVenues'].toString(), Icons.stadium, Colors.green),
              _buildStatCard('إجمالي الحجوزات', stats['totalBookings'].toString(), Icons.calendar_month, Colors.orange),
              _buildStatCard('إجمالي الأرباح', '${stats['totalRevenue'] ?? 0} ج.م', Icons.attach_money, Colors.purple),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    final usersAsync = ref.watch(adminUsersProvider);
    return usersAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: AppTheme.neonBlue)),
      error: (e, st) => Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.white))),
      data: (users) {
        return RefreshIndicator(
          onRefresh: () => ref.refresh(adminUsersProvider.future),
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final u = users[index];
              return ListTile(
                leading: CircleAvatar(
                                backgroundColor: AppTheme.neonBlue.withOpacity(0.2),
                                backgroundImage: u['profilePic'] != null ? NetworkImage(getFullUrl(u['profilePic'])) : null,
                                child: u['profilePic'] == null ? Text(u['name'][0].toUpperCase(), style: const TextStyle(color: AppTheme.neonBlue)) : null,
                ),
                title: Text(u['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('${u['phone']} - ${u['role']}', style: const TextStyle(color: Colors.white70)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${u['points']} نقطة', style: TextStyle(color: AppTheme.neonOrange)),
                    const SizedBox(width: 8),
                    if (u['isActive'] == false) const Icon(Icons.block, color: Colors.red, size: 16),
                  ],
                ),
                onTap: () {
                  _showUserDetails(context, u);
                },
              );
            },
          ),
        );
      },
    );
  }
  
  void _showUserDetails(BuildContext context, dynamic u) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.neonBlue.withOpacity(0.2),
                  backgroundImage: u['profilePic'] != null ? NetworkImage(getFullUrl(u['profilePic'])) : null,
                  child: u['profilePic'] == null ? Text(u['name'][0].toUpperCase(), style: const TextStyle(color: AppTheme.neonBlue, fontSize: 32, fontWeight: FontWeight.bold)) : null,
                ),
                const SizedBox(height: 16),
                Text(u['name'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(u['phone'], style: const TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildUserInfoBadge('الدور', u['role'], Icons.admin_panel_settings),
                    _buildUserInfoBadge('النقاط', '${u['points']}', Icons.stars),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (u['role'] == 'PLAYER' && u['bookings'] != null && (u['bookings'] as List).isNotEmpty) ...[
                          const Text('حجوزات اللاعب:', style: const TextStyle(color: AppTheme.neonBlue, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...(u['bookings'] as List).map((b) {
                            final courtName = b['court']?['name'] ?? 'ملعب';
                            final venueName = b['court']?['venue']?['name'] ?? 'مكان';
                            return Card(
                              color: AppTheme.surfaceLighter,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text('$venueName - $courtName', style: const TextStyle(color: Colors.white)),
                                subtitle: Text('السعر: ${b['price']} ج.م | الحالة: ${b['status']}', style: const TextStyle(color: Colors.white70)),
                                trailing: Text(b['startTime'].toString().substring(0, 10), style: const TextStyle(color: AppTheme.neonOrange)),
                              ),
                            );
                          }),
                        ],
                        if (u['role'] == 'OWNER' && u['venues'] != null && (u['venues'] as List).isNotEmpty) ...[
                          const Text('أماكن وحجوزات المالك:', style: const TextStyle(color: AppTheme.neonBlue, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...(u['venues'] as List).map((v) {
                            int totalBookings = 0;
                            double totalEarnings = 0.0;
                            if (v['courts'] != null) {
                              for (var c in v['courts']) {
                                if (c['bookings'] != null) {
                                  for (var b in c['bookings']) {
                                    totalBookings++;
                                    totalEarnings += (b['ownerAmount'] ?? 0.0);
                                  }
                                }
                              }
                            }
                            return Card(
                              color: AppTheme.surfaceLighter,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(v['name'], style: const TextStyle(color: Colors.white)),
                                subtitle: Text('إجمالي الحجوزات: $totalBookings', style: const TextStyle(color: Colors.white70)),
                                trailing: Text('أرباح: $totalEarnings ج.م', style: const TextStyle(color: Colors.greenAccent)),
                              ),
                            );
                          }),
                        ] else if (u['role'] == 'OWNER') ...[
                           const Text('لا توجد أماكن لهذا المالك', style: const TextStyle(color: Colors.white54)),
                        ],
                        if (u['role'] == 'PLAYER' && (u['bookings'] == null || (u['bookings'] as List).isEmpty))
                           const Text('لا توجد حجوزات لهذا اللاعب', style: const TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await ref.read(dioProvider).post('/admin/users/${u['id']}/toggle-ban');
                            ref.refresh(adminUsersProvider.future);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(u['isActive'] ? 'تم حظر المستخدم' : 'تم فك الحظر')));
                            }
                          } catch(e) {}
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: u['isActive'] ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(u['isActive'] ? 'حظر المستخدم' : 'فك الحظر', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.neonBlue,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildUserInfoBadge(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.neonOrange, size: 28),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPitchesTab() {
    final pitchesAsync = ref.watch(adminVenuesProvider);
    return pitchesAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: AppTheme.neonBlue)),
      error: (e, st) => Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.white))),
      data: (pitches) {
        return RefreshIndicator(
          onRefresh: () => ref.refresh(adminVenuesProvider.future),
          child: ListView.builder(
            itemCount: pitches.length,
            itemBuilder: (context, index) {
              final p = pitches[index];
              List<String> images = [];
              try {
                if (p['images'] != null && p['images'].toString().isNotEmpty) {
                  images = List<String>.from(jsonDecode(p['images']));
                }
              } catch (e) {}
              
              return ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppTheme.surfaceLighter,
                    image: images.isNotEmpty
                      ? DecorationImage(image: NetworkImage(getFullUrl(images[0])), fit: BoxFit.cover)
                      : null,
                  ),
                  child: images.isEmpty
                    ? const Icon(Icons.stadium, color: Colors.white54)
                    : null,
                ),
                title: Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('السعر: ${p['pricePerHour']} ج.م', style: const TextStyle(color: Colors.white70)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surfaceDark,
                        title: const Text('حذف الملعب', style: TextStyle(color: Colors.white)),
                        content: const Text('هل أنت متأكد أنك تريد حذف هذا الملعب وكل حجوزاته؟', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true), 
                            child: const Text('حذف', style: TextStyle(color: Colors.red))
                          ),
                        ],
                      )
                    );
                    if (confirm == true) {
                      try {
                        await ref.read(dioProvider).delete('/admin/pitches/${p['id']}');
                        ref.refresh(adminVenuesProvider.future);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الملعب')));
                      } catch(e) {}
                    }
                  },
                ),
                onTap: () {
                  context.push('/venue/${p['id']}');
                },
              );
            },
          ),
        );
      },
    );
  }
}
