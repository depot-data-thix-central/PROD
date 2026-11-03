// lib/presentation/thix_weeding/pages/guest/meal_preferences_page.dart
// ============================================================================
// THIX WEDDING — PRÉFÉRENCES REPAS CÔTÉ INVITÉ
// ============================================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/content/staff_content_pages.dart'
    show MenuEntry, kMenuCourses, kMenuCourseIcons, kMenuTags;
import 'package:thix_id/presentation/thix_weeding/pages/staff/messages/message_media.dart';
import 'package:thix_id/presentation/thix_weeding/widgets/thix_glass.dart';

class _G {
  static const rose = Color(0xFFD81B60);
  static const roseSoft = Color(0xFFFCE4EC);
  static const green = Color(0xFF059669);
  static const gold = Color(0xFFD4AF37);
  static const ink = Color(0xFF241521);
  static const ink2 = Color(0xFF8A7580);
  static const grad = LinearGradient(
    colors: [Color(0xFFE91E78), Color(0xFFC2185B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

String _msg(Object e) => e is PostgrestException ? e.message : '$e';

class MealPreferencesPage extends StatefulWidget {
  final String weddingId;
  const MealPreferencesPage({super.key, required this.weddingId});

  @override
  State<MealPreferencesPage> createState() => _MealPreferencesPageState();
}

class _MealPreferencesPageState extends State<MealPreferencesPage> {
  final _supa = Supabase.instance.client;
  final _note = TextEditingController();

  List<MenuEntry> _dishes = [];
  List<MenuEntry> _mine = [];
  Map<String, String> _myChoice = {}; 
  bool _votingOpen = true;
  bool _suggestOpen = true;
  int _persons = 1;
  String? _guestId;
  String? _myName;
  final Set<String> _myTags = {};
  bool _dietLoaded = false;
  bool _savingDiet = false;

  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  RealtimeChannel? _ch;
  Timer? _deb;

  String? get _uid => _supa.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
    PostgresChangeFilter f() => PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'wedding_id',
        value: widget.weddingId);
    void cb(PostgresChangePayload _) {
      _deb?.cancel();
      _deb = Timer(const Duration(milliseconds: 500), () {
        if (mounted) _load(silent: true);
      });
    }

    _ch = _supa
        .channel('guest-menu-${widget.weddingId}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'thix_weeding_menu_items',
            filter: f(),
            callback: cb)
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'thix_weeding_menu_settings',
            filter: f(),
            callback: cb)
        .subscribe();
  }

  @override
  void dispose() {
    _deb?.cancel();
    if (_ch != null) _supa.removeChannel(_ch!);
    _note.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final id = widget.weddingId;
      final uid = _uid;

      final rows = await _supa
          .from('thix_weeding_menu_items')
          .select()
          .eq('wedding_id', id)
          .order('position', ascending: true)
          .order('created_at', ascending: true);
      final all = (rows as List)
          .map((e) => MenuEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      var voting = true, suggest = true;
      try {
        final s = await _supa
            .from('thix_weeding_menu_settings')
            .select()
            .eq('wedding_id', id)
            .maybeSingle();
        if (s != null) {
          voting = s['voting_open'] != false;
          suggest = s['suggestions_open'] != false;
        }
      } catch (_) {}

      final choice = <String, String>{};
      var persons = _persons;
      String? guestId = _guestId;
      String? myName = _myName;
      if (uid != null) {
        try {
          final v = await _supa
              .from('thix_weeding_menu_votes')
              .select('item_id, course')
              .eq('wedding_id', id)
              .eq('user_id', uid);
          for (final r in (v as List)) {
            choice['${r['course']}'] = '${r['item_id']}';
          }
        } catch (_) {}
        try {
          final g = await _supa
              .from('thix_weeding_guests')
              .select('id, name, guests_count')
              .eq('wedding_id', id)
              .eq('user_id', uid)
              .maybeSingle();
          if (g != null) {
            guestId = '${g['id']}';
            myName = '${g['name'] ?? ''}'.trim();
            persons = math.max(1, (g['guests_count'] as num?)?.toInt() ?? 1);
          }
        } catch (_) {}
        if (!_dietLoaded) {
          try {
            final d = await _supa
                .from('thix_weeding_menu_diets')
                .select()
                .eq('wedding_id', id)
                .eq('user_id', uid)
                .maybeSingle();
            if (d != null) {
              _myTags
                ..clear()
                ..addAll(((d['tags'] as List?) ?? const []).map((e) => '$e'));
              final n = '${d['note'] ?? ''}';
              _note.text = n == 'null' ? '' : n;
            }
          } catch (_) {}
          _dietLoaded = true;
        }
      }

      if (!mounted) return;
      setState(() {
        _dishes = all.where((e) {
          if (e.source == 'staff') return e.published;
          return e.published && e.status == 'approved';
        }).toList();
        
        _mine = uid == null ? [] : all.where((e) => e.suggestedBy == uid).toList();
        
        _myChoice = choice;
        _votingOpen = voting;
        _suggestOpen = suggest;
        _persons = persons;
        _guestId = guestId;
        _myName = myName;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: error ? _G.rose : _G.green,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _choose(MenuEntry d) async {
    if (_uid == null) {
      _toast('Connectez-vous pour choisir vos plats', error: true);
      return;
    }
    if (!_votingOpen) {
      _toast('Les votes sont clos', error: true);
      return;
    }
    if (_busy.contains(d.id)) return;
    setState(() => _busy.add(d.id));
    try {
      await _supa.rpc('thix_weeding_menu_choose', params: {'p_item_id': d.id});
      HapticFeedback.mediumImpact();
      await _load(silent: true);
    } catch (e) {
      _toast(_msg(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(d.id));
    }
  }

  Future<void> _deleteMine(MenuEntry e) async {
    try {
      await _supa.from('thix_weeding_menu_items').delete().eq('id', e.id);
      await _load(silent: true);
    } catch (err) {
      _toast(_msg(err), error: true);
    }
  }

  Future<void> _saveDiet() async {
    final uid = _uid;
    if (uid == null) {
      _toast('Connectez-vous pour enregistrer votre régime', error: true);
      return;
    }
    setState(() => _savingDiet = true);
    try {
      await _supa.from('thix_weeding_menu_diets').upsert({
        'wedding_id': widget.weddingId,
        'user_id': uid,
        'guest_id': _guestId,
        'tags': _myTags.toList(),
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'wedding_id,user_id');
      FocusScope.of(context).unfocus();
      _toast('Merci ! Le traiteur en tiendra compte 🙏');
    } catch (e) {
      _toast(_msg(e), error: true);
    } finally {
      if (mounted) setState(() => _savingDiet = false);
    }
  }

  void _openSuggest(String course) {
    if (_uid == null) {
      _toast('Connectez-vous pour suggérer un plat', error: true);
      return;
    }
    if (_mine.length >= 3) {
      _toast('Vous avez atteint la limite de 3 suggestions', error: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuggestSheet(
        weddingId: widget.weddingId,
        myName: _myName,
        initialCourse: course,
        onDone: () {
          _toast('Suggestion envoyée — les mariés vont la valider 🍽️');
          _load(silent: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: const ThixGlassBar(),
        elevation: 0,
        foregroundColor: _G.ink,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Text('Menu & votes',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
      ),
      body: ThixGlassBackdrop(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _G.rose))
            : _error != null
                ? _empty(Icons.error_outline_rounded,
                    'Menu indisponible pour le moment.')
                : RefreshIndicator(
                    color: _G.rose,
                    onRefresh: () => _load(silent: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 50),
                      children: [
                        _intro(),
                        const SizedBox(height: 14),
                        if (_dishes.isEmpty && _mine.isEmpty && !_suggestOpen)
                          SizedBox(
                            height: 260,
                            child: _empty(Icons.restaurant_menu_rounded,
                                'Le menu n\'est pas encore publié.'),
                          )
                        else
                          for (final c in kMenuCourses.keys)
                            ..._courseSection(c),
                        const SizedBox(height: 18),
                        _dietCard(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _empty(IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: _G.rose.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(text,
                  textAlign: TextAlign.center,
                  style:
                      GoogleFonts.inter(color: _G.ink2, height: 1.4)),
            ],
          ),
        ),
      );

  Widget _chip(String t, {Color color = _G.rose}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9)),
        child: Text(t,
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color)),
      );

  Widget _intro() {
    final courses = kMenuCourses.keys
        .where((c) => _dishes.any((d) => d.course == c))
        .toList();
    final done = courses.where((c) => _myChoice.containsKey(c)).length;
    final ratio = courses.isEmpty ? 0.0 : done / courses.length;
    return ThixGlass(
      radius: 24,
      opacity: 0.65,
      borderColor: _G.rose.withOpacity(0.2),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration:
                  const BoxDecoration(gradient: _G.grad, shape: BoxShape.circle),
              child: Icon(
                  _votingOpen
                      ? Icons.how_to_vote_rounded
                      : Icons.lock_rounded,
                  color: Colors.white,
                  size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _votingOpen
                    ? 'Choisissez vos plats préférés'
                    : 'Les votes sont clos — merci !',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _G.ink),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            _votingOpen
                ? 'Les mariés commanderont les plats les plus choisis. Touchez « Choisir » sur un plat par rubrique.'
                : 'Les mariés préparent maintenant la commande selon les choix de chacun.',
            style: GoogleFonts.inter(
                fontSize: 12, color: _G.ink2, height: 1.4),
          ),
          if (_uid != null && _persons > 1) ...[
            const SizedBox(height: 6),
            Text(
                'Votre choix compte pour $_persons personnes (votre groupe).',
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: _G.rose,
                    fontWeight: FontWeight.w800)),
          ],
          if (_uid == null) ...[
            const SizedBox(height: 6),
            Text('Connectez-vous pour voter et suggérer des plats.',
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: _G.rose,
                    fontWeight: FontWeight.w800)),
          ],
          if (courses.isNotEmpty && _uid != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: Colors.white.withOpacity(0.7),
                valueColor: const AlwaysStoppedAnimation(_G.green),
              ),
            ),
            const SizedBox(height: 5),
            Text(
                done == courses.length
                    ? 'Tout est choisi ✓'
                    : '$done / ${courses.length} rubriques choisies',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _G.ink2,
                    fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }

  List<Widget> _courseSection(String c) {
    final list = _dishes.where((d) => d.course == c).toList();
    
    // On ne masque la rubrique que si elle est vide ET qu'on ne peut pas suggérer
    if (list.isEmpty && !_suggestOpen && _mine.where((e) => e.course == c).isEmpty) {
      return const [];
    }

    final maxVotes = list.isEmpty ? 0 : list.map((d) => d.votes).fold<int>(0, math.max);
    final mySuggestions = _mine.where((e) => e.course == c).toList();

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
                gradient: _G.grad, shape: BoxShape.circle),
            child: Icon(kMenuCourseIcons[c], size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(kMenuCourses[c]!,
              style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _G.ink)),
          const Spacer(),
          if (_myChoice.containsKey(c)) _chip('Choisi ✓', color: _G.green),
        ]),
      ),
      
      // Plats du staff
      ...list.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _dish(d, maxVotes))),

      // Suggestions de l'invité
      ...mySuggestions.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _mySuggestionTile(e))),

      // Bouton pour proposer un plat
      if (_suggestOpen)
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 4),
          child: OutlinedButton.icon(
            onPressed: () => _openSuggest(c),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Proposer un plat en ${kMenuCourses[c]?.toLowerCase()}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _G.rose,
              side: BorderSide(color: _G.rose.withOpacity(0.3), style: BorderStyle.solid),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 44),
              backgroundColor: Colors.white.withOpacity(0.5),
            ),
          ),
        ),
      const SizedBox(height: 6),
    ];
  }

  Widget _dish(MenuEntry d, int maxVotes) {
    final chosen = _myChoice[d.course] == d.id;
    final leader = maxVotes > 0 && d.votes == maxVotes;
    final busy = _busy.contains(d.id);
    
    return ThixGlass(
      radius: 22,
      opacity: chosen ? 0.82 : 0.62,
      borderColor: chosen ? _G.rose : _G.rose.withOpacity(0.15),
      padding: EdgeInsets.zero,
      // ✅ FIX : IntrinsicHeight empêche le Row de prendre une hauteur infinie dans la liste
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (d.imageUrl != null)
              GestureDetector(
                onTap: () => showPhotoViewer(context, [d.imageUrl!]),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(22)),
                  child: SizedBox(
                    width: 104,
                    child: Image.network(d.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: _G.roseSoft)),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, // Centre le texte si l'image est plus grande
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(d.name,
                            style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: _G.ink)),
                      ),
                      if (leader) _chip('🔥 Le plus choisi', color: _G.gold),
                    ]),
                    if (d.description != null) ...[
                      const SizedBox(height: 3),
                      Text(d.description!,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _G.ink2,
                              height: 1.35)),
                    ],
                    if (d.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: d.tags
                              .map((t) => _chip(kMenuTags[t] ?? t))
                              .toList()),
                    ],
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: maxVotes == 0 ? 0 : d.votes / maxVotes,
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.7),
                        valueColor:
                            AlwaysStoppedAnimation(leader ? _G.gold : _G.rose),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(
                          d.votes == 0
                              ? 'Aucun choix pour l\'instant'
                              : '${d.votes} choix',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _G.ink2,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      SizedBox(
                        height: 34,
                        child: chosen
                            ? FilledButton.icon(
                                onPressed:
                                    !_votingOpen || busy ? null : () => _choose(d),
                                icon: busy
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.check_circle_rounded,
                                        size: 16),
                                label: const Text('Mon choix'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _G.rose,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  textStyle: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                ),
                              )
                            : OutlinedButton(
                                onPressed:
                                    !_votingOpen || busy ? null : () => _choose(d),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _G.rose,
                                  side: BorderSide(
                                      color: _G.rose.withOpacity(0.6)),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  textStyle: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                ),
                                child: busy
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Text('Choisir'),
                              ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mySuggestionTile(MenuEntry e) {
    final statusColor = {
      'pending': _G.gold,
      'approved': _G.green,
      'rejected': _G.rose
    };
    final statusLabel = {
      'pending': 'En attente',
      'approved': 'Ajouté au menu ✓',
      'rejected': 'Non retenu'
    };
    
    return ThixGlass(
      radius: 16,
      opacity: 0.5,
      borderColor: _G.gold.withOpacity(0.3),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: _G.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Votre suggestion : ${e.name}',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _G.ink)),
                const SizedBox(height: 2),
                _chip(statusLabel[e.status] ?? e.status, color: statusColor[e.status] ?? _G.ink2),
              ],
            ),
          ),
          if (e.status == 'pending')
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline_rounded, size: 19, color: _G.rose),
              onPressed: () => _deleteMine(e),
            ),
        ],
      ),
    );
  }

  Widget _dietCard() {
    final diets = kMenuTags.entries.where((e) => e.key != 'epice');
    return ThixGlass(
      radius: 24,
      opacity: 0.62,
      borderColor: _G.rose.withOpacity(0.15),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.health_and_safety_outlined, color: _G.rose),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Régime & allergies',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _G.ink)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Aidez le traiteur à bien préparer le repas.',
              style: GoogleFonts.inter(fontSize: 12, color: _G.ink2)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: diets
                .map((e) => FilterChip(
                      label: Text(e.value,
                          style: const TextStyle(fontSize: 12)),
                      selected: _myTags.contains(e.key),
                      selectedColor: _G.roseSoft,
                      checkmarkColor: _G.rose,
                      onSelected: (v) => setState(
                          () => v ? _myTags.add(e.key) : _myTags.remove(e.key)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              labelText: 'Allergies ou remarques (arachides, fruits de mer…)',
              filled: true,
              fillColor: Colors.white.withOpacity(0.7),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _savingDiet ? null : _saveDiet,
              icon: _savingDiet
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _G.rose,
                side: BorderSide(color: _G.rose.withOpacity(0.6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestSheet extends StatefulWidget {
  final String weddingId;
  final String? myName;
  final String initialCourse;
  final VoidCallback onDone;
  const _SuggestSheet({
    required this.weddingId,
    required this.myName,
    required this.initialCourse,
    required this.onDone,
  });

  @override
  State<_SuggestSheet> createState() => _SuggestSheetState();
}

class _SuggestSheetState extends State<_SuggestSheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  late String _course;
  PickedPhoto? _photo;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _course = widget.initialCourse;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final p = await pickPhotos(max: 1);
      if (p.isNotEmpty) setState(() => _photo = p.first);
    } catch (e) {
      setState(() => _error = 'Galerie inaccessible : $e');
    }
  }

  Future<void> _send() async {
    final n = _name.text.trim();
    if (n.isEmpty) {
      setState(() => _error = 'Indiquez le nom du plat');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? url;
      if (_photo != null) {
        final urls = await uploadPhotos(widget.weddingId, [_photo!]);
        url = urls.first;
      }
      await Supabase.instance.client.from('thix_weeding_menu_items').insert({
        'wedding_id': widget.weddingId,
        'course': _course,
        'name': n,
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'image_url': url,
        'suggested_by': Supabase.instance.client.auth.currentUser?.id,
        'suggested_by_name': (widget.myName ?? '').isEmpty ? null : widget.myName,
        'source': 'guest', 
        'status': 'pending', 
      });
      widget.onDone();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.88),
        child: ThixGlass(
          radius: 28,
          opacity: 0.85,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Proposer un plat',
                    style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _G.ink)),
                Text('Les mariés valideront votre suggestion.',
                    style: GoogleFonts.inter(
                        fontSize: 11.5, color: _G.ink2)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: kMenuCourses.entries
                      .map((e) => ChoiceChip(
                            label: Text(e.value,
                                style: const TextStyle(fontSize: 12)),
                            selected: _course == e.key,
                            onSelected: (_) =>
                                setState(() => _course = e.key),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _name,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: 'Nom du plat *',
                    prefixIcon: const Icon(Icons.restaurant_rounded,
                        size: 19, color: _G.rose),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.7),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _desc,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    labelText: 'Pourquoi ce plat ? (optionnel)',
                    prefixIcon: const Icon(Icons.notes_rounded,
                        size: 19, color: _G.rose),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.7),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  if (_photo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(_photo!.bytes,
                          width: 64, height: 64, fit: BoxFit.cover),
                    ),
                  if (_photo != null) const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.add_photo_alternate_outlined,
                        size: 18),
                    label: Text(
                        _photo == null ? 'Ajouter une photo' : 'Changer'),
                  ),
                  if (_photo != null)
                    TextButton(
                        onPressed: () => setState(() => _photo = null),
                        child: const Text('Retirer')),
                ]),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(
                          color: _G.rose,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _G.rose,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _busy ? null : _send,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Envoyer ma suggestion',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
