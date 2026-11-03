// lib/presentation/thix_weeding/pages/guest/guest_playlist_page.dart
// ============================================================================
// THIX WEDDING — PLAYLIST (INVITÉ) — AVEC LECTEUR AUDIO INTÉGRÉ
// ✅ Lecture intégrée des fichiers audio du staff (via just_audio)
// ✅ Upload de fichiers locaux pour les propositions des invités (Web & Mobile)
// ============================================================================
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // ✅ AJOUTÉ : pour kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';

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
  // ❌ _link supprimé
  final _name = TextEditingController();

  List<PlaylistSong> _songs = [];
  Set<String> _myVotes = {};
  String? _guestId;
  bool _knownName = false;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  final Set<String> _voting = {};

  // 🎵 Variables d'upload
  bool _uploadingAudio = false;
  String? _uploadedAudioUrl;
  String? _uploadedAudioName;

  // 🎵 Lecteur audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlaying;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

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

    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
  }

  @override
  void dispose() {
    _deb?.cancel();
    if (_ch != null) _supa.removeChannel(_ch!);
    _tab.dispose();
    _title.dispose();
    _artist.dispose();
    // ❌ _link.dispose() supprimé
    _name.dispose();
    _audioPlayer.dispose();
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

  // ✅ CHARGER UN FICHIER AUDIO LOCAL
  Future<void> _pickAndUploadAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true, // ⚠️ IMPORTANT : Obligatoire pour le Web
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null && file.path == null) {
        _toast('Erreur : Impossible de lire le fichier', error: true);
        return;
      }

      setState(() => _uploadingAudio = true);

      final fileName = file.name;
      final storagePath = 'guests/${widget.weddingId}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final mimeType = lookupMimeType(fileName) ?? 'audio/mpeg';

      // ⚠️ Utilisation de file.bytes sur le Web
      final fileBytes = kIsWeb 
          ? file.bytes! 
          : await File(file.path!).readAsBytes();

      await _supa.storage.from('thix-playlist-audio').uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: FileOptions(cacheControl: '3600', contentType: mimeType, upsert: false),
      );

      final audioUrl = _supa.storage.from('thix-playlist-audio').getPublicUrl(storagePath);
      
      setState(() {
        _uploadedAudioUrl = audioUrl;
        _uploadedAudioName = fileName;
        // Pré-remplir le titre avec le nom du fichier (sans l'extension)
        if (_title.text.trim().isEmpty) {
          _title.text = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
        }
      });
      _toast('Fichier chargé avec succès ✓');
    } catch (e) {
      _toast('Erreur upload : $e', error: true);
    } finally {
      if (mounted) setState(() => _uploadingAudio = false);
    }
  }

  Future<void> _playTrack(PlaylistSong track) async {
    final url = track.audioUrl ?? track.linkUrl;
    if (url == null) return;

    try {
      if (_currentlyPlaying == track.id) {
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play();
        }
        return;
      }

      setState(() {
        _currentlyPlaying = track.id;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      setState(() => _currentlyPlaying = null);
      _toast('Erreur lecture : $e', error: true);
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _currentlyPlaying = null;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
  }

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
        'audio_url': _uploadedAudioUrl, // ✅ Ajout de l'URL locale
        'link_url': _uploadedAudioUrl,  // Gardé pour compatibilité avec l'existant
        'requested_by_name': _name.text.trim(),
        'guest_id': _guestId,
        'source': _uploadedAudioUrl != null ? 'guest_local' : 'guest',
      });
      _title.clear();
      _artist.clear();
      setState(() {
        _uploadedAudioUrl = null;
        _uploadedAudioName = null;
      });
      HapticFeedback.mediumImpact();
      _toast('Proposition envoyée — en attente de validation 🎶');
      await _load(silent: true);
      _tab.animateTo(1);
    } catch (e) {
      final s = '$e';
      if (s.contains('23505') || s.contains('duplicate')) {
        _toast('Ce titre a déjà été proposé — votez pour lui !', error: true);
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
      // Supprimer aussi le fichier du storage si c'est un fichier invité
      if (s.audioUrl != null && s.audioUrl!.contains('supabase.co/storage')) {
        try {
          final uri = Uri.parse(s.audioUrl!);
          final pathSegments = uri.pathSegments;
          final bucketIdx = pathSegments.indexOf('object');
          if (bucketIdx >= 0 && bucketIdx + 2 < pathSegments.length) {
            final storagePath = pathSegments.sublist(bucketIdx + 2).join('/');
            await _supa.storage.from('thix-playlist-audio').remove([storagePath]);
          }
        } catch (_) {}
      }
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

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
                      if (_currentlyPlaying != null) _playerBar(),
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

  Widget _playerBar() {
    final track = _songs.where((s) => s.id == _currentlyPlaying).firstOrNull;
    if (track == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_C.rose.withOpacity(0.15), _C.green.withOpacity(0.15)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.rose.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.rose, Color(0xFFE91E78)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _C.ink)),
                    Text(track.artist ?? 'Artiste inconnu', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11, color: _C.ink2)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _audioPlayer.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: _C.rose,
                  size: 36,
                ),
                onPressed: () async {
                  if (_audioPlayer.playing) {
                    await _audioPlayer.pause();
                  } else {
                    await _audioPlayer.play();
                  }
                  setState(() {});
                },
              ),
              IconButton(
                icon: const Icon(Icons.stop_circle_rounded, color: _C.ink2),
                onPressed: _stopAudio,
              ),
            ],
          ),
          if (_duration.inSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Text(_formatDuration(_position), style: GoogleFonts.inter(fontSize: 10, color: _C.ink2)),
                  Expanded(
                    child: Slider(
                      value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                      max: _duration.inSeconds.toDouble(),
                      onChanged: (v) async {
                        await _audioPlayer.seek(Duration(seconds: v.toInt()));
                      },
                      activeColor: _C.rose,
                      inactiveColor: _C.rose.withOpacity(0.2),
                    ),
                  ),
                  Text(_formatDuration(_duration), style: GoogleFonts.inter(fontSize: 10, color: _C.ink2)),
                ],
              ),
            ),
        ],
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
            
            // ✅ ZONE D'UPLOAD REMPLAÇANT LE CHAMP LIEN
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.rose,
                      side: BorderSide(color: _C.rose.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _uploadingAudio ? null : _pickAndUploadAudio,
                    icon: _uploadingAudio 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _C.rose))
                        : const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(
                      _uploadedAudioName ?? 'Charger un fichier audio (MP3/WAV)', 
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_uploadedAudioUrl != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: _C.rose, size: 20),
                    onPressed: () => setState(() {
                      _uploadedAudioUrl = null;
                      _uploadedAudioName = null;
                    }),
                  ),
              ],
            ),
            
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
    final isPlaying = _currentlyPlaying == s.id;
    final hasAudio = s.audioUrl != null;
    final isStaffLocal = s.source == 'staff_local';
    final isGuestLocal = s.source == 'guest_local'; // ✅ Nouveau badge

    return ThixGlass(
      radius: 18,
      opacity: 0.62,
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Row(
        children: [
          hasAudio
              ? GestureDetector(
                  onTap: () => _playTrack(s),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: isPlaying ? _C.rose.withOpacity(0.2) : _C.green.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying
                          ? (_audioPlayer.playing ? Icons.pause_rounded : Icons.play_arrow_rounded)
                          : Icons.play_arrow_rounded,
                      color: isPlaying ? _C.rose : _C.green,
                      size: 20,
                    ),
                  ),
                )
              : Container(
                  width: 36, height: 36, alignment: Alignment.center,
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
                    child: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: _C.ink)),
                  ),
                  if (s.isMust) const Padding(padding: EdgeInsets.only(left: 5), child: Text('⭐')),
                  if (isStaffLocal) const Padding(padding: EdgeInsets.only(left: 5), child: Text('📁')),
                  if (isGuestLocal) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.person, size: 12, color: _C.rose)),
                ]),
                Text(s.artist ?? 'Artiste inconnu',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11.5, color: _C.ink2)),
                if (played)
                  Text('Déjà jouée',
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF6B46C1), fontWeight: FontWeight.w800)),
                if (isStaffLocal && !played)
                  Text('Titre des mariés',
                      style: GoogleFonts.inter(fontSize: 10, color: _C.rose, fontWeight: FontWeight.w700)),
                if (isGuestLocal && !played)
                  Text('Fichier invité',
                      style: GoogleFonts.inter(fontSize: 10, color: _C.rose, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (!hasAudio && s.linkUrl != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.open_in_new_rounded, color: _C.ink2),
              onPressed: () => _open(s.linkUrl!),
              tooltip: 'Ouvrir dans YouTube/Spotify',
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
                    Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
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
