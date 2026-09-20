import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';
import 'location_picker_screen.dart';

class AddPitchScreen extends ConsumerStatefulWidget {
  const AddPitchScreen({super.key});

  @override
  ConsumerState<AddPitchScreen> createState() => _AddPitchScreenState();
}

class _AddPitchScreenState extends ConsumerState<AddPitchScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  
  String _selectedCategory = 'كرة قدم';
  final List<String> _categories = ['كرة قدم', 'بادل', 'تنس', 'كرة سلة'];
  
  List<XFile> _selectedImages = [];
  LatLng? _selectedLocation;
  bool _isLoading = false;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );
    if (result != null && result is LatLng) {
      setState(() {
        _selectedLocation = result;
      });
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال الاسم، السعر، والموقع')));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final dio = ref.read(dioProvider);
      
      // 1. Upload Images
      List<String> uploadedImageUrls = [];
      if (_selectedImages.isNotEmpty) {
        final formData = FormData();
        for (var file in _selectedImages) {
          formData.files.add(MapEntry('images', await MultipartFile.fromFile(file.path)));
        }
        final uploadRes = await dio.post('/upload', data: formData);
        uploadedImageUrls = List<String>.from(uploadRes.data['images']);
      }

      // 2. Create Pitch
      final payload = {
        'name': _nameCtrl.text,
        'category': _selectedCategory,
        'description': _descCtrl.text,
        'location': '${_selectedLocation!.latitude},${_selectedLocation!.longitude}',
        'pricePerHour': double.tryParse(_priceCtrl.text) ?? 200,
        'images': uploadedImageUrls,
        'amenities': 'موقف سيارات,مشروبات', // default or can be added later
      };

      await dio.post('/pitches', data: payload);
      ref.refresh(pitchesProvider);
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الملعب بنجاح')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة ملعب جديد'),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'اسم الملعب',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              dropdownColor: AppTheme.surfaceDark,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'نوع الملعب',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'وصف المكان',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'السعر بالساعة (ج.م)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: Icon(Icons.map, color: _selectedLocation == null ? Colors.white : AppTheme.neonBlue),
              label: Text(_selectedLocation == null ? 'تحديد على الخريطة' : 'تم التحديد (${_selectedLocation!.latitude.toStringAsFixed(4)}, ...)', style: const TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: _selectedLocation == null ? Colors.white54 : AppTheme.neonBlue),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
              label: Text('إضافة صور (${_selectedImages.length})', style: const TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.white54),
              ),
            ),
            if (_selectedImages.isNotEmpty)
              Container(
                height: 100,
                margin: const EdgeInsets.only(top: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (ctx, i) => Container(
                    margin: const EdgeInsets.only(left: 8),
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(image: FileImage(File(_selectedImages[i].path)), fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('إضافة الملعب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
