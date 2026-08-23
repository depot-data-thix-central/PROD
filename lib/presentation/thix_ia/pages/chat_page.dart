// lib/presentation/thix_ia/pages/chat_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/chat_provider.dart';

// 1. On importe explicitement le modèle officiel
import '../models/chat_message.dart'; 
// 2. On importe le widget qui affiche le message
import '../widgets/chat_message.dart'; 

// 3. On importe le widget d'input. 
// (Si le fichier s'appelle chat_input.dart au lieu de chat_input_widget.dart, modifie juste cette ligne)
import '../widgets/chat_input_widget.dart'; 

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.projectCode, this.initialMessage});
  final String projectCode;
  final String? initialMessage;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(chatProvider.notifier).build();
      if (widget.initialMessage != null) {
        ref.read(chatProvider.notifier).sendMessage(widget.initialMessage!);
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent, 
          duration: const Duration(milliseconds: 300), 
          curve: Curves.easeOut
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatProvider);
    final messages = messagesAsync.value ?? [];

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text('Chat THIX IA', style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold)), 
            Text(widget.projectCode, style: ThixPolicy.microStyle.copyWith(fontFamily: 'monospace'))
          ]
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded), 
            onPressed: () => ref.read(chatProvider.notifier).clear()
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur $e')),
              data: (_) {
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 48, color: ThixPolicy.primary.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text('Parlez à THIX IA', style: ThixPolicy.h3Style),
                          const SizedBox(height: 8),
                          Text(
                            'Posez des questions sur votre projet. THIX IA utilise votre mémoire, analyses et documents.', 
                            style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary), 
                            textAlign: TextAlign.center
                          ),
                        ]
                      ),
                    ),
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => ChatMessageWidget(message: messages[i]),
                );
              },
            ),
          ),
          ChatInputWidget(
            onSend: (text) {
              ref.read(chatProvider.notifier).sendMessage(text);
              _scrollToBottom();
            },
          ),
        ],
      ),
    );
  }
}
