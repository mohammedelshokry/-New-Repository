import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/api_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/owner_dashboard_screen.dart';
import 'screens/pitch_details_screen.dart';

void main() {
  runApp(const ProviderScope(child: PitchUpApp()));
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          if (user == null) {
            return const AuthScreen();
          }
          if (user['role'] == 'OWNER') {
            return const OwnerDashboardScreen();
          }
          return const HomeScreen();
        },
      ),
      GoRoute(
        path: '/pitch/:id',
        builder: (context, state) {
          final pitchId = state.pathParameters['id']!;
          return PitchDetailsScreen(pitchId: pitchId);
        },
      ),
    ],
  );
});

class PitchUpApp extends ConsumerWidget {
  const PitchUpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'PitchUp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl, // Default Arabic RTL
          child: child!,
        );
      },
      routerConfig: router,
    );
  }
}
