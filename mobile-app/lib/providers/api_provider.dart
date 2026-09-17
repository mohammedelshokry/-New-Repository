import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kProductionApiUrl = 'https://solid-brooms-check.loca.lt/api';

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

final pitchesProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/pitches');
  return response.data;
});

final pitchDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/pitches/$id');
  return response.data;
});

final matchRequestsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/match-requests');
  return response.data;
});
