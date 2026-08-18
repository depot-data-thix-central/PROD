// lib/presentation/chat/escalation/screens/escalation_history_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/escalation_provider.dart';
import '../widgets/level_badge.dart';
import '../widgets/priority_chip.dart';
import '../widgets/status_indicator.dart';
import '../../../chat/chat_screen.dart';
import '../../../../services/chat/chat_service.dart';

// Nouvelle palette "Grandeur Entreprise" (Thème Clair)
class _C {
  static const bg = Colors.white;
  static const searchBg = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFFEFF6FF);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const red = Color(0xFFEF4444);
}

class EscalationHistoryPage extends ConsumerStatefulWidget {
  final String conversationId;

  const EscalationHistoryPage({
    Key? key, 
    required this.conversationId
  }) : super(key: key);

  @override
  ConsumerState<EscalationHistoryPage> createState() => _EscalationHistoryPageState();
}

class _EscalationHistoryPageState extends ConsumerState<EscalationHistoryPage> {
  
  @override
  void initState() {
    super.initState();
    // Chargement automatique de l'historique lors de l'ouverture de la page
    Future.microtask(() {
      ref.read(escalationProvider.notifier).loadHistory(widget.conversationId);
    });
  }

  Future<void> _openConversation(String convId) async {
    try {
      final chatService = ChatService(Supabase.instance.client);
      final conv = await chatService.getConversation(convId);
      
      if (conv != null && mounted) {
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convId, 
              conversation: conv
            )
          )
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: _C.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Écoute de l'état global des escalades via Riverpod
    final escState = ref.watch(escalationProvider);
    final escNotifier = ref.read(escalationProvider.notifier);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1), 
          child: Divider(height: 1, color: _C.border)
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain), 
          onPressed: () => Navigator.pop(context)
        ),
        title: const Text(
          'Historique des escalades', 
          style: TextStyle(color: _C.textMain, fontSize: 16, fontWeight: FontWeight.bold)
        ),
      ),
      body: escState.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _C.primary, strokeWidth: 3)
            )
          : escState.history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: _C.searchBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history_rounded, size: 48, color: _C.textMuted),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune escalade pour cette conversation', 
                        style: TextStyle(color: _C.textMain, fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'L\'historique des transferts apparaîtra ici.', 
                        style: TextStyle(color: _C.textMuted, fontSize: 14)
                      )
                    ]
                  )
                )
              : RefreshIndicator(
                  color: _C.primary,
                  backgroundColor: Colors.white,
                  onRefresh: () => escNotifier.loadHistory(widget.conversationId),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: escState.history.length,
                    itemBuilder: (context, index) {
                      final step = escState.history[index];
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          borderRadius: BorderRadius.circular(16), 
                          border: Border.all(color: _C.border), 
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02), 
                              blurRadius: 10, 
                              offset: const Offset(0, 4)
                            )
                          ]
                        ),
                        child: InkWell(
                          onTap: () => _openConversation(step.conversationId),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                // Ligne du haut : Niveaux et Priorité
                                Row(
                                  children: [
                                    LevelBadge(level: step.fromLevel),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8), 
                                      child: Icon(Icons.arrow_forward_rounded, size: 16, color: _C.textMuted)
                                    ),
                                    LevelBadge(level: step.toLevel),
                                    const Spacer(),
                                    PriorityChip(priority: step.priority),
                                  ]
                                ),
                                
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12), 
                                  child: Divider(height: 1, color: _C.border)
                                ),
                                
                                // Raison principale
                                Text(
                                  step.reason, 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _C.textMain)
                                ),
                                
                                // Commentaire optionnel
                                if (step.comment != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _C.searchBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Commentaire : ${step.comment}', 
                                      style: const TextStyle(fontSize: 13, color: _C.textMuted, fontStyle: FontStyle.italic)
                                    ),
                                  ),
                                ],
                                
                                const SizedBox(height: 16),
                                
                                // Ligne du bas : Statut et Date
                                Row(
                                  children: [
                                    StatusIndicator(status: step.status), 
                                    const Spacer(), 
                                    Text(
                                      step.createdAt.toString().substring(0, 16), 
                                      style: const TextStyle(fontSize: 12, color: _C.textMuted, fontWeight: FontWeight.w500)
                                    )
                                  ]
                                ),
                                
                                // Date de résolution si applicable
                                if (step.resolvedAt != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Résolu le: ${step.resolvedAt!.toString().substring(0, 16)}', 
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)
                                      ),
                                    ],
                                  ),
                                ],
                              ]
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
