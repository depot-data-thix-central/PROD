// lib/presentation/thix_money/pages/savings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/saving_provider.dart';
import '../utils/formatter.dart';
import '../utils/constants.dart';

class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(savingProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      appBar: AppBar(title: const Text('Épargne'), backgroundColor: Colors.white),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showCreateSheet(context), label: const Text('Nouvelle épargne'), icon: const Icon(Icons.add)),
      body: RefreshIndicator(onRefresh: () => ref.read(savingProvider.notifier).refresh(), child: state.isLoading && state.items.isEmpty? const Center(child: CircularProgressIndicator()) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: state.items.length, itemBuilder: (_, i) {
        final s = state.items[i];
        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text('${(s.progress*100).toInt()}%', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)))]),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: s.progress, backgroundColor: Colors.grey.shade200, color: ThixConstants.primary, minHeight: 8),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(ThixFormatter.formatAmount(s.amount, s.devise), style: const TextStyle(fontWeight: FontWeight.bold)), Text('Objectif: ${ThixFormatter.formatAmount(s.goal, s.devise)}', style: const TextStyle(color: Colors.grey, fontSize: 12))]),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Retirer'))), const SizedBox(width: 8), Expanded(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: ThixConstants.primary), child: const Text('Ajouter', style: TextStyle(color: Colors.white))))]),
        ]));
      })),
    );
  }

  void _showCreateSheet(BuildContext ctx) {
    final titleCtrl = TextEditingController(); final goalCtrl = TextEditingController();
    showModalBottomSheet(context: ctx, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Nouvelle épargne', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Nom (ex: Maison)')),
      TextField(controller: goalCtrl, decoration: const InputDecoration(labelText: 'Objectif CDF'), keyboardType: TextInputType.number),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
        final thixId = (await Supabase.instance.client.from('profiles').select('thix_id').eq('id', Supabase.instance.client.auth.currentUser!.id).single())['thix_id'];
        await Supabase.instance.client.from('thix_savings').insert({'thix_id': thixId, 'title': titleCtrl.text, 'goal': int.parse(goalCtrl.text), 'amount': 0, 'devise': 'CDF'});
        Navigator.pop(ctx);
      }, child: const Text('Créer'))),
      const SizedBox(height: 24),
    ])));
  }
}
