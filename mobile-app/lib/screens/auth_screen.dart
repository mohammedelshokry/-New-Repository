import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/api_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool isLogin = true;
  String selectedRole = 'PLAYER';
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;
  String? errorMsg;

  void submit() async {
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      setState(() => errorMsg = 'الرجاء إدخال رقم الهاتف وكلمة المرور');
      return;
    }
    if (!isLogin && name.isEmpty) {
      setState(() => errorMsg = 'الرجاء إدخال الاسم');
      return;
    }

    setState(() { isLoading = true; errorMsg = null; });
    final dio = ref.read(dioProvider);

    try {
      if (isLogin) {
        final res = await dio.post('/auth/login', data: {
          'phone': phone,
          'password': password,
        });
        await _handleAuthSuccess(res.data['token'], res.data['user']);
      } else {
        final res = await dio.post('/auth/register', data: {
          'name': name,
          'phone': phone,
          'password': password,
          'role': selectedRole,
        });
        if (res.statusCode == 201) {
          final loginRes = await dio.post('/auth/login', data: {
            'phone': phone,
            'password': password,
          });
          await _handleAuthSuccess(loginRes.data['token'], loginRes.data['user']);
        }
      }
    } on DioException catch (e) {
      setState(() {
        errorMsg = e.response?.data?['error']?.toString() ?? 'خطأ في الاتصال بالسيرفر';
      });
    } catch (e) {
      setState(() => errorMsg = 'خطأ غير متوقع');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleAuthSuccess(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    ref.read(currentUserProvider.notifier).state = user;
  }

  Widget _buildRoleSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedRole = 'PLAYER'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: selectedRole == 'PLAYER' ? Colors.green.shade50 : Colors.transparent,
                  borderRadius: BorderRadius.horizontal(right: const Radius.circular(12)),
                  border: selectedRole == 'PLAYER' ? Border.all(color: Colors.green, width: 1) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_soccer, color: selectedRole == 'PLAYER' ? Colors.green : Colors.grey),
                    const SizedBox(width: 8),
                    Text('لاعب', style: TextStyle(color: selectedRole == 'PLAYER' ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedRole = 'OWNER'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: selectedRole == 'OWNER' ? Colors.green.shade50 : Colors.transparent,
                  borderRadius: BorderRadius.horizontal(left: const Radius.circular(12)),
                  border: selectedRole == 'OWNER' ? Border.all(color: Colors.green, width: 1) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stadium, color: selectedRole == 'OWNER' ? Colors.green : Colors.grey),
                    const SizedBox(width: 8),
                    Text('صاحب ملعب', style: TextStyle(color: selectedRole == 'OWNER' ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
                  ],
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                        ]
                      ),
                      child: const Icon(Icons.sports_soccer, color: Colors.white, size: 50),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('PitchUp', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.green.shade800, letterSpacing: -1)),
                  Text(isLogin ? 'مرحباً بعودتك للملعب!' : 'ابدأ رحلتك الرياضية', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  const SizedBox(height: 40),

                  // Tabs
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => {isLogin = true, errorMsg = null}),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isLogin ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isLogin ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)] : [],
                              ),
                              child: Center(child: Text('تسجيل دخول', style: TextStyle(color: isLogin ? Colors.green.shade700 : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 16))),
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
                                color: !isLogin ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: !isLogin ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)] : [],
                              ),
                              child: Center(child: Text('حساب جديد', style: TextStyle(color: !isLogin ? Colors.green.shade700 : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 16))),
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
                      decoration: InputDecoration(
                        labelText: 'الاسم بالكامل',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.green, width: 2)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.green, width: 2)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.green, width: 2)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (errorMsg != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade400),
                          const SizedBox(width: 12),
                          Expanded(child: Text(errorMsg!, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500))),
                        ],
                      ),
                    ),

                  ElevatedButton(
                    onPressed: isLoading ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(isLogin ? 'تسجيل الدخول' : 'إنشاء حساب جديد', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
