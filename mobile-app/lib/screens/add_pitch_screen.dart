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

class AddPitchScreen extends ConsumerStatefulWidget {
  const AddPitchScreen({super.key});

  @override
  ConsumerState<AddPitchScreen> createState() => _AddPitchScreenState();
}

class _AddPitchScreenState extends ConsumerState<AddPitchScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  
  String _selectedCategory = '\u0643\u0631\u0629 \u0642\u062f\u0645'; // كرة قدم
  final List<String> _categories = [
    '\u0643\u0631\u0629 \u0642\u062f\u0645', // كرة قدم
    '\u0628\u0627\u062f\u0644', // بادل
    '\u062a\u0646\u0633', // تنس
    '\u0643\u0631\u0629 \u0633\u0644\u0629', // كرة سلة
    '\u0628\u0644\u0627\u064a\u0633\u062a\u064a\u0634\u0646', // بلايستيشن
    '\u0628\u0644\u064a\u0627\u0631\u062f\u0648', // بلياردو
    '\u0643\u0631\u0629 \u0637\u0627\u0626\u0631\u0629', // كرة طائرة
  ];

  // Dynamic Options
  bool _isAirConditioned = false;
  bool _ballIncluded = false;
  String _footballSize = '\u062e\u0645\u0627\u0633\u064a'; // خماسي
  String _psConsole = 'PS4';
  String _psRoom = '\u0639\u0627\u062f\u064a\u0629'; // عادية
  
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
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null) {
      setState(() {
        _selectedLocation = result;
      });
    }
  }

  String _buildDynamicDescription() {
    List<String> options = [];
    if (_selectedCategory == '\u0643\u0631\u0629 \u0642\u062f\u0645') {
      options.add('\u0627\u0644\u0645\u0633\u0627\u062d\u0629: $_footballSize');
      if (_ballIncluded) options.add('\u0643\u0631\u0629 \u0645\u062a\u0648\u0641\u0631\u0629');
    } else if (_selectedCategory == '\u0628\u0644\u0627\u064a\u0633\u062a\u064a\u0634\u0646') {
      options.add('\u0627\u0644\u062c\u0647\u0627\u0632: $_psConsole');
      options.add('\u0627\u0644\u063a\u0631\u0641\u0629: $_psRoom');
    }
    
    if (_isAirConditioned) {
      options.add('\u0645\u0643\u064a\u0641');
    }

    String baseDesc = _descCtrl.text.trim();
    if (options.isNotEmpty) {
      return baseDesc.isNotEmpty ? '$baseDesc\n\n\u0627\u0644\u0645\u0645\u064a\u0632\u0627\u062a:\n- ${options.join('\n- ')}' : '\u0627\u0644\u0645\u0645\u064a\u0632\u0627\u062a:\n- ${options.join('\n- ')}';
    }
    return baseDesc;
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('\u064a\u0631\u062c\u0649 \u0625\u062f\u062e\u0627\u0644 \u0627\u0644\u0627\u0633\u0645 \u0648\u0627\u0644\u0633\u0639\u0631 \u0648\u0627\u0644\u0645\u0648\u0642\u0639')));
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
        // FIXED: parse urls correctly
        if (uploadRes.data['urls'] != null) {
          uploadedImageUrls = List<String>.from(uploadRes.data['urls']);
        } else if (uploadRes.data['images'] != null) {
          uploadedImageUrls = List<String>.from(uploadRes.data['images']);
        }
      }

      // 2. Create Pitch
      final payload = {
        'name': _nameCtrl.text,
        'category': _selectedCategory,
        'description': _buildDynamicDescription(),
        'location': '${_selectedLocation!.latitude},${_selectedLocation!.longitude}',
        'pricePerHour': double.tryParse(_priceCtrl.text) ?? 200,
        'images': uploadedImageUrls,
        'amenities': _isAirConditioned ? 'AC' : '',
        'surface': '\u063a\u064a\u0631 \u0645\u062d\u062f\u062f', // Fix for missing surface field
      };

      await dio.post('/pitches', data: payload);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('\u062a\u0645\u062a \u0627\u0644\u0625\u0636\u0627\u0641\u0629 \u0628\u0646\u062c\u0627\u062d')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\u062e\u0637\u0623: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('\u0625\u0636\u0627\u0641\u0629 \u0645\u0644\u0639\u0628 \u062c\u062f\u064a\u062f')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '\u0627\u0633\u0645 \u0627\u0644\u0645\u0644\u0639\u0628 / \u0627\u0644\u0645\u0643\u0627\u0646',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              dropdownColor: AppTheme.surfaceDark,
              style: const TextStyle(color: Colors.white),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedCategory = v!;
                });
              },
              decoration: InputDecoration(
                labelText: '\u0646\u0648\u0639 \u0627\u0644\u0645\u0644\u0639\u0628',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            
            // Dynamic UI based on category
            const SizedBox(height: 16),
            if (_selectedCategory == '\u0643\u0631\u0629 \u0642\u062f\u0645') ...[
              DropdownButtonFormField<String>(
                value: _footballSize,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: Colors.white),
                items: ['\u062e\u0645\u0627\u0633\u064a', '\u0633\u062f\u0627\u0633\u064a', '\u0633\u0628\u0627\u0639\u064a', '\u062d\u0627\u062f\u064a \u0639\u0634\u0631'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _footballSize = v!),
                decoration: InputDecoration(labelText: '\u0627\u0644\u0645\u0633\u0627\u062d\u0629', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              SwitchListTile(
                title: const Text('\u0643\u0631\u0629 \u0645\u062c\u0627\u0646\u064a\u0629 \u0645\u0639 \u0627\u0644\u062d\u062c\u0632\u061f', style: TextStyle(color: Colors.white)),
                value: _ballIncluded,
                onChanged: (v) => setState(() => _ballIncluded = v),
              ),
            ],
            
            if (_selectedCategory == '\u0628\u0644\u0627\u064a\u0633\u062a\u064a\u0634\u0646') ...[
              DropdownButtonFormField<String>(
                value: _psConsole,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: Colors.white),
                items: ['PS4', 'PS5'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _psConsole = v!),
                decoration: InputDecoration(labelText: '\u0646\u0648\u0639 \u0627\u0644\u062c\u0647\u0627\u0632', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _psRoom,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: Colors.white),
                items: ['\u0639\u0627\u062f\u064a\u0629', 'VIP', '\u062e\u0627\u0635\u0629'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _psRoom = v!),
                decoration: InputDecoration(labelText: '\u0646\u0648\u0639 \u0627\u0644\u063a\u0631\u0641\u0629', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],

            SwitchListTile(
              title: const Text('\u0645\u0643\u064a\u0641\u061f', style: TextStyle(color: Colors.white)),
              value: _isAirConditioned,
              onChanged: (v) => setState(() => _isAirConditioned = v),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '\u0648\u0635\u0641 \u0625\u0636\u0627\u0641\u064a',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '\u0627\u0644\u0633\u0639\u0631 \u0628\u0627\u0644\u0633\u0627\u0639\u0629 (\u062c.\u0645)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: Icon(Icons.map, color: _selectedLocation == null ? Colors.white : AppTheme.neonBlue),
              label: Text(_selectedLocation == null ? '\u062a\u062d\u062f\u064a\u062f \u0639\u0644\u0649 \u0627\u0644\u062e\u0631\u064a\u0637\u0629' : '\u062a\u0645 \u0627\u0644\u062a\u062d\u062f\u064a\u062f (${_selectedLocation!.latitude.toStringAsFixed(4)}, ...)', style: const TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: _selectedLocation == null ? Colors.white54 : AppTheme.neonBlue),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
              label: Text('\u0625\u0636\u0627\u0641\u0629 \u0635\u0648\u0631 (${_selectedImages.length})', style: const TextStyle(color: Colors.white)),
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
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text('\u0625\u0636\u0627\u0641\u0629 \u0627\u0644\u0645\u0643\u0627\u0646', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
