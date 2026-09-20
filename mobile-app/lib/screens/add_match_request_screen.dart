import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_provider.dart';
import '../core/theme/app_theme.dart';

class AddMatchRequestScreen extends ConsumerStatefulWidget {
  const AddMatchRequestScreen({super.key});
  @override
  ConsumerState<AddMatchRequestScreen> createState() => _AddMatchRequestScreenState();
}

class _AddMatchRequestScreenState extends ConsumerState<AddMatchRequestScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _spotsCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0);
  bool _isLoading = false;

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.neonBlue, onPrimary: Colors.black, surface: AppTheme.surfaceDark),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
        builder: (context, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: AppTheme.neonBlue, onPrimary: Colors.black, surface: AppTheme.surfaceDark),
          ),
          child: child!,
        ),
      );
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          _selectedTime = time;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty || _spotsCtrl.text.isEmpty || _costCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء ملء جميع الحقول المطلوبة')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final payload = {
        'title': _titleCtrl.text,
        'description': _descCtrl.text,
        'matchTime': _selectedDate.toUtc().toIso8601String(),
        'missingSpots': int.parse(_spotsCtrl.text),
        'costPerSpot': double.parse(_costCtrl.text),
      };
      await ref.read(dioProvider).post('/match-requests', data: payload);
      ref.refresh(matchRequestsProvider.future);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء طلب المباراة بنجاح!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: \$e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء طلب ناقصني لاعب'),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('هل فريقك ناقص لاعبين؟ اكتب التفاصيل هنا وسيتمكن باقي اللاعبين من الانضمام لك.',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 24),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'عنوان الطلب',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true, fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'تفاصيل إضافية',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true, fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _spotsCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'عدد اللاعبين المطلوب',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true, fillColor: AppTheme.surfaceDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _costCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'تكلفة الفرد (ج.م)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true, fillColor: AppTheme.surfaceDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.calendar_month, color: AppTheme.neonBlue),
              label: Text('موعد المباراة: \${_selectedDate.year}-\${_selectedDate.month}-\${_selectedDate.day}',
                style: const TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppTheme.neonBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                : const Text('نشر الطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
