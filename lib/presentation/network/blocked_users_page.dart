import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});
  @override State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  List<Map<String, dynamic>> _blocked = [];
  bool _loading = true;
  Set<String> _processing = {};

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; });
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid == null) { if (mounted) setState(() { _loading = false; }); return; }
    try {
      final r = await supa.from('blocked_users').select('blocked_user_id').eq('user_id', uid);
      final ids = (r as List).map((e) => e['blocked_user_id'] as String).toList();
      if (ids.isNotEmpty) {
        final profs = await supa.from('profiles').select('id, display_name, photo_url, avatar_url, profession').inFilter('id', ids);
        _blocked = (profs as List).cast<Map<String, dynamic>>();
      } else {
        _blocked = [];
      }
    } catch (_) { _blocked = []; }
    if (mounted) setState(() { _loading = false; });
  }

  Future<void> _unblock(String id, String name) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Débloquer'), content: Text('Débloquer $name?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Débloquer'))]));
    if (ok!= true) return;
    setState(() { _processing.add(id); });
    try {
      await Supabase.instance.client.from('blocked_users').delete().eq('user_id', Supabase.instance.client.auth.currentUser!.id).eq('blocked_user_id', id);
      setState(() { _blocked.removeWhere((u) => u['id'] == id); _processing.remove(id); });
    } catch (_) { setState(() { _processing.remove(id); }); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Utilisateurs bloqués'), leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop())),
      body: _loading? const Center(child: CircularProgressIndicator()) : _blocked.isEmpty? const Center(child: Text('Aucun utilisateur bloqué')) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _blocked.length, itemBuilder: (_, i) {
        final u = _blocked[i];
        final id = u['id'] as String;
        final name = (u['display_name']?? 'Utilisateur') as String;
        final photo = (u['photo_url']?? u['avatar_url']) as String?;
        final proc = _processing.contains(id);
        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Row(children: [
          CircleAvatar(backgroundImage: photo!= null? NetworkImage(photo) : null, child: photo == null? Text(name.isNotEmpty? name[0] : '?') : null),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
          proc? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : TextButton(onPressed: () => _unblock(id, name), child: const Text('Débloquer')),
        ]));
      }),
    );
  }
}
