// lib/presentation/thix_weeding/pages/guest/guest_playlist_page.dart
// ============================================================================
// THIX WEDDING — PLAYLIST (INVITÉ)
// ✅ Proposer jusqu'à 5 titres (validés par les mariés)
// ✅ Voir la playlist validée, voter pour vos titres préférés ❤
// ✅ Suivre l'état de vos propositions • temps réel • verre dépoli
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/playlist/playlist_models.dart';
import 'package:thix_id/presentation/thix_weeding/widgets/thix_glass.dart';

class _C {
  static const rose = Color(0xFFD81B60);
  static const green = Color(0xFF059669);
  static const ink = Color(0xFF241521);
  static const ink2 = Color(0xFF8A7580);
  static const roseSoft = Color(0xFFFCE4EC);
}

class GuestPlaylistPage extends StatefulWidget {
  final String weddingId;
  const GuestPlaylistPage({super.key, required this.weddingId});

  @override
  State<GuestPlaylistPage> createState() => _GuestPlaylistPageState();
}

class _GuestPlaylistPageState extends State<GuestPlaylistPage> with SingleTickerProviderStateMixin {
  static const int kMaxProposals = 5;

  final _supa = Supabase.instance.client;
  late final TabController _tab;
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _link = TextEditingController();
  final _name = TextEditingController();

  List<PlaylistSong> _songs = [];
  Set<String> _myVotes = {};
  String? _guestId;
  bool _knownName = false;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  final Set<String> _voting = {};

  RealtimeChannel? _ch;
  Timer? _deb;

  String? get _uid => _supa.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
    _ch = _supa
        .channel('guest-playlist-${widget.weddingId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_playlist',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'wedding_id', value: widget.weddingId),
          callback: (_) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 500), () {
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
    _title.dispose();
    _artist.dispose();
    _link.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final rows = await _supa
          .from('thix_weeding_playlist')
          .select()
          .eq('wedding_id', widget.weddingId)
          .order('votes_count', ascending: false)
          .order('created_at', ascending: true);
      final songs = (rows as List).map((e) => PlaylistSong.fromJson(Map<String, dynamic>.from(e as Map))).toList();

      var votes = <String>{};
      final uid = _uid;
      if (uid != null) {
        try {
          final v = await _supa.from('thix_weeding_playlist_votes').select('song_id').eq('user_id', uid);
          votes = (v as List).map((e) => '${e['song_id']}').toSet();
        } catch (_) {}
        try {
          final g = await _supa
              .from('thix_weeding_guests')
              .select('id, name')
              .eq('wedding_id', widget.weddingId)
              .eq('user_id', uid)
              .maybeSingle();
          if (g != null) {
            _guestId = '${g['id']}';
            final n = '${g['name'] ?? ''}'.trim();
            if (n.isNotEmpty) {
              _name.text = n;
              _knownName = true;
            }
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _myVotes = votes;
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

  List<PlaylistSong> get _mine => _songs.where((s) => _uid != null && s.requestedBy == _uid).toList();
  List<PlaylistSong> get _public =>
      _songs.where((s) => (s.status == 'approved' || s.status == 'played') && !s.isAvoid).toList();

  Future<void> _propose() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _toast('Indiquez le titre de la chanson', error: true);
      return;
    }
    if (_name.text.trim().isEmpty) {
      _toast('Indiquez votre nom', error: true);
      return;
    }
    if (_uid != null && _mine.length >= kMaxProposals) {
      _toast('Vous avez déjà proposé $kMaxProposals titres', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await _supa.from('thix_weeding_playlist').insert({
        'wedding_id': widget.weddingId,
        'title': title,
        'artist': _artist.text.trim().isEmpty ? null : _artist.text.trim(),
        'link_url': _link.text.trim().isEmpty ? null : _link.text.trim(),
        'requested_by_name': _name.text.trim(),
        'guest_id': _guestId,
        'source': 'guest',
      });
      _title.clear();
      _artist.clear();
      _link.clear();
      HapticFeedback.mediumImpact();
      _toast('Proposition envoyée — en attente de validation 🎶');
      await _load(silent: true);
      _tab.animateTo(1);
    } catch (e) {
      final s = '$e';
      if (s.contains('23505') || s.contains('duplicate')) {
        _toast('Ce titre a déjà été proposé — votez pour lui dans la playlist !', error: true);
      } else if (s.contains('Maximum 5')) {
        _toast('Maximum $kMaxProposals titres par invité', error: true);
      } else {
        _toast('Envoi impossible : $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _vote(PlaylistSong s) async {
    if (_uid == null) {
      _toast('Connectez-vous pour voter', error: true);
      return;
    }
    if (_voting.contains(s.id)) return;
    _voting.add(s.id);
    HapticFeedback.selectionClick();
    try {
      final r = await _supa.rpc('thix_weeding_playlist_toggle_vote', params: {'p_song_id': s.id});
      final m = Map<String, dynamic>.from(r as Map);
      setState(() {
        s.votes = (m['votes'] as num?)?.toInt() ?? s.votes;
        if (m['voted'] == true) {
          _myVotes.add(s.id);
        } else {
          _myVotes.remove(s.id);
        }
      });
    } catch (e) {
      _toast('$e'.replaceAll('PostgrestException', '').split('message:').last.split(',').first.trim(), error: true);
    } finally {
      _voting.remove(s.id);
    }
  }

  Future<void> _deleteMine(PlaylistSong s) async {
    try {
      await _supa.from('thix_weeding_playlist').delete().eq('id', s.id);
      await _load(silent: true);
    } catch (e) {
      _toast('Suppression impossible : $e', error: true);
    }
  }

  Future<void> _open(String url) async {
    final u = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (u == null) return;
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      _toast('Lien impossible à ouvrir', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: const ThixGlassBar(),
        elevation: 0,
        foregroundColor: _C.ink,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Text('Playlist', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _C.rose,
          labelColor: _C.rose,
          unselectedLabelColor: _C.ink2,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(text: 'Playlist (${_public.length})'),
            Tab(text: 'Mes propositions (${_mine.length})'),
          ],
        ),
      ),
      body: ThixGlassBackdrop(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _C.rose))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Playlist indisponible\n$_error', textAlign: TextAlign.center),
                    ),
                  )
                : Column(
                    children: [
                      _form(),
                      Expanded(
                        child: TabBarView(
                          controller: _tab,
                          children: [_publicList(), _mineList()],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _form() {
    final left = kMaxProposals - _mine.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: ThixGlass(
        radius: 24,
        opacity: 0.62,
        borderColor: _C.rose.withOpacity(0.2),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFE91E78), Color(0xFFC2185B)]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Proposer une chanson',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: _C.ink)),
                ),
                Text(_uid == null ? '' : '$left restante${left > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _C.rose)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(flex: 3, child: _in(_title, 'Titre *', Icons.music_note_rounded)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _in(_artist, 'Artiste', Icons.person_outline_rounded)),
              ],
            ),
            const SizedBox(height: 8),
            _in(_link, 'Lien (optionnel)', Icons.link_rounded),
            if (!_knownName) ...[
              const SizedBox(height: 8),
              _in(_name, 'Votre nom *', Icons.badge_outlined),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _C.rose,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _sending ? null : _propose,
                icon: _sending
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text('Proposer', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _in(TextEditingController c, String l, IconData i) => TextField(
        controller: c,
        textInputAction: TextInputAction.next,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          labelText: l,
          labelStyle: GoogleFonts.inter(fontSize: 12, color: _C.ink2),
          prefixIcon: Icon(i, size: 18, color: _C.rose),
          filled: true,
          fillColor: Colors.white.withOpacity(0.7),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      );

  Widget _empty(String t, IconData i) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(i, size: 40, color: _C.rose.withOpacity(0.5)),
              const SizedBox(height: 10),
              Text(t, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _C.ink2, height: 1.4)),
            ],
          ),
        ),
      );

  Widget _publicList() {
    final l = _public;
    if (l.isEmpty) {
      return _empty('La playlist est vide pour le moment.\nProposez vos chansons préférées ci-dessus !',
          Icons.library_music_outlined);
    }
    return RefreshIndicator(
      color: _C.rose,
      onRefresh: () => _load(silent: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
        itemCount: l.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _publicTile(l[i], i),
      ),
    );
  }

  Widget _publicTile(PlaylistSong s, int i) {
    final voted = _myVotes.contains(s.id);
    final played = s.status == 'played';
    return ThixGlass(
      radius: 18,
      opacity: 0.62,
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (played ? const Color(0xFF6B46C1) : _C.rose).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: played
                ? const Icon(Icons.check_rounded, size: 17, color: Color(0xFF6B46C1))
                : Text('${i + 1}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: _C.rose)),
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
                  if (s.isMust) const Padding(padding: EdgeInsets.only(left: 5), child: Text('⭐', style: TextStyle(fontSize: 12))),
                ]),
                Text(s.artist ?? 'Artiste inconnu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11.5, color: _C.ink2)),
                if (played)
                  Text('Déjà jouée',
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF6B46C1), fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (s.linkUrl != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.play_circle_outline_rounded, color: _C.rose),
              onPressed: () => _open(s.linkUrl!),
            ),
          GestureDetector(
            onTap: played ? null : () => _vote(s),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: voted ? _C.rose : _C.roseSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(voted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 16, color: voted ? Colors.white : _C.rose),
                  const SizedBox(width: 4),
                  Text('${s.votes}',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w900, color: voted ? Colors.white : _C.rose)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mineList() {
    final l = _mine;
    if (l.isEmpty) {
      return _empty('Vous n\'avez encore rien proposé.\nLes mariés valideront vos titres.', Icons.lightbulb_outline_rounded);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
      itemCount: l.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = l[i];
        final c = kPlaylistStatusColor[s.status] ?? _C.ink2;
        return ThixGlass(
          radius: 18,
          opacity: 0.62,
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: _C.ink)),
                    Text(s.artist ?? 'Artiste inconnu',
                        style: GoogleFonts.inter(fontSize: 11.5, color: _C.ink2)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  s.isAvoid ? 'Non retenue' : (kPlaylistStatusLabel[s.status] ?? s.status),
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: c),
                ),
              ),
              if (s.status == 'pending')
                IconButton(
                  tooltip: 'Retirer',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: _C.rose),
                  onPressed: () => _deleteMine(s),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        );
      },
    );
  }
}
