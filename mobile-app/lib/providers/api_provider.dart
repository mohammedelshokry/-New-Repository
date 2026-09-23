import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kProductionApiUrl = 'http://192.168.1.10:3001/api';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: kProductionApiUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));
  
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      options.headers['Bypass-Tunnel-Reminder'] = 'true';
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
  ));

  return dio;
});

final currentUserProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

final venuesProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/venues');
  return response.data;
});

final venueDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/venues/$id');
  return response.data;
});

final matchRequestsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/match-requests');
  return response.data;
});

final myBookingsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/bookings');
  return response.data;
});

final leaderboardProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/users/leaderboard');
  return response.data;
});

final venueLeaderboardProvider = FutureProvider.family<List<dynamic>, String>((ref, venueId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/venues/$venueId/leaderboard'); // Note: backend doesn't have this implemented right now, but UI might not use it heavily
  return response.data;
});

final notificationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/notifications');
  return res.data;
});

// Admin Providers
final adminStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/admin/stats');
  return response.data;
});

final adminUsersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/admin/users');
  return response.data;
});

final adminVenuesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/admin/venues');
  return response.data;
});
