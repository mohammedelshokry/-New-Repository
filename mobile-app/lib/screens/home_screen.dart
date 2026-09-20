import 'package:share_plus/share_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'map_screen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../providers/api_provider.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}



class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
  }

  Future<void> _setupPushNotifications() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          final dio = ref.read(dioProvider);
          await dio.put('/users/me', data: {'fcmToken': token});
        }
      }
    } catch (e) {
      print('FCM Setup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotaia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 1.2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 2
          ? FloatingActionButton.extended(
              onPressed: () {
                // TODO: Add Match Request Dialog
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم إضافة نافذة الإنشاء قريباً')));
              },
              backgroundColor: AppTheme.neonBlue,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text('طلب جديد', style: TextStyle(fontWeight: FontWeight.bold)),
            ).animate().scale(duration: 400.ms)
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.stadium_outlined), selectedIcon: const Icon(Icons.stadium).animate().scale(duration: 300.ms, curve: Curves.easeOutBack), label: 'الملاعب'),
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map).animate().scale(duration: 300.ms, curve: Curves.easeOutBack), label: 'الخريطة'),
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
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return _buildPitchesTab();
      case 1:
        return const MapScreen();
      case 2:
        return _buildCommunityTab(context);
      case 3:
        return _buildLeaderboardTab(context);
      case 4:
        return _buildProfileTab(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLeaderboardTab(BuildContext context) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return leaderboardAsync.when(
      loading: () => const Center(child: SpinKitPulse(color: AppTheme.neonBlue, size: 50.0)),
      error: (err, stack) => Center(child: Text('خطأ: $err', style: const TextStyle(color: Colors.white))),
      data: (users) {
        if (users.isEmpty) return const Center(child: Text('لا يوجد تصنيف حالياً', style: TextStyle(color: Colors.white)));
        
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('توب 10 لاعبين - لوحة الشرف 🏆', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length > 10 ? 10 : users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isTop3 = index < 3;
                  Color rankColor = Colors.grey;
                  if (index == 0) rankColor = const Color(0xFFFFD700); // Gold
                  else if (index == 1) rankColor = const Color(0xFFC0C0C0); // Silver
                  else if (index == 2) rankColor = const Color(0xFFCD7F32); // Bronze
                  
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    color: AppTheme.surfaceLighter,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isTop3 ? BorderSide(color: rankColor.withValues(alpha: 0.5), width: 2) : BorderSide.none,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor: rankColor.withValues(alpha: 0.2),
                        child: Text('#${index + 1}', style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      title: Text(user['name'] ?? 'لاعب', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text('${user['level']} - ${user['points']} نقطة', style: const TextStyle(color: AppTheme.neonBlue)),
                      trailing: user['profilePic'] != null
                          ? CircleAvatar(backgroundImage: NetworkImage(user['profilePic']))
                          : const CircleAvatar(backgroundColor: Colors.black, child: Icon(Icons.person, color: Colors.white)),
                    ),
                  ).animate().fade(duration: 400.ms, delay: (50 * index).ms).slideX(begin: 0.2);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileTab(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final bookingsAsync = ref.watch(myBookingsProvider);

    if (user == null) return const Center(child: SpinKitPulse(color: AppTheme.neonBlue, size: 50.0));

    Color badgeColor = Colors.grey;
    if (user['level'] == 'DIAMOND') badgeColor = const Color(0xFFE0F7FA);
    else if (user['level'] == 'GOLD') badgeColor = const Color(0xFFFFD700);
    else if (user['level'] == 'SILVER') badgeColor = const Color(0xFFC0C0C0);
    else if (user['level'] == 'BRONZE') badgeColor = const Color(0xFFCD7F32);
    
    int points = user['points'] ?? 0;
    int nextLevelPoints = 500;
    if (points >= 500) nextLevelPoints = 1500;
    if (points >= 1500) nextLevelPoints = 5000;
    if (points >= 5000) nextLevelPoints = 5000;
    double progress = (points / nextLevelPoints).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. GAMIFICATION & USER INFO HEADER
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.surfaceLighter, badgeColor.withValues(alpha: 0.15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: badgeColor.withValues(alpha: 0.2),
                      backgroundImage: user['profilePic'] != null ? NetworkImage(user['profilePic']) : null,
                      child: user['profilePic'] == null ? Icon(Icons.person, size: 40, color: badgeColor) : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppTheme.surfaceLighter, shape: BoxShape.circle),
                      child: Icon(Icons.military_tech, color: badgeColor, size: 20),
                    )
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('${user['level']} - $points نقطة', style: TextStyle(fontSize: 14, color: badgeColor, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.black,
                        color: badgeColor,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(height: 4),
                      Text('$points / $nextLevelPoints للمستوى التالي', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: -0.1),

          const SizedBox(height: 24),
          
          // 2. UPCOMING BOOKINGS SECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('حجوزاتي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              TextButton(onPressed: () {}, child: const Text('عرض الكل', style: TextStyle(color: AppTheme.neonBlue))),
            ],
          ),
          const SizedBox(height: 8),
          
          bookingsAsync.when(
            loading: () => const Center(child: SpinKitPulse(color: AppTheme.neonBlue, size: 50.0)),
            error: (err, stack) => Text('خطأ: $err', style: const TextStyle(color: Colors.red)),
            data: (bookings) {
              if (bookings.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: Text('لا توجد حجوزات. ابدأ اللعب الآن!', style: TextStyle(color: Colors.grey))),
                );
              }
              // Show only up to 3 recent bookings in profile
              final recentBookings = bookings.take(3).toList();
              return Column(
                children: recentBookings.map((booking) {
                  final pitch = booking['pitch'] ?? {};
                  final isUnpaid = booking['paymentStatus'] == 'UNPAID';
                  final status = booking['status'];

                  Color statusColor = AppTheme.neonBlue; // COMPLETED / PAID
                  String statusText = 'مكتمل';
                  bool showConfirmBtn = false;

                  if (status == 'REJECTED') {
                    statusColor = Colors.red;
                    statusText = 'مرفوض من المالك';
                  } else if (status == 'PENDING') {
                    statusColor = Colors.amber;
                    statusText = 'بانتظار قبول المالك';
                  } else if (status == 'CONFIRMED') {
                    statusColor = AppTheme.neonOrange;
                    statusText = 'تم القبول (بانتظار حضورك)';
                    showConfirmBtn = true;
                  } else if (status == 'ATTENDANCE_CONFIRMED') {
                    statusColor = Colors.greenAccent;
                    statusText = 'تم تأكيد الحضور (الدفع كاش)';
                  }

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    color: AppTheme.surfaceLighter,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: statusColor.withValues(alpha: 0.3))),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.sports_soccer, color: statusColor),
                      ),
                      title: Text(pitch['name'] ?? 'ملعب', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                              booking['startTime'] != null 
                                ? "${DateTime.parse(booking['startTime']).toLocal().year}-${DateTime.parse(booking['startTime']).toLocal().month.toString().padLeft(2, '0')}-${DateTime.parse(booking['startTime']).toLocal().day.toString().padLeft(2, '0')} ${DateTime.parse(booking['startTime']).toLocal().hour.toString().padLeft(2, '0')}:00" 
                                : '', 
                              style: const TextStyle(color: Colors.white70, fontSize: 12)
                            ),
                          Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      trailing: showConfirmBtn
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonOrange, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16)),
                            onPressed: () async {
                              try {
                                final dio = ref.read(dioProvider);
                                await dio.post('/bookings/${booking['id']}/confirm-attendance');
                                ref.invalidate(myBookingsProvider);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تأكيد الحضور! الدفع كاش بالملعب.')));
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ')));
                              }
                            },
                            child: const Text('تأكيد حضوري'),
                          )
                        : (status == 'COMPLETED' || status == 'ATTENDANCE_CONFIRMED') 
                            ? const Icon(Icons.check_circle, color: AppTheme.neonBlue, size: 30)
                            : null,
                    ),
                  ).animate().fade().slideX();
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // 3. ACCOUNT SETTINGS & OPTIONS
          const Text('الإعدادات والحساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceLighter,
              borderRadius: BorderRadius.circular(16),
            ),
                          child: Column(
                children: [
                  _buildSettingsTile(Icons.person_outline, 'تعديل الملف الشخصي', () => _showEditProfileSheet(context, user)),
                  _buildDivider(),
                  _buildSettingsTile(Icons.credit_card, 'طرق الدفع', () => _showPaymentMethodsSheet(context)),
                  _buildDivider(),
                  _buildSettingsTile(Icons.settings_outlined, 'إعدادات التطبيق', () => _showAppSettingsSheet(context)),
                  _buildDivider(),
                  _buildSettingsTile(Icons.help_outline, 'المساعدة والدعم', () => _showSupportSheet(context)),
                  _buildDivider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('تسجيل خروج', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('jwt_token');
                      ref.read(currentUserProvider.notifier).state = null;
                      if (context.mounted) {
                        context.go('/auth');
                      }
                    },
                  ),
                ],
              ),
          ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
          const SizedBox(height: 30),
        ],
      ),
    );
  }


  void _showEditProfileSheet(BuildContext context, Map<String, dynamic> user) {
    final nameCtrl = TextEditingController(text: user['name']);
    final phoneCtrl = TextEditingController(text: user['phone']);
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceLighter,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('تعديل الملف الشخصي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'الاسم', labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: AppTheme.backgroundDark, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'رقم الهاتف', hintText: '01XXXXXXXXX', hintStyle: const TextStyle(color: Colors.white38), labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: AppTheme.backgroundDark, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonBlue, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: isLoading ? null : () async {
                    setModalState(() => isLoading = true);
                    try {
                      final dio = ref.read(dioProvider);
                      final res = await dio.put('/users/me', data: {
                        'name': nameCtrl.text,
                        'phone': phoneCtrl.text,
                      });
                      ref.read(currentUserProvider.notifier).state = res.data;
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات بنجاح!')));
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء التحديث: $e')));
                    } finally {
                      setModalState(() => isLoading = false);
                    }
                  },
                  child: isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('حفظ التغييرات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showPaymentMethodsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceLighter,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('طرق الدفع', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.backgroundDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.neonOrange.withValues(alpha: 0.3))),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppTheme.neonOrange),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('المحفظة (كاش)', style: TextStyle(color: Colors.white, fontSize: 16))),
                  Text('0 ج.م', style: TextStyle(color: AppTheme.neonOrange, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.backgroundDark, foregroundColor: AppTheme.neonBlue, padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: AppTheme.neonBlue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {},
              icon: const Icon(Icons.add_card),
              label: const Text('إضافة بطاقة جديدة'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showAppSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceLighter,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('إعدادات التطبيق', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('الإشعارات', style: TextStyle(color: Colors.white)),
              subtitle: const Text('تفعيل تنبيهات المباريات والحجوزات', style: TextStyle(color: Colors.white54)),
              value: true,
              activeColor: AppTheme.neonBlue,
              onChanged: (v) {},
            ),
            SwitchListTile(
              title: const Text('الوضع المظلم', style: TextStyle(color: Colors.white)),
              value: true,
              activeColor: AppTheme.neonBlue,
              onChanged: (v) {},
            ),
            ListTile(
              title: const Text('اللغة', style: TextStyle(color: Colors.white)),
              trailing: const Text('العربية', style: TextStyle(color: AppTheme.neonBlue, fontWeight: FontWeight.bold)),
              onTap: () {},
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceLighter,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('المساعدة والدعم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: AppTheme.neonBlue),
              title: const Text('تواصل معنا (شات)', style: TextStyle(color: Colors.white)),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: AppTheme.neonBlue),
              title: const Text('البريد الإلكتروني', style: TextStyle(color: Colors.white)),
              subtitle: const Text('support@spotaia.com', style: TextStyle(color: Colors.white54)),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.question_answer_outlined, color: AppTheme.neonBlue),
              title: const Text('الأسئلة الشائعة', style: TextStyle(color: Colors.white)),
              onTap: () {},
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.neonBlue),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: Color(0xFF2A2A2A), indent: 56);
  }

  Widget _buildCommunityTab(BuildContext context) {
    final matchesAsync = ref.watch(matchRequestsProvider);

    return matchesAsync.when(
      loading: () => const Center(child: SpinKitPulse(color: AppTheme.neonBlue, size: 50.0)),
      error: (err, stack) => Center(child: Text('خطأ: $err', style: const TextStyle(color: Colors.white))),
      data: (matches) {
        if (matches.isEmpty) {
          return const Center(child: Text('لا توجد طلبات لاعبين حالياً. كن أول من يطلب!', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];
            final creator = match['creator'] ?? {};
            
            // Gamification badge color logic
            Color badgeColor = Colors.grey;
            if (creator['level'] == 'DIAMOND') badgeColor = const Color(0xFFE0F7FA);
            else if (creator['level'] == 'GOLD') badgeColor = const Color(0xFFFFD700);
            else if (creator['level'] == 'SILVER') badgeColor = const Color(0xFFC0C0C0);
            else if (creator['level'] == 'BRONZE') badgeColor = const Color(0xFFCD7F32);

            return Card(
                    clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.only(bottom: 16.0),
              color: AppTheme.surfaceLighter,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: creator['profilePic'] != null ? NetworkImage(creator['profilePic']) : null,
                          backgroundColor: badgeColor,
                          child: creator['profilePic'] == null ? const Icon(Icons.person, color: Colors.black) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(creator['name'] ?? 'لاعب', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              Row(
                                children: [
                                  Icon(Icons.military_tech, size: 16, color: badgeColor),
                                  Text('${creator['level']} • ${creator['points']} نقطة', style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              )
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.neonBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('مطلوب ${match['missingSpots']}', style: const TextStyle(color: AppTheme.neonBlue, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const Divider(color: Color(0xFF333333), height: 24),
                    Text(match['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(match['description'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('نصيب الفرد: ${match['costPerSpot']} ج.م', style: const TextStyle(color: AppTheme.neonOrange, fontWeight: FontWeight.bold)),
                        Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.neonBlue,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: () {
                                    context.push('/chat/${match['id']}');
                                  },
                                  icon: const Icon(Icons.forum, size: 20),
                                  label: const Text('انضمام / تواصل', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppTheme.neonBlue),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.share, color: AppTheme.neonBlue),
                                  onPressed: () {
                                    final text = '''🔥 ينقصنا لاعبين في مباراة عبر تطبيق Spotaia!
🏆 المباراة: ${match['title'] ?? 'مباراة حماسية'}
👤 المطلوب: ${match['missingSpots'] ?? '?'} لاعبين
💰 التكلفة: ${match['costPerSpot'] ?? '?'} ج.م

حمّل التطبيق الآن وانضم إلينا!''';
                                    Share.share(text);
                                  },
                                ),
                              )
                            ],
                          )
                      ],
                    )
                  ],
                ),
              ),
            ).animate().fade(duration: 400.ms, delay: (100 * index).ms).slideY(begin: 0.2);
          },
        );
      },
    );
  }

  Widget _buildPitchesTab() {
    final pitchesAsync = ref.watch(pitchesProvider);

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ابحث عن ملعب...',
              hintStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: AppTheme.surfaceLighter,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ).animate().fade(duration: 400.ms).slideY(begin: -0.2),

        // Categories
        SizedBox(
          height: 40,
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
                  selectedColor: AppTheme.neonBlue.withValues(alpha: 0.2),
                  backgroundColor: AppTheme.surfaceLighter,
                  labelStyle: TextStyle(color: isSelected ? AppTheme.neonBlue : Colors.white70, fontWeight: FontWeight.bold),
                  showCheckmark: false,
                  side: BorderSide(color: isSelected ? AppTheme.neonBlue : Colors.transparent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              );
            }).toList(),
          ),
        ).animate().fade(duration: 400.ms, delay: 100.ms).slideX(begin: 0.1),

        // Pitches List
        pitchesAsync.when(
          loading: () => Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: 3,
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: AppTheme.surfaceLighter,
                highlightColor: const Color(0xFF333333),
                child: Container(
                  height: 250,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
          error: (err, stack) => Center(child: Text('خطأ: $err', style: const TextStyle(color: Colors.white))),
          data: (pitches) {
            final filteredPitches = pitches.where((p) {
              final matchesCategory = _selectedCategory == 'All' || p['category'] == _selectedCategory;
              final name = (p['name'] ?? '').toString().toLowerCase();
              final type = (p['type'] ?? '').toString().toLowerCase();
              final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery) || type.contains(_searchQuery);
              return matchesCategory && matchesSearch;
            }).toList();

            return Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12.0),
                itemCount: filteredPitches.length,
                itemBuilder: (context, index) {
                  final pitch = filteredPitches[index];
                  final images = pitch['images'] as List? ?? [];
                  final imgUrl = images.isNotEmpty ? images[0] : '';
                  
                  // Mocking dynamic distance based on ID length for demonstration of distance metric
                  final distanceKm = ((pitch['name'].toString().length % 5) + 1.2).toStringAsFixed(1);

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
                            tag: 'pitch_image_${pitch['id']}',
                            child: CachedNetworkImage(
                              imageUrl: imgUrl,
                              height: 180,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: AppTheme.surfaceLighter,
                                highlightColor: const Color(0xFF333333),
                                child: Container(color: Colors.black, height: 180),
                              ),
                              errorWidget: (context, url, error) => Container(
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
                                    Expanded(child: Text(pitch['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    Text('${pitch['pricePerHour']} ج.م/ساعة', style: const TextStyle(color: AppTheme.neonBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 16, color: AppTheme.neonOrange),
                                    const SizedBox(width: 4),
                                    Text('$distanceKm كم', style: const TextStyle(color: AppTheme.neonOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('• ${pitch['location']}', style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, size: 16, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Text('${pitch['rating'] ?? 0.0}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                                      ],
                                    )
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ).animate().fade(duration: 500.ms, delay: (50 * index).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
