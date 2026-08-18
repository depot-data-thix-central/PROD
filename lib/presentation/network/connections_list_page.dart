// lib/presentation/network/pages/connections_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/network/widgets/connection_card.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ─────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────
final connectionsProvider =
    AsyncNotifierProvider<ConnectionsNotifier, List<Map<String, dynamic>>>(
  ConnectionsNotifier.new,
);

class ConnectionsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  static const _limit = 30;
  int _offset = 0;
  bool _hasMore = true;
  bool get hasMore => _hasMore;
  String _search = '';

  @override
  Future<List<Map<String, dynamic>>> build() async {
    _offset = 0;
    _hasMore = true;
    return _fetch(0);
  }

  Future<List<Map<String, dynamic>>> _fetch(int offset) async {
    final supa = Supabase.instance.client;
    final userId = supa.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // ✅ Table follows (je suis → following_id)
      final res = await supa
          .from('follows')
          .select('''
            created_at,
            following_id,
            following:profiles!follows_following_id_fkey(
              id, display_name, avatar_url, photo_url, profession, bio
            )
          ''')
          .eq('follower_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + _limit - 1);

      final list = <Map<String, dynamic>>[];

      for (final row in (res as List)) {
        final profile = row['following'] as Map<String, dynamic>?;
        if (profile == null) continue;

        list.add({
          'id': profile['id'], // on utilise l'id du profil comme clé
          'user_id': profile['id'],
          'display_name': profile['display_name'] ?? 'Utilisateur',
          'photo_url': profile['avatar_url'] ?? profile['photo_url'],
          'profession': profile['profession'] ?? 'Membre THIX',
          'bio': profile['bio'],
          'connected_at': row['created_at'],
        });
      }

      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return list
            .where((c) =>
                (c['display_name'] as String).toLowerCase().contains(q))
            .toList();
      }

      return list;
    } catch (e) {
      debugPrint('connectionsProvider error: $e');

      // Fallback : ancienne table connections
      try {
        final res = await supa
            .from('connections')
            .select('''
              id, created_at, user1_id, user2_id,
              user1:profiles!user1_id(id, display_name, avatar_url, photo_url, profession, bio),
              user2:profiles!user2_id(id, display_name, avatar_url, photo_url, profession, bio)
            ''')
            .or('user1_id.eq.$userId,user2_id.eq.$userId')
            .order('created_at', ascending: false)
            .range(offset, offset + _limit - 1);

        final list = <Map<String, dynamic>>[];
        for (final conn in (res as List)) {
          final isUser1 = conn['user1_id'] == userId;
          final userData = isUser1 ? conn['user2'] : conn['user1'];
          if (userData == null) continue;

          list.add({
            'id': conn['id'],
            'user_id': userData['id'],
            'display_name': userData['display_name'] ?? 'Utilisateur',
            'photo_url': userData['avatar_url'] ?? userData['photo_url'],
            'profession': userData['profession'] ?? 'Membre THIX',
            'bio': userData['bio'],
            'connected_at': conn['created_at'],
          });
        }
        return list;
      } catch (e2) {
        debugPrint('connectionsProvider fallback error: $e2');
        return [];
      }
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final current = state.valueOrNull ?? <Map<String, dynamic>>[];
    final more = await _fetch(_offset + _limit);
    if (more.isEmpty) {
      _hasMore = false;
      return;
    }
    _offset += _limit;
    _hasMore = more.length >= _limit;
    state = AsyncData([...current, ...more]);
  }

  void search(String q) {
    _search = q;
    ref.invalidateSelf();
  }

  Future<void> removeConnection(String targetUserId) async {
    final current = [...state.valueOrNull ?? <Map<String, dynamic>>[]];
    final filtered =
        current.where((c) => c['user_id'] != targetUserId).toList();
    state = AsyncData(filtered);

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      // ✅ Unfollow via table follows
      await Supabase.instance.client
          .from('follows')
          .delete()
          .eq('follower_id', uid)
          .eq('following_id', targetUserId);
    } catch (e) {
      // Fallback ancienne table
      try {
        await Supabase.instance.client
            .from('connections')
            .delete()
            .eq('id', targetUserId);
      } catch (_) {}
      state = AsyncData(current);
      rethrow;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────
class ConnectionsListPage extends ConsumerStatefulWidget {
  const ConnectionsListPage({super.key});

  @override
  ConsumerState<ConnectionsListPage> createState() =>
      _ConnectionsListPageState();
}

class _ConnectionsListPageState extends ConsumerState<ConnectionsListPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >=
          _scroll.position.maxScrollExtent - 400) {
        ref.read(connectionsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _removeConnection(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Retirer l\'abonnement'),
        content: Text('Voulez-vous vraiment vous désabonner de $userName ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Se désabonner'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(connectionsProvider.notifier).removeConnection(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vous ne suivez plus $userName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncConnections = ref.watch(connectionsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0.5,
        title: Row(
          children: [
            Text(
              'Mes abonnements',
              style: ThixPolicy.titleStyle.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            asyncConnections.when(
              data: (l) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ThixPolicy.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${l.length}',
                  style: TextStyle(
                    color: ThixPolicy.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: ThixPolicy.textMain, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: ThixPolicy.textMain, size: 22),
            onPressed: _showSearch,
          ),
        ],
      ),
      body: asyncConnections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorWidget(e.toString()),
        data: (connections) => connections.isEmpty
            ? _buildEmptyWidget()
            : RefreshIndicator(
                color: ThixPolicy.gold,
                onRefresh: () async =>
                    ref.invalidate(connectionsProvider),
                child: ListView.builder(
                  controller: _scroll,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: connections.length + 1,
                  itemBuilder: (context, index) {
                    if (index == connections.length) {
                      return ref.read(connectionsProvider.notifier).hasMore
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            )
                          : const SizedBox(height: 20);
                    }

                    final conn = connections[index];
                    return ConnectionCard(
                      userId: conn['user_id'],
                      displayName: conn['display_name'],
                      photoUrl: conn['photo_url'],
                      profession: conn['profession'],
                      bio: conn['bio'],
                      connectedAt: conn['connected_at'] ?? '',
                      onTap: () => context
                          .push('/network/profile/${conn['user_id']}'),
                      onMessageTap: () => context
                          .push('/network/chat/${conn['user_id']}'),
                      onRemoveTap: () => _removeConnection(
                        conn['user_id'],
                        conn['display_name'],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(error, style: ThixPolicy.bodySmallStyle),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(connectionsProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.gold,
              foregroundColor: Colors.white,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: ThixPolicy.gold.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 64,
              color: ThixPolicy.gold.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun abonnement',
            style: ThixPolicy.h3Style,
          ),
          const SizedBox(height: 8),
          Text(
            'Commencez à suivre des professionnels\nde votre secteur.',
            textAlign: TextAlign.center,
            style: ThixPolicy.bodySmallStyle,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/network/discover'),
            icon: const Icon(Icons.explore),
            label: const Text('Découvrir des personnes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.gold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearch() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rechercher'),
        content: TextField(
          controller: _searchCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nom...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) =>
              ref.read(connectionsProvider.notifier).search(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
