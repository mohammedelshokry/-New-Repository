import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';

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
        title: Text('Ù„ÙˆØ­Ø© Ø§Ù„Ø¥Ø¯Ø§Ø±Ø© - Ù…Ø±Ø­Ø¨Ø§Ù‹ ${user?['name'] ?? ''}'),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'ØªØ³Ø¬ÙŠÙ„ Ø®Ø±ÙˆØ¬',
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
            Tab(text: 'Ø§Ù„Ø¥Ø­ØµØ§Ø¦ÙŠØ§Øª', icon: Icon(Icons.analytics_outlined)),
            Tab(text: 'Ø§Ù„Ù…Ø³ØªØ®Ø¯Ù…ÙŠÙ†', icon: Icon(Icons.group_outlined)),
            Tab(text: 'Ø§Ù„Ù…Ù„Ø§Ø¹Ø¨', icon: Icon(Icons.stadium_outlined)),
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
      error: (e, st) => Center(child: Text('Ø®Ø·Ø£: $e', style: const TextStyle(color: Colors.white))),
      data: (stats) {
        return RefreshIndicator(
          onRefresh: () => ref.refresh(adminStatsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatCard('Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø³ØªØ®Ø¯Ù…ÙŠÙ†', stats['totalUsers'].toString(), Icons.people, Colors.blue),
              _buildStatCard('Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ù„Ø§Ø¹Ø¨', stats['totalPitches'].toString(), Icons.stadium, Colors.green),
              _buildStatCard('Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø­Ø¬ÙˆØ²Ø§Øª', stats['totalBookings'].toString(), Icons.calendar_month, Colors.orange),
              _buildStatCard('Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø£Ø±Ø¨Ø§Ø­', '${stats['totalRevenue']} Ø¬.Ù…', Icons.attach_money, Colors.purple),
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
      error: (e, st) => Center(child: Text('Ø®Ø·Ø£: $e', style: const TextStyle(color: Colors.white))),
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
                  child: Text(u['name'][0].toUpperCase(), style: TextStyle(color: AppTheme.neonBlue)),
                ),
                title: Text(u['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('${u['phone']} - ${u['role']}', style: const TextStyle(color: Colors.white70)),
                trailing: Text('${u['points']} Ù†Ù‚Ø·Ø©', style: TextStyle(color: AppTheme.neonOrange)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPitchesTab() {
    final pitchesAsync = ref.watch(adminPitchesProvider);
    return pitchesAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: AppTheme.neonBlue)),
      error: (e, st) => Center(child: Text('Ø®Ø·Ø£: $e', style: const TextStyle(color: Colors.white))),
      data: (pitches) {
        return RefreshIndicator(
          onRefresh: () => ref.refresh(adminPitchesProvider.future),
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
                      ? DecorationImage(image: NetworkImage(images[0]), fit: BoxFit.cover)
                      : null,
                  ),
                  child: images.isEmpty
                    ? const Icon(Icons.stadium, color: Colors.white54)
                    : null,
                ),
                title: Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('Ø§Ù„Ø³Ø¹Ø±: ${p['pricePerHour']} Ø¬.Ù…', style: const TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              );
            },
          ),
        );
      },
    );
  }
}
