// lib/presentation/chat/escalation/screens/received_escalations_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/escalation_status.dart';
import '../models/escalation_step.dart';   // ← AJOUTER CETTE LIGNE
import '../providers/escalation_provider.dart';
import '../../chat_screen.dart';
import '../../../../services/chat/chat_service.dart';

class _C {
  static const bg = Colors.white;
  static const searchBg = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF1D4ED8);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const red = Color(0xFFEF4444);
}

final chatServiceProvider = Provider((ref) => ChatService(Supabase.instance.client));

class ReceivedEscalationsPage extends ConsumerStatefulWidget {
  const ReceivedEscalationsPage({super.key});

  @override
  ConsumerState<ReceivedEscalationsPage> createState() =>
      _ReceivedEscalationsPageState();
}

class _ReceivedEscalationsPageState
    extends ConsumerState<ReceivedEscalationsPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadData(refresh: true));

    _scroll.addListener(() {
      if (_scroll.position.pixels >
          _scroll.position.maxScrollExtent - 300) {
        _loadData(refresh: false);
      }
    });
  }

  /// Charge les escalades destinées à l'utilisateur courant (to_agent_id),
  /// et non plus par niveau (to_level). Aligné avec le badge du chat list.
  void _loadData({required bool refresh}) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    ref.read(escalationProvider.notifier).loadReceived(
          user.id,
          refresh: refresh,
        );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openConversation(String conversationId) async {
    try {
      final conv =
          await ref.read(chatServiceProvider).getConversation(conversationId);
      if (conv != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversationId,
              conversation: conv,
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation introuvable.'),
          backgroundColor: _C.textMain,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: _C.red),
      );
    }
  }

  Future<void> _accept(String id) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;

  EscalationStep? step;
  try {
    step = ref.read(escalationProvider).pending.firstWhere((s) => s.id == id);
  } catch (_) {
    step = null;
  }

  final ok = await ref.read(escalationProvider.notifier).accept(id, user.id);

  if (!mounted) return;

  if (ok != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Escalade acceptée'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
    final conversationId = step?.conversationId ?? ok.conversationId;
    if (conversationId.isNotEmpty) {
      await _openConversation(conversationId);
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur: ${ref.read(escalationProvider).error}'),
        backgroundColor: _C.red,
      ),
    );
  }
}

  Future<void> _reject(String id) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _C.border),
        ),
        title: const Text(
          'Refuser l\'escalade',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _C.textMain,
          ),
        ),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: _C.textMain, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Motif du refus...',
            filled: true,
            fillColor: _C.searchBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: _C.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Refuser',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await ref
        .read(escalationProvider.notifier)
        .reject(id, reasonController.text);

    if (!mounted) return;

    if (ok != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escalade refusée'),
          backgroundColor: _C.textMain,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${ref.read(escalationProvider).error}'),
          backgroundColor: _C.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(escalationProvider);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _C.border),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Escalades reçues',
          style: TextStyle(
            color: _C.textMain,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _C.textMuted),
            onPressed: () => _loadData(refresh: true),
          ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(EscalationState state) {
    if (state.isLoading && state.pending.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _C.primary, strokeWidth: 3),
      );
    }

    if (state.error != null && state.pending.isEmpty) {
      return Center(
        child: Text(
          'Erreur : ${state.error}',
          style: const TextStyle(color: _C.textMuted, fontSize: 14),
        ),
      );
    }

    if (state.pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _C.searchBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 48,
                color: _C.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune escalade reçue',
              style: TextStyle(
                color: _C.textMain,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _C.primary,
      backgroundColor: Colors.white,
      onRefresh: () async => _loadData(refresh: true),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        itemCount: state.pending.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.pending.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: _C.primary,
                  ),
                ),
              ),
            );
          }

          final step = state.pending[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openConversation(step.conversationId),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _C.searchBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: _C.border),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 16,
                            color: _C.textMuted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step.fromAgentName ?? 'Agent Inconnu',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _C.textMain,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: step.status.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: step.status.color.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            step.status.label,
                            style: TextStyle(
                              color: step.status.color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: _C.border),
                    ),
                    Text(
                      'Raison : ${step.reason}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: _C.textMain,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (step.comment != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Commentaire : ${step.comment}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _C.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Demandé le ${step.createdAt.toString().substring(0, 16)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _C.textMuted,
                      ),
                    ),
                    if (step.status == EscalationStatus.pending) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _reject(step.id),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text(
                              'Refuser',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _C.red,
                              side: const BorderSide(color: _C.border),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _accept(step.id),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text(
                              'Accepter',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _C.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
