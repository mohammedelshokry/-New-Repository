import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
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
  bool isLoading = false;
  String? errorMsg;

  void submit() async {
    final phone = phoneController.text.trim();
    final name = nameController.text.trim();

    if (phone.isEmpty) {
      setState(() => errorMsg = 'من فضلك أدخل رقم الهاتف');
      return;
    }
    if (!isLogin && name.isEmpty) {
      setState(() => errorMsg = 'من فضلك أدخل الاسم');
      return;
    }

    setState(() { isLoading = true; errorMsg = null; });

    final dio = ref.read(dioProvider);

    try {
      if (isLogin) {
        // Login: find user by phone
        final res = await dio.get('/users');
        final users = res.data as List;
        final user = users.firstWhere(
          (u) => u['phone'] == phone,
          orElse: () => null,
        );
        if (user == null) {
          setState(() { errorMsg = 'رقم الهاتف غير مسجل. قم بإنشاء حساب جديد.'; isLoading = false; });
          return;
        }
        ref.read(currentUserProvider.notifier).state = user;
      } else {
        // Register
        final res = await dio.post('/users/register', data: {
          'name': name,
          'phone': phone,
          'role': selectedRole,
        });
        ref.read(currentUserProvider.notifier).state = res.data;
      }
    } on DioException catch (e) {
      setState(() {
        errorMsg = e.response?.data?['error'] ?? 'حدث خطأ في الاتصال بالسيرفر';
      });
    } catch (e) {
      setState(() { errorMsg = 'حدث خطأ غير متوقع'; });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              // Logo
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
                    const SizedBox(height: 4),
                    const Text('احجز ملعبك. العب مباراتك.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Toggle Login / Register
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

              // Name field (register only)
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

              // Phone field
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

              // Role selector (register only)
              if (!isLogin) ...[
                const Text('أنت إيه؟', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => selectedRole = 'PLAYER'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedRole == 'PLAYER' ? Colors.green.shade50 : Colors.grey.shade50,
                            border: Border.all(color: selectedRole == 'PLAYER' ? Colors.green : Colors.grey.shade300, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.sports_soccer, size: 36, color: selectedRole == 'PLAYER' ? Colors.green : Colors.grey),
                              const SizedBox(height: 8),
                              Text('لاعب', style: TextStyle(fontWeight: FontWeight.bold, color: selectedRole == 'PLAYER' ? Colors.green.shade800 : Colors.grey)),
                              const Text('هحجز واتمرن', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => selectedRole = 'OWNER'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedRole == 'OWNER' ? Colors.blue.shade50 : Colors.grey.shade50,
                            border: Border.all(color: selectedRole == 'OWNER' ? Colors.blue : Colors.grey.shade300, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.business, size: 36, color: selectedRole == 'OWNER' ? Colors.blue : Colors.grey),
                              const SizedBox(height: 8),
                              Text('صاحب ملعب', style: TextStyle(fontWeight: FontWeight.bold, color: selectedRole == 'OWNER' ? Colors.blue.shade800 : Colors.grey)),
                              const Text('هسجل ملعبي', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Error message
              if (errorMsg != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(errorMsg!, style: TextStyle(color: Colors.red.shade700), textAlign: TextAlign.center),
                ),
              const SizedBox(height: 16),

              // Submit button
              ElevatedButton(
                onPressed: isLoading ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(isLogin ? 'دخول' : 'إنشاء حساب', style: const TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
