import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LikedPostsPage extends ConsumerStatefulWidget {
  const LikedPostsPage({super.key});
  @override ConsumerState<LikedPostsPage> createState() => _LikedPostsPageState();
}

class _LikedPostsPageState extends ConsumerState<LikedPostsPage> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override void initState(){ super.initState(); _load(); }

  Future<void> _load() async {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if(uid==null){ setState(()=> _loading=false); return; }
    try{
      // essaie post_likes puis likes
      var res = await supa.from('post_likes').select('id, created_at, network_posts!inner(id, content, image_url, media_urls, created_at, user_id, profiles(display_name, photo_url, avatar_url))').eq('user_id', uid).order('created_at', ascending: false).limit(100);
      if(mounted) setState(()=> {_posts = (res as List).cast<Map<String,dynamic>>(), _loading=false});
    }catch(e){
      try{
        final res2 = await supa.from('likes').select('id, created_at, network_posts!inner(id, content, image_url, media_urls, created_at, user_id, profiles(display_name, photo_url, avatar_url))').eq('user_id', uid).order('created_at', ascending: false).limit(100);
        if(mounted) setState(()=> {_posts = (res2 as List).cast<Map<String,dynamic>>(), _loading=false});
      }catch(_){ if(mounted) setState(()=> _loading=false); }
    }
  }

  Future<void> _unlike(String likeId) async {
    try{
      await Supabase.instance.client.from('post_likes').delete().eq('id', likeId);
      await Supabase.instance.client.from('likes').delete().eq('id', likeId);
    }catch(_){}
    if(mounted) setState(()=> _posts.removeWhere((e)=> e['id']==likeId));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F8FA),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: Text('Posts aimés', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))), iconTheme: IconThemeData(color: Color(0xFF1A1A2E))),
      body: _loading? Center(child: CircularProgressIndicator(color: Color(0xFF2B5CFF))) : _posts.isEmpty? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.favorite, size: 80, color: Colors.grey.shade300), SizedBox(height: 16), Text('Aucun post aimé', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('Les posts que vous aimez apparaîtront ici', style: TextStyle(color: Colors.grey))])) : RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: EdgeInsets.all(16), itemCount: _posts.length, itemBuilder: (_,i){
        final wrap = _posts[i];
        final post = wrap['network_posts'] as Map<String,dynamic>;
        final profile = post['profiles'] as Map?;
        final name = profile?['display_name']?? 'Utilisateur';
        final avatar = profile?['photo_url']?? profile?['avatar_url'];
        final img = post['image_url']?? (post['media_urls']!=null && (post['media_urls'] as List).isNotEmpty? (post['media_urls'] as List).first : null);
        return Container(margin: EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]), child: InkWell(onTap: ()=> context.push('/network/post/${post['id']}'), borderRadius: BorderRadius.circular(16), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [CircleAvatar(radius: 18, backgroundColor: Colors.grey.shade200, child: ClipOval(child: avatar!=null? Image.network(avatar, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Icon(Icons.person, size: 18)) : Icon(Icons.person, size: 18))), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text('Aimé le ${wrap['created_at']!=null? DateTime.parse(wrap['created_at']).toLocal().toString().split(' ').first : ''}', style: TextStyle(fontSize: 10, color: Colors.grey))])), IconButton(icon: Icon(Icons.favorite, color: Colors.red, size: 20), onPressed: ()=> _unlike(wrap['id']))]),
          SizedBox(height: 10),
          Text(post['content']?? '', maxLines: 4, overflow: TextOverflow.ellipsis),
          if(img!=null)...[SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(img, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___)=> SizedBox()))],
        ]))));
      })),
    );
  }
}
