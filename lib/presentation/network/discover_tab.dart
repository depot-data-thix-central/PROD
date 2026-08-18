// lib/presentation/network/discover_tab.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});
  @override 
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _tags = [], _users = [], _posts = [];
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();

  // Liste de secours (Fallback) pour ne jamais laisser l'onglet vide
  final List<Map<String, dynamic>> _defaultTags = [
    {'tag': 'THIXCentral', 'count': 120},
    {'tag': 'Innovation', 'count': 85},
    {'tag': 'Technologie', 'count': 64},
    {'tag': 'Entrepreneuriat', 'count': 52},
    {'tag': 'Education', 'count': 41},
    {'tag': 'Networking', 'count': 30},
  ];

  @override 
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }
  
  @override 
  void dispose() { 
    _tab.dispose(); 
    _search.dispose(); 
    super.dispose(); 
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final supa = Supabase.instance.client;
      
      // 1. Hashtags Tendances
      final rawPosts = await supa.from('network_posts').select('content').limit(200);
      final Map<String, int> counter = {};
      final reg = RegExp(r'#(\w+)');
      for (final r in (rawPosts as List)) {
        final c = (r['content'] ?? '') as String;
        for (final m in reg.allMatches(c)) {
          final t = m.group(1)!.toLowerCase();
          counter[t] = (counter[t] ?? 0) + 1;
        }
      }
      final sortedTags = counter.entries.toList()..sort((a,b) => b.value.compareTo(a.value));

      // 2. Personnes (Utilisateurs)
      List users = [];
      try {
        users = await supa.from('profiles').select('id, display_name, photo_url, avatar_url, profession, followers_count').order('followers_count', ascending: false).limit(20);
      } catch (_) {
        users = await supa.from('profiles').select('id, display_name, photo_url, avatar_url, profession').limit(20);
      }

      // 3. Publications Populaires
      final pop = await supa.from('network_posts')
          .select('id, content, image_url, likes_count, created_at, profiles(display_name, photo_url)')
          .order('likes_count', ascending: false)
          .limit(20);

      if (!mounted) return;
      
      setState(() {
        final fetchedTags = sortedTags.map((e) => {'tag': e.key, 'count': e.value}).toList();
        // Si aucun hashtag n'est trouvé dans les posts, on utilise les tendances par défaut
        _tags = fetchedTags.isEmpty ? _defaultTags : fetchedTags.take(15).toList();
        _users = (users as List).cast<Map<String, dynamic>>();
        _posts = (pop as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() { 
          // En cas d'erreur réseau, on charge quand même les tags par défaut pour l'UI
          _tags = _defaultTags;
          _error = e.toString(); 
          _loading = false; 
        });
      }
    }
  }

  @override 
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 0,
        title: const Text('Découvrir', style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab, 
          labelColor: ThixPolicy.primary, 
          unselectedLabelColor: ThixPolicy.textSecondary, 
          indicatorColor: ThixPolicy.primary, 
          tabs: const [
            Tab(text: 'Tendances'), 
            Tab(text: 'Personnes'), 
            Tab(text: 'Populaires')
          ]
        ),
      ),
      body: Column(children: [
        Container(
          color: Colors.white, 
          padding: const EdgeInsets.all(12), 
          child: TextField(
            controller: _search, 
            onSubmitted: (v) { 
              if (v.trim().isEmpty) return; 
              if (v.startsWith('#')) { 
                context.push('/network/hashtag/${v.replaceAll('#','').trim()}'); 
              } else { 
                context.push('/network/search?q=${Uri.encodeComponent(v)}'); 
              } 
            }, 
            decoration: InputDecoration(
              hintText: 'Rechercher #hashtag ou personne', 
              prefixIcon: const Icon(Icons.search, color: ThixPolicy.textSecondary), 
              filled: true, 
              fillColor: ThixPolicy.surfaceSoft, 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)
            )
          )
        ),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)) 
            : TabBarView(
                controller: _tab, 
                children: [
                  _trendTab(), 
                  _peopleTab(), 
                  _popularTab()
                ]
              )
        ),
      ]),
    );
  }

  Widget _trendTab() => RefreshIndicator(
    color: ThixPolicy.primary,
    onRefresh: _load, 
    child: ListView(
      padding: const EdgeInsets.all(16), 
      children: [
        const Text('Hashtags tendances', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, 
          runSpacing: 8, 
          children: _tags.map((t) => ActionChip(
            backgroundColor: Colors.white,
            side: BorderSide(color: ThixPolicy.border),
            label: Text('#${t['tag']} • ${t['count']}', style: const TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w600)), 
            onPressed: () => context.push('/network/hashtag/${t['tag']}')
          )).toList()
        ),
      ]
    )
  );

  Widget _peopleTab() => RefreshIndicator(
    color: ThixPolicy.primary,
    onRefresh: _load, 
    child: ListView.builder(
      padding: const EdgeInsets.all(12), 
      itemCount: _users.length, 
      itemBuilder: (_, i) {
        final u = _users[i];
        final avatar = u['photo_url'] ?? u['avatar_url'];
        return Container(
          margin: const EdgeInsets.only(bottom: 10), 
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowSoft(),
          ), 
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            // CHANGEMENT DE FORME : Carré arrondi au lieu de rond
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 50,
                height: 50,
                color: ThixPolicy.surfaceSoft,
                child: avatar != null 
                    ? Image.network(avatar, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.person, color: ThixPolicy.textSecondary)) 
                    : const Icon(Icons.person, color: ThixPolicy.textSecondary),
              ),
            ), 
            title: Text(
              u['display_name'] ?? 'Utilisateur', 
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: ThixPolicy.textMain)
            ), 
            subtitle: Text(
              u['profession'] ?? 'Membre THIX', 
              style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)
            ), 
            trailing: ElevatedButton(
              onPressed: () => context.push('/network/profile/${u['id']}'), 
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary, 
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
              ), 
              child: const Text('Voir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
            ), 
            onTap: () => context.push('/network/profile/${u['id']}')
          )
        );
      }
    )
  );

  Widget _popularTab() => RefreshIndicator(
    color: ThixPolicy.primary,
    onRefresh: _load, 
    child: _posts.isEmpty 
      ? const Center(child: Text('Aucune publication populaire', style: TextStyle(color: ThixPolicy.textSecondary)))
      : GridView.builder(
          padding: const EdgeInsets.all(8), 
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, 
            childAspectRatio: 0.78, 
            crossAxisSpacing: 8, 
            mainAxisSpacing: 8
          ), 
          itemCount: _posts.length, 
          itemBuilder: (_, i) {
            final p = _posts[i];
            final img = p['image_url'];
            
            return GestureDetector(
              onTap: () => context.push('/network/post/${p['id']}'), 
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  border: Border.all(color: ThixPolicy.border),
                  boxShadow: ThixPolicy.shadowSoft(),
                ), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    if (img != null) 
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rMd)), 
                        child: Image.network(img, height: 110, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 110, color: ThixPolicy.surfaceSoft, child: const Icon(Icons.image, color: ThixPolicy.textMuted)))
                      ),
                    Padding(
                      padding: const EdgeInsets.all(10), 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          Text((p['profiles']?['display_name'] ?? ''), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ThixPolicy.textMain)), 
                          const SizedBox(height: 4), 
                          Text(p['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary)), 
                          const SizedBox(height: 6), 
                          Row(children: [const Icon(Icons.favorite, size: 12, color: Colors.red), const SizedBox(width: 4), Text('${p['likes_count'] ?? 0}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ThixPolicy.textSecondary))])
                        ]
                      )
                    ),
                  ]
                )
              )
            );
          }
        ),
  );
}
