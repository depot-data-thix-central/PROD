import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/network_post.dart';

class MemberProfile extends ConsumerStatefulWidget {
  final String userId;
  const MemberProfile({super.key, required this.userId});
  @override ConsumerState<MemberProfile> createState() => _MemberProfileState();
}

class _MemberProfileState extends ConsumerState<MemberProfile> {
  Map<String, dynamic>? _user;
  List<NetworkPost> _posts = [];
  bool _loading = true;
  String? _connStatus; // accepted, pending, null

  @override void initState(){ super.initState(); _load(); }

  Future<void> _load() async {
    setState(()=> _loading=true);
    final supa = Supabase.instance.client;
    try{
      final prof = await supa.from('profiles').select().eq('id', widget.userId).single();
      final postsRes = await supa.from('network_posts').select('*, profiles!network_posts_user_id_fkey(display_name, photo_url, avatar_url)').eq('user_id', widget.userId).order('created_at', ascending: false).limit(20);
      String? status;
      try{
        final c1 = await supa.from('connection_requests').select('status').eq('sender_id', supa.auth.currentUser!.id).eq('receiver_id', widget.userId).maybeSingle();
        final c2 = await supa.from('connections').select('status').or('and(user_id.eq.${supa.auth.currentUser!.id},connection_id.eq.${widget.userId}),and(user_id.eq.${widget.userId},connection_id.eq.${supa.auth.currentUser!.id})').maybeSingle();
        status = (c2?['status'] as String?) ?? (c1?['status'] as String?);
      }catch(_){}
      if(!mounted) return;
      setState((){
        _user = prof;
        _posts = (postsRes as List).map((e)=> NetworkPost.fromJson({...e, 'author_name': e['profiles']?['display_name'], 'author_avatar': e['profiles']?['photo_url']?? e['profiles']?['avatar_url']})).toList();
        _connStatus = status;
        _loading=false;
      });
    }catch(e){ if(mounted) setState(()=> _loading=false); }
  }

  Future<void> _toggleConnect() async {
    final supa = Supabase.instance.client;
    final me = supa.auth.currentUser!.id;
    try{
      if(_connStatus==null){
        setState(()=> _connStatus='pending');
        await supa.from('connection_requests').insert({'sender_id': me, 'receiver_id': widget.userId, 'status': 'pending'});
      }else if(_connStatus=='pending'){
        setState(()=> _connStatus=null);
        await supa.from('connection_requests').delete().eq('sender_id', me).eq('receiver_id', widget.userId);
      }else{
        setState(()=> _connStatus=null);
        await supa.from('connections').delete().or('and(user_id.eq.$me,connection_id.eq.${widget.userId}),and(user_id.eq.${widget.userId},connection_id.eq.$me)');
      }
    }catch(e){ _load(); }
  }

  @override Widget build(BuildContext context) {
    if(_loading) return Scaffold(backgroundColor: Color(0xFFF8FAFC), appBar: AppBar(backgroundColor: Colors.white, elevation: 0), body: Center(child: CircularProgressIndicator()));
    final avatar = _user?['photo_url']?? _user?['avatar_url'];
    final name = _user?['display_name']?? 'Profil';
    final bio = _user?['bio']?? '';
    final prof = _user?['profession']?? '';

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: Text(name, style: TextStyle(color: Color(0xFF0B1B3D), fontWeight: FontWeight.bold)), leading: IconButton(icon: Icon(Icons.arrow_back, color: Color(0xFF0B1B3D)), onPressed: ()=> context.pop())),
      body: RefreshIndicator(onRefresh: _load, child: SingleChildScrollView(physics: AlwaysScrollableScrollPhysics(), child: Column(children: [
        Container(padding: EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))), child: Column(children: [
          CircleAvatar(radius: 50, backgroundColor: Colors.grey.shade200, child: ClipOval(child: avatar!=null && avatar.isNotEmpty? Image.network(avatar, width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Icon(Icons.person, size: 50)) : Icon(Icons.person, size: 50))),
          SizedBox(height: 12),
          Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF0B1B3D))),
          if(prof.isNotEmpty) Text(prof, style: TextStyle(color: Colors.grey)),
          if(bio.isNotEmpty)...[SizedBox(height: 8), Text(bio, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))],
        ])),
        SizedBox(height: 12),
        // Stats
        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
          Expanded(child: _stat('${_posts.length}', 'Posts')),
          Expanded(child: _stat('${_user?['connections_count']?? 0}', 'Connexions')),
          Expanded(child: _stat('${_user?['followers_count']?? 0}', 'Abonnés')),
        ])),
        SizedBox(height: 12),
        // Actions
        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
          Expanded(child: ElevatedButton(onPressed: _toggleConnect, style: ElevatedButton.styleFrom(backgroundColor: _connStatus=='accepted'? Colors.grey.shade200 : Color(0xFF2B5CFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: Text(_connStatus=='accepted'? 'Connecté' : _connStatus=='pending'? 'En attente' : 'Se connecter', style: TextStyle(color: _connStatus=='accepted'? Colors.black : Colors.white, fontWeight: FontWeight.bold)))),
          SizedBox(width: 10),
          OutlinedButton(onPressed: ()=> context.push('/network/chat/${widget.userId}'), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: Icon(Icons.message_outlined)),
        ])),
        SizedBox(height: 16),
        ..._posts.map((p)=> Container(margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if(p.content.isNotEmpty) Text(p.content, style: TextStyle(fontSize: 13)),
          if(p.imageUrl!=null && p.imageUrl!.isNotEmpty)...[SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p.imageUrl!, width: double.infinity, height: 180, fit: BoxFit.cover, errorBuilder: (_,__,___)=> SizedBox()))],
        ]))).toList(),
        SizedBox(height: 80),
      ]))),
    );
  }

  Widget _stat(String v, String l)=> Column(children: [Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(l, style: TextStyle(fontSize: 12, color: Colors.grey))]);
}
