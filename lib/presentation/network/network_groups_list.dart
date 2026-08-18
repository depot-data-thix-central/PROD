import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/network_community.dart';

class NetworkGroupsList extends ConsumerStatefulWidget {
  const NetworkGroupsList({super.key});
  @override ConsumerState<NetworkGroupsList> createState() => _NetworkGroupsListState();
}

class _NetworkGroupsListState extends ConsumerState<NetworkGroupsList> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<NetworkCommunity> _my = [], _sugg = [];
  bool _loading = true;
  final _blue = Color(0xFF2B5CFF), _dark = Color(0xFF1A1A2E), _gold = Color(0xFFD4AF37);

  @override void initState(){ super.initState(); _tab=TabController(length: 2, vsync: this); _load(); }
  @override void dispose(){ _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(()=> _loading=true);
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if(uid==null) return;
    try{
      final myRes = await supa.from('community_members').select('communities!inner(*)').eq('user_id', uid);
      final suggRes = await supa.from('communities').select().limit(20);
      final myIds = (myRes as List).map((e)=> (e['communities'] as Map)['id'] as String).toSet();
      if(mounted) setState((){
        _my = (myRes as List).map((e)=> NetworkCommunity.fromJson(e['communities'] as Map<String,dynamic>)).toList();
        _sugg = (suggRes as List).map((e)=> NetworkCommunity.fromJson(e as Map<String,dynamic>)).where((g)=>!myIds.contains(g.id)).toList();
        _loading=false;
      });
    }catch(e){ if(mounted) setState(()=> _loading=false); }
  }

  Future<void> _toggle(NetworkCommunity g, bool isMember) async {
    setState((){
      if(isMember){ _my.removeWhere((x)=> x.id==g.id); _sugg.insert(0,g); }
      else { _sugg.removeWhere((x)=> x.id==g.id); _my.insert(0,g); }
    });
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser!.id;
    try{
      if(isMember) await supa.from('community_members').delete().eq('community_id', g.id).eq('user_id', uid);
      else await supa.from('community_members').insert({'community_id': g.id, 'user_id': uid});
    }catch(e){
      // rollback
      if(mounted) setState((){
        if(isMember){ _sugg.removeWhere((x)=> x.id==g.id); _my.insert(0,g); }
        else { _my.removeWhere((x)=> x.id==g.id); _sugg.insert(0,g); }
      });
    }
  }

  void _createDialog(){
    final nameC = TextEditingController(); final descC = TextEditingController();
    bool creating=false;
    showDialog(context: context, builder: (dCtx)=> StatefulBuilder(builder: (c,setD){
      return AlertDialog(title: Text('Créer un groupe', style: TextStyle(fontWeight: FontWeight.bold)), content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: InputDecoration(hintText: 'Nom', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        SizedBox(height: 12),
        TextField(controller: descC, maxLines: 3, decoration: InputDecoration(hintText: 'Description', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
      ]), actions: [
        if(!creating) TextButton(onPressed: ()=> Navigator.pop(dCtx), child: Text('Annuler')),
        ElevatedButton(onPressed: creating? null : () async {
          if(nameC.text.trim().isEmpty) return;
          setD(()=> creating=true);
          final supa = Supabase.instance.client;
          try{
            final res = await supa.from('communities').insert({'name': nameC.text.trim(), 'description': descC.text.trim(), 'owner_id': supa.auth.currentUser!.id}).select().single();
            if(mounted){ Navigator.pop(dCtx); setState(()=> _my.insert(0, NetworkCommunity.fromJson(res))); }
          }catch(_){ setD(()=> creating=false); }
        }, style: ElevatedButton.styleFrom(backgroundColor: _gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: creating? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Créer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ]);
    }));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F8FA),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: Text('Groupes', style: TextStyle(color: _dark, fontWeight: FontWeight.bold)), leading: IconButton(icon: Icon(Icons.arrow_back, color: _dark), onPressed: ()=> context.pop()), actions: [IconButton(icon: Icon(Icons.add, color: _dark), onPressed: _createDialog)], bottom: TabBar(controller: _tab, labelColor: _blue, unselectedLabelColor: Colors.grey, indicatorColor: _blue, tabs: [Tab(text: 'Mes groupes'), Tab(text: 'Suggestions')])),
      body: _loading? Center(child: CircularProgressIndicator(color: _blue)) : TabBarView(controller: _tab, children: [_list(_my, true), _list(_sugg, false)]),
    );
  }

  Widget _list(List<NetworkCommunity> groups, bool isMy){
    if(groups.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isMy? Icons.groups : Icons.explore, size: 64, color: Colors.grey.shade300), SizedBox(height: 16), Text(isMy? 'Aucun groupe rejoint' : 'Aucune suggestion', style: TextStyle(color: Colors.grey.shade600))]));
    return ListView.builder(padding: EdgeInsets.all(16), itemCount: groups.length, itemBuilder: (_,i)=> _card(groups[i], isMy));
  }

  Widget _card(NetworkCommunity g, bool isMy){
    final hasBanner = g.bannerUrl!=null && g.bannerUrl!.isNotEmpty;
    return GestureDetector(onTap: ()=> context.push('/network/community/${g.id}'), child: Container(margin: EdgeInsets.only(bottom: 12), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)]), child: Row(children: [
      Container(width: 60, height: 60, decoration: BoxDecoration(color: _blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: hasBanner? Image.network(g.bannerUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Icon(Icons.groups, color: _blue)) : Icon(Icons.groups, size: 30, color: _blue))),
      SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(g.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _dark)), SizedBox(height: 4), Text('${g.membersCount} membres', style: TextStyle(fontSize: 12, color: Colors.grey))])),
      OutlinedButton(onPressed: ()=> _toggle(g, isMy), style: OutlinedButton.styleFrom(side: BorderSide(color: isMy? Colors.red.shade300 : _blue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: Text(isMy? 'Quitter' : 'Rejoindre', style: TextStyle(color: isMy? Colors.red : _blue, fontWeight: FontWeight.bold, fontSize: 12))),
    ])));
  }
}
