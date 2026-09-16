import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_provider.dart';

class ChatSheet extends ConsumerStatefulWidget {
  const ChatSheet({super.key});

  @override
  ConsumerState<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<ChatSheet> {
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'content': 'أهلاً بك! أنا مساعد PitchUp الذكي المدعوم بـ Astra. كيف يمكنني مساعدتك في العثور على ملعب اليوم؟'}
  ];
  bool _isLoading = false;

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    
    final userMessage = _controller.text;
    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
      _isLoading = true;
      _controller.clear();
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/ai-assistant', data: {'message': userMessage});
      
      setState(() {
        _messages.add({'role': 'ai', 'content': response.data['reply']});
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'content': 'حدث خطأ في الاتصال بالمساعد الذكي.'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('مساعدك الذكي من Astra 🤖', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.green.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(msg['content'] ?? ''),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن ملعب...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: _sendMessage,
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
