// lib/presentation/chat/call/call_history_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/chat/call_invite.dart';
import '../../../models/chat/call_status.dart';
import 'call_page.dart';
import 'providers/call_provider.dart';

class CallHistoryPage extends ConsumerStatefulWidget {
  const CallHistoryPage({super.key});

  @override
  ConsumerState<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends ConsumerState<CallHistoryPage> {
  final _db = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  late Future<List<_CallRow>> _future;
  String _query = '';

  String get _myId => _db.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<_CallRow>> _load() async {
    final uid = _myId;
    if (uid.isEmpty) return [];

    final rows = await _db
        .from('call_invites')
        .select()
        .or('caller_id.eq.$uid,callee_id.eq.$uid')
        .order('created_at', ascending: false)
        .limit(80);

    final invites = (rows as List)
        .map((r) => CallInvite.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();

    final peerIds = <String>{};
    for (final inv in invites) {
      final peer = inv.callerId == uid ? inv.calleeId : inv.callerId;
      if (peer.isNotEmpty) peerIds.add(peer);
    }

    final nameById = <String, String>{};
    final avatarById = <String, String?>{};

    if (peerIds.isNotEmpty) {
      final profiles = await _db
          .from('profiles')
          .select('id, display_name, full_name, avatar_url')
          .inFilter('id', peerIds.toList());

      for (final p in (profiles as List)) {
        final m = Map<String, dynamic>.from(p as Map);
        final id = '${m['id'] ?? ''}';
        final name = '${m['display_name'] ?? m['full_name'] ?? ''}'.trim();
        nameById[id] = name.isNotEmpty ? name : 'Contact';
        avatarById[id] = m['avatar_url']?.toString();
      }
    }

    return invites.map((inv) {
      final peerId = inv.callerId == uid ? inv.calleeId : inv.callerId;
      final nameFromInvite = inv.callerId == uid
          ? (inv.calleeName ?? '')
          : (inv.callerName ?? '');
      final name = nameFromInvite.trim().isNotEmpty
          ? nameFromInvite.trim()
          : (nameById[peerId] ?? 'Contact');
      final avatar =
          inv.callerId == uid ? inv.calleeAvatar : inv.callerAvatar;

      return _CallRow(
        invite: inv,
        peerId: peerId,
        peerName: name,
        peerAvatar: avatar ?? avatarById[peerId],
      );
    }).toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _callBack(_CallRow row, {required bool video}) async {
    if (row.peerId.isEmpty) return;

    await ref.read(callProvider.notifier).start(
          myUserId: _myId,
          calleeId: row.peerId,
          calleeName: row.peerName,
          calleeAvatar: row.peerAvatar,
          type: video ? CallType.video : CallType.audio,
        );

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CallPage()),
    );
  }

  void _openSearchToCall() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SearchCallSheet(
        onPick: (id, name, avatar, {required bool video}) async {
          Navigator.pop(ctx);
          await ref.read(callProvider.notifier).start(
                myUserId: _myId,
                calleeId: id,
                calleeName: name,
                calleeAvatar: avatar,
                type: video ? CallType.video : CallType.audio,
              );
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CallPage()),
          );
        },
      ),
    );
  }

  String _subtitle(_CallRow row) {
    final inv = row.invite;
    final type = inv.isVideo ? 'Video' : 'Audio';
    final label = inv.status.label;
    if (inv.durationSec > 0) {
      final m = (inv.durationSec / 60).floor();
      final s = inv.durationSec % 60;
      final mm = m.toString().padLeft(2, '0');
      final ss = s.toString().padLeft(2, '0');
      return '$type · $label · $mm:$ss';
    }
    return '$type · $label';
  }

  Color _statusColor(CallInvite inv) {
    if (inv.status == CallStatus.missed ||
        inv.status == CallStatus.rejected ||
        inv.status == CallStatus.canceled) {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFF16A34A);
  }

  IconData _dirIcon(_CallRow row) {
    final inv = row.invite;
    final missed = inv.status == CallStatus.missed ||
        inv.status == CallStatus.rejected ||
        inv.status == CallStatus.canceled;
    if (missed) return Icons.call_missed;
    if (inv.callerId == _myId) return Icons.call_made;
    return Icons.call_received;
  }

  String _fmtDate(DateTime d) {
    final local = d.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return DateFormat('HH:mm').format(local);
    if (day == today.subtract(const Duration(days: 1))) return 'Hier';
    return DateFormat('dd/MM/yy').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Appels'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A1F44),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _openSearchToCall,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0A1F44),
        onPressed: _openSearchToCall,
        child: const Icon(Icons.add_call, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher un appel...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<_CallRow>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(child: Text('Erreur: ${snap.error}')),
                      ],
                    );
                  }

                  var list = snap.data ?? [];
                  if (_query.isNotEmpty) {
                    list = list
                        .where((r) =>
                            r.peerName.toLowerCase().contains(_query))
                        .toList();
                  }

                  if (list.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 100),
                        Icon(Icons.call_outlined,
                            size: 48, color: Colors.black26),
                        SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Aucun appel',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final row = list[i];
                      final inv = row.invite;
                      final red = inv.status == CallStatus.missed ||
                          inv.status == CallStatus.rejected ||
                          inv.status == CallStatus.canceled;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE8EEF7),
                          backgroundImage: row.peerAvatar != null &&
                                  row.peerAvatar!.isNotEmpty
                              ? NetworkImage(row.peerAvatar!)
                              : null,
                          child: row.peerAvatar == null ||
                                  row.peerAvatar!.isEmpty
                              ? Text(
                                  row.peerName.isNotEmpty
                                      ? row.peerName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0B3D91),
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          row.peerName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: red
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF0A1F44),
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(_dirIcon(row),
                                size: 14, color: _statusColor(inv)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _subtitle(row),
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fmtDate(inv.createdAt),
                              style: const TextStyle(
                                color: Colors.black45,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.videocam_outlined,
                                color: Color(0xFF0A1F44),
                              ),
                              onPressed: () =>
                                  _callBack(row, video: true),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.call_outlined,
                                color: Color(0xFF0A1F44),
                              ),
                              onPressed: () =>
                                  _callBack(row, video: false),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallRow {
  final CallInvite invite;
  final String peerId;
  final String peerName;
  final String? peerAvatar;

  _CallRow({
    required this.invite,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
  });
}

/// Bottom sheet : contacts (connexions) + appel audio / vidéo
class _SearchCallSheet extends StatefulWidget {
  final void Function(
    String id,
    String name,
    String? avatar, {
    required bool video,
  }) onPick;

  const _SearchCallSheet({required this.onPick});

  @override
  State<_SearchCallSheet> createState() => _SearchCallSheetState();
}

class _SearchCallSheetState extends State<_SearchCallSheet> {
  final _db = Supabase.instance.client;
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search(''); // affiche les contacts tout de suite
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final query = q.trim().toLowerCase();
    final myId = _db.auth.currentUser?.id;
    if (myId == null) return;

    setState(() => _loading = true);
    try {
      final rows = await _db
          .from('connections')
          .select('user1_id, user2_id')
          .or('user1_id.eq.$myId,user2_id.eq.$myId');

      final peerIds = <String>{};
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final u1 = '${m['user1_id']}';
        final u2 = '${m['user2_id']}';
        if (u1 == myId) peerIds.add(u2);
        if (u2 == myId) peerIds.add(u1);
      }

      if (peerIds.isEmpty) {
        setState(() {
          _results = [];
          _loading = false;
        });
        return;
      }

      final profiles = await _db
          .from('profiles')
          .select('id, display_name, full_name, avatar_url')
          .inFilter('id', peerIds.toList());

      var list = (profiles as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (query.isNotEmpty) {
        list = list.where((p) {
          final name =
              '${p['display_name'] ?? p['full_name'] ?? ''}'.toLowerCase();
          return name.contains(query);
        }).toList();
      }

      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nouvel appel',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Nom du contact...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _results.isEmpty && !_loading
                  ? const Center(
                      child: Text(
                        'Aucune connexion',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final p = _results[i];
                        final id = '${p['id'] ?? ''}';
                        final name =
                            '${p['display_name'] ?? p['full_name'] ?? 'Contact'}'
                                .trim();
                        final avatar = p['avatar_url']?.toString();

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                avatar != null && avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : null,
                            child: avatar == null || avatar.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                  )
                                : null,
                          ),
                          title: Text(name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.videocam_outlined,
                                  color: Color(0xFF0A1F44),
                                ),
                                onPressed: () => widget.onPick(
                                  id,
                                  name,
                                  avatar,
                                  video: true,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.call_outlined,
                                  color: Color(0xFF0A1F44),
                                ),
                                onPressed: () => widget.onPick(
                                  id,
                                  name,
                                  avatar,
                                  video: false,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
