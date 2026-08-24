// lib/presentation/thix_ia/providers/chat_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../services/ai_service.dart';
import 'thix_ia_provider.dart';
import 'active_project_provider.dart';

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

  /// Envoie un message utilisateur + appelle l'IA + enregistre la réponse
  Future<void> sendMessage(String content) async {
    final code = ref.read(activeProjectCodeProvider);
    if (code == null || content.trim().isEmpty) return;

    final client = ref.read(supabaseClientProvider);
    final aiService = ref.read(aiServiceProvider);

    // 1. Message utilisateur (optimistic)
    final userMsg = ChatMessage(
      id: 'temp_user_${DateTime.now().millisecondsSinceEpoch}',
      projectCode: code,
      role: ChatRole.user,
      content: content.trim(),
      createdAt: DateTime.now(),
    );

    final current = state.value ?? [];
    state = AsyncData([...current, userMsg]);

    try {
      // 2. Sauvegarde message utilisateur
      await client.from('chat_messages').insert(userMsg.toInsertJson());

      // 3. Appel à l'IA via Edge Function thix_ai
      final history = current
          .map((m) => {
                'role': m.role == ChatRole.user ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      final aiResponse = await aiService.chat(
        message: content.trim(),
        projectCode: code,
        history: history,
        provider: ThixAiProvider.auto,
      );

      String replyContent;
      if (aiResponse.success && (aiResponse.content?.isNotEmpty ?? false)) {
        replyContent = aiResponse.content!;
      } else {
        replyContent = aiResponse.error ?? "Désolé, je n'ai pas pu générer de réponse.";
      }

      // 4. Message IA
      final aiMsg = ChatMessage(
        id: 'temp_ai_${DateTime.now().millisecondsSinceEpoch}',
        projectCode: code,
        role: ChatRole.assistant,
        content: replyContent,
        createdAt: DateTime.now(),
      );

      // Optimistic update
      state = AsyncData([...current, userMsg, aiMsg]);

      // 5. Sauvegarde message IA
      await client.from('chat_messages').insert(aiMsg.toInsertJson());

      // 6. Rafraîchir depuis la base
      final fresh = await _fetchMessages(code);
      state = AsyncData(fresh);
    } catch (e) {
      // En cas d'erreur on revient à l'état précédent
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
