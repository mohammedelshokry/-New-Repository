import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class AddCourtScreen extends ConsumerStatefulWidget {
  final String venueId;
  final String venueCategory;
  final dynamic existingCourt;
  const AddCourtScreen({super.key, required this.venueId, required this.venueCategory, this.existingCourt});
  @override
  ConsumerState<AddCourtScreen> createState() => _AddCourtScreenState();
}

class _AddCourtScreenState extends ConsumerState<AddCourtScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  
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
  List<String> _networkImages = [];
  bool _isLoading = false;
  late String _roomCategory;
  
  final List<String> _categories = [
    'كرة قدم', 'بادل', 'تنس', 'كرة سلة', 
    'بلايستيشن', 'بلياردو', 'كرة طائرة', 'بينج بونج'
  ];


  @override
  void initState() {
    super.initState();
    _roomCategory = widget.venueCategory;
    if (widget.existingCourt != null) {
      if (_categories.contains(widget.existingCourt['category'])) {
        _roomCategory = widget.existingCourt['category'];
      }
      _nameCtrl.text = widget.existingCourt['name'] ?? '';
      _priceCtrl.text = widget.existingCourt['pricePerHour']?.toString() ?? '';
      if (widget.existingCourt['images'] != null) {
        final imgs = widget.existingCourt['images'];
        if (imgs is List) {
          _networkImages = List<String>.from(imgs);
        } else if (imgs is String) {
          try { _networkImages = List<String>.from(jsonDecode(imgs)); } catch(e) {}
        }
      }
      if (widget.existingCourt['amenities'] != null) {
        try {
                    final parsed = widget.existingCourt['amenities'] is String 
              ? jsonDecode(widget.existingCourt['amenities']) 
              : widget.existingCourt['amenities'];
          _amenities.addAll(Map<String, dynamic>.from(parsed));
        } catch(e) {}
      }
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) setState(() => _selectedImages.addAll(images));
  }

  void _resetForm() {
    _nameCtrl.clear();
    _priceCtrl.clear();
    _descCtrl.clear();
    setState(() => _selectedImages.clear());
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
        for (var file in _selectedImages) formData.files.add(MapEntry('images', await MultipartFile.fromFile(file.path)));
        final uploadRes = await dio.post('/upload', data: formData);
        uploadedImageUrls = List<String>.from(uploadRes.data['urls'] ?? uploadRes.data['images'] ?? []);
      }


      // Filter amenities based on category to prevent mixed UI artifacts
      final Map<String, dynamic> filteredAmenities = {};
      filteredAmenities['isAirConditioned'] = _amenities['isAirConditioned'];
      
      if (_roomCategory == 'بادل') {
        filteredAmenities['courtType'] = _amenities['courtType'];
        filteredAmenities['ballIncluded'] = _amenities['ballIncluded'];
      } else if (_roomCategory == 'بلايستيشن') {
        filteredAmenities['psConsole'] = _amenities['psConsole'];
        filteredAmenities['psRoomType'] = _amenities['psRoomType'];
      } else if (_roomCategory == 'بلياردو') {
        filteredAmenities['billiardsType'] = _amenities['billiardsType'];
      } else if (_roomCategory == 'كرة قدم') {
        filteredAmenities['footballSize'] = _amenities['footballSize'];
        filteredAmenities['ballIncluded'] = _amenities['ballIncluded'];
      }

      final payload = {
        'name': _nameCtrl.text,
        'category': _roomCategory,
        'description': _descCtrl.text,
        'pricePerHour': double.tryParse(_priceCtrl.text) ?? 100,
        'images': [..._networkImages, ...uploadedImageUrls],
        'amenities': jsonEncode(filteredAmenities),
      };

      if (widget.existingCourt != null) {
        await dio.patch('/courts/${widget.existingCourt['id']}', data: payload);
      } else {
        await dio.post('/venues/${widget.venueId}/courts', data: payload);
      }
      
      ref.refresh(venueDetailsProvider(widget.venueId));
      ref.refresh(venuesProvider);
      
      if (mounted) {
        showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: Text(widget.existingCourt != null ? 'تم التعديل بنجاح' : 'تمت الإضافة بنجاح', style: const TextStyle(color: AppTheme.neonBlue)),
          content: Text(widget.existingCourt != null ? 'تم تحديث بيانات الغرفة/الملعب.' : 'هل تريد إضافة غرفة/ملعب آخر في نفس المكان؟', style: const TextStyle(color: Colors.white)),
          actions: [
            if (widget.existingCourt == null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('لا، اكتفيت', style: TextStyle(color: Colors.grey)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonBlue, foregroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(ctx);
                if (widget.existingCourt == null) {
                  _resetForm();
                } else {
                  Navigator.pop(context); // just go back if edited
                }
              },
              child: Text(widget.existingCourt != null ? 'حسناً' : 'نعم، إضافة المزيد'),
            ),
          ],
        ),
      );
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
      appBar: AppBar(title: Text('إضافة غرفة/ملعب (${widget.venueCategory})')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            DropdownButtonFormField<String>(
              value: _roomCategory,
              dropdownColor: AppTheme.surfaceDark, style: const TextStyle(color: Colors.white),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _roomCategory = v!),
              decoration: InputDecoration(labelText: 'نوع الغرفة/الملعب', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'اسم/رقم الغرفة أو الملعب (مثال: غرفة 1, VIP, ملعب خماسي A)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            
            // Dynamic Options based on the venue's category passed from AddVenueScreen
            if (widget.venueCategory == '\u0643\u0631\u0629 \u0642\u062f\u0645') ...[
              DropdownButtonFormField<String>(
                value: _amenities['footballSize'], dropdownColor: AppTheme.surfaceDark, style: const TextStyle(color: Colors.white),
                items: ['\u062e\u0645\u0627\u0633\u064a', '\u0633\u062f\u0627\u0633\u064a', '\u0633\u0628\u0627\u0639\u064a', '\u062d\u0627\u062f\u064a \u0639\u0634\u0631'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _amenities['footballSize'] = v),
                decoration: InputDecoration(labelText: 'المساحة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              SwitchListTile(title: const Text('كرة مجانية؟', style: TextStyle(color: Colors.white)), value: _amenities['ballIncluded'], onChanged: (v) => setState(() => _amenities['ballIncluded'] = v)),
            ] else if (widget.venueCategory == '\u0628\u0644\u0627\u064a\u0633\u062a\u064a\u0634\u0646') ...[
              DropdownButtonFormField<String>(
                value: _amenities['psConsole'], dropdownColor: AppTheme.surfaceDark, style: const TextStyle(color: Colors.white),
                items: ['PS4', 'PS5'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _amenities['psConsole'] = v),
                decoration: InputDecoration(labelText: 'نوع الجهاز المتوفر', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _amenities['psRoomType'], dropdownColor: AppTheme.surfaceDark, style: const TextStyle(color: Colors.white),
                items: ['\u0639\u0627\u062f\u064a\u0629', 'VIP', '\u062e\u0627\u0635\u0629'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _amenities['psRoomType'] = v),
                decoration: InputDecoration(labelText: 'تصنيف الغرفة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ] else if (widget.venueCategory == '\u0628\u0627\u062f\u0644') ...[
              SwitchListTile(title: const Text('مغطى (Indoor)؟', style: TextStyle(color: Colors.white)), value: _amenities['padelIndoor'], onChanged: (v) => setState(() => _amenities['padelIndoor'] = v)),
            ] else if (widget.venueCategory == '\u0628\u0644\u064a\u0627\u0631\u062f\u0648') ...[
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
              decoration: InputDecoration(labelText: 'السعر بالساعة (ج.م) لهذه الغرفة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl, maxLines: 2, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'ملاحظات إضافية للغرفة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImages, icon: const Icon(Icons.add_photo_alternate),
              label: Text('إضافة صور خاصة بهذه الغرفة (${_selectedImages.length})', style: const TextStyle(color: Colors.white)),
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
              child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('حفظ الغرفة', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
