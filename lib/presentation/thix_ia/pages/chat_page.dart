// lib/presentation/thix_ia/pages/chat_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart'; 
import '../widgets/chat_message.dart';

// ON A SUPPRIMÉ L'IMPORT QUI N'EXISTAIT PAS ICI

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
                            'Posez des questions sur votre projet.', 
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
          // Utilisation du widget défini juste en bas
          ChatInput(
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

// ────────────────────────────────────────────────────────────────────────────
// WIDGET CHAT INPUT DE SECOURS INTÉGRÉ DIRECTEMENT ICI
// ────────────────────────────────────────────────────────────────────────────
class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  const ChatInput({super.key, required this.onSend});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Écrivez votre message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: ThixPolicy.surfaceStrong,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    widget.onSend(val.trim());
                    _controller.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: ThixPolicy.primary,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: () {
                  if (_controller.text.trim().isNotEmpty) {
                    widget.onSend(_controller.text.trim());
                    _controller.clear();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
