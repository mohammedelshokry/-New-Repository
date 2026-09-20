import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/api_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    await Future.delayed(const Duration(seconds: 3)); // Display splash for 3 seconds
    
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    final token = prefs.getString('jwt_token');

    if (!mounted) return;

    if (!hasSeenOnboarding) {
      context.go('/onboarding');
    } else if (token != null && token.isNotEmpty) {
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get('/auth/me');
        ref.read(currentUserProvider.notifier).state = res.data;
        context.go('/home');
      } catch (e) {
        context.go('/auth');
      }
    } else {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D), // AppTheme.backgroundDark
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5)
                ],
                image: const DecorationImage(
                  image: AssetImage('assets/icon.jpg'),
                  fit: BoxFit.contain,
                ),
              ),
            ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack).then().shimmer(duration: 1200.ms, color: const Color(0xFF00E5FF)),
            const SizedBox(height: 24),
            const Text(
              'SPOTAIA',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ).animate().fade(delay: 400.ms, duration: 600.ms).slideY(begin: 0.5),
            const SizedBox(height: 8),
            const Text(
              'رياضتك، ملعبك، فريقك',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF00E5FF),
                letterSpacing: 1.5,
              ),
            ).animate().fade(delay: 800.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
