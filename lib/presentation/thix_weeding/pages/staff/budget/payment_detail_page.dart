// lib/presentation/thix_weeding/pages/staff/budget/payment_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// TES 3 FICHIERS CENTRAUX
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

// Provider typé pour un seul expense
final expenseDetailProvider = FutureProvider.family<ExpenseModel, String>((ref, expenseId) async {
  final data = await Supabase.instance.client.from('thix_weeding_expenses').select().eq('id', expenseId).single();
  return ExpenseModel.fromJson(data);
});

class PaymentDetailPage extends ConsumerWidget {
  final String weddingId;
  final String expenseId;
  const PaymentDetailPage({super.key, required this.weddingId, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));
    final vendorsAsync = ref.watch(vendorsProvider(weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Détail paiement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/thix-weeding/staff/$weddingId/budget/add?edit=$expenseId'),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: expenseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erreur: $e')),
        data: (ExpenseModel expense) {
          // Resolve vendor name depuis ton provider central
          final vendorName = vendorsAsync.maybeWhen(
            data: (vendors) {
              final match = vendors.where((v) => v.id == expense.vendorId);
              return match.isEmpty ? 'Aucun' : match.first.name;
            },
            orElse: () => 'Aucun',
          );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // HEADER CARD
              _MainCard(expense: expense, vendorName: vendorName),

              const SizedBox(height: 16),

              // INFOS CARD
              _InfoCard(expense: expense, vendorName: vendorName),

              const SizedBox(height: 24),

              // ACTION
              _ActionButton(expense: expense, onMarkedPaid: () => _markAsPaid(context, ref)),
            ],
          );
        },
      ),
    );
  }

  // ================= ACTIONS =================

  Future<void> _markAsPaid(BuildContext context, WidgetRef ref) async {
    try {
      await Supabase.instance.client
          .from('thix_weeding_expenses')
          .update({'is_paid': true, 'paid_at': DateTime.now().toIso8601String()})
          .eq('id', expenseId);

      ref.invalidate(expenseDetailProvider(expenseId));
      ref.invalidate(expensesProvider(weddingId));
      ref.invalidate(budgetProvider(weddingId));
      ref.invalidate(paymentsSummaryProvider(weddingId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marqué comme payé')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: const Text('Cette dépense sera supprimée définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(budgetServiceProvider).deleteExpense(expenseId);
      ref.invalidate(expensesProvider(weddingId));
      ref.invalidate(budgetProvider(weddingId));
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }
}

// ================= WIDGETS INTERNES - Pour bonne lecture =================

class _MainCard extends StatelessWidget {
  final ExpenseModel expense;
  final String vendorName;
  const _MainCard({required this.expense, required this.vendorName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: expense.isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(expense.isPaid ? Icons.check_circle : Icons.pending, color: expense.isPaid ? Colors.green : Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    Text('ID: ${expense.id.substring(0, 8)} • $vendorName', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('${expense.amount.toInt()} FCFA', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: expense.isPaid ? Colors.green : const Color(0xFF0B3B8F))),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final ExpenseModel expense;
  final String vendorName;
  const _InfoCard({required this.expense, required this.vendorName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _RowInfo(label: 'Montant', value: '${expense.amount.toInt()} FCFA'),
          _RowInfo(label: 'Prestataire', value: vendorName),
          _RowInfo(label: 'Catégorie', value: expense.category),
          _RowInfo(label: 'Statut', value: expense.isPaid ? 'Payé' : 'Impayé', valueColor: expense.isPaid ? Colors.green : Colors.orange),
          _RowInfo(label: 'Créé le', value: expense.createdAt.toString().substring(0, 16)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onMarkedPaid;
  const _ActionButton({required this.expense, required this.onMarkedPaid});

  @override
  Widget build(BuildContext context) {
    if (expense.isPaid) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.verified, color: Colors.green), SizedBox(width: 8), Text('Déjà payé', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]),
      );
    }
    return FilledButton.icon(
      onPressed: onMarkedPaid,
      icon: const Icon(Icons.check),
      label: const Text('Marquer comme payé'),
      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.green),
    );
  }
}

class _RowInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _RowInfo({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: valueColor)),
          ],
        ),
      );
}
