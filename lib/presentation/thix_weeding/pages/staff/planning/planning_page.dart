// lib/presentation/thix_weeding/pages/staff/planning/planning_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final planningProvider = FutureProvider.family<List<Map<String,dynamic>>, String>((ref, weddingId) async {
  final res = await Supabase.instance.client.from('thix_weeding_planning').select().eq('wedding_id', weddingId).order('date', ascending: true);
  return List<Map<String,dynamic>>.from(res);
});

class PlanningPage extends ConsumerStatefulWidget {
  final String weddingId;
  const PlanningPage({super.key, required this.weddingId});
  @override ConsumerState<PlanningPage> createState()=> _PlanningPageState();
}

class _PlanningPageState extends ConsumerState<PlanningPage> {
  String _filter = 'all';
  @override Widget build(BuildContext context){
    final async = ref.watch(planningProvider(widget.weddingId));
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Planning'), backgroundColor: Colors.white, actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: ()=> context.push('/thix-weeding/staff/${widget.weddingId}/planning/add')),
      ]),
      body: async.when(
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,s)=> Center(child: Text('$e')),
        data: (tasks){
          var filtered = tasks.where((t){
            if(_filter=='all') return true;
            return t['status']==_filter;
          }).toList();
          if(filtered.isEmpty) return const Center(child: Text('Aucune tâche planifiée'));
          // Group by date
          Map<String, List<Map<String,dynamic>>> grouped = {};
          for(var t in filtered){
            final date = t['date'] as String;
            grouped.putIfAbsent(date, ()=> []).add(t);
          }
          return Column(children: [
            SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(12), child: Row(children: [
              _Chip(label:'Toutes', sel:_filter=='all', tap:()=>setState(()=>_filter='all')),
              _Chip(label:'À faire', sel:_filter=='todo', tap:()=>setState(()=>_filter='todo')),
              _Chip(label:'En cours', sel:_filter=='in_progress', tap:()=>setState(()=>_filter='in_progress')),
              _Chip(label:'Terminées', sel:_filter=='done', tap:()=>setState(()=>_filter='done')),
            ])),
            Expanded(child: RefreshIndicator(onRefresh: () async => ref.invalidate(planningProvider(widget.weddingId)), child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: grouped.keys.length, itemBuilder: (_,i){
              final date = grouped.keys.elementAt(i);
              final dayTasks = grouped[date]!;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:6), decoration: BoxDecoration(color: const Color(0xFF0B3B8F), borderRadius: BorderRadius.circular(20)), child: Text(date, style: const TextStyle(color: Colors.white, fontSize:12, fontWeight: FontWeight.bold))),
                const SizedBox(height:8),
               ...dayTasks.map((t)=> Container(margin: const EdgeInsets.only(bottom:8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border(left: BorderSide(color: t['priority']=='high'?Colors.red:t['priority']=='medium'?Colors.orange:Colors.green, width:4))), child: ListTile(
                  leading: IconButton(icon: Icon(t['status']=='done'?Icons.check_circle:Icons.circle_outlined, color: t['status']=='done'?Colors.green:Colors.grey), onPressed: () async {
                    final newStatus = t['status']=='done'?'todo':'done';
                    await Supabase.instance.client.from('thix_weeding_planning').update({'status': newStatus}).eq('id', t['id']);
                    ref.invalidate(planningProvider(widget.weddingId));
                  }),
                  title: Text(t['title'], style: TextStyle(decoration: t['status']=='done'?TextDecoration.lineThrough:null, fontWeight: FontWeight.bold)),
                  subtitle: Text('${t['time']??''} ${t['location']??''} • ID: ${t['id'].toString().substring(0,6)}'),
                  trailing: PopupMenuButton(onSelected: (v) async {
                    if(v=='edit') context.push('/thix-weeding/staff/${widget.weddingId}/planning/add?edit=${t['id']}');
                    if(v=='delete'){ await Supabase.instance.client.from('thix_weeding_planning').delete().eq('id', t['id']); ref.invalidate(planningProvider(widget.weddingId)); }
                  }, itemBuilder: (_)=> [const PopupMenuItem(value:'edit', child:Text('Modifier')), const PopupMenuItem(value:'delete', child:Text('Supprimer'))]),
                  onTap: ()=> context.push('/thix-weeding/staff/${widget.weddingId}/planning/add?edit=${t['id']}'),
                ))),
                const SizedBox(height:12),
              ]);
            }))),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: ()=> context.push('/thix-weeding/staff/${widget.weddingId}/planning/add'), icon: const Icon(Icons.add), label: const Text('Tâche')),
    );
  }
}
class _Chip extends StatelessWidget{ final String label; final bool sel; final VoidCallback tap; const _Chip({required this.label, required this.sel, required this.tap}); @override Widget build(BuildContext context)=> Padding(padding: const EdgeInsets.only(right:8), child: ChoiceChip(label: Text(label), selected: sel, onSelected: (_)=> tap())); }
