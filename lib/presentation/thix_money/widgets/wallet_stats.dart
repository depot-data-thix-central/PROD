// lib/presentation/thix_money/widgets/wallet_stats.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/saving_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/tontine_provider.dart';
import '../utils/formatter.dart';

class WalletStats extends ConsumerWidget {
  const WalletStats({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savings = ref.watch(savingProvider);
    final loans = ref.watch(loanProvider);
    final tontines = ref.watch(tontineProvider);

    final epargneTotal = savings.items.fold<int>(0, (s, e) => s + e.amount);
    final creditTotal = loans.items.fold<int>(0, (s, e) => s + e.remaining);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(child: _StatCard(icon: Icons.savings_rounded, color: Colors.green, title: 'Épargne', value: ThixFormatter.formatCdf(epargneTotal), trend: true)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(icon: Icons.trending_up_rounded, color: Colors.purple, title: 'Invest', value: '${savings.items.length} actifs', trend: true)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(icon: Icons.credit_card_rounded, color: Colors.orange, title: 'Crédits', value: ThixFormatter.formatCdf(creditTotal), trend: false)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(icon: Icons.groups_rounded, color: Colors.blue, title: 'Tontines', value: '${tontines.items.length} actives', isAction: true)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon; final Color color; final String title; final String value; final bool trend; final bool isAction;
  const _StatCard({required this.icon, required this.color, required this.title, required this.value, this.trend = false, this.isAction = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (trend) Icon(Icons.show_chart, size: 16, color: color.withOpacity(0.7)),
        if (isAction) const Text('Voir >', style: TextStyle(fontSize: 10, color: Colors.blue)),
      ]),
    );
  }
}
