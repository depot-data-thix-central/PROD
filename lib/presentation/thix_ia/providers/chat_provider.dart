// lib/presentation/thix_ia/providers/chat_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'thix_ia_provider.dart';
import 'active_project_provider.dart';

/// ============================================================================
/// CHAT PROVIDER - Chat contextualisé avec mémoire projet §7
/// Table: chat_messages (Supabase) + RAG
/// ============================================================================

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.projectCode,
    required this.role, // user, assistant, system
    required this.content,
    this.sources = const [],
    this.createdAt,
  });

  final String id;
  final String projectCode;
  final String role;
  final String content;
  final List<String> sources;
  final DateTime? createdAt;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id']?? '',
        projectCode: json['project_code']?? '',
        role: json['role']?? 'user',
        content: json['content']?? '',
        sources: (json['sources'] as List?)?.map((e) => e.toString()).toList()?? [],
        createdAt: json['created_at']!= null? DateTime.tryParse(json['created_at']) : null,
      );

  Map<String, dynamic> toSupabase() => {
        'project_code': projectCode,
        'role': role,
        'content': content,
        'sources': sources,
      };

  @override
  List<Object?> get props => [id, role, content];
}

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
      role: 'user',
      content: content.trim(),
      createdAt: DateTime.now(),
    );

    // Optimistic
    final current = state.value?? [];
    state = AsyncData([...current, userMsg]);

    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('chat_messages').insert(userMsg.toSupabase());

      // Edge Function va générer la réponse assistant avec RAG + mémoire
      // Pour l'instant on attend realtime
      // await client.functions.invoke('thix-chat', body: {...})

      // Refresh après 1s pour récupérer réponse assistant (Phase 2 realtime)
      await Future.delayed(const Duration(seconds: 1));
      final fresh = await _fetchMessages(code);
      state = AsyncData(fresh);
    } catch (e) {
      // Rollback optimistic
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
  final messages = ref.watch(chatProvider).value?? [];
  return messages.isNotEmpty;
});
