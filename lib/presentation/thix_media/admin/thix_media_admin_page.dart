import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/media_content.dart';
import 'media_form_sheet.dart';
import '../providers/admin_media_provider.dart';

const kNavyDeep = Color(0xFF0A1F44);
const kAccent = Color(0xFF2D6CDF);
const kGold = Color(0xFFE3B23C);
const kBg = Color(0xFFF7FAFF);
const kBorder = Color(0xFFE7EEFC);

class ThixMediaAdminPage extends ConsumerStatefulWidget {
  const ThixMediaAdminPage({super.key});
  @override ConsumerState<ThixMediaAdminPage> createState() => _ThixMediaAdminPageState();
}

class _ThixMediaAdminPageState extends ConsumerState<ThixMediaAdminPage> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  @override void initState(){
    super.initState();
    _scrollCtrl.addListener((){
      if(_scrollCtrl.position.pixels > _scrollCtrl.position.maxScrollExtent - 300){
        ref.read(adminMediaProvider.notifier).loadMore();
      }
    });
  }

  @override void dispose(){ _scrollCtrl.dispose(); _searchCtrl.dispose(); super.dispose(); }

  void _openForm({MediaContent? item}){
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_)=> MediaFormSheet(existing: item, onSaved: ()=> ref.read(adminMediaProvider.notifier).refreshList()));
  }

  @override Widget build(BuildContext context){
    final asyncAll = ref.watch(adminMediaProvider);
    final filtered = ref.watch(filteredAdminProvider);
    final all = asyncAll.valueOrNull??[];
    final filter = ref.watch(adminFilterProvider);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kNavyDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18), onPressed: ()=> context.pop()),
        title: Row(children: [Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.play_circle_fill_rounded, size: 16, color: kGold)), const SizedBox(width: 8), const Text('ADMIN MEDIA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))]),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: ElevatedButton.icon(onPressed: ()=> _openForm(), icon: const Icon(Icons.cloud_upload_rounded, size: 16), label: const Text('Charger', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: kNavyDeep, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8))))],
      ),
      body: asyncAll.when(
        loading: ()=> const Center(child: CircularProgressIndicator(color: kAccent)),
        error: (e,st)=> Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Erreur: $e'), const SizedBox(height: 12), ElevatedButton(onPressed: ()=> ref.read(adminMediaProvider.notifier).refreshList(), child: const Text('Réessayer'))])),
        data: (_)=> RefreshIndicator(onRefresh: ()=> ref.read(adminMediaProvider.notifier).refreshList(), child: CustomScrollView(controller: _scrollCtrl, physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverToBoxAdapter(child: _stats(all)),
          SliverToBoxAdapter(child: const SizedBox(height: 12)),
          SliverToBoxAdapter(child: _search()),
          SliverToBoxAdapter(child: const SizedBox(height: 10)),
          SliverToBoxAdapter(child: _filters(filter)),
          SliverPadding(padding: const EdgeInsets.all(16), sliver: filtered.isEmpty? SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Text('Aucun contenu dans $filter', style: const TextStyle(color: Color(0xFF7386A8)))))) : SliverGrid(delegate: SliverChildBuilderDelegate((c,i){
            final item = filtered[i];
            return _card(item);
          }, childCount: filtered.length), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: 12, mainAxisSpacing: 12))),
          SliverToBoxAdapter(child: Consumer(builder: (c,ref,_){ final hasMore = ref.read(adminMediaProvider.notifier).hasMore; return hasMore? const Padding(padding: EdgeInsets.all(20), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))) : const SizedBox(height: 40); })),
        ])),
      ),
    );
  }

  Widget _search()=> Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(controller: _searchCtrl, onChanged: (v)=> ref.read(adminSearchProvider.notifier).state=v, decoration: InputDecoration(hintText: 'Rechercher titre...', prefixIcon: const Icon(Icons.search_rounded, size: 18), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)))));

  Widget _stats(List<MediaContent> all)=> Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder), boxShadow: [BoxShadow(color: kNavyDeep.withOpacity(0.04), blurRadius: 12)]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_stat('${all.length}','Total'), _stat('${all.where((e)=>e.isPublished).length}','Publiés'), _stat('${all.where((e)=>e.isNewRelease).length}','Nouveautés'), _stat('${(all.fold<int>(0,(s,e)=>s+e.viewCount)/1000).toStringAsFixed(1)}k','Vues')]));
  Widget _stat(String v,String l)=> Column(children: [Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kNavyDeep)), const SizedBox(height: 2), Text(l, style: const TextStyle(fontSize: 10.5, color: Color(0xFF7386A8), fontWeight: FontWeight.w600))]);

  Widget _filters(String cur)=> SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: ['Tous','Publiés','Brouillons','Films','Séries','Vidéos','Musique'].map((f)=> Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(f, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), selected: cur==f, selectedColor: kNavyDeep, backgroundColor: Colors.white, side: const BorderSide(color: kBorder), labelStyle: TextStyle(color: cur==f? Colors.white : kNavyDeep), onSelected: (_)=> ref.read(adminFilterProvider.notifier).state=f))).toList()));

  Widget _card(MediaContent item)=> Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder), boxShadow: [BoxShadow(color: kNavyDeep.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Stack(children: [
      ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(18)), child: Image.network(item.coverUrl, height: 110, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Container(height:110,color: const Color(0xFFEFF5FF), child: const Icon(Icons.image_rounded, color: kBorder)))),
      Positioned(top:8,right:8, child: Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:3), decoration: BoxDecoration(color: item.isPublished? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(20)), child: Text(item.isPublished?'PUBLIÉ':'BROUILLON', style: const TextStyle(color:Colors.white,fontSize:8.5,fontWeight: FontWeight.w900)))),
      if(item.rankPosition!=null) Positioned(top:8,left:8, child: Container(padding: const EdgeInsets.symmetric(horizontal:7, vertical:3), decoration: BoxDecoration(color: kNavyDeep, borderRadius: BorderRadius.circular(20)), child: Text('#${item.rankPosition}', style: const TextStyle(color:Colors.white,fontSize:9,fontWeight: FontWeight.w800)))),
    ]),
    Expanded(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(item.title, maxLines:1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize:12.5, color: kNavyDeep)),
      const SizedBox(height: 2),
      Text('${item.type} • ${item.year??''} • ${item.viewCount} vues', maxLines:1, style: const TextStyle(fontSize:9.5, color: Color(0xFF7386A8))),
      const Spacer(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        InkWell(onTap: ()=> _openForm(item: item), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFEFF5FF), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.edit_rounded, size:16, color: kAccent))),
        InkWell(onTap: () async {
          final ok = await showDialog<bool>(context: context, builder: (_)=> AlertDialog(title: Text('Supprimer ${item.title}?'), content: const Text('Action irréversible.'), actions: [TextButton(onPressed: ()=> Navigator.pop(context,false), child: const Text('Annuler')), TextButton(onPressed: ()=> Navigator.pop(context,true), child: const Text('Supprimer', style: TextStyle(color: Colors.red)))]));
          if(ok==true){ await ref.read(adminMediaProvider.notifier).delete(item); }
        }, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFFFEFF0), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.delete_rounded, size:16, color: Colors.redAccent))),
      ]),
    ]))),
  ]));
}
