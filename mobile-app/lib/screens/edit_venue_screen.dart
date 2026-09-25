import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class EditVenueScreen extends ConsumerStatefulWidget {
  final dynamic venue;
  const EditVenueScreen({super.key, required this.venue});

  @override
  ConsumerState<EditVenueScreen> createState() => _EditVenueScreenState();
}

class _EditVenueScreenState extends ConsumerState<EditVenueScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _locationCtrl;
  late String _selectedCategory;
  late TimeOfDay _openTime;
  late TimeOfDay _closeTime;
  List<String> _networkImages = [];
  List<XFile> _newImages = [];
  bool _isLoading = false;

  final List<String> _categories = [
    '\u0643\u0631\u0629 \u0642\u062f\u0645', '\u0628\u0627\u062f\u0644', '\u062a\u0646\u0633', '\u0643\u0631\u0629 \u0633\u0644\u0629', 
    '\u0628\u0644\u0627\u064a\u0633\u062a\u064a\u0634\u0646', '\u0628\u0644\u064a\u0627\u0631\u062f\u0648', '\u0643\u0631\u0629 \u0637\u0627\u0626\u0631\u0629', 'بينج بونج'
  ];
  TimeOfDay _parseTime(String? time) {
    if (time == null || !time.contains(':')) return const TimeOfDay(hour: 14, minute: 0);
    final parts = time.split(':');
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 14, minute: int.tryParse(parts[1]) ?? 0);
  }

  String _formatTimeOfDay(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _displayTime(TimeOfDay t) {
    final dt = DateTime(2023, 1, 1, t.hour, t.minute);
    return DateFormat('h:mm a').format(dt).replaceAll('AM', 'ص').replaceAll('PM', 'م');
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.venue['name'] ?? '');
    _descCtrl = TextEditingController(text: widget.venue['description'] ?? '');
    _locationCtrl = TextEditingController(text: widget.venue['location'] ?? '');
    _selectedCategory = _categories.contains(widget.venue['category'])
        ? widget.venue['category']
        : _categories.first;
    _openTime = _parseTime(widget.venue['openTime']);
    _closeTime = _parseTime(widget.venue['closeTime']);

    // Parse existing images
    if (widget.venue['images'] != null) {
      try {
        final decoded = widget.venue['images'];
        if (decoded is List) {
          _networkImages = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isOpen) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen ? _openTime : _closeTime,
    );
    if (picked != null) {
      setState(() {
        if (isOpen) { _openTime = picked; } else { _closeTime = picked; }
      });
    }
  }

  Future<void> _pickNewImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isNotEmpty) {
      setState(() => _newImages.addAll(files));
    }
  }

  String _getFullUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'http://192.168.1.10:3001$url';
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اسم المكان مطلوب')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _selectedCategory,
        'location': _locationCtrl.text.trim(),
        'openTime': _formatTimeOfDay(_openTime),
        'closeTime': _formatTimeOfDay(_closeTime),
        'existingImages': '["${_networkImages.join('","')}"]',
      });

      // Add new image files
      for (final img in _newImages) {
        formData.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(img.path, filename: img.name),
        ));
      }

      await dio.patch('/venues/${widget.venue['id']}', data: formData);
      ref.invalidate(venueDetailsProvider(widget.venue['id']));
      ref.invalidate(venuesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات بنجاح ✅')));
        Navigator.pop(context);
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
      appBar: AppBar(title: const Text('تعديل المكان'), backgroundColor: AppTheme.surfaceDark),
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
              decoration: InputDecoration(labelText: 'فئة المكان', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'اسم المكان', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'وصف المكان', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'الموقع', prefixIcon: const Icon(Icons.location_on), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _pickTime(true),
                  icon: const Icon(Icons.access_time),
                  label: Text('يفتح: ${_displayTime(_openTime)}', style: const TextStyle(color: Colors.white)),
                )),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _pickTime(false),
                  icon: const Icon(Icons.access_time),
                  label: Text('يغلق: ${_displayTime(_closeTime)}', style: const TextStyle(color: Colors.white)),
                )),
              ],
            ),

            const SizedBox(height: 24),
            const Text('الصور الحالية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_networkImages.isEmpty)
              const Text('لا توجد صور حالية', style: TextStyle(color: Colors.grey)),
            if (_networkImages.isNotEmpty)
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _networkImages.length,
                  itemBuilder: (ctx, i) => Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(image: NetworkImage(_getFullUrl(_networkImages[i])), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 4, right: 12,
                        child: GestureDetector(
                          onTap: () => setState(() => _networkImages.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickNewImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text('إضافة صور جديدة (${_newImages.length})', style: const TextStyle(color: Colors.white)),
            ),
            if (_newImages.isNotEmpty)
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _newImages.length,
                  itemBuilder: (ctx, i) => Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8, top: 8),
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(image: FileImage(File(_newImages[i].path)), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 0, right: 12,
                        child: GestureDetector(
                          onTap: () => setState(() => _newImages.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
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
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('حفظ التعديلات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
