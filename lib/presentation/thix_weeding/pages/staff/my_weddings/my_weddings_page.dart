// lib/presentation/thix_weeding/pages/staff/my_weddings/my_weddings_page.dart
// ============================================================================
// THIX WEDDING — MES MARIAGES (v3)
// ✅ Liste = mariages CRÉÉS + mariages REJOINTS (équipe) — rien d'obligatoire
// ✅ Bouton + : créer un ou plusieurs mariages quand on veut
// ✅ Recherche (code THIX-W-…, nom, uuid) → Demander accès / Ouvrir / En attente
// ✅ Demandes d'accès reçues avec le NOM du demandeur (✓ / ✗ via RPC sécurisée)
// ✅ Temps réel : un accès accepté apparaît aussitôt chez le membre
// ============================================================================
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

TextStyle _mono({double? fontSize, FontWeight? fontWeight, Color? color}) => TextStyle(
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: 0.5,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );

class _R {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color gold = Color(0xFFB8860B);
  static const Color rose = Color(0xFFE31C4E);
  static const Color green = Color(0xFF059669);
  static const Color amber = Color(0xFFD97706);
  static const Color cream = Color(0xFFFFFBF5);
  static const Color text = Color(0xFF111827);
  static const Color text2 = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  static const LinearGradient roseG = LinearGradient(
    colors: [rose, Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

List<Map<String, dynamic>> _maps(dynamic r) =>
    (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

String _err(Object e) => e is PostgrestException ? e.message : '$e';

String? _s(dynamic v) {
  final s = v == null ? '' : '$v'.trim();
  return (s.isEmpty || s == 'null') ? null : s;
}

// ============================================================================
// PAGE
// ============================================================================
class MyWeddingsPage extends ConsumerStatefulWidget {
  const MyWeddingsPage({super.key});

  @override
  ConsumerState<MyWeddingsPage> createState() => _MyWeddingsPageState();
}

class _MyWeddingsPageState extends ConsumerState<MyWeddingsPage> {
  final _supa = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  List<Map<String, dynamic>> _weddings = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _results = [];

  bool _loading = true;
  String? _error;
  bool _searching = false;
  bool _hasSearched = false;
  final Set<String> _busy = {};

  RealtimeChannel? _ch;
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    _load();
    final uid = _supa.auth.currentUser?.id;
    if (uid != null) {
      _ch = _supa
          .channel('my-weddings-$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'thix_weeding_staff_members',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
            callback: (_) => _schedule(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'thix_weeding_staff_requests',
            callback: (_) => _schedule(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'thix_weeding_weddings',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq, column: 'owner_id', value: uid),
            callback: (_) => _schedule(),
          )
          .subscribe();
    }
  }

  void _schedule() {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _deb?.cancel();
    if (_ch != null) _supa.removeChannel(_ch!);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ───────────────────────── DONNÉES ─────────────────────────
  Future<void> _load({bool silent = false}) async {
    try {
      final w = _maps(await _supa.rpc('thix_weeding_my_weddings'));
      var req = <Map<String, dynamic>>[];
      try {
        req = _maps(await _supa.rpc('thix_weeding_all_pending_requests'));
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _weddings = w;
        _requests = req;
        _loading = false;
        _error = null;
      });
      // rafraîchit aussi l'ancien provider (autres écrans)
      final uid = _supa.auth.currentUser?.id;
      if (uid != null) ref.invalidate(myWeddingsProvider(uid));
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() { _loading = false; _error = _err(e); });
    }
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 3) {
      setState(() {
        _results = [];
        _hasSearched = q.isNotEmpty;
      });
      if (q.isNotEmpty) _toast('Saisissez au moins 3 caractères', error: true);
      return;
    }
    setState(() { _searching = true; _hasSearched = true; });
    try {
      final r = _maps(await _supa.rpc('thix_weeding_search_weddings', params: {'p_q': q}));
      if (!mounted) return;
      setState(() => _results = r);
    } catch (e) {
      if (mounted) {
        setState(() => _results = []);
        _toast(_err(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _requestAccess(String weddingId) async {
    if (_busy.contains(weddingId)) return;
    setState(() => _busy.add(weddingId));
    try {
      await _supa.rpc('thix_weeding_request_access', params: {'p_wedding': weddingId});
      _toast('Demande envoyée au propriétaire !');
      await _search();
    } catch (e) {
      _toast(_err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(weddingId));
    }
  }

  Future<void> _resolve(String requestId, bool accept) async {
    if (_busy.contains(requestId)) return;
    setState(() => _busy.add(requestId));
    try {
      await _supa.rpc('thix_weeding_resolve_staff_request',
          params: {'p_request': requestId, 'p_approve': accept});
      _toast(accept ? 'Accès accordé ✓' : 'Demande refusée');
      await _load(silent: true);
    } catch (e) {
      _toast(_err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(requestId));
    }
  }

  Future<void> _delete(Map<String, dynamic> w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce mariage ?'),
        content: const Text('Toutes ses données seront supprimées définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: _R.rose)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(weddingServiceProvider).delete('${w['id']}');
      await _load(silent: true);
    } catch (e) {
      _toast(_err(e), error: true);
    }
  }

  Future<void> _leave(Map<String, dynamic> w) async {
    final uid = _supa.auth.currentUser?.id;
    if (uid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter l\'équipe ?'),
        content: const Text('Vous n\'aurez plus accès à ce mariage.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter', style: TextStyle(color: _R.rose)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _supa
          .from('thix_weeding_staff_members')
          .delete()
          .eq('wedding_id', '${w['id']}')
          .eq('user_id', uid);
      await _load(silent: true);
    } catch (e) {
      _toast(_err(e), error: true);
    }
  }

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: error ? _R.rose : _R.green,
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ───────────────────────── BUILD ─────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_supa.auth.currentUser == null) {
      return const Scaffold(body: Center(child: Text('Veuillez vous connecter.')));
    }

    return Scaffold(
      backgroundColor: _R.cream,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _R.rose))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Erreur : $_error\n(SQL « Mes mariages » exécuté ?)', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _R.rose),
                        onPressed: () {
                          setState(() => _loading = true);
                          _load();
                        },
                        child: const Text('Réessayer'),
                      ),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  color: _R.rose,
                  onRefresh: () => _load(silent: true),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    slivers: [
                      _header(),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _searchBar(),
                            const SizedBox(height: 16),
                            if (_hasSearched) _searchResults(),
                            if (_requests.isNotEmpty) _incomingRequests(),
                            if (_weddings.isNotEmpty) ...[
                              Text('Mes événements',
                                  style: GoogleFonts.inter(
                                      fontSize: 18, fontWeight: FontWeight.w900, color: _R.text)),
                              const SizedBox(height: 12),
                              ..._weddings.map((w) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _card(w),
                                  )),
                            ] else
                              _empty(),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ───────────────────────── EN-TÊTE ─────────────────────────
  Widget _header() {
    final n = _weddings.length;
    return SliverAppBar(
      expandedHeight: 170,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: _R.roseG,
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
        ),
        child: FlexibleSpaceBar(
          background: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _circleBtn(Icons.arrow_back_ios_new, () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/thix-weeding');
                      }
                    }),
                    const Spacer(),
                    _circleBtn(Icons.add_rounded, () => context.push('/thix-weeding/create'),
                        color: _R.rose, size: 22),
                  ]),
                  const Spacer(),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(9)),
                      child: const Icon(Icons.favorite, color: Colors.white, size: 15),
                    ),
                    const SizedBox(width: 8),
                    Text('MES MARIAGES',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                            color: Colors.white.withOpacity(0.92))),
                  ]),
                  const SizedBox(height: 6),
                  Text('Gérez vos événements',
                      style: GoogleFonts.inter(
                          fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text(
                    n == 0 ? 'Aucun mariage pour le moment' : '$n mariage${n > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white.withOpacity(0.92)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {Color color = _R.text, double size = 15}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8)],
        ),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }

  // ───────────────────────── RECHERCHE ─────────────────────────
  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Rejoindre un mariage : code (THIX-W-…), nom ou ID',
          hintStyle: GoogleFonts.inter(fontSize: 12.5, color: _R.text2),
          prefixIcon: const Icon(Icons.search, color: _R.blue),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: _R.text2),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _results = [];
                      _hasSearched = false;
                    });
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: _R.blue),
                  onPressed: _search,
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  Widget _searchResults() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: _R.rose)),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Text('Aucun mariage trouvé pour cette recherche.',
            style: GoogleFonts.inter(color: _R.text2, fontStyle: FontStyle.italic)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Résultats de recherche (${_results.length})',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _R.text)),
        const SizedBox(height: 10),
        ..._results.map((w) {
          final id = '${w['id']}';
          final status = '${w['my_status'] ?? 'none'}';
          final name = _s(w['couple_names']) ?? 'Mariage sans nom';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _R.border),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(_s(w['unique_code']) ?? '', style: _mono(fontSize: 11, color: _R.blue)),
                ]),
              ),
              const SizedBox(width: 8),
              if (status == 'owner' || status == 'member')
                OutlinedButton(
                  onPressed: () => context.push('/thix-weeding/staff/$id'),
                  child: const Text('Ouvrir'),
                )
              else if (status == 'pending')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                      color: _R.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text('Demande envoyée',
                      style: GoogleFonts.inter(
                          fontSize: 11.5, fontWeight: FontWeight.w800, color: _R.amber)),
                )
              else
                ElevatedButton.icon(
                  onPressed: _busy.contains(id) ? null : () => _requestAccess(id),
                  icon: _busy.contains(id)
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('Demander accès'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _R.blue.withOpacity(0.1),
                    foregroundColor: _R.blue,
                    elevation: 0,
                  ),
                ),
            ]),
          );
        }),
        const Divider(height: 28),
      ],
    );
  }

  // ───────────────────────── DEMANDES REÇUES ─────────────────────────
  Widget _incomingRequests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.notifications_active, color: _R.amber, size: 20),
          const SizedBox(width: 8),
          Text('Demandes d\'accès (${_requests.length})',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _R.text)),
        ]),
        const SizedBox(height: 10),
        ..._requests.map((r) {
          final id = '${r['id']}';
          final busy = _busy.contains(id);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _R.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _R.amber.withOpacity(0.3)),
            ),
            child: Row(children: [
              const CircleAvatar(
                  backgroundColor: Colors.white, child: Icon(Icons.person, color: _R.amber)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_s(r['requester_name']) ?? 'Utilisateur THIX',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  Text('Souhaite rejoindre « ${_s(r['couple_names']) ?? 'votre mariage'} »',
                      style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
                ]),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.check_circle, color: _R.green),
                  onPressed: () => _resolve(id, true),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: _R.rose),
                  onPressed: () => _resolve(id, false),
                ),
              ],
            ]),
          );
        }),
        const Divider(height: 28),
      ],
    );
  }

  // ───────────────────────── CARTE MARIAGE ─────────────────────────
  Widget _card(Map<String, dynamic> w) {
    final id = '${w['id']}';
    final isOwner = '${w['my_role']}' == 'owner';
    final name = _s(w['couple_names']) ?? 'Mariage sans nom';
    final venue = _s(w['venue']) ?? 'Lieu à définir';
    final code = _s(w['unique_code']) ?? '';
    final published = w['invitation_published'] == true;
    final date = DateTime.tryParse('${w['wedding_date']}')?.toLocal();
    final days = date == null ? null : date.difference(DateTime.now()).inDays;
    final shortId = id.replaceAll('-', '').substring(0, 8).toUpperCase();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/thix-weeding/staff/$id'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: published ? _R.green.withOpacity(0.3) : _R.border,
              width: published ? 1.5 : 1,
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                    gradient: _R.roseG, borderRadius: BorderRadius.all(Radius.circular(16))),
                child: const Center(child: Icon(Icons.favorite, color: Colors.white, size: 27)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 15.5, fontWeight: FontWeight.w900, color: _R.text)),
                    ),
                    const SizedBox(width: 6),
                    _pill(published ? 'Publié' : 'Brouillon',
                        published ? _R.green : _R.amber, filled: published),
                  ]),
                  const SizedBox(height: 5),
                  Wrap(spacing: 10, runSpacing: 2, children: [
                    if (date != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.calendar_today_outlined, size: 12, color: _R.text2),
                        const SizedBox(width: 4),
                        Text(_fmt(date), style: GoogleFonts.inter(fontSize: 11.5, color: _R.text2)),
                      ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.place_outlined, size: 12, color: _R.text2),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(venue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 11.5, color: _R.text2)),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _chip('ID: $shortId', _R.blue),
                    if (days != null && days >= 0)
                      _chip('J−$days', _R.rose, solid: true)
                    else if (days != null)
                      _chip('Célébré', _R.green),
                    if (code.isNotEmpty) _chip(code, _R.gold, mono: true),
                    if (!isOwner) _chip('Équipe', _R.blue, solid: true),
                  ]),
                ]),
              ),
              Column(children: [
                GestureDetector(
                  onTap: () => context.push('/thix-weeding/guest/$id'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: _R.blue.withOpacity(0.08), shape: BoxShape.circle),
                    child: const Icon(Icons.visibility_outlined, color: _R.blue, size: 20),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: _R.text2),
                  onSelected: (v) {
                    if (v == 'copy') {
                      Clipboard.setData(ClipboardData(text: code));
                      _toast('Code copié');
                    }
                    if (v == 'delete') _delete(w);
                    if (v == 'leave') _leave(w);
                  },
                  itemBuilder: (_) => [
                    if (code.isNotEmpty)
                      const PopupMenuItem(value: 'copy', child: Text('Copier le code')),
                    if (isOwner)
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer', style: TextStyle(color: _R.rose)))
                    else
                      const PopupMenuItem(
                          value: 'leave',
                          child: Text('Quitter l\'équipe', style: TextStyle(color: _R.rose))),
                  ],
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String t, Color c, {bool filled = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: filled ? c : c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
          border: filled ? null : Border.all(color: c.withOpacity(0.4)),
        ),
        child: Text(t,
            style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w800, color: filled ? Colors.white : c)),
      );

  Widget _chip(String t, Color c, {bool solid = false, bool mono = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: solid ? c : c.withOpacity(0.09),
          borderRadius: BorderRadius.circular(20),
          border: mono ? Border.all(color: c.withOpacity(0.4)) : null,
        ),
        child: Text(t,
            style: mono
                ? _mono(fontSize: 10, fontWeight: FontWeight.w800, color: c)
                : GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: solid ? Colors.white : c)),
      );

  String _fmt(DateTime d) {
    const m = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  // ───────────────────────── VIDE ─────────────────────────
  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _R.border),
      ),
      child: Column(children: [
        const Icon(Icons.favorite_border, size: 46, color: _R.rose),
        const SizedBox(height: 12),
        Text('Aucun mariage pour le moment',
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(
          'Créez le vôtre, ou rejoignez l\'équipe d\'un mariage existant avec son code.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 12.5, color: _R.text2, height: 1.4),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: () => context.push('/thix-weeding/create'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Créer un mariage'),
            style: FilledButton.styleFrom(
              backgroundColor: _R.rose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _searchFocus.requestFocus(),
            icon: const Icon(Icons.vpn_key_outlined),
            label: const Text('Rejoindre avec un code'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _R.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }
}
