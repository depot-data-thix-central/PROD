// lib/presentation/thix_ia/providers/chat_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart'; 
import 'thix_ia_provider.dart';
import 'active_project_provider.dart'; // Garde-le s'il définit activeProjectCodeProvider

class ChatNotifier extends AsyncNotifier<List<ChatMessage>> {
  @override
  Future<List<ChatMessage>> build() async {
    final code = ref.watch(activeProjectCodeProvider);
    if (code == null) return [];
    return _fetchMessages(code);
  }

  Future<List<ChatMessage>> _fetchMessages(String projectCode) async {
    final client = ref.read(supabaseClientProvider);
    final res = await client
       .from('chat_messages')
       .select()
       .eq('project_code', projectCode)
       .order('created_at', ascending: true)
       .limit(100);
    return (res as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<void> sendMessage(String content) async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null || content.trim().isEmpty) return;

    final userMsg = ChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      projectCode: code,
      role: ChatRole.user, // <-- CORRECTION 1 : Enum ChatRole
      content: content.trim(),
      createdAt: DateTime.now(),
    );

    final current = state.value ?? [];
    state = AsyncData([...current, userMsg]);

    try {
      final client = ref.read(supabaseClientProvider);
      
      // <-- CORRECTION 2 : Utilisation de toInsertJson() qui existe dans ton modèle
      await client.from('chat_messages').insert(userMsg.toInsertJson());

      await Future.delayed(const Duration(seconds: 1));
      final fresh = await _fetchMessages(code);
      state = AsyncData(fresh);
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> clear() async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null) return;
    final client = ref.read(supabaseClientProvider);
    await client.from('chat_messages').delete().eq('project_code', code);
    state = const AsyncData([]);
  }
}

final chatProvider = AsyncNotifierProvider<ChatNotifier, List<ChatMessage>>(() {
  return ChatNotifier();
});

final chatHasMessagesProvider = Provider<bool>((ref) {
  final messages = ref.watch(chatProvider).value ?? [];
  return messages.isNotEmpty;
});
