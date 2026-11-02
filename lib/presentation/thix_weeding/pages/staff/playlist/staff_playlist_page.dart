// lib/presentation/thix_weeding/pages/staff/playlist/staff_playlist_page.dart
// ============================================================================
// THIX WEDDING — PLAYLIST (STAFF)
// ✅ Valider / refuser les propositions des invités
// ✅ Ordre de passage (glisser-déposer), ⭐ incontournable, 🚫 à éviter
// ✅ Marquer « jouée », ajouter vos propres titres, copier la liste
// ✅ Temps réel + verre dépoli
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thix_id/presentation/thix_weeding/widgets/thix_glass.dart';
import 'playlist_models.dart';

class _C {
  static const rose = Color(0xFFD81B60);
  static const gold = Color(0xFFD4AF37);
  static const green = Color(0xFF059669);
  static const ink = Color(0xFF111827);
  static const ink2 = Color(0xFF6B7280);
}

class StaffPlaylistPage extends StatefulWidget {
  final String weddingId;
  const StaffPlaylistPage({super.key, required this.weddingId});

  @override
  State<StaffPlaylistPage> createState() => _StaffPlaylistPageState();
}

class _StaffPlaylistPageState extends State<StaffPlaylistPage> with SingleTickerProviderStateMixin {
  final _supa = Supabase.instance.client;
  late final TabController _tab;
  List<PlaylistSong> _songs = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  RealtimeChannel? _ch;
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this)..addListener(() => setState(() {}));
    _load();
    _ch = _supa
        .channel('staff-playlist-${widget.weddingId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_playlist',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'wedding_id', value: widget.weddingId),
          callback: (_) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 400), () {
              if (mounted) _load(silent: true);
            });
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _deb?.cancel();
    if (_ch != null) _supa.removeChannel(_ch!);
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final rows = await _supa
          .from('thix_weeding_playlist')
          .select()
          .eq('wedding_id', widget.weddingId)
          .order('position', ascending: true)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _songs = (rows as List).map((e) => PlaylistSong.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() { _loading = false; _error = '$e'; });
    }
  }

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: error ? _C.rose : _C.green,
        behavior: SnackBarBehavior.floating,
      ));
  }

  List<PlaylistSong> _by(String status) {
    final q = _query.toLowerCase();
    final l = _songs
        .where((s) => s.status == status && (q.isEmpty || s.line.toLowerCase().contains(q)))
        .toList();
    if (status == 'pending') {
      l.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    }
    return l;
  }

  Future<void> _update(PlaylistSong s, Map<String, dynamic> patch) async {
    try {
      await _supa.from('thix_weeding_playlist').update(patch).eq('id', s.id);
      await _load(silent: true);
    } catch (e) {
      _toast('Erreur : $e', error: true);
    }
  }

  int get _nextPos => _songs.isEmpty ? 0 : _songs.map((s) => s.position).reduce((a, b) => a > b ? a : b) + 1;

  Future<void> _approve(PlaylistSong s) => _update(s, {'status': 'approved', 'position': _nextPos});
  Future<void> _reject(PlaylistSong s) => _update(s, {'status': 'rejected'});
  Future<void> _played(PlaylistSong s) => _update(s, {'status': 'played'});
  Future<void> _backToList(PlaylistSong s) => _update(s, {'status': 'approved', 'position': _nextPos});
  Future<void> _must(PlaylistSong s) => _update(s, {'priority': s.isMust ? 'normal' : 'must_play'});
  Future<void> _avoid(PlaylistSong s) => _update(s, {'status': 'rejected', 'priority': 'do_not_play'});

  Future<void> _delete(PlaylistSong s) async {
    try {
      await _supa.from('thix_weeding_playlist').delete().eq('id', s.id);
      await _load(silent: true);
    } catch (e) {
      _toast('Suppression impossible : $e', error: true);
    }
  }

  Future<void> _reorder(List<PlaylistSong> list, int oldI, int newI) async {
    if (newI > oldI) newI -= 1;
    final item = list.removeAt(oldI);
    list.insert(newI, item);
    setState(() {
      for (var i = 0; i < list.length; i++) {
        list[i].position = i;
      }
    });
    try {
      for (var i = 0; i < list.length; i++) {
        await _supa.from('thix_weeding_playlist').update({'position': i}).eq('id', list[i].id);
      }
    } catch (e) {
      _toast('Ordre non enregistré : $e', error: true);
      _load(silent: true);
    }
  }

  Future<void> _copyList() async {
    final l = _by('approved');
    if (l.isEmpty) {
      _toast('Aucun titre validé à copier', error: true);
      return;
    }
    final text = [
      'Playlist du mariage',
      for (var i = 0; i < l.length; i++) '${i + 1}. ${l[i].line}${l[i].isMust ? ' ⭐' : ''}',
      '',
      'À éviter :',
      for (final s in _songs.where((s) => s.isAvoid)) '🚫 ${s.line}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    _toast('Playlist copiée');
  }

  Future<void> _openLink(String url) async {
    final u = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (u == null) return;
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      _toast('Lien impossible à ouvrir', error: true);
    }
  }

  void _addDialog() {
    final t = TextEditingController();
    final a = TextEditingController();
    final l = TextEditingController();
    var must = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.of(ctx).viewInsets.bottom),
          child: ThixGlass(
            radius: 28,
            opacity: 0.85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ajouter un titre',
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: _C.ink)),
                const SizedBox(height: 12),
                _field(t, 'Titre *', Icons.music_note_rounded),
                const SizedBox(height: 8),
                _field(a, 'Artiste', Icons.person_outline_rounded),
                const SizedBox(height: 8),
                _field(l, 'Lien (YouTube, Spotify…)', Icons.link_rounded),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('⭐ À jouer absolument'),
                  value: must,
                  onChanged: (v) => setM(() => must = v),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _C.rose,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      if (t.text.trim().isEmpty) return;
                      try {
                        await _supa.from('thix_weeding_playlist').insert({
                          'wedding_id': widget.weddingId,
                          'title': t.text.trim(),
                          'artist': a.text.trim().isEmpty ? null : a.text.trim(),
                          'link_url': l.text.trim().isEmpty ? null : l.text.trim(),
                          'requested_by_name': 'Staff',
                          'source': 'staff',
                          'status': 'approved',
                          'priority': must ? 'must_play' : 'normal',
                          'position': _nextPos,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load(silent: true);
                      } catch (e) {
                        final m = '$e'.contains('23505') || '$e'.contains('duplicate')
                            ? 'Ce titre est déjà dans la liste'
                            : 'Erreur : $e';
                        _toast(m, error: true);
                      }
                    },
                    child: Text('Ajouter à la playlist', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) => TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 19, color: _C.rose),
          filled: true,
          fillColor: Colors.white.withOpacity(0.65),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pending = _by('pending').length;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: const ThixGlassBar(),
        elevation: 0,
        foregroundColor: _C.ink,
        title: Text('Playlist', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(tooltip: 'Copier la playlist', icon: const Icon(Icons.copy_all_rounded), onPressed: _copyList),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _C.rose,
          labelColor: _C.rose,
          unselectedLabelColor: _C.ink2,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12.5),
          tabs: [
            Tab(text: 'À valider${pending > 0 ? ' ($pending)' : ''}'),
            Tab(text: 'Playlist (${_by('approved').length})'),
            Tab(text: 'Jouées (${_by('played').length})'),
            Tab(text: 'Refusées (${_by('rejected').length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _C.rose,
        foregroundColor: Colors.white,
        onPressed: _addDialog,
        icon: const Icon(Icons.add_rounded),
        label: Text('Ajouter', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: ThixGlassBackdrop(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _C.rose))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Erreur : $_error\n(Avez-vous exécuté le SQL de la playlist ?)',
                          textAlign: TextAlign.center),
                    ),
                  )
                : Column(
                    children: [
                      _stats(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Rechercher un titre ou un artiste',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.65),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tab,
                          children: [
                            _list(_by('pending'), 'pending'),
                            _approvedList(),
                            _list(_by('played'), 'played'),
                            _list(_by('rejected'), 'rejected'),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _stats() {
    final votes = _songs.where((s) => s.status == 'approved').fold(0, (a, s) => a + s.votes);
    Widget cell(String v, String l, IconData i) => Expanded(
          child: Column(
            children: [
              Icon(i, size: 17, color: _C.rose),
              const SizedBox(height: 3),
              Text(v, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _C.ink)),
              Text(l, style: GoogleFonts.inter(fontSize: 9.5, color: _C.ink2, fontWeight: FontWeight.w700)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: ThixGlass(
        radius: 20,
        opacity: 0.6,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            cell('${_songs.length}', 'Titres', Icons.library_music_rounded),
            cell('${_by('pending').length}', 'À valider', Icons.hourglass_top_rounded),
            cell('${_by('approved').length}', 'Validés', Icons.check_circle_outline_rounded),
            cell('$votes', 'Votes', Icons.favorite_border_rounded),
          ],
        ),
      ),
    );
  }

  Widget _empty(String t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(t, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _C.ink2, height: 1.4)),
        ),
      );

  Widget _list(List<PlaylistSong> l, String status) {
    if (l.isEmpty) {
      return _empty(status == 'pending'
          ? 'Aucune proposition en attente.\nLes titres proposés par vos invités apparaîtront ici.'
          : 'Rien ici pour le moment.');
    }
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
        itemCount: l.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _tile(l[i], key: ValueKey(l[i].id)),
      ),
    );
  }

  Widget _approvedList() {
    final l = _by('approved');
    if (l.isEmpty) return _empty('Aucun titre validé.\nValidez des propositions ou ajoutez vos titres.');
    final canReorder = _query.isEmpty;
    if (!canReorder) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
        itemCount: l.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _tile(l[i], key: ValueKey(l[i].id)),
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
      buildDefaultDragHandles: false,
      itemCount: l.length,
      onReorder: (a, b) => _reorder(l, a, b),
      proxyDecorator: (child, i, a) => Material(color: Colors.transparent, child: child),
      itemBuilder: (_, i) => Padding(
        key: ValueKey(l[i].id),
        padding: const EdgeInsets.only(bottom: 8),
        child: _tile(l[i], index: i),
      ),
    );
  }

  Widget _tile(PlaylistSong s, {Key? key, int? index}) {
    final sc = kPlaylistStatusColor[s.status] ?? _C.ink2;
    return ThixGlass(
      key: key,
      radius: 18,
      opacity: 0.62,
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      child: Column(
        children: [
          Row(
            children: [
              if (index != null)
                ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _C.rose.withOpacity(0.12), shape: BoxShape.circle),
                    child: Text('${index + 1}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: _C.rose)),
                  ),
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: sc.withOpacity(0.14), shape: BoxShape.circle),
                  child: Icon(Icons.music_note_rounded, size: 17, color: sc),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: _C.ink)),
                      ),
                      if (s.isMust) const Padding(padding: EdgeInsets.only(left: 5), child: Text('⭐', style: TextStyle(fontSize: 13))),
                      if (s.isAvoid) const Padding(padding: EdgeInsets.only(left: 5), child: Text('🚫', style: TextStyle(fontSize: 13))),
                    ]),
                    Text(s.artist ?? 'Artiste inconnu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11.5, color: _C.ink2)),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(s.source == 'staff' ? Icons.verified_user_outlined : Icons.person_outline_rounded,
                          size: 12, color: _C.ink2),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(s.requestedByName ?? (s.source == 'staff' ? 'Staff' : 'Invité'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 10.5, color: _C.ink2, fontWeight: FontWeight.w600)),
                      ),
                      if (s.votes > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.favorite_rounded, size: 12, color: _C.rose),
                        const SizedBox(width: 2),
                        Text('${s.votes}',
                            style: GoogleFonts.inter(fontSize: 10.5, color: _C.rose, fontWeight: FontWeight.w800)),
                      ],
                    ]),
                  ],
                ),
              ),
              if (s.linkUrl != null)
                IconButton(
                  tooltip: 'Écouter',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.play_circle_outline_rounded, color: _C.rose),
                  onPressed: () => _openLink(s.linkUrl!),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (v) {
                  switch (v) {
                    case 'approve':
                      _approve(s);
                      break;
                    case 'reject':
                      _reject(s);
                      break;
                    case 'played':
                      _played(s);
                      break;
                    case 'back':
                      _backToList(s);
                      break;
                    case 'must':
                      _must(s);
                      break;
                    case 'avoid':
                      _avoid(s);
                      break;
                    case 'delete':
                      _delete(s);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  if (s.status != 'approved') const PopupMenuItem(value: 'approve', child: Text('✓ Valider')),
                  if (s.status == 'approved') const PopupMenuItem(value: 'played', child: Text('▶ Marquer jouée')),
                  if (s.status == 'played') const PopupMenuItem(value: 'back', child: Text('↩ Remettre dans la playlist')),
                  if (s.status == 'approved') PopupMenuItem(value: 'must', child: Text(s.isMust ? 'Retirer ⭐' : '⭐ Incontournable')),
                  if (s.status != 'rejected') const PopupMenuItem(value: 'reject', child: Text('✗ Refuser')),
                  if (!s.isAvoid) const PopupMenuItem(value: 'avoid', child: Text('🚫 À ne pas jouer')),
                  const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                ],
              ),
            ],
          ),
          if (s.status == 'pending')
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 6, 2),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reject(s),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Refuser'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _C.rose,
                        side: BorderSide(color: _C.rose.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _approve(s),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Valider'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _C.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
