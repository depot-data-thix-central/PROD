// lib/presentation/thix_weeding/pages/staff/prestataires/vendors_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final vendorsListProvider = FutureProvider.family<List<Map<String,dynamic>>, String>((ref, weddingId) async {
  final res = await Supabase.instance.client.from('thix_weeding_vendors').select().eq('wedding_id', weddingId).order('created_at', ascending: false);
  return List<Map<String,dynamic>>.from(res);
});

class VendorsListPage extends ConsumerStatefulWidget {
  final String weddingId;
  const VendorsListPage({super.key, required this.weddingId});
  @override ConsumerState<VendorsListPage> createState() => _VendorsListPageState();
}

class _VendorsListPageState extends ConsumerState<VendorsListPage> {
  String _search = '';
  String _filterCat = 'all';
  @override Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsListProvider(widget.weddingId));
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Prestataires'), backgroundColor: Colors.white, actions: [
        IconButton(icon: const Icon(Icons.add_business), onPressed: () => context.push('/thix-weeding/staff/${widget.weddingId}/prestataires/add')),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v)=> setState(()=> _search=v), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Rechercher prestataire...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal:12), child: Row(children: [
          _Chip(label:'Tous', sel:_filterCat=='all', tap:()=>setState(()=>_filterCat='all')),
          _Chip(label:'Traiteur', sel:_filterCat=='Traiteur', tap:()=>setState(()=>_filterCat='Traiteur')),
          _Chip(label:'Photo', sel:_filterCat=='Photographe', tap:()=>setState(()=>_filterCat='Photographe')),
          _Chip(label:'DJ', sel:_filterCat=='DJ', tap:()=>setState(()=>_filterCat='DJ')),
          _Chip(label:'Décoration', sel:_filterCat=='Décoration', tap:()=>setState(()=>_filterCat='Décoration')),
        ])),
        Expanded(child: vendorsAsync.when(
          loading: ()=> const Center(child: CircularProgressIndicator()),
          error: (e,s)=> Center(child: Text('$e')),
          data: (vendors){
            var filtered = vendors.where((v){
              final matchSearch = v['name'].toString().toLowerCase().contains(_search.toLowerCase());
              final matchCat = _filterCat=='all' || v['category']==_filterCat;
              return matchSearch && matchCat;
            }).toList();
            if(filtered.isEmpty) return const Center(child: Text('Aucun prestataire'));
            return RefreshIndicator(onRefresh: () async => ref.invalidate(vendorsListProvider(widget.weddingId)), child: ListView.separated(padding: const EdgeInsets.all(12), itemCount: filtered.length, separatorBuilder: (_,__)=> const SizedBox(height:8), itemBuilder: (_,i){
              final v = filtered[i];
              return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: ListTile(
                leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.store, color: Color(0xFF0B3B8F))),
                title: Text(v['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${v['category']} • ${v['price']??0} FCFA • ID: ${v['id'].toString().substring(0,6)}'),
                trailing: _Status(status: v['status']),
                onTap: ()=> context.push('/thix-weeding/staff/${widget.weddingId}/prestataires/${v['id']}'),
              ));
            }));
          },
        )),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: ()=> context.push('/thix-weeding/staff/${widget.weddingId}/prestataires/add'), icon: const Icon(Icons.add), label: const Text('Ajouter')),
    );
  }
}
class _Chip extends StatelessWidget{ final String label; final bool sel; final VoidCallback tap; const _Chip({required this.label, required this.sel, required this.tap}); @override Widget build(BuildContext context)=> Padding(padding: const EdgeInsets.only(right:8), child: ChoiceChip(label: Text(label), selected: sel, onSelected: (_)=> tap())); }
class _Status extends StatelessWidget{ final String status; const _Status({required this.status}); @override Widget build(BuildContext context){ Color c = status=='booked'?Colors.green:status=='paid'?Colors.blue:status=='cancelled'?Colors.red:Colors.orange; return Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:4), decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(status, style: TextStyle(color: c, fontSize:10, fontWeight: FontWeight.bold))); } }
