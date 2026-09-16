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
        final token = res.data['token'];
        final user = res.data['user'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        ref.read(currentUserProvider.notifier).state = user;
      } else {
        final res = await dio.post('/auth/register', data: {
          'name': name,
          'phone': phone,
          'password': password,
        });
        if (res.statusCode == 201) {
          final loginRes = await dio.post('/auth/login', data: {
            'phone': phone,
            'password': password,
          });
          final token = loginRes.data['token'];
          final user = loginRes.data['user'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          ref.read(currentUserProvider.notifier).state = user;
        }
      }
    } on DioException catch (e) {
      setState(() {
        errorMsg = e.response?.data?['error']?.toString() ?? 'خطأ في الاتصال';
      });
    } catch (e) {
      setState(() => errorMsg = 'خطأ غير متوقع');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            stretch: true,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.sports_soccer, color: Colors.white, size: 45),
                    ),
                    const SizedBox(height: 16),
                    Text('PitchUp', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              Container(
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isLogin = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isLogin ? Colors.green : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('تسجيل دخول', style: TextStyle(color: isLogin ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isLogin = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isLogin ? Colors.green : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('حساب جديد', style: TextStyle(color: !isLogin ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (!isLogin) ...[
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'الاسم',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'كلمة السر',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              if (errorMsg != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(errorMsg!, style: TextStyle(color: Colors.red.shade700), textAlign: TextAlign.center),
                ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: isLoading ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(isLogin ? 'تسجيل دخول' : 'إنشاء حساب', style: const TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
