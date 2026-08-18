// lib/presentation/thix_money/pages/tontines_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tontine_provider.dart';
import '../utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TontinesPage extends ConsumerWidget {
  const TontinesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tontineProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      appBar: AppBar(title: const Text('Tontines')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _createTontine(context), label: const Text('Créer tontine'), icon: const Icon(Icons.add)),
      body: RefreshIndicator(onRefresh: () => ref.read(tontineProvider.notifier).refresh(), child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: state.items.length, itemBuilder: (_, i) {
        final t = state.items[i];
        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)), Text('${t.members}/${t.totalMembers}', style: const TextStyle(color: Colors.grey))]),
          const SizedBox(height: 8), LinearProgressIndicator(value: t.progress, color: Colors.green),
          const SizedBox(height: 8), Row(children: [Chip(label: Text('${t.cotisation} ${t.devise} / ${t.frequence}', style: const TextStyle(fontSize: 11))), const Spacer(), TextButton(onPressed: () {}, child: const Text('Contribuer'))]),
        ]));
      })),
    );
  }

  void _createTontine(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    showModalBottomSheet(context: ctx, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Nouvelle tontine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom tontine')),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
        final uid = Supabase.instance.client.auth.currentUser!.id;
        final thixId = (await Supabase.instance.client.from('profiles').select('thix_id').eq('id', uid).single())['thix_id'];
        await Supabase.instance.client.from('thix_tontines').insert({'thix_id': thixId, 'name': nameCtrl.text, 'members': 1, 'total_members': 10, 'cotisation': 50000, 'devise': 'CDF', 'frequence': 'mensuel'});
        Navigator.pop(ctx);
      }, style: ElevatedButton.styleFrom(backgroundColor: ThixConstants.primary), child: const Text('Créer', style: TextStyle(color: Colors.white)))),
      const SizedBox(height: 24),
    ])));
  }
}
