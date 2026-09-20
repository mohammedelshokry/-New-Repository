import 'screens/notifications_screen.dart';
import 'screens/chat_screen.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:go_router/go_router.dart';
import 'providers/api_provider.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/owner_dashboard_screen.dart';
import 'screens/pitch_details_screen.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() {
  runApp(const ProviderScope(child: SpotaiaApp()));
}

final isInitializedProvider = StateProvider<bool>((ref) => false);




final goRouterProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          final isInitialized = ref.watch(isInitializedProvider);
          if (!isInitialized) return const SplashScreen();
          if (user == null) {
            return const AuthScreen();
          }
          if (user['role'] == 'OWNER' || user['role'] == 'ADMIN') {
            return const OwnerDashboardScreen();
          }
          return const HomeScreen();
        },
      ),
      GoRoute(
        path: '/pitch/:id',
        pageBuilder: (context, state) {
          final pitchId = state.pathParameters['id']!;
          return CustomTransitionPage(
            key: state.pageKey,
            child: PitchDetailsScreen(pitchId: pitchId),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),

      GoRoute(
        path: '/chat/:id',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: ChatScreen(matchId: state.pathParameters['id']!),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SharedAxisTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                transitionType: SharedAxisTransitionType.scaled,
                child: child,
              ),
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const NotificationsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SharedAxisTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                transitionType: SharedAxisTransitionType.scaled,
                child: child,
              ),
        ),
      ),
    ],
  );
});

class SpotaiaApp extends ConsumerWidget {
  const SpotaiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Spotaia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
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
