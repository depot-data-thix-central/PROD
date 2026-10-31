// lib/presentation/thix_weeding/pages/staff/prestataires/vendors_list_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — VENDORS LIST (PRODUCTION)
// Design royal + 15 Catégories + Stats live + Recherche debounce + Typed
// Branché sur providers & services EXISTANTS du dépôt
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

// ============================================================================
// DESIGN SYSTEM ROYAL
// ============================================================================
class _R {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color purple = Color(0xFF6B46C1);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color rose = Color(0xFFE31C4E);
  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFF10B981);
  static const Color amber = Color(0xFFD97706);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color text = Color(0xFF111827);
  static const Color text2 = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  static const LinearGradient royal = LinearGradient(
    colors: [blue, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient goldG = LinearGradient(
    colors: [gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient greenG = LinearGradient(
    colors: [green, greenSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration card({double r = 14}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

// ============================================================================
// 15 CATÉGORIES DYNAMIQUES
// ============================================================================
const List<_CatDef> _CATEGORIES = [
  _CatDef('organisateur', 'Organisateur', Icons.celebration, Color(0xFF6B46C1)),
  _CatDef('decorateur', 'Décorateur', Icons.auto_awesome, Color(0xFFFF6B9D)),
  _CatDef('photographe', 'Photographe', Icons.camera_alt_outlined, Color(0xFFE31C4E)),
  _CatDef('videaste', 'Vidéaste', Icons.videocam_outlined, Color(0xFFDB2777)),
  _CatDef('traiteur', 'Traiteur', Icons.restaurant, Color(0xFFD97706)),
  _CatDef('patissier', 'Pâtissier', Icons.cake_outlined, Color(0xFFBE185D)),
  _CatDef('maquilleur', 'Maquilleur', Icons.auto_fix_high, Color(0xFFEC4899)),
  _CatDef('coiffeur', 'Coiffeur', Icons.content_cut, Color(0xFF8B5CF6)),
  _CatDef('couturier', 'Couturier', Icons.checkroom, Color(0xFF0891B2)),
  _CatDef('dj', 'DJ / Musique', Icons.music_note, Color(0xFF7C3AED)),
  _CatDef('vehicule', 'Véhicules', Icons.directions_car, Color(0xFF4338CA)),
  _CatDef('salle', 'Salle', Icons.place_outlined, Color(0xFF0B3B8F)),
  _CatDef('fleuriste', 'Fleuriste', Icons.local_florist, Color(0xFF059669)),
  _CatDef('securite', 'Sécurité', Icons.shield_outlined, Color(0xFF64748B)),
  _CatDef('materiel', 'Matériel', Icons.inventory_2_outlined, Color(0xFF78716C)),
];

class _CatDef {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _CatDef(this.key, this.label, this.icon, this.color);
}

_CatDef _findCat(String? raw) {
  if (raw == null || raw.isEmpty) return _CatDef('autre', 'Autre', Icons.store_outlined, _R.text2);
  final lower = raw.toLowerCase();
  for (final c in _CATEGORIES) {
    if (c.key == lower || c.label.toLowerCase() == lower) return c;
  }
  return _CatDef(raw, raw, Icons.store_outlined, _R.blue);
}

// ============================================================================
// STATUTS
// ============================================================================
const Map<String, _StatusDef> _STATUS_MAP = {
  'pending': _StatusDef('En attente', Icons.hourglass_empty, Color(0xFF6B7280)),
  'contacted': _StatusDef('Contacté', Icons.phone_callback, Color(0xFF0B3B8F)),
  'devis_envoye': _StatusDef('Devis envoyé', Icons.description_outlined, Color(0xFF6B46C1)),
  'booked': _StatusDef('Réservé', Icons.event_available, Color(0xFF059669)),
  'paid': _StatusDef('Payé', Icons.payments, Color(0xFFD4AF37)),
  'cancelled': _StatusDef('Annulé', Icons.cancel_outlined, Color(0xFFE31C4E)),
};

class _StatusDef {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusDef(this.label, this.icon, this.color);
}

_StatusDef _getStatus(String? key) =>
    _STATUS_MAP[key ?? ''] ?? _StatusDef(key ?? 'Inconnu', Icons.info_outline, _R.text2);

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class VendorsListPage extends ConsumerStatefulWidget {
  final String weddingId;
  const VendorsListPage({super.key, required this.weddingId});

  @override
  ConsumerState<VendorsListPage> createState() => _VendorsListPageState();
}

class _VendorsListPageState extends ConsumerState<VendorsListPage>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _filterCat = 'all';
  Timer? _debounce;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _debounce?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _search = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.surface,
      body: vendorsAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(vendorsProvider(widget.weddingId)),
        ),
        data: (vendors) => FadeTransition(
          opacity: _fadeAnim,
          child: _VendorsContent(
            weddingId: widget.weddingId,
            vendors: vendors,
            searchCtrl: _searchCtrl,
            search: _search,
            filterCat: _filterCat,
            onFilterChanged: (f) => setState(() => _filterCat = f),
            onRefresh: () async => ref.invalidate(vendorsProvider(widget.weddingId)),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CONTENU PRINCIPAL
// ============================================================================
class _VendorsContent extends StatelessWidget {
  final String weddingId;
  final List<VendorModel> vendors;
  final TextEditingController searchCtrl;
  final String search;
  final String filterCat;
  final ValueChanged<String> onFilterChanged;
  final Future<void> Function() onRefresh;

  const _VendorsContent({
    required this.weddingId,
    required this.vendors,
    required this.searchCtrl,
    required this.search,
    required this.filterCat,
    required this.onFilterChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Stats
    final total = vendors.length;
    final booked = vendors.where((v) => v.isBooked).length;
    final totalBudget = vendors.fold<double>(0, (s, v) => s + (v.price ?? 0));

    // Catégories uniques présentes dans les données
    final activeCategories = <String>{};
    for (final v in vendors) {
      if (v.category.isNotEmpty) activeCategories.add(v.category);
    }

    // Filtrage
    final filtered = vendors.where((v) {
      final matchSearch = search.isEmpty ||
          v.name.toLowerCase().contains(search) ||
          (v.contactName ?? '').toLowerCase().contains(search) ||
          v.category.toLowerCase().contains(search);
      final matchCat = filterCat == 'all' ||
          v.category.toLowerCase() == filterCat.toLowerCase() ||
          _findCat(v.category).key == filterCat;
      return matchSearch && matchCat;
    }).toList()
      ..sort((a, b) {
        // Réservés en premier
        if (a.isBooked != b.isBooked) return a.isBooked ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── APP BAR ───────────────────────────────────────────────────
        _VendorsAppBar(
          weddingId: weddingId,
          total: total,
          booked: booked,
          totalBudget: totalBudget,
          searchCtrl: searchCtrl,
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── STATS BAR ──────────────────────────────────────────
              _StatsBar(total: total, booked: booked, totalBudget: totalBudget),
              const SizedBox(height: 12),

              // ── FILTRES CATÉGORIES ─────────────────────────────────
              _CategoryFilterRow(
                selected: filterCat,
                activeCategories: activeCategories,
                onChanged: onFilterChanged,
              ),
              const SizedBox(height: 16),

              // ── HEADER LISTE ───────────────────────────────────────
              _ListHeader(count: filtered.length, total: total, search: search),
              const SizedBox(height: 10),

              // ── LISTE / EMPTY ──────────────────────────────────────
              if (filtered.isEmpty)
                _EmptyState(hasSearch: search.isNotEmpty, hasFilter: filterCat != 'all', weddingId: weddingId)
              else
                RefreshIndicator(
                  color: _R.blue,
                  onRefresh: onRefresh,
                  child: Column(
                    children: filtered
                        .map((v) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _VendorCard(vendor: v, weddingId: weddingId),
                            ))
                        .toList(),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// APP BAR ROYALE
// ============================================================================
class _VendorsAppBar extends StatelessWidget {
  final String weddingId;
  final int total;
  final int booked;
  final double totalBudget;
  final TextEditingController searchCtrl;

  const _VendorsAppBar({
    required this.weddingId,
    required this.total,
    required this.booked,
    required this.totalBudget,
    required this.searchCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 14, color: _R.text),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push('/thix-weeding/staff/$weddingId/prestataires/add'),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.add_business_outlined, color: _R.blue, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 10),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: _R.royal,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -60, top: -60,
              child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08))),
            ),
            Positioned(
              right: 30, bottom: -40,
              child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: _R.gold.withOpacity(0.15))),
            ),
            FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 55, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text('PRESTATAIRES', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.85), letterSpacing: 2)),
                          const Spacer(),
                          _AddButton(weddingId: weddingId),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Gestion des prestataires', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('$total prestataire${total > 1 ? 's' : ''} • $booked réservé${booked > 1 ? 's' : ''}', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9))),
                      const SizedBox(height: 14),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: TextField(
                          controller: searchCtrl,
                          style: GoogleFonts.inter(fontSize: 14, color: _R.text),
                          decoration: InputDecoration(
                            hintText: 'Rechercher nom, catégorie...',
                            hintStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
                            prefixIcon: const Icon(Icons.search, color: _R.blue, size: 20),
                            suffixIcon: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: searchCtrl,
                              builder: (_, v, __) => v.text.isNotEmpty
                                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => searchCtrl.clear())
                                  : const SizedBox.shrink(),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String weddingId;
  const _AddButton({required this.weddingId});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/thix-weeding/staff/$weddingId/prestataires/add'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: _R.goldG,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: _R.gold.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_business, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text('Ajouter', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STATS BAR
// ============================================================================
class _StatsBar extends StatelessWidget {
  final int total;
  final int booked;
  final double totalBudget;

  const _StatsBar({required this.total, required this.booked, required this.totalBudget});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _R.card(),
      child: Row(
        children: [
          _MiniStat(icon: Icons.storefront, label: 'Total', value: '$total', color: _R.blue),
          _MiniStat(icon: Icons.event_available, label: 'Réservés', value: '$booked', color: _R.green),
          _MiniStat(icon: Icons.account_balance_wallet, label: 'Budget', value: '${_fmtMoney(totalBudget)}', color: _R.gold),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 14, color: color)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: _R.text2)),
        ],
      ),
    );
  }
}

// ============================================================================
// CATEGORY FILTER ROW (dynamique)
// ============================================================================
class _CategoryFilterRow extends StatelessWidget {
  final String selected;
  final Set<String> activeCategories;
  final ValueChanged<String> onChanged;

  const _CategoryFilterRow({required this.selected, required this.activeCategories, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Construire la liste : "Tous" + catégories actives triées
    final chips = <Widget>[
      _FilterChip(label: 'Tous', icon: Icons.all_inbox, color: _R.blue, isSelected: selected == 'all', onTap: () => onChanged('all')),
    ];

    // Ajouter les catégories présentes dans les données
    for (final catKey in activeCategories) {
      final cat = _findCat(catKey);
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _FilterChip(
            label: cat.label,
            icon: cat.icon,
            color: cat.color,
            isSelected: selected == cat.key,
            onTap: () => onChanged(cat.key),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.icon, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? color : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? color : _R.border, width: isSelected ? 1.5 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: isSelected ? Colors.white : color),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : _R.text)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LIST HEADER
// ============================================================================
class _ListHeader extends StatelessWidget {
  final int count;
  final int total;
  final String search;

  const _ListHeader({required this.count, required this.total, required this.search});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.list_alt_outlined, size: 16, color: _R.blue),
        const SizedBox(width: 6),
        Text(search.isEmpty ? 'Liste des prestataires' : 'Résultats', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _R.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Text(search.isEmpty ? '$total' : '$count / $total', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _R.blue)),
        ),
      ],
    );
  }
}

// ============================================================================
// VENDOR CARD
// ============================================================================
class _VendorCard extends StatelessWidget {
  final VendorModel vendor;
  final String weddingId;

  const _VendorCard({required this.vendor, required this.weddingId});

  @override
  Widget build(BuildContext context) {
    final cat = _findCat(vendor.category);
    final status = _getStatus(vendor.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push('/thix-weeding/staff/$weddingId/prestataires/${vendor.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: vendor.isBooked ? _R.green.withOpacity(0.4) : _R.border,
              width: vendor.isBooked ? 1.5 : 1,
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              // Icône catégorie
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [cat.color, cat.color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vendor.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _R.text),
                          ),
                        ),
                        if (vendor.isBooked)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(gradient: _R.goldG, borderRadius: BorderRadius.circular(6)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.star, color: Colors.white, size: 10),
                              const SizedBox(width: 2),
                              Text('RÉSERVÉ', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                            ]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Badge statut
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: status.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: status.color.withOpacity(0.3))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(status.icon, size: 10, color: status.color),
                            const SizedBox(width: 3),
                            Text(status.label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: status.color)),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        // Prix
                        if (vendor.price != null && vendor.price! > 0) ...[
                          Icon(Icons.payments_outlined, size: 10, color: _R.gold),
                          const SizedBox(width: 3),
                          Text('${_fmtMoney(vendor.price!)} FCFA', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _R.gold)),
                        ],
                        const SizedBox(width: 6),
                        // Contact
                        if (vendor.contactName != null && vendor.contactName!.isNotEmpty) ...[
                          Icon(Icons.person_outline, size: 10, color: _R.text2),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(vendor.contactName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10, color: _R.text2)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: _R.text2, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================
class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final bool hasFilter;
  final String weddingId;

  const _EmptyState({required this.hasSearch, required this.hasFilter, required this.weddingId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _R.card(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [_R.blue.withOpacity(0.15), _R.purple.withOpacity(0.1)]), shape: BoxShape.circle),
            child: Icon(hasSearch ? Icons.search_off : Icons.storefront_outlined, size: 40, color: _R.blue),
          ),
          const SizedBox(height: 16),
          Text(hasSearch ? 'Aucun résultat' : (hasFilter ? 'Aucun prestataire pour ce filtre' : 'Aucun prestataire'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(hasSearch ? 'Essayez avec d\'autres termes' : 'Ajoutez votre premier prestataire', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: _R.text2)),
          if (!hasSearch && !hasFilter) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push('/thix-weeding/staff/$weddingId/prestataires/add'),
              icon: const Icon(Icons.add_business, size: 18),
              label: const Text('Ajouter un prestataire'),
              style: FilledButton.styleFrom(backgroundColor: _R.blue, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// LOADING / ERROR
// ============================================================================
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle), child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 36)),
          const SizedBox(height: 16),
          Text('Chargement des prestataires...', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2)),
        ]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _R.rose.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, color: _R.rose, size: 40)),
            const SizedBox(height: 16),
            Text('Impossible de charger', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: _R.text2)),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer'), style: FilledButton.styleFrom(backgroundColor: _R.blue)),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// UTILITAIRES
// ============================================================================
String _fmtMoney(double v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  var c = 0;
  for (var i = s.length - 1; i >= 0; i--) {
    buf.write(s[i]);
    c++;
    if (c % 3 == 0 && i > 0) buf.write(' ');
  }
  return buf.toString().split('').reversed.join();
}
