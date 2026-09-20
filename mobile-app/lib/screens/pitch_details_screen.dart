import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_provider.dart';
import 'package:intl/intl.dart';

class PitchDetailsScreen extends ConsumerStatefulWidget {
  final String pitchId;
  const PitchDetailsScreen({super.key, required this.pitchId});

  @override
  ConsumerState<PitchDetailsScreen> createState() => _PitchDetailsScreenState();
}

class _PitchDetailsScreenState extends ConsumerState<PitchDetailsScreen> {
  DateTime selectedDate = DateTime.now();
  List<int> selectedHours = [];

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(pitchDetailsProvider(widget.pitchId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: detailsAsync.when(
        data: (pitch) {
          final bookings = pitch['bookings'] as List? ?? [];
          final todayBookings = bookings.where((b) {
            final st = DateTime.parse(b['startTime']).toLocal();
            return st.year == selectedDate.year && st.month == selectedDate.month && st.day == selectedDate.day;
          }).toList();

          
          final images = pitch['images'] as List? ?? [];
          final imgUrl = images.isNotEmpty ? images[0] : '';
          
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                pinned: true,
                backgroundColor: AppTheme.surfaceDark,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(pitch['name'] ?? 'تفاصيل الملعب', style: const TextStyle(fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
                  background: Hero(
                    tag: 'pitch_image_${pitch["id"]}',
                    child: imgUrl.isNotEmpty 
                      ? CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey.shade900,
                            highlightColor: Colors.grey.shade800,
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => Container(color: Colors.grey.shade900, child: const Icon(Icons.sports_soccer, size: 50, color: Colors.grey)),
                        )
                      : Container(color: Colors.grey.shade900, child: const Icon(Icons.sports_soccer, size: 50, color: Colors.grey)),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(pitch['name']?.toString() ?? 'بدون اسم', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('سعر الساعة: ${pitch['pricePerHour']} ج.م', style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Text('وصف الملعب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(pitch['description'] ?? 'لا يوجد وصف', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      const Text('المرافق المتاحة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Wrap(
                        spacing: 8.0,
                        children: (pitch['amenities'] as List).map((a) => Chip(label: Text(a.toString()))).toList(),
                      ),
                      const Divider(height: 48, thickness: 1),
                      
                      const Text('تحديد وقت الحجز:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.neonBlue)),
                      const SizedBox(height: 8),
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.withOpacity(0.3))),
                        title: Text('التاريخ: '),
                        trailing: const Icon(Icons.calendar_today, color: AppTheme.neonBlue),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context, 
                            initialDate: selectedDate, 
                            firstDate: DateTime.now(), 
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                            builder: (context, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(primary: AppTheme.neonBlue, onPrimary: Colors.black, surface: AppTheme.surfaceDark, onSurface: Colors.white),
                              ),
                              child: child!,
                            ),
                          );
                          if (d != null) setState(() { selectedDate = d; selectedHours.clear(); });
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text('اختر المواعيد المناسبة (بالساعة):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final openTimeStr = pitch['openTime']?.toString() ?? '00:00';
                          final closeTimeStr = pitch['closeTime']?.toString() ?? '23:59';
                          final openHour = int.tryParse(openTimeStr.split(':')[0]) ?? 0;
                          final closeHour = int.tryParse(closeTimeStr.split(':')[0]) ?? 23;
                          
                          final now = DateTime.now();
                          final isToday = selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day;
                          
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 2.5,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: (closeHour - openHour) + 1,
                            itemBuilder: (context, index) {
                              final h = openHour + index;
                              if (h >= 24) return const SizedBox();
                              
                              // Check if booked
                              bool isBooked = false;
                              for (var b in todayBookings) {
                                final st = DateTime.parse(b['startTime']).toLocal();
                                final et = DateTime.parse(b['endTime']).toLocal();
                                // A booking from 14:00 to 16:00 means hour 14 and 15 are booked.
                                if (st.hour <= h && et.hour > h) {
                                  isBooked = true;
                                  break;
                                }
                              }
                              
                              // Check if past
                              bool isPast = isToday && h <= now.hour;
                              
                              final bool isSelected = selectedHours.contains(h);
                              
                              Color bgColor = AppTheme.surfaceLighter;
                              Color textColor = Colors.white;
                              Color borderColor = Colors.grey.withOpacity(0.3);
                              
                              if (isPast) {
                                bgColor = Colors.black;
                                textColor = Colors.grey.shade700;
                              } else if (isBooked) {
                                bgColor = Colors.red.withOpacity(0.1);
                                textColor = Colors.red;
                                borderColor = Colors.red.withOpacity(0.5);
                              } else if (isSelected) {
                                bgColor = AppTheme.neonBlue.withOpacity(0.2);
                                textColor = AppTheme.neonBlue;
                                borderColor = AppTheme.neonBlue;
                              }
                              
                              return InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: (isPast || isBooked) ? null : () {
                                  setState(() {
                                    if (isSelected) {
                                      selectedHours.remove(h);
                                    } else {
                                      selectedHours.add(h);
                                    }
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: borderColor),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${h.toString().padLeft(2, '0')}:00', 
                                    
                                    style: TextStyle(
                                      color: textColor, 
                                      fontWeight: isSelected || isBooked ? FontWeight.bold : FontWeight.normal,
                                      decoration: isPast ? TextDecoration.lineThrough : null,
                                    )
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      ),
                      if (selectedHours.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.neonOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.neonOrange.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('إجمالي التكلفة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('${(pitch['pricePerHour'] ?? 0) * selectedHours.length} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.neonOrange)),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),
                      const Text('أفضل لاعبي الملعب 🏆', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFFD700))),
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, ref, child) {
                          final boardAsync = ref.watch(venueLeaderboardProvider(widget.pitchId));
                          return boardAsync.when(
                            loading: () => const Center(child: SpinKitPulse(color: AppTheme.neonBlue, size: 50.0)),
                            error: (e, st) => Text('خطأ في تحميل الترتيب: $e'),
                            data: (players) {
                              if (players.isEmpty) return const Text('كن أول من يحجز هذا الملعب لتتصدر القائمة!', style: TextStyle(color: Colors.grey));
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: players.length,
                                itemBuilder: (context, index) {
                                  final p = players[index];
                                  final bool isTop3 = index < 3;
                                  Color rankColor = Colors.grey;
                                  if (index == 0) rankColor = const Color(0xFFFFD700);
                                  if (index == 1) rankColor = const Color(0xFFC0C0C0);
                                  if (index == 2) rankColor = const Color(0xFFCD7F32);
                                  
                                  return Card(
                                    color: AppTheme.surfaceLighter,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: isTop3 ? BorderSide(color: rankColor.withOpacity(0.5)) : BorderSide.none,
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: rankColor.withOpacity(0.2),
                                        child: Text('#${index + 1}', style: TextStyle(color: rankColor, fontWeight: FontWeight.bold)),
                                      ),
                                      title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      trailing: Text('${p['venuePoints']} نقطة', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                    ),
                                  );
                                },
                              );
                            }
                          );
                        }
                      ),
                      const SizedBox(height: 32),

                      const Text('التقييمات والآراء:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.neonBlue)),
                      const SizedBox(height: 8),
                      if ((pitch['reviews'] as List? ?? []).isEmpty)
                        const Text('لا توجد تقييمات حتى الآن. كن أول من يقيّم!'),
                      ...(pitch['reviews'] as List? ?? []).map((r) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: r['user']['profilePic'] != null ? NetworkImage(r['user']['profilePic']) : null,
                              child: r['user']['profilePic'] == null ? const Icon(Icons.person) : null,
                            ),
                            title: Row(
                              children: [
                                Text(r['user']['name']?.toString() ?? 'مستخدم', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Row(children: List.generate(5, (index) => Icon(Icons.star, size: 16, color: index < (r['rating'] ?? 0) ? Colors.amber : Colors.grey.shade300))),
                              ],
                            ),
                            subtitle: Text(r['comment']?.toString() ?? ''),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 16),
                      Builder(
                          builder: (context) {
                            final user = ref.watch(currentUserProvider);
                            final userId = user?['id'];
                            
                            final hasBooked = (pitch['bookings'] as List? ?? []).any((b) => b['userId'] == userId);
                            final hasReviewed = (pitch['reviews'] as List? ?? []).any((r) => r['userId'] == userId);
                            
                            if (user == null || user['role'] != 'PLAYER') return const SizedBox();
                            
                            if (!hasBooked) {
                              return const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('يجب عليك حجز الملعب أولاً لتتمكن من التقييم', style: TextStyle(color: Colors.grey)),
                              );
                            }
                            
                            if (hasReviewed) {
                              return const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('لقد قمت بتقييم هذا الملعب مسبقاً، شكراً لك!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              );
                            }
                            
                            return ElevatedButton.icon(
                              onPressed: () => _showReviewDialog(context, ref, widget.pitchId),
                              icon: const Icon(Icons.rate_review),
                              label: const Text('أضف تقييمك للملعب'),
                            );
                          },
                        ),

                      const SizedBox(height: 32),
                      const Text('أفضل لاعبي الملعب 🏆', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFFD700))),
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, ref, child) {
                          final boardAsync = ref.watch(venueLeaderboardProvider(widget.pitchId));
                          return boardAsync.when(
                            loading: () => const Center(child: SpinKitPulse(color: AppTheme.neonBlue, size: 50.0)),
                            error: (e, st) => Text('خطأ في تحميل الترتيب: $e'),
                            data: (players) {
                              if (players.isEmpty) return const Text('كن أول من يحجز هذا الملعب لتتصدر القائمة!', style: TextStyle(color: Colors.grey));
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: players.length,
                                itemBuilder: (context, index) {
                                  final p = players[index];
                                  final bool isTop3 = index < 3;
                                  Color rankColor = Colors.grey;
                                  if (index == 0) rankColor = const Color(0xFFFFD700);
                                  if (index == 1) rankColor = const Color(0xFFC0C0C0);
                                  if (index == 2) rankColor = const Color(0xFFCD7F32);
                                  
                                  return Card(
                                    color: AppTheme.surfaceLighter,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: isTop3 ? BorderSide(color: rankColor.withOpacity(0.5)) : BorderSide.none,
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: rankColor.withOpacity(0.2),
                                        child: Text('#${index + 1}', style: TextStyle(color: rankColor, fontWeight: FontWeight.bold)),
                                      ),
                                      title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      trailing: Text('${p['venuePoints']} نقطة', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                    ),
                                  );
                                },
                              );
                            }
                          );
                        }
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: SpinKitPulse(color: AppTheme.neonBlue, size: 50.0)),
        error: (err, stack) => Center(child: Text('خطأ: $err')),
      ),
      bottomNavigationBar: detailsAsync.hasValue ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonBlue,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          onPressed: () => _confirmBooking(detailsAsync.value!),
          child: const Text('تأكيد الحجز (الدفع كاش في الملعب)', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ) : null,
    );
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref, String pitchId) {
    int rating = 5;
    String comment = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('تقييم الملعب'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(Icons.star, color: index < rating ? Colors.amber : Colors.grey.shade300, size: 32),
                        onPressed: () => setModalState(() => rating = index + 1),
                      );
                    }),
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'تعليقك (اختياري)'),
                    maxLines: 2,
                    onChanged: (v) => comment = v,
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref.read(dioProvider).post('/pitches/' + pitchId + '/reviews', data: {
                        'rating': rating,
                        'comment': comment,
                      });
                      if (context.mounted) Navigator.pop(ctx);
                      ref.invalidate(pitchDetailsProvider(pitchId));
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء إضافة التقييم')));
                    }
                  },
                  child: const Text('إرسال التقييم'),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _confirmBooking(Map<String, dynamic> pitch) async {
    if (selectedHours.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار وقت الحجز')));
      return;
    }
    
    selectedHours.sort();
    for (int i = 0; i < selectedHours.length - 1; i++) {
      if (selectedHours[i + 1] - selectedHours[i] != 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب اختيار ساعات متتالية للحجز')));
        return;
      }
    }

    final startDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedHours.first);
    final endDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedHours.last + 1);
    
    final totalPrice = (pitch['pricePerHour'] ?? 0) * selectedHours.length;

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/bookings', data: {
        'pitchId': widget.pitchId,
        'startTime': startDateTime.toUtc().toIso8601String(),
        'endTime': endDateTime.toUtc().toIso8601String(),
        'isManual': false,
      });
      
      if (context.mounted) {
        // Simple client-side level update prediction
        ref.invalidate(myBookingsProvider);
          final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          Map<String, dynamic> updatedUser = Map.from(currentUser);
          updatedUser['points'] = (updatedUser['points'] ?? 0) + 50;
          int pts = updatedUser['points'];
          if (pts >= 1000) updatedUser['level'] = 'GOLD';
          else if (pts >= 500) updatedUser['level'] = 'SILVER';
          ref.read(currentUserProvider.notifier).state = updatedUser;
        }

        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Dismiss',
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, anim1, anim2) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLighter,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppTheme.neonBlue.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5)],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppTheme.neonBlue, size: 80)
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scale(duration: 1.seconds, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
                      const SizedBox(height: 16),
                      const Text('تم الحجز بنجاح! 🎉', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('لقد قمت بحجز ${pitch['name']} بنجاح.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.neonBlue.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('إجمالي التكلفة:', style: TextStyle(color: Colors.white70)),
                                Text('$totalPrice ج.م', style: const TextStyle(color: AppTheme.neonOrange, fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('طريقة الدفع:', style: TextStyle(color: Colors.white70)),
                                Text('الدفع نقدًا بالملعب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.neonBlue,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          child: const Text('ممتاز!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
          transitionBuilder: (context, anim1, anim2, child) {
            return Transform.scale(
              scale: Curves.easeOutBack.transform(anim1.value),
              child: FadeTransition(opacity: anim1, child: child),
            );
          },
        );
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحجز: $e')));
    }
  }
}
