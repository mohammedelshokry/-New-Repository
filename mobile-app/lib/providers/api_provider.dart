import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// The centralized backend API URL (completely invisible to players and pitch owners, just like Uber)
// When deploying to Render/Railway, simply paste your live cloud URL here (e.g. 'https://pitchup-backend.onrender.com/api')
const String kProductionApiUrl = 'http://10.0.2.2:3001/api';

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: kProductionApiUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));
});

// Current logged in user (null = show AuthScreen)
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
