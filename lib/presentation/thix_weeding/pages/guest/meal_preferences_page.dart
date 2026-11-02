// lib/presentation/thix_weeding/pages/guest/meal_preferences_page.dart
// ============================================================================
// THIX WEDDING — PRÉFÉRENCES REPAS CÔTÉ INVITÉ (PRODUCTION)
// ✅ Liste des plats PUBLICS validés
// ✅ Coche multiple (un invité peut aimer plusieurs plats)
// ✅ Compteur de votes affiché en temps réel
// ✅ Mise en avant du plat le plus populaire (Top 1)
// ✅ Identification invité via SharedPreferences (guestId stable)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE INVITÉ (cohérent avec guest_home_page)
// ═══════════════════════════════════════════════════════════════════════════
class _G {
  static const Color bg = Color(0xFFFFFBFC);
  static const Color surface = Colors.white;
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFF1E3E8);
  static const Color rose = Color(0xFFD81B60);
  static const Color roseLight = Color(0xFFFF6F9C);
  static const Color gold = Color(0xFFD4AF37);
  static const Color green = Color(0xFF059669);
  static const Color blue = Color(0xFF0B3B8F);

  static const LinearGradient roseG = LinearGradient(
    colors: [Color(0xFFE91E78), Color(0xFFC2185B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient goldG = LinearGradient(
    colors: [gold, Color(0xFFB8860B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Provider de l'identité invité courante (guestId + guestName)
/// Stockée en SharedPreferences pour persistance locale
final _currentGuestIdentityProvider =
    FutureProvider<({String guestId, String guestName})>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final id = prefs.getString('thix_current_guest_id');
  final name = prefs.getString('thix_current_guest_name') ?? '';
  if (id != null && id.isNotEmpty) {
    return (guestId: id, guestName: name);
  }
  // Générer un id invité anonyme (basé sur device + timestamp)
  final newId =
      'guest_${DateTime.now().millisecondsSinceEpoch}_${Supabase.instance.client.auth.currentUser?.id ?? 'anon'}';
  await prefs.setString('thix_current_guest_id', newId);
  return (guestId: newId, guestName: '');
});

// ═══════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════
class MealPreferencesPage extends ConsumerStatefulWidget {
  final String weddingId;
  const MealPreferencesPage({super.key, required this.weddingId});

  @override
  ConsumerState<MealPreferencesPage> createState() =>
      _MealPreferencesPageState();
}

class _MealPreferencesPageState extends ConsumerState<MealPreferencesPage> {
  final _nameCtrl = TextEditingController();
  bool _nameSaved = false;

  @override
  void initState() {
    super.initState();
    _loadGuestName();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGuestName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('thix_current_guest_name') ?? '';
    if (name.isNotEmpty && mounted) {
      setState(() {
        _nameCtrl.text = name;
        _nameSaved = true;
      });
    }
  }

  Future<void> _saveGuestName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Veuillez saisir votre nom',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _G.rose,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('thix_current_guest_name', name);
    setState(() => _nameSaved = true);
    ref.invalidate(_currentGuestIdentityProvider);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Bienvenue $name !',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      backgroundColor: _G.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(_currentGuestIdentityProvider);
    final publicMenuAsync =
        ref.watch(weddingPublicMenuProvider(widget.weddingId));
    final votesAsync = ref.watch(menuVotesCountProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _G.bg,
      body: identityAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: _G.rose)),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (identity) {
          // Si pas de nom → demander avant d'afficher les plats
          if (!_nameSaved || identity.guestName.isEmpty) {
            return _GuestNameForm(
              controller: _nameCtrl,
              onSave: _saveGuestName,
            );
          }

          return publicMenuAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: _G.rose)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: _G.rose),
                      const SizedBox(height: 12),
                      Text('Erreur: $e',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: _G.rose)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(weddingPublicMenuProvider(
                              widget.weddingId));
                          ref.invalidate(menuVotesCountProvider(
                              widget.weddingId));
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _G.rose,
                            foregroundColor: Colors.white),
                      ),
                    ]),
              ),
            ),
            data: (publicItems) {
              if (publicItems.isEmpty) {
                return const _EmptyPublicMenu();
              }

              final votes = votesAsync.valueOrNull ?? {};
              final guestVotesAsync = ref.watch(guestMenuVotesProvider(
                  (weddingId: widget.weddingId,
                      guestId: identity.guestId)));
              final guestVotes = guestVotesAsync.valueOrNull ?? {};

              // Top 1
              Map<String, dynamic>? topItem;
              int topVotes = 0;
              for (final item in publicItems) {
                final v = votes[item['id'] as String] ?? 0;
                if (v > topVotes) {
                  topVotes = v;
                  topItem = item;
                }
              }

              // Tri : top en premier, puis par votes décroissants
              final sorted = List<Map<String, dynamic>>.from(publicItems)
                ..sort((a, b) {
                  final va = votes[a['id'] as String] ?? 0;
                  final vb = votes[b['id'] as String] ?? 0;
                  return vb.compareTo(va);
                });

              return RefreshIndicator(
                color: _G.rose,
                onRefresh: () async {
                  ref.invalidate(
                      weddingPublicMenuProvider(widget.weddingId));
                  ref.invalidate(
                      menuVotesCountProvider(widget.weddingId));
                  ref.invalidate(guestMenuVotesProvider((
                    weddingId: widget.weddingId,
                    guestId: identity.guestId,
                  )));
                },
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    // ── APP BAR ──
                    _GuestAppBar(
                      guestName: identity.guestName,
                      onEditName: () =>
                          setState(() => _nameSaved = false),
                    ),

                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Intro
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                _G.rose.withOpacity(0.08),
                                _G.gold.withOpacity(0.05),
                              ]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: _G.rose.withOpacity(0.2)),
                            ),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _G.rose.withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                    Icons.restaurant_menu_rounded,
                                    color: _G.rose,
                                    size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Choisissez vos plats préférés',
                                          style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight.w800,
                                              color: _G.ink)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Le traiteur se concentrera sur les plats les plus plébiscités',
                                        style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            color: _G.inkSoft,
                                            height: 1.4),
                                      ),
                                    ]),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 16),

                          // Top 1 — mise en avant
                          if (topItem != null && topVotes > 0) ...[
                            _TopItemCard(
                              item: topItem,
                              votes: topVotes,
                              isVoted: guestVotes
                                  .contains(topItem['id'] as String),
                              onToggle: (v) => _toggleVote(
                                identity: identity,
                                item: topItem!, 
                                vote: v,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Liste complète (sans le top)
                          ...sorted
                              .where((i) => i != topItem || topVotes == 0)
                              .map((item) => Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 10),
                                    child: _GuestMenuItemCard(
                                      item: item,
                                      votes: votes[item['id'] as String] ??
                                          0,
                                      isVoted: guestVotes
                                          .contains(item['id'] as String),
                                      onToggle: (v) => _toggleVote(
                                        identity: identity,
                                        item: item,
                                        vote: v,
                                      ),
                                    ),
                                  )),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _toggleVote({
    required ({String guestId, String guestName}) identity,
    required Map<String, dynamic> item,
    required bool vote,
  }) async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(menuServiceProvider).toggleVote(
            weddingId: widget.weddingId,
            menuItemId: item['id'] as String,
            guestId: identity.guestId,
            guestName: identity.guestName,
            vote: vote,
          );
      // Refresh votes
      ref.invalidate(menuVotesCountProvider(widget.weddingId));
      ref.invalidate(guestMenuVotesProvider((
        weddingId: widget.weddingId,
        guestId: identity.guestId,
      )));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          vote ? '❤ Ajouté à vos favoris' : 'Retiré de vos favoris',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: vote ? _G.rose : _G.inkSoft,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: _G.rose,
      ));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FORMULAIRE NOM INVITÉ
// ═══════════════════════════════════════════════════════════════════════════
class _GuestNameForm extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSave;
  const _GuestNameForm({required this.controller, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _G.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _G.line),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: _G.roseG,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                Text('Bienvenue !',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _G.ink)),
                const SizedBox(height: 6),
                Text(
                  'Avant de choisir vos plats préférés, comment vous appelez-vous ?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _G.inkSoft, height: 1.4),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Votre nom',
                    hintText: 'Ex: Sophie Martin',
                    prefixIcon: const Icon(Icons.person_outline,
                        color: _G.rose),
                    filled: true,
                    fillColor: _G.bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: _G.rose, width: 2)),
                  ),
                  onSubmitted: (_) => onSave(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text('Continuer',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _G.rose,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════
// APP BAR INVITÉ
// ═══════════════════════════════════════════════════════════════════════════
class _GuestAppBar extends StatelessWidget {
  final String guestName;
  final VoidCallback onEditName;
  const _GuestAppBar({
    required this.guestName,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1), blurRadius: 8)
              ]),
          child: const Icon(Icons.arrow_back_ios_new,
              size: 14, color: _G.ink),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onEditName,
            child: Container(
              padding: const EdgeInsets.all(10),
              child:
                  const Icon(Icons.edit_outlined, color: _G.rose, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: _G.roseG,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: FlexibleSpaceBar(
          background: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('BONJOUR $guestName',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.85),
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text('Préférences repas',
                      style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE TOP PLAT (mise en avant)
// ═══════════════════════════════════════════════════════════════════════════
class _TopItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int votes;
  final bool isVoted;
  final ValueChanged<bool> onToggle;

  const _TopItemCard({
    required this.item,
    required this.votes,
    required this.isVoted,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? 'Sans nom';
    final desc = item['description'] as String? ?? '';
    final img = item['image_url'] as String?;
    final vendor =
        (item['vendor'] as Map?)?.cast<String, dynamic>() ?? {};
    final vendorName = vendor['name'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _G.goldG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _G.gold.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.emoji_events,
                    color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text('LE PLUS POPULAIRE',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1)),
              ]),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.favorite, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text('$votes',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withOpacity(0.2),
              ),
              clipBehavior: Clip.antiAlias,
              child: (img != null && img.isNotEmpty)
                  ? Image.network(img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.restaurant,
                          color: Colors.white,
                          size: 36))
                  : const Icon(Icons.restaurant,
                      color: Colors.white, size: 36),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    if (desc.isNotEmpty)
                      Text(desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.4)),
                    if (vendorName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(vendorName,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w600)),
                    ],
                  ]),
            ),
          ]),
          const SizedBox(height: 16),
          _VoteButton(
            isVoted: isVoted,
            onToggle: onToggle,
            isTop: true,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE PLAT NORMAL (invité)
// ═══════════════════════════════════════════════════════════════════════════
class _GuestMenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int votes;
  final bool isVoted;
  final ValueChanged<bool> onToggle;

  const _GuestMenuItemCard({
    required this.item,
    required this.votes,
    required this.isVoted,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? 'Sans nom';
    final desc = item['description'] as String? ?? '';
    final price = (item['price'] as num?)?.toDouble();
    final img = item['image_url'] as String?;
    final category = item['category'] as String? ?? 'plat';
    final vendor =
        (item['vendor'] as Map?)?.cast<String, dynamic>() ?? {};
    final vendorName = vendor['name'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _G.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVoted ? _G.rose.withOpacity(0.5) : _G.line,
          width: isVoted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _G.rose.withOpacity(0.08),
            ),
            clipBehavior: Clip.antiAlias,
            child: (img != null && img.isNotEmpty)
                ? Image.network(img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.restaurant,
                        color: _G.rose,
                        size: 28))
                : const Icon(Icons.restaurant,
                    color: _G.rose, size: 28),
          ),
          const SizedBox(width: 12),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _G.ink)),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _G.inkSoft,
                            height: 1.35)),
                  ),
                const SizedBox(height: 6),
                Row(children: [
                  _TagChip(category, _G.blue),
                  if (vendorName.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _TagChip(vendorName, _G.inkSoft),
                  ],
                  if (price != null && price > 0) ...[
                    const SizedBox(width: 6),
                    _TagChip(
                        '${price.toStringAsFixed(0)}\$', _G.gold),
                  ],
                  const Spacer(),
                  if (votes > 0)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.favorite,
                          size: 13, color: _G.rose),
                      const SizedBox(width: 3),
                      Text('$votes',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _G.rose)),
                    ]),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Checkbox vote
          GestureDetector(
            onTap: () => onToggle(!isVoted),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isVoted ? _G.rose : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isVoted ? _G.rose : _G.line,
                  width: 2,
                ),
                boxShadow: isVoted
                    ? [
                        BoxShadow(
                            color: _G.rose.withOpacity(0.35),
                            blurRadius: 10,
                            spreadRadius: 1)
                      ]
                    : null,
              ),
              child: Icon(
                isVoted ? Icons.favorite : Icons.favorite_border,
                color: isVoted ? Colors.white : _G.inkSoft,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  final Color color;
  const _TagChip(this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOUTON VOTE
// ═══════════════════════════════════════════════════════════════════════════
class _VoteButton extends StatelessWidget {
  final bool isVoted;
  final ValueChanged<bool> onToggle;
  final bool isTop;
  const _VoteButton({
    required this.isVoted,
    required this.onToggle,
    this.isTop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onToggle(!isVoted),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isTop
                ? (isVoted
                    ? Colors.white
                    : Colors.white.withOpacity(0.25))
                : (isVoted
                    ? _G.rose
                    : _G.rose.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isTop
                  ? Colors.white
                  : (isVoted ? _G.rose : _G.rose.withOpacity(0.3)),
              width: isTop ? 2 : 1.5,
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              isVoted ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: isTop ? _G.rose : (isVoted ? Colors.white : _G.rose),
            ),
            const SizedBox(width: 8),
            Text(
              isVoted ? 'Retirer de mes favoris' : "J'aime ce plat",
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isTop
                      ? _G.rose
                      : (isVoted ? Colors.white : _G.rose)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY STATE — pas de menu public
// ═══════════════════════════════════════════════════════════════════════════
class _EmptyPublicMenu extends StatelessWidget {
  const _EmptyPublicMenu();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _G.rose.withOpacity(0.12),
                  _G.gold.withOpacity(0.08)
                ]),
                shape: BoxShape.circle),
            child: const Icon(Icons.restaurant_menu_rounded,
                size: 56, color: _G.rose),
          ),
          const SizedBox(height: 20),
          Text('Menu en cours de préparation',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _G.ink)),
          const SizedBox(height: 8),
          Text(
            'Le traiteur et les organisateurs finalisent la sélection des plats.\nRevenez bientôt pour voter !',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13, color: _G.inkSoft, height: 1.5),
          ),
        ]),
      ),
    );
  }
}
