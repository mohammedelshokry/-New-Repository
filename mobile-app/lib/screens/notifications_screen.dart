import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_provider.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  
  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/notifications/read-all');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsProvider);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('الإشعارات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ: $err')),
        data: (notifs) {
          if (notifs.isEmpty) {
            return const Center(child: Text('لا توجد إشعارات حالياً', style: TextStyle(color: Colors.grey, fontSize: 18)));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(notificationsProvider),
            child: ListView.builder(
              itemCount: notifs.length,
              itemBuilder: (context, index) {
                final notif = notifs[index];
                final isRead = notif['isRead'] == true;
                final date = DateTime.parse(notif['createdAt']).toLocal();
                
                IconData icon = Icons.notifications;
                Color iconColor = Colors.grey;
                if (notif['type'] == 'NEW_BOOKING') { icon = Icons.calendar_today; iconColor = const Color(0xFF00E5FF); }
                if (notif['type'] == 'BOOKING_UPDATE') { icon = Icons.check_circle; iconColor = const Color(0xFF00FF00); }
                if (notif['title'].contains('رفض')) { icon = Icons.cancel; iconColor = Colors.red; }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isRead ? const Color(0xFF1A1A1A) : const Color(0xFF2A2A2A),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withValues(alpha: 0.2),
                      child: Icon(icon, color: iconColor),
                    ),
                    title: Text(notif['title'], style: TextStyle(color: Colors.white, fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notif['body'], style: TextStyle(color: Colors.grey.shade400)),
                        const SizedBox(height: 4),
                        Text(DateFormat('yyyy-MM-dd HH:mm').format(date), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
