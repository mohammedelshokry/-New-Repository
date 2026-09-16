import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Change this IP to your computer's local Wi-Fi IP (e.g. http://192.168.1.5:3001/api)
// or use your deployed domain / ngrok URL when sending the APK to other people!
final apiBaseUrlProvider = StateProvider<String>((ref) => 'http://10.0.2.2:3001/api');

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  return Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
});

// Currently logged in user (null if not logged in)
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
