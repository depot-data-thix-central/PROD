import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RepostedPostsPage extends ConsumerStatefulWidget {
  const RepostedPostsPage({super.key});
  @override ConsumerState<RepostedPostsPage> createState() => _RepostedPostsPageState();
}

class _RepostedPostsPageState extends ConsumerState<RepostedPostsPage> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if(uid==null){ setState(()=> _loading=false); return; }
    try{
      // 2 cas : table reposts OU network_posts avec reposted_by
      final res = await supa.from('reposts').select('id, created_at, network_posts!inner(id, content, image_url, user_id, created_at, profiles(display_name, photo_url, avatar_url))').eq('user_id', uid).order('created_at', ascending: false);
      if(mounted) setState(()=> {_posts = (res as List).cast<Map<String,dynamic>>(), _loading=false});
    }catch(e){
      // fallback si pas de table reposts -> cherche dans network_posts où reposted_from not null
      try{
        final res2 = await supa.from('network_posts').select('id, content, image_url, created_at, reposted_from, profiles!network_posts_user_id_fkey(display_name, photo_url, avatar_url)').eq('user_id', uid).not('reposted_from', 'is', null).order('created_at', ascending: false);
        if(mounted) setState(()=> {_posts = (res2 as List).map((p)=> {'id': p['id'], 'network_posts': p}).toList(), _loading=false});
      }catch(_){ if(mounted) setState(()=> _loading=false); }
    }
  }

  Future<void> _unrepost(String id) async {
    try{ await Supabase.instance.client.from('reposts').delete().eq('id', id); if(mounted) setState(()=> _posts.removeWhere((e)=> e['id']==id)); }catch(_){}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F8FA),
      appBar: AppBar(title: Text('Posts repostés', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))), backgroundColor: Colors.white, elevation: 0, iconTheme: IconThemeData(color: Color(0xFF1A1A2E))),
      body: _loading? Center(child: CircularProgressIndicator(color: Color(0xFF2B5CFF))) : _posts.isEmpty? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.repeat, size: 80, color: Colors.grey), SizedBox(height: 16), Text('Aucun post reposté', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('Les posts que vous repostez apparaîtront ici', style: TextStyle(color: Colors.grey))])) : RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: EdgeInsets.all(16), itemCount: _posts.length, itemBuilder: (_,i){
        final wrap = _posts[i];
        final post = (wrap['network_posts']?? wrap) as Map<String,dynamic>;
        final profile = post['profiles'] as Map?;
        final name = profile?['display_name']?? 'Utilisateur';
        final avatar = profile?['photo_url']?? profile?['avatar_url'];
        return Container(margin: EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: InkWell(onTap: ()=> context.push('/network/post/${post['id']}'), borderRadius: BorderRadius.circular(16), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.repeat, size: 14, color: Colors.grey), SizedBox(width: 6), Text('Vous avez reposté', style: TextStyle(fontSize: 11, color: Colors.grey)), Spacer(), IconButton(icon: Icon(Icons.close, size: 18), onPressed: ()=> _unrepost(wrap['id']))]),
          SizedBox(height: 8),
          Row(children: [CircleAvatar(radius: 18, child: ClipOval(child: avatar!=null? Image.network(avatar, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Icon(Icons.person, size: 18)) : Icon(Icons.person, size: 18))), SizedBox(width: 10), Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))]),
          SizedBox(height: 10),
          Text(post['content']?? '', maxLines: 4, overflow: TextOverflow.ellipsis),
          if(post['image_url']!=null)...[SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(post['image_url'], width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___)=> SizedBox()))],
        ]))));
      })),
    );
  }
}
