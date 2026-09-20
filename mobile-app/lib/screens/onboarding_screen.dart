import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) return;
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        padding: const EdgeInsets.only(bottom: 80),
        child: PageView(
          controller: _controller,
          onPageChanged: (index) {
            setState(() => isLastPage = index == 2);
          },
          children: [
            _buildPage(
              color: AppTheme.neonBlue,
              icon: Icons.stadium_outlined,
              title: 'احجز ملعبك بسهولة',
              subtitle: 'ابحث عن أقرب الملاعب الرياضية، تصفح الصور والأسعار، واحجز وقتك بضغطة زر واحدة بدون تعقيد.',
            ),
            _buildPage(
              color: AppTheme.neonOrange,
              icon: Icons.group_add_outlined,
              title: 'كمّل فريقك',
              subtitle: 'هل ينقصك لاعبون؟ انشر طلباً للانضمام أو ابحث عن مباريات متاحة وتعرف على أصدقاء جدد في غرف الدردشة.',
            ),
            _buildPage(
              color: Colors.amber,
              icon: Icons.workspace_premium_outlined,
              title: 'العب، تقيّم، وارتقِ!',
              subtitle: 'ارفع مستواك في كل مرة تلعب فيها، واجمع النقاط لتتصدر قائمة أفضل اللاعبين في مدينتك.',
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 80,
        color: AppTheme.backgroundDark,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => _controller.jumpToPage(2),
              child: const Text('تخطي', style: TextStyle(color: Colors.white54, fontSize: 16)),
            ),
            SmoothPageIndicator(
              controller: _controller,
              count: 3,
              effect: const WormEffect(
                spacing: 16,
                dotColor: Colors.white24,
                activeDotColor: AppTheme.neonBlue,
                dotHeight: 10,
                dotWidth: 10,
              ),
            ),
            isLastPage
                ? TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text('ابدأ الآن', style: TextStyle(color: AppTheme.neonBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                  ).animate().fade().scale()
                : TextButton(
                    onPressed: () => _controller.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
                    child: const Text('التالي', style: TextStyle(color: AppTheme.neonBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({required Color color, required IconData icon, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 120, color: color).animate().scale(duration: 500.ms, delay: 200.ms).then().shimmer(color: Colors.white),
          const SizedBox(height: 64),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate().slideY(begin: 0.3, duration: 400.ms).fade(),
          const SizedBox(height: 24),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().slideY(begin: 0.3, duration: 400.ms, delay: 200.ms).fade(),
        ],
      ),
    );
  }
}
