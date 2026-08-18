import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/network_community.dart';

// ✅ Imports pour la certification
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';

class SearchNetworkPage extends ConsumerStatefulWidget {
  const SearchNetworkPage({super.key});
  @override 
  ConsumerState<SearchNetworkPage> createState() => _SearchNetworkPageState();
}

class _SearchNetworkPageState extends ConsumerState<SearchNetworkPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  List<NetworkCommunity> _communities = [];

  Set<String> _pending = {};
  Set<String> _connected = {};

  final _blue = const Color(0xFF2B5CFF);
  final _dark = const Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadConnections();
  }

  @override 
  void dispose() { 
    _searchCtrl.dispose(); 
    _tab.dispose(); 
    _debounce?.cancel(); 
    super.dispose(); 
  }

  Future<void> _loadConnections() async {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if(uid == null) return;
    try {
      final pend = await supa.from('connection_requests').select('receiver_id').eq('sender_id', uid).eq('status','pending');
      final conn = await supa.from('connections').select('connection_id').eq('user_id', uid).eq('status','accepted');
      if(mounted) {
        setState((){
          _pending = (pend as List).map((e)=> e['receiver_id'] as String).toSet();
          _connected = (conn as List).map((e)=> e['connection_id'] as String).toSet();
        });
      }
    } catch(_) {}
  }

  void _onChanged(String v){
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if(q.isEmpty){ 
      if(mounted) setState(()=> {_query='', _users=[], _posts=[], _communities=[], _loading=false}); 
      return; 
    }
    setState(()=> {_query=q, _loading=true});
    final supa = Supabase.instance.client;
    
    try {
      final res = await Future.wait([
        supa.from('profiles').select().ilike('display_name','%$q%').limit(20),
        supa.from('network_posts').select().ilike('content','%$q%').limit(20),
        supa.from('communities').select().ilike('name','%$q%').limit(20),
      ]);
      
      if(!mounted) return;
      if(_searchCtrl.text.trim() != q) return; // anti race
      
      setState((){
        _users = (res[0] as List).cast<Map<String, dynamic>>();
        _posts = (res[1] as List).cast<Map<String, dynamic>>();
        _communities = (res[2] as List).map((e)=> NetworkCommunity.fromJson(e as Map<String,dynamic>)).toList();
        _loading=false;
      });
    } catch(e) {
      if(mounted && _searchCtrl.text.trim() == q) {
        setState(()=> {_loading=false, _users=[], _posts=[], _communities=[]});
      }
    }
  }

  Future<void> _sendReq(String uid, String name) async {
    setState(()=> _pending.add(uid));
    try{
      await Supabase.instance.client.from('connection_requests').insert({
        'sender_id': Supabase.instance.client.auth.currentUser!.id, 
        'receiver_id': uid, 
        'status':'pending'
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Demande à $name'), backgroundColor: Colors.green));
    } catch(e) {
      if(mounted) setState(()=> _pending.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 0, 
        title: Text('Recherche', style: TextStyle(color: _dark, fontWeight: FontWeight.bold)), 
        iconTheme: IconThemeData(color: _dark),
        bottom: TabBar(
          controller: _tab, 
          labelColor: _blue, 
          unselectedLabelColor: Colors.grey, 
          indicatorColor: _blue, 
          tabs: const [Tab(text:'Personnes'), Tab(text:'Publications'), Tab(text:'Communautés')]
        )
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), 
            color: Colors.white, 
            child: TextField(
              controller: _searchCtrl, 
              onChanged: _onChanged, 
              onSubmitted: (_) => _search(), 
              decoration: InputDecoration(
                hintText: 'Rechercher...', 
                prefixIcon: const Icon(Icons.search, color: Colors.grey), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), 
                filled: true, 
                fillColor: const Color(0xFFF5F8FA)
              )
            )
          ),
          Expanded(
            child: _loading
              ? Center(child: CircularProgressIndicator(color: _blue)) 
              : _query.isEmpty
                ? Center(child: Text('Recherchez des personnes, publications...', style: TextStyle(color: Colors.grey.shade600))) 
                : TabBarView(
                    controller: _tab, 
                    children: [_usersTab(), _postsTab(), _commsTab()]
                  )
          ),
        ]
      ),
    );
  }

  Widget _usersTab() => _users.isEmpty
    ? const Center(child: Text('Aucun utilisateur')) 
    : ListView.builder(
        padding: const EdgeInsets.all(16), 
        itemCount: _users.length, 
        itemBuilder: (_,i) => _userTile(_users[i])
      );

  Widget _userTile(Map<String,dynamic> u) {
    final avatar = u['avatar_url'] ?? u['photo_url'];
    final name = u['display_name'] ?? 'Utilisateur';
    final title = u['profession'] ?? '';
    final id = u['id'] ?? '';
    
    // ✅ Extraction de la certification
    CertificationTier? tier;
    CertificationStatus? status;
    bool isCertified = false;
    bool isLegacyVerified = u['is_verified'] == true;

    if (u.containsKey('certification_tier') && u['certification_tier'] != null) {
      tier = CertificationTierX.parse(u['certification_tier']);
      status = CertificationStatusX.parse(u['certification_status']);
      isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
    }

    final isMe = id == Supabase.instance.client.auth.currentUser?.id;
    final pending = _pending.contains(id);
    final connected = _connected.contains(id);

    return GestureDetector(
      onTap: () => context.push('/network/profile/$id'), 
      child: Container(
        margin: const EdgeInsets.only(bottom: 12), 
        padding: const EdgeInsets.all(12), 
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), 
        child: Row(
          children: [
            CircleAvatar(
              radius: 24, 
              backgroundColor: Colors.grey.shade200, 
              child: ClipOval(
                child: avatar != null && avatar.isNotEmpty
                  ? Image.network(avatar, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_,__,___)=> const Icon(Icons.person)) 
                  : const Icon(Icons.person)
              )
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  // ✅ LIGNE AVEC NOM + BADGE DE CERTIFICATION
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name, 
                          style: TextStyle(fontWeight: FontWeight.bold, color: _dark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      ),
                      if (isCertified)
                        CertificationNameBadge(
                          tier: tier,
                          status: status,
                          showLabel: false, // Badge seul
                          iconSize: 14,
                          padding: const EdgeInsets.only(left: 4),
                        )
                      else if (isLegacyVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.verified_rounded, color: Color(0xFFE3B23C), size: 14),
                        ),
                    ],
                  ),
                  if(title.isNotEmpty) 
                    Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)
                ]
              )
            ),
            if(!isMe) 
              connected
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)), 
                    child: const Row(children: [Icon(Icons.check, size: 14), SizedBox(width: 4), Text('Connecté', style: TextStyle(fontSize: 11))])
                  ) 
                : pending
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(20)), 
                      child: const Text('En attente', style: TextStyle(fontSize: 11, color: Colors.grey))
                    ) 
                  : OutlinedButton(
                      onPressed: () => _sendReq(id, name), 
                      style: OutlinedButton.styleFrom(side: BorderSide(color: _blue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), 
                      child: const Text('Se connecter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
                    ),
          ]
        )
      )
    );
  }

  Widget _postsTab() => _posts.isEmpty
    ? const Center(child: Text('Aucune publication')) 
    : ListView.builder(
        padding: const EdgeInsets.all(16), 
        itemCount: _posts.length, 
        itemBuilder: (_,i){
          final p = _posts[i]; 
          return GestureDetector(
            onTap: () => context.push('/network/post/${p['id']}'), 
            child: Container(
              margin: const EdgeInsets.only(bottom: 12), 
              padding: const EdgeInsets.all(16), 
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [Text(p['content'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis)]
              )
            )
          );
        }
      );

  Widget _commsTab() => _communities.isEmpty
    ? const Center(child: Text('Aucune communauté')) 
    : ListView.builder(
        padding: const EdgeInsets.all(16), 
        itemCount: _communities.length, 
        itemBuilder: (_,i){
          final c = _communities[i]; 
          return GestureDetector(
            onTap: () => context.push('/network/community/${c.id}'), 
            child: Container(
              margin: const EdgeInsets.only(bottom: 12), 
              padding: const EdgeInsets.all(12), 
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), 
              child: Row(
                children: [
                  Container(
                    width: 50, 
                    height: 50, 
                    decoration: BoxDecoration(color: _blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), 
                    child: Icon(Icons.groups, color: _blue)
                  ), 
                  const SizedBox(width: 12), 
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
                        Text('${c.membersCount} membres', style: const TextStyle(fontSize: 11, color: Colors.grey))
                      ]
                    )
                  )
                ]
              )
            )
          );
        }
      );
}
