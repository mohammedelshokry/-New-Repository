import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';

class AddCourtScreen extends ConsumerStatefulWidget {
  final String venueId;
  const AddCourtScreen({super.key, required this.venueId});
  @override
  ConsumerState<AddCourtScreen> createState() => _AddCourtScreenState();
}

class _AddCourtScreenState extends ConsumerState<AddCourtScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  
  String _selectedCategory = '\u0643\u0631\u0629 \u0642\u062f\u0645';
  final List<String> _categories = [
    '\u0643\u0631\u0629 \u0642\u062f\u0645', '\u0628\u0627\u062f\u0644', '\u062a\u0646\u0633', '\u0643\u0631\u0629 \u0633\u0644\u0629', 
    '\u0628\u0644\u0627\u064a\u0633\u062a\u064a\u0634\u0646', '\u0628\u0644\u064a\u0627\u0631\u062f\u0648', '\u0643\u0631\u0629 \u0637\u0627\u0626\u0631\u0629'
  ];

  Map<String, dynamic> _amenities = {
    'isAirConditioned': false,
    'ballIncluded': false,
    'footballSize': '\u062e\u0645\u0627\u0633\u064a',
    'psConsole': 'PS4',
    'psRoomType': '\u0639\u0627\u062f\u064a\u0629',
    'padelIndoor': false,
    'billiardsType': '8-Ball',
  };

  List<XFile> _selectedImages = [];
  bool _isLoading = false;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) setState(() => _selectedImages.addAll(images));
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال الاسم والسعر')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      List<String> uploadedImageUrls = [];
      if (_selectedImages.isNotEmpty) {
        final formData = FormData();
        for (var file in _selectedImages) {
          formData.files.add(MapEntry('images', await MultipartFile.fromFile(file.path)));
        }
        final uploadRes = await dio.post('/upload', data: formData);
        uploadedImageUrls = List<String>.from(uploadRes.data['urls'] ?? uploadRes.data['images'] ?? []);
      }

      final payload = {
        'name': _nameCtrl.text,
        'category': _selectedCategory,
        'description': _descCtrl.text,
        'pricePerHour': double.tryParse(_priceCtrl.text) ?? 100,
        'images': uploadedImageUrls,
        'amenities': jsonEncode(_amenities),
      };

      await dio.post('/venues//courts', data: payload);
      ref.refresh(venueDetailsProvider(widget.venueId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة الملعب/الغرفة بنجاح')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة ملعب/غرفة جديدة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              dropdownColor: AppTheme.surfaceDark,
              style: const TextStyle(color: Colors.white),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
              decoration: InputDecoration(labelText: 'الفئة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'اسم الملعب/الغرفة (مثال: ملعب A, غرفة VIP)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            
            // Dynamic Options
            if (_selectedCategory == '\u0643\u0631\u0629 \u0642\u062f\u0645') ...[
              DropdownButtonFormField<String>(
                value: _amenities['footballSize'], dropdownColor: AppTheme.surfaceDark, style: const TextStyle(color: Colors.white),
                items: ['\u062e\u0645\u0627\u0633\u064a', '\u0633\u062f\u0627\u0633\u064a', '\u0633\u0628\u0627\u0639\u064a', '\u062d\u0627\u062f\u064a \u0639\u0634\u0631'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _amenities['footballSize'] = v),
                decoration: InputDecoration(labelText: 'المساحة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              SwitchListTile(title: const Text('كرة مجانية؟', style: TextStyle(color: Colors.white)), value: _amenities['ballIncluded'], onChanged: (v) => setState(() => _amenities['ballIncluded'] = v)),
            ] else if (_selectedCategory == '\u0628\u0644\u0627\u064a\u0633\u062a\u064a\u0634\u0646') ...[
              DropdownButtonFormField<String>(
                value: _amenities['psConsole'], dropdownColor: AppTheme.surfaceDark, style: const TextStyle(color: Colors.white),
                items: ['PS4', 'PS5'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _amenities['psConsole'] = v),
                decoration: InputDecoration(labelText: 'الجهاز', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _amenities['psRoomType'], dropdownColor: AppTheme.surfaceDark, style: const TextStyle(color: Colors.white),
                items: ['\u0639\u0627\u062f\u064a\u0629', 'VIP', '\u062e\u0627\u0635\u0629'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _amenities['psRoomType'] = v),
                decoration: InputDecoration(labelText: 'نوع الغرفة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ] else if (_selectedCategory == '\u0628\u0627\u062f\u0644') ...[
              SwitchListTile(title: const Text('مغطى (Indoor)؟', style: TextStyle(color: Colors.white)), value: _amenities['padelIndoor'], onChanged: (v) => setState(() => _amenities['padelIndoor'] = v)),
            ] else if (_selectedCategory == '\u0628\u0644\u064a\u0627\u0631\u062f\u0648') ...[
              DropdownButtonFormField<String>(
                value: _amenities['billiardsType'], dropdownColor: AppTheme.surfaceDark, style: const TextStyle(color: Colors.white),
                items: ['8-Ball', 'Snooker', 'French'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _amenities['billiardsType'] = v),
                decoration: InputDecoration(labelText: 'نوع الطاولة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],

            SwitchListTile(title: const Text('مكيف؟', style: TextStyle(color: Colors.white)), value: _amenities['isAirConditioned'], onChanged: (v) => setState(() => _amenities['isAirConditioned'] = v)),
            
            const SizedBox(height: 16),
            TextField(
              controller: _priceCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'السعر بالساعة (ج.م)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl, maxLines: 2, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'ملاحظات إضافية', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImages, icon: const Icon(Icons.add_photo_alternate),
              label: Text('إضافة صور الغرفة/الملعب ()', style: const TextStyle(color: Colors.white)),
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
              child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('إضافة للـ المجمع', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
