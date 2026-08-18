import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SavedPostsPage extends ConsumerStatefulWidget {
  const SavedPostsPage({super.key});
  @override ConsumerState<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends ConsumerState<SavedPostsPage> {
  List<Map<String, dynamic>> _saved = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if(uid==null){ setState(()=> _loading=false); return; }
    try{
      final res = await supa.from('saved_posts').select('id, created_at, network_posts!inner(id, content, image_url, created_at, profiles(display_name, photo_url, avatar_url))').eq('user_id', uid).order('created_at', ascending: false);
      if(mounted) setState(()=> {_saved = (res as List).cast<Map<String,dynamic>>(), _loading=false});
    }catch(e){ if(mounted) setState(()=> _loading=false); }
  }

  Future<void> _unsave(String saveId) async {
    try{ await Supabase.instance.client.from('saved_posts').delete().eq('id', saveId); if(mounted) setState(()=> _saved.removeWhere((e)=> e['id']==saveId)); }catch(_){}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA),
      appBar: AppBar(title: const Text('Posts sauvegardés', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))), backgroundColor: Colors.white, elevation: 0, iconTheme: IconThemeData(color: Color(0xFF1A1A2E))),
      body: _loading? Center(child: CircularProgressIndicator(color: Color(0xFF2B5CFF))) : _saved.isEmpty? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.bookmark, size: 80, color: Colors.grey), SizedBox(height: 16), Text('Aucun post sauvegardé', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('Les posts que vous sauvegardez apparaîtront ici', style: TextStyle(color: Colors.grey))])) : RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: EdgeInsets.all(16), itemCount: _saved.length, itemBuilder: (_,i){
        final save = _saved[i];
        final post = save['network_posts'] as Map<String,dynamic>;
        final profile = post['profiles'] as Map?;
        final name = profile?['display_name']?? 'Utilisateur';
        final avatar = profile?['photo_url']?? profile?['avatar_url'];
        return Container(margin: EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: InkWell(onTap: ()=> context.push('/network/post/${post['id']}'), borderRadius: BorderRadius.circular(16), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 18, child: ClipOval(child: avatar!=null? Image.network(avatar, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Icon(Icons.person, size: 18)) : Icon(Icons.person, size: 18))),
            SizedBox(width: 10),
            Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            IconButton(icon: Icon(Icons.bookmark, color: Color(0xFFD4AF37)), onPressed: ()=> _unsave(save['id'])),
          ]),
          SizedBox(height: 10),
          Text(post['content']?? '', maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF1A1A2E).withValues(alpha: 0.8))),
          if(post['image_url']!=null)...[SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(post['image_url'], width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___)=> SizedBox()))],
        ]))));
      })),
    );
  }
}
