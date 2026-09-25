import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool isLogin = true;
  bool isOwner = false;
  bool isLoading = false;
  bool obscurePassword = true;
  String? errorMsg;

  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  String _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout || 
        e.type == DioExceptionType.receiveTimeout || 
        e.type == DioExceptionType.sendTimeout) {
      return 'انتهى وقت الاتصال بالسيرفر. تأكد من جودة الإنترنت.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'خطأ في الاتصال بالسيرفر. يرجى التأكد من تشغيل السيرفر أو الاتصال بالشبكة الصحيحة.';
    }
    if (e.response != null && e.response?.data != null) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('error')) {
        return data['error'].toString();
      }
    }
    return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }

  Future<void> submit() async {
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    if (phone.isEmpty || password.isEmpty || (!isLogin && name.isEmpty)) {
      setState(() => errorMsg = 'يرجى ملء جميع الحقول المطلوبة');
      return;
    }

    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    try {
      final dio = ref.read(dioProvider);
      
      if (isLogin) {
        final res = await dio.post('/auth/login', data: {
          'phone': phone,
          'password': password,
        });
        ref.read(currentUserProvider.notifier).state = res.data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', res.data['token']);
      } else {
        await dio.post('/auth/register', data: {
          'name': name,
          'phone': phone,
          'password': password,
          'role': isOwner ? 'OWNER' : 'PLAYER'
        });
        // Auto-login after register
        final res = await dio.post('/auth/login', data: {
          'phone': phone,
          'password': password,
        });
        ref.read(currentUserProvider.notifier).state = res.data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', res.data['token']);
      }
      
      if (mounted) {
         final user = ref.read(currentUserProvider);
         if (user?['role'] == 'OWNER' || user?['role'] == 'ADMIN') {
           context.go('/home');
         } else {
           context.go('/home');
         }
      }
    } on DioException catch (e) {
      setState(() {
        errorMsg = _mapDioError(e);
      });
    } catch (e) {
      setState(() => errorMsg = 'حدث خطأ في التطبيق');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildRoleSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isOwner = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !isOwner ? AppTheme.neonBlue.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: !isOwner ? AppTheme.neonBlue.withValues(alpha: 0.5) : Colors.transparent),
                ),
                child: Center(
                  child: Text('لاعب', style: TextStyle(
                    color: !isOwner ? AppTheme.neonBlue : Colors.white70, 
                    fontWeight: FontWeight.bold, fontSize: 16
                  )),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isOwner = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isOwner ? AppTheme.neonOrange.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isOwner ? AppTheme.neonOrange.withValues(alpha: 0.5) : Colors.transparent),
                ),
                child: Center(
                  child: Text('مالك ملعب', style: TextStyle(
                    color: isOwner ? AppTheme.neonOrange : Colors.white70, 
                    fontWeight: FontWeight.bold, fontSize: 16
                  )),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo animation and rendering
                Hero(
                    tag: 'app_logo',
                    child: Container(
                      height: 160,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.neonBlue.withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                          radius: 0.6,
                        ),
                      ),
                      child: Image.asset('assets/logo_transparent.png', height: 120, fit: BoxFit.contain),
                    ),
                  ),
                const SizedBox(height: 32),
                
                Text(
                  isLogin ? 'تسجيل الدخول' : 'حساب جديد',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  isLogin ? 'مرحباً بعودتك إلى SPOTAIA!' : 'انضم إلى مجتمع الرياضة الأكبر',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 40),

                // Login/Register Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark, 
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => {isLogin = true, errorMsg = null}),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isLogin ? AppTheme.surfaceLighter : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('تسجيل دخول', style: TextStyle(
                                color: isLogin ? Colors.white : Colors.white54, 
                                fontWeight: FontWeight.bold, fontSize: 16
                              )),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => {isLogin = false, errorMsg = null}),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: !isLogin ? AppTheme.surfaceLighter : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('حساب جديد', style: TextStyle(
                                color: !isLogin ? Colors.white : Colors.white54, 
                                fontWeight: FontWeight.bold, fontSize: 16
                              )),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Form Fields
                if (!isLogin) ...[
                  _buildRoleSelector(),
                  TextField(
                    controller: nameController,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (errorMsg != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1), 
                      borderRadius: BorderRadius.circular(12), 
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3))
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppTheme.error),
                        const SizedBox(width: 12),
                        Expanded(child: Text(errorMsg!, style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ),

                ElevatedButton(
                  onPressed: isLoading ? null : submit,
                  child: isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppTheme.backgroundDark, strokeWidth: 2.5))
                      : Text(isLogin ? 'تسجيل الدخول' : 'إنشاء حساب جديد'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
