import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';
import 'location_picker_screen.dart';
import 'package:go_router/go_router.dart';
import 'add_court_screen.dart';

class AddVenueScreen extends ConsumerStatefulWidget {
  const AddVenueScreen({super.key});
  @override
  ConsumerState<AddVenueScreen> createState() => _AddVenueScreenState();
}

class _AddVenueScreenState extends ConsumerState<AddVenueScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  
  String _selectedCategory = '\u0643\u0631\u0629 \u0642\u062f\u0645';
  final List<String> _categories = [
    '\u0643\u0631\u0629 \u0642\u062f\u0645', '\u0628\u0627\u062f\u0644', '\u062a\u0646\u0633', '\u0643\u0631\u0629 \u0633\u0644\u0629', 
    '\u0628\u0644\u0627\u064a\u0633\u062a\u064a\u0634\u0646', '\u0628\u0644\u064a\u0627\u0631\u062f\u0648', '\u0643\u0631\u0629 \u0637\u0627\u0626\u0631\u0629'
  ];

  TimeOfDay _openTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 2, minute: 0);
  
  List<XFile> _selectedImages = [];
  LatLng? _selectedLocation;
  bool _isLoading = false;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) setState(() => _selectedImages.addAll(images));
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (_) => const LocationPickerScreen()));
    if (result != null) setState(() => _selectedLocation = result);
  }

  Future<void> _pickTime(bool isOpenTime) async {
    final time = await showTimePicker(context: context, initialTime: isOpenTime ? _openTime : _closeTime);
    if (time != null) {
      setState(() { if (isOpenTime) _openTime = time; else _closeTime = time; });
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم وموقع المجمع')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      List<String> uploadedImageUrls = [];
      if (_selectedImages.isNotEmpty) {
        final formData = FormData();
        for (var file in _selectedImages) formData.files.add(MapEntry('images', await MultipartFile.fromFile(file.path)));
        final uploadRes = await dio.post('/upload', data: formData);
        uploadedImageUrls = List<String>.from(uploadRes.data['urls'] ?? uploadRes.data['images'] ?? []);
      }

      final payload = {
        'name': _nameCtrl.text,
        'category': _selectedCategory,
        'description': _descCtrl.text,
        'location': '${_selectedLocation!.latitude},${_selectedLocation!.longitude}',
        'openTime': '${_openTime.hour.toString().padLeft(2, '0')}:${_openTime.minute.toString().padLeft(2, '0')}',
        'closeTime': '${_closeTime.hour.toString().padLeft(2, '0')}:${_closeTime.minute.toString().padLeft(2, '0')}',
        'images': uploadedImageUrls,
      };

      final response = await dio.post('/venues', data: payload);
      ref.refresh(venuesProvider);
      
      if (mounted) {
        // Now navigate to AddCourtScreen to add the first room/pitch!
        final venueId = response.data['id'];
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء المجمع بنجاح، قم بإضافة الغرف/الملاعب الآن.')));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AddCourtScreen(venueId: venueId, venueCategory: _selectedCategory)));
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
      appBar: AppBar(title: const Text('إضافة مجمع/مكان جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              dropdownColor: AppTheme.surfaceDark, style: const TextStyle(color: Colors.white),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
              decoration: InputDecoration(labelText: 'فئة المكان (النشاط الأساسي)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'اسم المجمع (مثال: أكاديمية الأبطال، بلايستيشن زون)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl, maxLines: 2, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'وصف عام للمجمع', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _pickTime(true), icon: const Icon(Icons.access_time), label: Text('يفتح: ${_openTime.format(context)}', style: const TextStyle(color: Colors.white)))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(onPressed: () => _pickTime(false), icon: const Icon(Icons.access_time), label: Text('يغلق: ${_closeTime.format(context)}', style: const TextStyle(color: Colors.white)))),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: Icon(Icons.map, color: _selectedLocation == null ? Colors.white : AppTheme.neonBlue),
              label: Text(_selectedLocation == null ? 'تحديد على الخريطة' : 'تم التحديد', style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImages, icon: const Icon(Icons.add_photo_alternate),
              label: Text('إضافة صور عامة للمكان (${_selectedImages.length})', style: const TextStyle(color: Colors.white)),
            ),
            if (_selectedImages.isNotEmpty)
              Container(
                height: 100, margin: const EdgeInsets.only(top: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal, itemCount: _selectedImages.length,
                  itemBuilder: (ctx, i) => Container(
                    margin: const EdgeInsets.only(left: 8), width: 100,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: FileImage(File(_selectedImages[i].path)), fit: BoxFit.cover)),
                  ),
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonBlue, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('الخطوة التالية: إضافة الغرف', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
