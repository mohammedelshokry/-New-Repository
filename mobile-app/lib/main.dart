import 'screens/notifications_screen.dart';
import 'screens/chat_screen.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/api_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/owner_dashboard_screen.dart';
import 'screens/pitch_details_screen.dart';

void main() {
  runApp(const ProviderScope(child: SpotaiaApp()));
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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00E5FF), // Neon Blue (Football in logo)
          secondary: const Color(0xFFFF9100), // Neon Orange (Padel in logo)
          surface: const Color(0xFF121212),
          background: const Color(0xFF0A0A0A),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Color(0xFF00E5FF),
          unselectedLabelColor: Colors.white70,
          indicatorColor: Color(0xFF00E5FF),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        splashColor: const Color(0xFF00E5FF).withOpacity(0.3),
        highlightColor: const Color(0xFF00E5FF).withOpacity(0.1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF121212),
          indicatorColor: const Color(0xFF00E5FF).withOpacity(0.2),
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold);
            }
            return const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600);
          }),
          iconTheme: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const IconThemeData(color: Color(0xFF00E5FF));
            }
            return const IconThemeData(color: Colors.white70);
          }),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        fontFamily: 'Cairo', // Assuming you have an Arabic font, or default
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
