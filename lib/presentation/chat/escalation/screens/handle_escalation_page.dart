// lib/presentation/chat/escalation/screens/handle_escalation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/escalation_level.dart';
import '../models/escalation_step.dart';
import '../models/escalation_status.dart';
import '../providers/escalation_provider.dart';
import '../widgets/level_badge.dart';
import '../widgets/priority_chip.dart';
import '../widgets/status_indicator.dart';

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

class HandleEscalationPage extends ConsumerStatefulWidget {
  final String escalationId;
  final String agentId;

  const HandleEscalationPage({
    super.key, 
    required this.escalationId, 
    required this.agentId
  });

  @override 
  ConsumerState<HandleEscalationPage> createState() => _HandleEscalationPageState();
}

class _HandleEscalationPageState extends ConsumerState<HandleEscalationPage> {
  final _rejectReasonController = TextEditingController();
  bool _showRejectReason = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadData());
  }

  Future<void> _loadData() async {
    // CORRECTION : Appel de loadPending au lieu de loadPendingEscalations
    await ref.read(escalationProvider.notifier).loadPending(widget.agentId, EscalationLevel.senior);
  }

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final escState = ref.watch(escalationProvider);
    final escNotifier = ref.read(escalationProvider.notifier);

    EscalationStep? escalation;
    try {
      // CORRECTION : pending au lieu de pendingEscalations
      escalation = escState.pending.firstWhere((e) => e.id == widget.escalationId);
    } catch (_) {
      escalation = null;
    }

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        surfaceTintColor: _C.bg,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1), 
          child: Divider(height: 1, color: _C.border)
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain), 
          onPressed: () => context.pop()
        ),
        title: const Text(
          'Gérer l\'escalade', 
          style: TextStyle(color: _C.textMain, fontSize: 16, fontWeight: FontWeight.bold)
        ),
      ),
      body: escalation == null
          ? const Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 3))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _C.bg, 
                      borderRadius: BorderRadius.circular(16), 
                      border: Border.all(color: _C.border),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    child: Row(
                      children: [
                        LevelBadge(level: escalation.toLevel),
                        const SizedBox(width: 8),
                        PriorityChip(priority: escalation.priority),
                        const Spacer(),
                        StatusIndicator(status: escalation.status),
                      ]
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _C.searchBg, 
                      borderRadius: BorderRadius.circular(16), 
                      border: Border.all(color: _C.border)
                    ),
                    child: Column(
                      children: [
                        _infoRow('De', escalation.fromAgentName ?? escalation.fromAgentId),
                        const Divider(color: _C.border, height: 16),
                        _infoRow('À', escalation.toAgentName ?? escalation.toAgentId),
                        const Divider(color: _C.border, height: 16),
                        _infoRow('Raison', escalation.reason),
                        if (escalation.comment != null) ...[
                          const Divider(color: _C.border, height: 16),
                          _infoRow('Commentaire', escalation.comment!),
                        ],
                        const Divider(color: _C.border, height: 16),
                        _infoRow('Date', escalation.createdAt.toString().substring(0, 16)),
                      ]
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  if (escalation.status == EscalationStatus.pending) ...[
                    const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _C.textMain)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: escState.isLoading ? null : () => _accept(escNotifier),
                            icon: escState.isLoading 
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                : const Icon(Icons.check_rounded, size: 20),
                            label: const Text('Accepter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _C.primary, 
                              foregroundColor: Colors.white, 
                              elevation: 0, 
                              padding: const EdgeInsets.symmetric(vertical: 16), 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: escState.isLoading ? null : () => setState(() => _showRejectReason = !_showRejectReason),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            label: const Text('Refuser', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _C.red, 
                              side: const BorderSide(color: _C.border), 
                              padding: const EdgeInsets.symmetric(vertical: 16), 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                          ),
                        ),
                      ]
                    ),
                    
                    if (_showRejectReason) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _rejectReasonController,
                        style: const TextStyle(color: _C.textMain, fontSize: 14),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Veuillez préciser le motif du refus...', 
                          hintStyle: const TextStyle(color: _C.textMuted),
                          filled: true, 
                          fillColor: _C.searchBg, 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.border)), 
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.border)), 
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.red, width: 1.5))
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity, 
                        child: ElevatedButton(
                          onPressed: escState.isLoading ? null : () => _reject(escNotifier), 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _C.red, 
                            foregroundColor: Colors.white, 
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ), 
                          child: const Text('Confirmer le refus', style: TextStyle(fontWeight: FontWeight.bold))
                        )
                      ),
                    ],
                  ],
                  
                  if (escalation.status == EscalationStatus.accepted) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5), 
                        borderRadius: BorderRadius.circular(12), 
                        border: Border.all(color: const Color(0xFFA7F3D0))
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24), 
                          SizedBox(width: 12), 
                          Expanded(
                            child: Text(
                              'Escalade acceptée. Vous pouvez maintenant traiter la conversation et résoudre le cas.', 
                              style: TextStyle(color: Color(0xFF166534), fontSize: 14, fontWeight: FontWeight.w500)
                            )
                          )
                        ]
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: escState.isLoading ? null : () => _resolve(escNotifier),
                        icon: escState.isLoading 
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                            : const Icon(Icons.done_all_rounded, size: 20),
                        label: const Text('Marquer comme résolu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.primary, 
                          foregroundColor: Colors.white, 
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                      ),
                    ),
                  ],
                  
                  if (escalation.status == EscalationStatus.resolved)
                    Container(
                      padding: const EdgeInsets.all(16), 
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5), 
                        borderRadius: BorderRadius.circular(12), 
                        border: Border.all(color: const Color(0xFFA7F3D0))
                      ), 
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24), 
                          SizedBox(width: 12), 
                          Text('Cette escalade est résolue.', style: TextStyle(color: Color(0xFF166534), fontSize: 14, fontWeight: FontWeight.bold))
                        ]
                      )
                    ),
                    
                  if (escalation.status == EscalationStatus.rejected)
                    Container(
                      padding: const EdgeInsets.all(16), 
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2), 
                        borderRadius: BorderRadius.circular(12), 
                        border: Border.all(color: const Color(0xFFFECACA))
                      ), 
                      child: const Row(
                        children: [
                          Icon(Icons.cancel_rounded, color: _C.red, size: 24), 
                          SizedBox(width: 12), 
                          Text('Cette escalade a été refusée.', style: TextStyle(color: _C.red, fontSize: 14, fontWeight: FontWeight.bold))
                        ]
                      )
                    ),
                    
                  const SizedBox(height: 24),
                  
                  if (escState.error != null) 
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _C.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: _C.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Erreur: ${escState.error}', style: const TextStyle(color: _C.red, fontSize: 13, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                ]
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          SizedBox(
            width: 100, 
            child: Text(
              label, 
              style: const TextStyle(fontWeight: FontWeight.w600, color: _C.textMuted, fontSize: 13)
            )
          ),
          Expanded(
            child: Text(
              value, 
              style: const TextStyle(color: _C.textMain, fontSize: 14, fontWeight: FontWeight.w500)
            )
          ),
        ]
      ),
    );
  }

  void _accept(EscalationNotifier notifier) async {
    // CORRECTION : accept() au lieu de acceptEscalation()
    final success = await notifier.accept(widget.escalationId, widget.agentId);
    if (!mounted) return;
    if (success != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escalade acceptée avec succès'), backgroundColor: Color(0xFF16A34A)));
    } else {
      final error = ref.read(escalationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $error'), backgroundColor: _C.red));
    }
  }

  void _reject(EscalationNotifier notifier) async {
    if (_rejectReasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez indiquer un motif de refus'), backgroundColor: _C.red));
      return;
    }
    // CORRECTION : reject() au lieu de rejectEscalation()
    final success = await notifier.reject(widget.escalationId, _rejectReasonController.text);
    if (!mounted) return;
    if (success != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escalade refusée'), backgroundColor: _C.textMain));
      context.pop();
    } else {
      final error = ref.read(escalationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $error'), backgroundColor: _C.red));
    }
  }

  void _resolve(EscalationNotifier notifier) async {
    // CORRECTION : resolve() au lieu de resolveEscalation()
    final success = await notifier.resolve(widget.escalationId);
    if (!mounted) return;
    if (success != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escalade marquée comme résolue'), backgroundColor: Color(0xFF16A34A)));
      context.pop();
    } else {
      final error = ref.read(escalationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $error'), backgroundColor: _C.red));
    }
  }
}
