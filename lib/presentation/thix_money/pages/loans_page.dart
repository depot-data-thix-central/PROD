// lib/presentation/thix_money/pages/loans_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/loan_provider.dart';
import '../utils/formatter.dart';
import '../utils/constants.dart';

class LoansPage extends ConsumerWidget {
  const LoansPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loanProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      appBar: AppBar(title: const Text('Crédits')),
      body: Column(children: [
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [ThixConstants.darkBlue, ThixConstants.primary]), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Capacité d\'emprunt', style: TextStyle(color: Colors.white70)), const SizedBox(height: 8), const Text('Jusqu\'à 2 500 000 FC', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _showLoanRequest(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.white), child: const Text('Demander un crédit', style: TextStyle(color: ThixConstants.primary, fontWeight: FontWeight.bold)))),
        ])),
        Expanded(child: state.isLoading && state.items.isEmpty? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: state.items.length, itemBuilder: (_, i) {
          final l = state.items[i];
          return Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(ThixFormatter.formatAmount(l.amount, l.devise), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: l.statut == 'en_cours'? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text(l.statut, style: TextStyle(color: l.statut == 'en_cours'? Colors.orange : Colors.green, fontSize: 11, fontWeight: FontWeight.bold)))]),
            const SizedBox(height: 10), LinearProgressIndicator(value: l.progress, color: Colors.green), const SizedBox(height: 6), Text('Restant: ${ThixFormatter.formatAmount(l.remaining, l.devise)} • ${l.interestRate}%/mois', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]));
        })),
      ]),
    );
  }

  void _showLoanRequest(BuildContext ctx) {
    showModalBottomSheet(context: ctx, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Demande de crédit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 12), TextField(decoration: InputDecoration(labelText: 'Montant souhaité', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number),
      const SizedBox(height: 12), const Text('Analyse IA de votre score THIX en cours... Éligibilité vérifiée par thix_id.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: ThixConstants.primary), child: const Text('Soumettre', style: TextStyle(color: Colors.white)))),
    ])));
  }
}
