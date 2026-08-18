// lib/presentation/thix_weeding/pages/staff/prestataires/vendor_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

final vendorDetailProvider = FutureProvider.family<Map<String,dynamic>, String>((ref, vendorId) async {
  return await Supabase.instance.client.from('thix_weeding_vendors').select().eq('id', vendorId).single();
});

final vendorExpensesProvider = FutureProvider.family<List<Map<String,dynamic>>, String>((ref, vendorId) async {
  final res = await Supabase.instance.client.from('thix_weeding_expenses').select().eq('vendor_id', vendorId);
  return List<Map<String,dynamic>>.from(res);
});

class VendorDetailPage extends ConsumerWidget {
  final String weddingId; final String vendorId;
  const VendorDetailPage({super.key, required this.weddingId, required this.vendorId});
  @override Widget build(BuildContext context, WidgetRef ref){
    final async = ref.watch(vendorDetailProvider(vendorId));
    final expAsync = ref.watch(vendorExpensesProvider(vendorId));
    return Scaffold(appBar: AppBar(title: const Text('Détail prestataire'), backgroundColor: Colors.white, actions: [
      IconButton(icon: const Icon(Icons.edit), onPressed: ()=> context.push('/thix-weeding/staff/$weddingId/prestataires/add?edit=$vendorId')),
      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
        await Supabase.instance.client.from('thix_weeding_vendors').delete().eq('id', vendorId);
        if(context.mounted) context.pop();
      }),
    ]), body: async.when(
      loading: ()=> const Center(child: CircularProgressIndicator()),
      error: (e,s)=> Center(child: Text('$e')),
      data: (v)=> ListView(padding: const EdgeInsets.all(20), children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.store, color: Color(0xFF0B3B8F))), const SizedBox(width:12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v['name'], style: const TextStyle(fontSize:20, fontWeight: FontWeight.w900)), Text('${v['category']} • ID: ${v['id']}', style: const TextStyle(fontSize:11, color: Colors.grey))]))]),
          const SizedBox(height:16),
          _Row(label:'Contact', value:v['contact_name']??'-'),
          _Row(label:'Téléphone', value:v['phone']??'-'),
          _Row(label:'Email', value:v['email']??'-'),
          _Row(label:'Prix convenu', value:'${v['price']??0} FCFA'),
          _Row(label:'Statut', value:v['status']),
          if(v['notes']!=null) Padding(padding: const EdgeInsets.only(top:8), child: Text(v['notes'])),
        ])),
        const SizedBox(height:16),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: (){}, icon: const Icon(Icons.phone), label: const Text('Appeler'))),
          const SizedBox(width:12),
          Expanded(child: FilledButton.icon(onPressed: () async {
            await Supabase.instance.client.from('thix_weeding_vendors').update({'status':'booked'}).eq('id', vendorId);
            ref.invalidate(vendorDetailProvider(vendorId));
          }, icon: const Icon(Icons.check), label: const Text('Confirmer'))),
        ]),
        const SizedBox(height:20),
        const Text('Dépenses liées', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height:8),
        expAsync.when(loading: ()=> const CircularProgressIndicator(), error: (e,s)=> Text('$e'), data: (exps){
          if(exps.isEmpty) return const Text('Aucune dépense', style: TextStyle(color: Colors.grey));
          return Column(children: exps.map((e)=> ListTile(title: Text(e['title']), subtitle: Text('${e['amount']} FCFA'), trailing: Icon(e['paid']?Icons.check_circle:Icons.pending, color: e['paid']?Colors.green:Colors.orange))).toList());
        }),
      ]),
    ));
  }
}
class _Row extends StatelessWidget{ final String label; final String value; const _Row({required this.label, required this.value}); @override Widget build(BuildContext context)=> Padding(padding: const EdgeInsets.only(bottom:8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize:12)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))])); }
