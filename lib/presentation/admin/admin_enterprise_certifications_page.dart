// lib/presentation/admin/admin_enterprise_certifications_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/presentation/admin/providers/admin_certification_provider.dart';
import 'package:thix_id/services/admin_certification_service.dart';

class AdminEnterpriseCertificationsPage extends ConsumerStatefulWidget {
  const AdminEnterpriseCertificationsPage({super.key});

  @override
  ConsumerState<AdminEnterpriseCertificationsPage> createState() =>
      _AdminEnterpriseCertificationsPageState();
}

class _AdminEnterpriseCertificationsPageState
    extends ConsumerState<AdminEnterpriseCertificationsPage> {
  final Set<String> _busyUserIds = {};

  Future<void> _handleApprove(PendingEnterpriseCertification item) async {
    final notes = await _promptNotes(
      title: 'Approuver ${item.displayName ?? item.thixId ?? item.userId}',
      hint: 'Note interne (optionnel)',
    );
    if (notes == null) return; // annulé

    setState(() => _busyUserIds.add(item.userId));
    try {
      await ref.read(adminCertificationServiceProvider).approve(item.userId, notes: notes);
      if (!mounted) return;
      ref.invalidate(pendingEnterpriseCertificationsProvider);
      _toast('Compte Entreprise activé pour ${item.displayName ?? item.thixId ?? item.userId}');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busyUserIds.remove(item.userId));
    }
  }

  Future<void> _handleReject(PendingEnterpriseCertification item) async {
    final notes = await _promptNotes(
      title: 'Rejeter ${item.displayName ?? item.thixId ?? item.userId}',
      hint: 'Motif du rejet',
      required: true,
    );
    if (notes == null) return;

    setState(() => _busyUserIds.add(item.userId));
    try {
      await ref.read(adminCertificationServiceProvider).reject(item.userId, notes: notes);
      if (!mounted) return;
      ref.invalidate(pendingEnterpriseCertificationsProvider);
      _toast('Demande rejetée');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busyUserIds.remove(item.userId));
    }
  }

  Future<String?> _promptNotes({
    required String title,
    required String hint,
    bool required = false,
  }) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (required && text.isEmpty) return;
              Navigator.pop(ctx, text.isEmpty ? null : text);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? ThixPolicy.danger : ThixPolicy.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(pendingEnterpriseCertificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1B3A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Certifications Entreprise — à valider',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      body: asyncList.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune demande Entreprise en attente.',
                  style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingEnterpriseCertificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final item = items[i];
                final busy = _busyUserIds.contains(item.userId);
                return _RequestCard(
                  item: item,
                  busy: busy,
                  onApprove: () => _handleApprove(item),
                  onReject: () => _handleReject(item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final PendingEnterpriseCertification item;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.item,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final paidStr = item.paidAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(item.paidAt!.toLocal())
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF111827).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.business_center_rounded, color: Color(0xFF111827)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName ?? item.thixId ?? item.userId,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ThixPolicy.textMain),
                    ),
                    if (item.thixId != null)
                      Text(
                        item.thixId!,
                        style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PAYÉ',
                  style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoChip(label: 'Montant', value: '${item.amountUsd.toStringAsFixed(0)} USD'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoChip(label: 'Payé le', value: paidStr),
              ),
            ],
          ),
          if (item.reason != null && item.reason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Motif : ${item.reason}',
              style: const TextStyle(fontSize: 12.5, color: ThixPolicy.textSecondary, height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Rejeter', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Approuver', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
        ],
      ),
    );
  }
}
