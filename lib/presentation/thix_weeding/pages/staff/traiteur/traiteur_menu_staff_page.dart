// lib/presentation/thix_weeding/pages/staff/traiteur/traiteur_menu_staff_page.dart
// ============================================================================
// THIX WEDDING — MENUS TRAITEUR CÔTÉ STAFF (PRODUCTION)
// ✅ Liste groupée par prestataire (traiteur)
// ✅ Validation par le staff (override) + toggle "Public pour les invités"
// ✅ Stats de votes en temps réel + plat le plus populaire mis en avant
// ✅ Filtrage par statut (tous / validés / publics / en attente)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// DESIGN SYSTEM ROYAL (cohérent avec le reste staff)
// ═══════════════════════════════════════════════════════════════════════════
class _R {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color purple = Color(0xFF6B46C1);
  static const Color gold = Color(0xFFD4AF37);
  static const Color rose = Color(0xFFE31C4E);
  static const Color green = Color(0xFF059669);
  static const Color amber = Color(0xFFD97706);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color cream = Color(0xFFFFFBF5);
  static const Color text = Color(0xFF111827);
  static const Color text2 = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  static const LinearGradient royal = LinearGradient(
    colors: [blue, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient goldG = LinearGradient(
    colors: [gold, Color(0xFFB8860B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient greenG = LinearGradient(
    colors: [green, Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration card({double r = 16}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      );
}

enum _MenuFilter { all, validated, public, pending }

// ═══════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════
class TraiteurMenuStaffPage extends ConsumerStatefulWidget {
  final String weddingId;
  const TraiteurMenuStaffPage({super.key, required this.weddingId});

  @override
  ConsumerState<TraiteurMenuStaffPage> createState() =>
      _TraiteurMenuStaffPageState();
}

class _TraiteurMenuStaffPageState extends ConsumerState<TraiteurMenuStaffPage> {
  _MenuFilter _filter = _MenuFilter.all;

  void _refresh() {
    ref.invalidate(weddingMenuItemsProvider(widget.weddingId));
    ref.invalidate(menuVotesCountProvider(widget.weddingId));
  }

  Future<void> _togglePublic(Map<String, dynamic> item) async {
    final current = item['is_public'] as bool? ?? false;
    HapticFeedback.selectionClick();
    try {
      await ref
          .read(menuServiceProvider)
          .update(item['id'] as String, {'is_public': !current});
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          !current
              ? '✓ Plat rendu public pour les invités'
              : 'Plat retiré de la vue invités',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: !current ? _R.green : _R.amber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose),
      );
    }
  }

  Future<void> _toggleValidated(Map<String, dynamic> item) async {
    final current = item['is_validated'] as bool? ?? false;
    HapticFeedback.selectionClick();
    try {
      await ref
          .read(menuServiceProvider)
          .update(item['id'] as String, {'is_validated': !current});
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Supprimer "${item['name']}" ?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
            'Cette action est irréversible. Les votes des invités sur ce plat seront également supprimés.',
            style: GoogleFonts.inter(color: _R.text2, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler',
                  style: GoogleFonts.inter(color: _R.text2))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _R.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Supprimer',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(menuServiceProvider).delete(item['id'] as String);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Plat supprimé ✓',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: _R.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(weddingMenuItemsProvider(widget.weddingId));
    final votesAsync = ref.watch(menuVotesCountProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.cream,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── APP BAR ──
          SliverAppBar(
            expandedHeight: 140,
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
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    size: 14, color: _R.text),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _refresh,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.refresh,
                        color: _R.blue, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: _R.goldG,
                borderRadius: const BorderRadius.only(
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
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.restaurant_menu,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text('MENUS TRAITEUR',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 2)),
                        ]),
                        const SizedBox(height: 6),
                        Text('Validation & visibilité invités',
                            style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── CONTENU ──
          itemsAsync.when(
            loading: () => const SliverFillRemaining(
              child:
                  Center(child: CircularProgressIndicator(color: _R.blue)),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: _R.rose),
                        const SizedBox(height: 12),
                        Text('Erreur: $e',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: _R.rose)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _R.blue,
                              foregroundColor: Colors.white),
                        ),
                      ]),
                ),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const SliverFillRemaining(
                  child: _EmptyMenus(),
                );
              }

              final votes = votesAsync.valueOrNull ?? {};
              final totalVotes =
                  votes.values.fold(0, (s, v) => s + v);

              // Filtrage
              var visible = items.where((i) {
                switch (_filter) {
                  case _MenuFilter.all:
                    return true;
                  case _MenuFilter.validated:
                    return i['is_validated'] == true;
                  case _MenuFilter.public:
                    return i['is_public'] == true;
                  case _MenuFilter.pending:
                    return i['is_validated'] != true;
                }
              }).toList();

              // Grouper par vendor
              final grouped = <String, List<Map<String, dynamic>>>{};
              for (final item in visible) {
                final vendor = (item['vendor'] as Map?)
                        ?.cast<String, dynamic>() ??
                    {};
                final vendorId = item['vendor_id'] as String? ?? 'unknown';
                grouped.putIfAbsent(vendorId, () => []).add(item);
              }

              // Top 3 plats les plus votés
              final topPlats = items
                  .map((i) => {
                        'item': i,
                        'votes': votes[i['id'] as String] ?? 0,
                      })
                  .toList()
                ..sort((a, b) =>
                    (b['votes'] as int).compareTo(a['votes'] as int));
              final top3 = topPlats.take(3).toList();

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── STATS ──
                    _MenuStatsRow(
                      total: items.length,
                      validated: items
                          .where((i) => i['is_validated'] == true)
                          .length,
                      public: items
                          .where((i) => i['is_public'] == true)
                          .length,
                      totalVotes: totalVotes,
                    ),
                    const SizedBox(height: 16),

                    // ── TOP 3 PLATS POPULAIRES ──
                    if (totalVotes > 0) ...[
                      _SectionTitle(
                          title: '🏆 Les plus plébiscités par les invités',
                          icon: Icons.emoji_events,
                          color: _R.gold),
                      const SizedBox(height: 10),
                      ...top3.where((t) => (t['votes'] as int) > 0).map(
                          (t) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 10),
                                child: _PopularItemCard(
                                  item: t['item']
                                      as Map<String, dynamic>,
                                  votes: t['votes'] as int,
                                ),
                              )),
                      const SizedBox(height: 20),
                    ],

                    // ── FILTRES ──
                    _FilterChips(
                      selected: _filter,
                      onChanged: (f) => setState(() => _filter = f),
                      counts: {
                        _MenuFilter.all: items.length,
                        _MenuFilter.validated: items
                            .where((i) => i['is_validated'] == true)
                            .length,
                        _MenuFilter.public: items
                            .where((i) => i['is_public'] == true)
                            .length,
                        _MenuFilter.pending: items
                            .where((i) => i['is_validated'] != true)
                            .length,
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── LISTE GROUPEE PAR TRAITEUR ──
                    if (grouped.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: _R.card(),
                        child: Column(children: [
                          const Icon(Icons.filter_alt_off,
                              size: 40, color: _R.text2),
                          const SizedBox(height: 10),
                          Text('Aucun plat pour ce filtre',
                              style: GoogleFonts.inter(
                                  color: _R.text2,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      )
                    else
                      ...grouped.entries.map((entry) {
                        final vendor = (entry.value.first['vendor']
                                    as Map?)
                                ?.cast<String, dynamic>() ??
                            {};
                        final vendorName =
                            vendor['name'] as String? ?? 'Traiteur';
                        final vendorCat =
                            vendor['category'] as String? ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _VendorMenuGroup(
                            vendorName: vendorName,
                            vendorCategory: vendorCat,
                            items: entry.value,
                            votes: votes,
                            onTogglePublic: _togglePublic,
                            onToggleValidated: _toggleValidated,
                            onDelete: _delete,
                          ),
                        );
                      }),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATS ROW
// ═══════════════════════════════════════════════════════════════════════════
class _MenuStatsRow extends StatelessWidget {
  final int total, validated, public, totalVotes;
  const _MenuStatsRow({
    required this.total,
    required this.validated,
    required this.public,
    required this.totalVotes,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: _MiniStat(
              icon: Icons.restaurant_menu,
              label: 'Total',
              value: '$total',
              color: _R.blue)),
      const SizedBox(width: 8),
      Expanded(
          child: _MiniStat(
              icon: Icons.check_circle,
              label: 'Validés',
              value: '$validated',
              color: _R.green)),
      const SizedBox(width: 8),
      Expanded(
          child: _MiniStat(
              icon: Icons.visibility,
              label: 'Publics',
              value: '$public',
              color: _R.purple)),
      const SizedBox(width: 8),
      Expanded(
          child: _MiniStat(
              icon: Icons.favorite,
              label: 'Votes',
              value: '$totalVotes',
              color: _R.gold)),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: _R.card(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _R.text)),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9, color: _R.text2, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION TITLE
// ═══════════════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(title,
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _R.text)),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FILTRES
// ═══════════════════════════════════════════════════════════════════════════
class _FilterChips extends StatelessWidget {
  final _MenuFilter selected;
  final ValueChanged<_MenuFilter> onChanged;
  final Map<_MenuFilter, int> counts;

  const _FilterChips({
    required this.selected,
    required this.onChanged,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chip(_MenuFilter.all, 'Tous', Icons.all_inbox, _R.blue),
        const SizedBox(width: 8),
        _chip(_MenuFilter.validated, 'Validés', Icons.check_circle, _R.green),
        const SizedBox(width: 8),
        _chip(_MenuFilter.public, 'Publics', Icons.visibility, _R.purple),
        const SizedBox(width: 8),
        _chip(_MenuFilter.pending, 'En attente', Icons.hourglass_empty, _R.amber),
      ]),
    );
  }

  Widget _chip(_MenuFilter f, String label, IconData icon, Color color) {
    final sel = selected == f;
    return Material(
      color: sel ? color : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(f);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? color : _R.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 14, color: sel ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : _R.text)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: sel ? Colors.white.withOpacity(0.25) : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${counts[f] ?? 0}',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: sel ? Colors.white : color)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GROUPE PAR TRAITEUR
// ═══════════════════════════════════════════════════════════════════════════
class _VendorMenuGroup extends StatelessWidget {
  final String vendorName;
  final String vendorCategory;
  final List<Map<String, dynamic>> items;
  final Map<String, int> votes;
  final Future<void> Function(Map<String, dynamic>) onTogglePublic;
  final Future<void> Function(Map<String, dynamic>) onToggleValidated;
  final Future<void> Function(Map<String, dynamic>) onDelete;

  const _VendorMenuGroup({
    required this.vendorName,
    required this.vendorCategory,
    required this.items,
    required this.votes,
    required this.onTogglePublic,
    required this.onToggleValidated,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header vendor
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [
                    _R.blue.withOpacity(0.06),
                    _R.purple.withOpacity(0.04)
                  ]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    gradient: _R.royal, shape: BoxShape.circle),
                child: const Icon(Icons.storefront,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendorName,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _R.text)),
                      Text(vendorCategory.isEmpty ? 'Traiteur' : vendorCategory,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: _R.text2)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _R.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${items.length} plat${items.length > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _R.blue)),
              ),
            ]),
          ),

          // Liste plats
          ...items.map((item) => _MenuItemCard(
                item: item,
                votes: votes[item['id'] as String] ?? 0,
                onTogglePublic: () => onTogglePublic(item),
                onToggleValidated: () => onToggleValidated(item),
                onDelete: () => onDelete(item),
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE PLAT
// ═══════════════════════════════════════════════════════════════════════════
class _MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int votes;
  final VoidCallback onTogglePublic;
  final VoidCallback onToggleValidated;
  final VoidCallback onDelete;

  const _MenuItemCard({
    required this.item,
    required this.votes,
    required this.onTogglePublic,
    required this.onToggleValidated,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isValidated = item['is_validated'] as bool? ?? false;
    final isPublic = item['is_public'] as bool? ?? false;
    final name = item['name'] as String? ?? 'Sans nom';
    final desc = item['description'] as String? ?? '';
    final price = (item['price'] as num?)?.toDouble();
    final img = item['image_url'] as String?;
    final category = item['category'] as String? ?? 'plat';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _R.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPublic
              ? _R.purple.withOpacity(0.35)
              : isValidated
                  ? _R.green.withOpacity(0.3)
                  : _R.border,
          width: isPublic ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Image ou icône
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _R.gold.withOpacity(0.1),
              ),
              clipBehavior: Clip.antiAlias,
              child: (img != null && img.isNotEmpty)
                  ? Image.network(img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.restaurant,
                          color: _R.gold,
                          size: 26))
                  : const Icon(Icons.restaurant,
                      color: _R.gold, size: 26),
            ),
            const SizedBox(width: 12),
            // Nom + desc
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
                            color: _R.text)),
                    if (desc.isNotEmpty)
                      Text(desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: _R.text2)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _Tag(category, _R.blue),
                      if (price != null && price > 0) ...[
                        const SizedBox(width: 6),
                        _Tag(
                            '${price.toStringAsFixed(0)} \$',
                            _R.gold),
                      ],
                      if (votes > 0) ...[
                        const SizedBox(width: 6),
                        _Tag('❤ $votes', _R.rose),
                      ],
                    ]),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          // Badges statut
          Wrap(spacing: 6, runSpacing: 6, children: [
            _StatusChip(
              label: isValidated ? 'Validé' : 'Non validé',
              icon: isValidated ? Icons.check_circle : Icons.pending,
              color: isValidated ? _R.green : _R.amber,
            ),
            _StatusChip(
              label: isPublic ? 'Public' : 'Privé',
              icon: isPublic ? Icons.visibility : Icons.visibility_off,
              color: isPublic ? _R.purple : _R.text2,
            ),
          ]),
          const SizedBox(height: 12),
          // Actions
          Row(children: [
            Expanded(
              child: _MiniBtn(
                icon: isValidated ? Icons.close : Icons.check,
                label: isValidated ? 'Retirer validation' : 'Valider',
                color: isValidated ? _R.amber : _R.green,
                onTap: onToggleValidated,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MiniBtn(
                icon: isPublic ? Icons.visibility_off : Icons.visibility,
                label: isPublic ? 'Rendre privé' : 'Rendre public',
                color: isPublic ? _R.text2 : _R.purple,
                onTap: onTogglePublic,
              ),
            ),
            const SizedBox(width: 6),
            _IconBtn(
              icon: Icons.delete_outline,
              color: _R.rose,
              onTap: onDelete,
            ),
          ]),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MiniBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE PLAT POPULAIRE (Top 3)
// ═══════════════════════════════════════════════════════════════════════════
class _PopularItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int votes;
  const _PopularItemCard({required this.item, required this.votes});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? 'Sans nom';
    final vendor =
        (item['vendor'] as Map?)?.cast<String, dynamic>() ?? {};
    final vendorName = vendor['name'] as String? ?? 'Traiteur';
    final img = item['image_url'] as String?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          _R.gold.withOpacity(0.15),
          _R.gold.withOpacity(0.05),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _R.gold.withOpacity(0.4), width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _R.gold.withOpacity(0.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: (img != null && img.isNotEmpty)
              ? Image.network(img,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.star,
                      color: _R.gold,
                      size: 28))
              : const Icon(Icons.star, color: _R.gold, size: 28),
        ),
        const SizedBox(width: 12),
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
                        color: _R.text)),
                Text(vendorName,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _R.text2)),
              ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const BoxDecoration(
            gradient: _R.goldG,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.favorite, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text('$votes',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════
class _EmptyMenus extends StatelessWidget {
  const _EmptyMenus();

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
                  _R.gold.withOpacity(0.15),
                  _R.rose.withOpacity(0.08)
                ]),
                shape: BoxShape.circle),
            child:
                const Icon(Icons.restaurant_menu, size: 56, color: _R.gold),
          ),
          const SizedBox(height: 20),
          Text('Aucun menu pour le moment',
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _R.text)),
          const SizedBox(height: 8),
          Text(
            'Les traiteurs ajoutent leurs plats depuis leur espace prestataire.\nDès qu\'ils proposent un menu, il apparaîtra ici pour validation.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13, color: _R.text2, height: 1.5),
          ),
        ]),
      ),
    );
  }
}
