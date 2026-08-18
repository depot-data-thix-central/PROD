// lib/presentation/thix_weeding/pages/staff/paiements/payments_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

class PaymentsPage extends ConsumerWidget {
  final String weddingId;
  const PaymentsPage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsProvider(weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Paiements'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card),
            onPressed: () =>
                context.push('/thix-weeding/staff/$weddingId/paiements/add'),
          ),
        ],
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erreur: $e')),
        data: (List<PaymentModel> pays) {
          final total = pays.fold<double>(0, (sum, e) => sum + e.amount);

          return Column(
            children: [
              _TotalCard(total: total, count: pays.length),
              Expanded(
                child: pays.isEmpty
                    ? const Center(child: Text('Aucun paiement'))
                    : _PaymentList(pays: pays, weddingId: weddingId),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/thix-weeding/staff/$weddingId/paiements/add'),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau paiement'),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  final int count;

  const _TotalCard({required this.total, required this.count});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.payments, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total payé',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  '$total FCFA',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '$count paiements',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
}

class _PaymentList extends ConsumerWidget {
  final List<PaymentModel> pays;
  final String weddingId;

  const _PaymentList({required this.pays, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(paymentsProvider(weddingId)),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: pays.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final PaymentModel p = pays[i];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: Icon(
                  p.status == 'completed'
                      ? Icons.check_circle
                      : Icons.pending,
                  color: p.status == 'completed'
                      ? Colors.green
                      : Colors.orange,
                ),
                title: Text(
                  '${p.amount} FCFA • ${p.vendorName ?? p.vendorId ?? p.expenseTitle ?? p.expenseId ?? 'Paiement'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  '${p.method} • Ref: ${p.referenceCode ?? '-'} • ID: ${p.id.substring(0, 6)}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(
                  p.status,
                  style: TextStyle(
                    fontSize: 10,
                    color: p.status == 'completed'
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => context.push(
                  '/thix-weeding/staff/\( weddingId/paiements/ \){p.id}',
                ),
              ),
            );
          },
        ),
      );
}
