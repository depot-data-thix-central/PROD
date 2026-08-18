// lib/presentation/thix_weeding/pages/staff/paiements/payment_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

class PaymentDetailPage extends ConsumerWidget {
  final String weddingId;
  final String paymentId;

  const PaymentDetailPage({
    super.key,
    required this.weddingId,
    required this.paymentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentAsync = ref.watch(paymentDetailProvider(paymentId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Détail paiement'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: paymentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erreur: $e')),
        data: (PaymentModel p) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _AmountCard(payment: p),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: p.status == 'completed'
                  ? null
                  : () => _markCompleted(context, ref),
              icon: const Icon(Icons.check),
              label: Text(
                p.status == 'completed'
                    ? 'Déjà complété'
                    : 'Marquer comme complété',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await Supabase.instance.client
        .from('thix_weeding_payments')
        .delete()
        .eq('id', paymentId);
    ref.invalidate(paymentsProvider(weddingId));
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _markCompleted(BuildContext context, WidgetRef ref) async {
    await Supabase.instance.client
        .from('thix_weeding_payments')
        .update({'status': 'completed'})
        .eq('id', paymentId);
    ref.invalidate(paymentDetailProvider(paymentId));
    ref.invalidate(paymentsProvider(weddingId));
  }
}

class _AmountCard extends StatelessWidget {
  final PaymentModel payment;

  const _AmountCard({required this.payment});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${payment.amount} FCFA',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _Row(label: 'ID', value: '${payment.id.substring(0, 8)}...'),
            _Row(label: 'Méthode', value: payment.method),
            _Row(label: 'Statut', value: payment.status),
            _Row(
              label: 'Référence',
              value: payment.referenceCode ?? '-',
            ),
            _Row(
              label: 'Prestataire',
              value: payment.vendorName ?? payment.vendorId ?? '-',
            ),
            _Row(
              label: 'Dépense liée',
              value: payment.expenseTitle ?? payment.expenseId ?? '-',
            ),
            _Row(
              label: 'Date',
              value: payment.createdAt.toString().substring(0, 16),
            ),
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
}
