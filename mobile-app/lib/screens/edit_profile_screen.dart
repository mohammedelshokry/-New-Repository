import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';

String getFullUrl(String url) {
  if (url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  if (url.startsWith('/')) return 'http://192.168.1.10:3001$url';
  return 'http://192.168.1.10:3001/$url';
}


class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  XFile? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameCtrl = TextEditingController(text: user?['name'] ?? '');
    _phoneCtrl = TextEditingController(text: user?['phone'] ?? '');
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _selectedImage = image);
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      String? profilePicUrl;
      if (_selectedImage != null) {
        final formData = FormData.fromMap({
          'images': await MultipartFile.fromFile(_selectedImage!.path),
        });
        final uploadRes = await dio.post('/upload', data: formData);
        final images = List<String>.from(uploadRes.data['urls'] ?? uploadRes.data['images'] ?? []);
        if (images.isNotEmpty) profilePicUrl = images[0];
      }
      final payload = {'name': _nameCtrl.text, 'phone': _phoneCtrl.text};
      if (profilePicUrl != null) payload['profilePic'] = profilePicUrl;
      final res = await dio.put('/users/me', data: payload);
      ref.read(currentUserProvider.notifier).state = res.data;
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الملف الشخصي بنجاح')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final currentPic = user?['profilePic'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppTheme.surfaceLighter,
                    backgroundImage: _selectedImage != null
                        ? FileImage(File(_selectedImage!.path)) as ImageProvider
                        : (currentPic != null ? NetworkImage(getFullUrl(currentPic)) : null),
                    child: (_selectedImage == null && currentPic == null)
                        ? const Icon(Icons.person, size: 60, color: Colors.white54)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: AppTheme.neonBlue, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'الاسم',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true, fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true, fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('حفظ التعديلات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
