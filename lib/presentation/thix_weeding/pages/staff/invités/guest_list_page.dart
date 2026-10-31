// lib/presentation/thix_weeding/pages/staff/invités/guest_list_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — GUEST LIST (PRODUCTION)
// Design ultra royal + Scanner QR + Import Excel + Stats live + Multi-actions
// Branché sur providers & services EXISTANTS du dépôt
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const LinearGradient roseG = LinearGradient(
    colors: [rose, Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient greenG = LinearGradient(
    colors: [green, greenSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient amberG = LinearGradient(
    colors: [amber, Color(0xFFF59E0B)],
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
// HELPERS RSVP / GROUPES
// ============================================================================
enum _RsvpStatus { pending, confirmed, declined, maybe }

_RsvpStatus _parseRsvp(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'confirmed':
    case 'accepted':
    case 'oui':
      return _RsvpStatus.confirmed;
    case 'declined':
    case 'non':
      return _RsvpStatus.declined;
    case 'maybe':
    case 'peut-être':
      return _RsvpStatus.maybe;
    default:
      return _RsvpStatus.pending;
  }
}

Color _rsvpColor(_RsvpStatus s) {
  switch (s) {
    case _RsvpStatus.confirmed:
      return _R.green;
    case _RsvpStatus.declined:
      return _R.rose;
    case _RsvpStatus.maybe:
      return _R.amber;
    case _RsvpStatus.pending:
      return _R.text2;
  }
}

String _rsvpLabel(_RsvpStatus s) {
  switch (s) {
    case _RsvpStatus.confirmed:
      return 'Confirmé';
    case _RsvpStatus.declined:
      return 'Décliné';
    case _RsvpStatus.maybe:
      return 'Peut-être';
    case _RsvpStatus.pending:
      return 'En attente';
  }
}

Color _groupColor(String? group) {
  final g = (group ?? '').toLowerCase();
  if (g.contains('marié') && !g.contains('mariée')) return _R.blue;
  if (g.contains('mariée')) return _R.rose;
  if (g.contains('vip')) return _R.gold;
  if (g.contains('ami')) return _R.purple;
  if (g.contains('collèg')) return _R.amber;
  if (g.contains('famille')) return _R.blue;
  return _R.blue;
}

IconData _groupIcon(String? group) {
  final g = (group ?? '').toLowerCase();
  if (g.contains('vip')) return Icons.star;
  if (g.contains('mariée')) return Icons.favorite;
  if (g.contains('ami')) return Icons.people;
  if (g.contains('collèg')) return Icons.work;
  return Icons.family_restroom;
}

// ============================================================================
// PAGE
// ============================================================================
class GuestListPage extends ConsumerStatefulWidget {
  final String weddingId;
  const GuestListPage({super.key, required this.weddingId});

  @override
  ConsumerState<GuestListPage> createState() => _GuestListPageState();
}

class _GuestListPageState extends ConsumerState<GuestListPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _filter = 'all'; // all, present, absent, confirmed, declined, vip
  String? _groupFilter;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _debounce?.cancel();
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
    final guestsAsync = ref.watch(guestsProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.surface,
      body: guestsAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(guestsProvider(widget.weddingId)),
        ),
        data: (guests) => _GuestListContent(
          weddingId: widget.weddingId,
          guests: guests,
          searchCtrl: _searchCtrl,
          search: _search,
          filter: _filter,
          groupFilter: _groupFilter,
          onFilterChanged: (f) => setState(() => _filter = f),
          onGroupFilterChanged: (g) => setState(() => _groupFilter = g),
          onRefresh: () async => ref.invalidate(guestsProvider(widget.weddingId)),
        ),
      ),
    );
  }
}

// ============================================================================
// CONTENU PRINCIPAL
// ============================================================================
class _GuestListContent extends StatelessWidget {
  final String weddingId;
  final List<GuestModel> guests;
  final TextEditingController searchCtrl;
  final String search;
  final String filter;
  final String? groupFilter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String?> onGroupFilterChanged;
  final Future<void> Function() onRefresh;

  const _GuestListContent({
    required this.weddingId,
    required this.guests,
    required this.searchCtrl,
    required this.search,
    required this.filter,
    required this.groupFilter,
    required this.onFilterChanged,
    required this.onGroupFilterChanged,
    required this.onRefresh,
  });

  List<GuestModel> get _filtered {
    return guests.where((g) {
      // Search
      final matchSearch = search.isEmpty ||
          g.name.toLowerCase().contains(search) ||
          (g.phone ?? '').toLowerCase().contains(search) ||
          (g.email ?? '').toLowerCase().contains(search) ||
          (g.groupName ?? '').toLowerCase().contains(search);

      // Filter
      bool matchFilter = true;
      final rsvp = _parseRsvp(g.rsvpStatus);
      switch (filter) {
        case 'present':
          matchFilter = g.isPresent;
          break;
        case 'absent':
          matchFilter = !g.isPresent;
          break;
        case 'confirmed':
          matchFilter = rsvp == _RsvpStatus.confirmed;
          break;
        case 'declined':
          matchFilter = rsvp == _RsvpStatus.declined;
          break;
        case 'vip':
          matchFilter = (g.groupName ?? '').toLowerCase().contains('vip');
          break;
      }

      // Group filter
      final matchGroup = groupFilter == null ||
          (g.groupName ?? '').toLowerCase() == groupFilter!.toLowerCase();

      return matchSearch && matchFilter && matchGroup;
    }).toList()
      ..sort((a, b) {
        // VIP en premier
        final aVip = (a.groupName ?? '').toLowerCase().contains('vip');
        final bVip = (b.groupName ?? '').toLowerCase().contains('vip');
        if (aVip && !bVip) return -1;
        if (!aVip && bVip) return 1;
        // Puis présents en premier
        if (a.isPresent && !b.isPresent) return -1;
        if (!a.isPresent && b.isPresent) return 1;
        // Puis par nom
        return a.name.compareTo(b.name);
      });
  }

  // Extraire les groupes uniques
  List<String> get _uniqueGroups {
    final set = <String>{};
    for (final g in guests) {
      if (g.groupName != null && g.groupName!.isNotEmpty) {
        set.add(g.groupName!);
      }
    }
    return set.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final uniqueGroups = _uniqueGroups;

    // Stats
    final total = guests.length;
    final totalSeats = guests.fold<int>(0, (s, g) => s + g.guestsCount);
    final present = guests.where((g) => g.isPresent).fold<int>(0, (s, g) => s + g.guestsCount);
    final confirmed = guests.where((g) => _parseRsvp(g.rsvpStatus) == _RsvpStatus.confirmed).length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── APP BAR ROYALE ──────────────────────────────────────────────
        _RoyalAppBar(
          weddingId: weddingId,
          total: total,
          confirmed: confirmed,
          present: present,
          totalSeats: totalSeats,
          searchCtrl: searchCtrl,
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── STATS BAR ─────────────────────────────────────────────
              _StatsBar(
                total: total,
                confirmed: confirmed,
                present: present,
                declined: guests.where((g) => _parseRsvp(g.rsvpStatus) == _RsvpStatus.declined).length,
              ),
              const SizedBox(height: 12),

              // ── FILTRES ──────────────────────────────────────────────
              _FilterRow(
                current: filter,
                onChanged: onFilterChanged,
              ),
              if (uniqueGroups.isNotEmpty) ...[
                const SizedBox(height: 10),
                _GroupFilterRow(
                  groups: uniqueGroups,
                  selected: groupFilter,
                  onChanged: onGroupFilterChanged,
                ),
              ],
              const SizedBox(height: 16),

              // ── RÉSULTATS ────────────────────────────────────────────
              _ResultHeader(
                count: filtered.length,
                total: total,
                search: search,
              ),
              const SizedBox(height: 10),

              // ── LISTE / EMPTY ────────────────────────────────────────
              if (filtered.isEmpty)
                _EmptyState(
                  hasSearch: search.isNotEmpty,
                  hasFilter: filter != 'all' || groupFilter != null,
                  weddingId: weddingId,
                )
              else
                RefreshIndicator(
                  color: _R.blue,
                  onRefresh: onRefresh,
                  child: Column(
                    children: filtered
                        .map((g) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _GuestCard(
                                guest: g,
                                weddingId: weddingId,
                              ),
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
class _RoyalAppBar extends StatelessWidget {
  final String weddingId;
  final int total;
  final int confirmed;
  final int present;
  final int totalSeats;
  final TextEditingController searchCtrl;

  const _RoyalAppBar({
    required this.weddingId,
    required this.total,
    required this.confirmed,
    required this.present,
    required this.totalSeats,
    required this.searchCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 230,
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
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
            ],
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 14, color: _R.text),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        // Bouton import Excel
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _showImportSheet(context, weddingId),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.file_upload_outlined, color: _R.blue, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Bouton Scanner QR
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _openScanner(context, weddingId),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.qr_code_scanner, color: _R.blue, size: 20),
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
            // Motifs décoratifs
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _R.gold.withOpacity(0.15),
                ),
              ),
            ),

            FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'INVITÉS',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.85),
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$total',
                                      style: GoogleFonts.inter(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'invités',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '$totalSeats places • $confirmed confirmés • $present présents',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Bouton Ajouter
                          _AddButton(weddingId: weddingId),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Search bar
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: searchCtrl,
                          style: GoogleFonts.inter(fontSize: 14, color: _R.text),
                          decoration: InputDecoration(
                            hintText: 'Rechercher nom, téléphone, email...',
                            hintStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
                            prefixIcon: const Icon(Icons.search, color: _R.blue, size: 20),
                            suffixIcon: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: searchCtrl,
                              builder: (_, v, __) => v.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        searchCtrl.clear();
                                      },
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        onTap: () => context.push('/thix-weeding/staff/$weddingId/invites/add'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: _R.goldG,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _R.gold.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_add, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                'Ajouter',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
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
  final int confirmed;
  final int present;
  final int declined;

  const _StatsBar({
    required this.total,
    required this.confirmed,
    required this.present,
    required this.declined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _R.card(),
      child: Row(
        children: [
          _MiniStat(
            icon: Icons.people_outline,
            label: 'Total',
            value: '$total',
            color: _R.blue,
          ),
          _MiniStat(
            icon: Icons.check_circle_outline,
            label: 'Confirmés',
            value: '$confirmed',
            color: _R.green,
          ),
          _MiniStat(
            icon: Icons.event_available,
            label: 'Présents',
            value: '$present',
            color: _R.purple,
          ),
          _MiniStat(
            icon: Icons.cancel_outlined,
            label: 'Déclinés',
            value: '$declined',
            color: _R.rose,
          ),
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
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 9, color: _R.text2),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FILTER ROW
// ============================================================================
class _FilterRow extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _FilterRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final filters = <_FilterDef>[
      _FilterDef('all', 'Tous', Icons.all_inbox, _R.blue),
      _FilterDef('confirmed', 'Confirmés', Icons.check_circle_outline, _R.green),
      _FilterDef('present', 'Présents', Icons.event_available, _R.purple),
      _FilterDef('absent', 'Absents', Icons.event_busy, _R.amber),
      _FilterDef('declined', 'Déclinés', Icons.cancel_outlined, _R.rose),
      _FilterDef('vip', 'VIP', Icons.star, _R.gold),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final selected = current == f.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: selected ? f.color : Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onChanged(f.value),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? f.color : _R.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        f.icon,
                        size: 14,
                        color: selected ? Colors.white : f.color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        f.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : _R.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterDef {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  _FilterDef(this.value, this.label, this.icon, this.color);
}

// ============================================================================
// GROUP FILTER ROW
// ============================================================================
class _GroupFilterRow extends StatelessWidget {
  final List<String> groups;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _GroupFilterRow({
    required this.groups,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _GroupChip(
            label: 'Tous groupes',
            icon: Icons.filter_list,
            color: _R.text2,
            isSelected: selected == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 6),
          ...groups.map((g) {
            final color = _groupColor(g);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _GroupChip(
                label: g,
                icon: _groupIcon(g),
                color: color,
                isSelected: selected == g,
                onTap: () => onChanged(g),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color.withOpacity(0.12) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : _R.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : _R.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// RESULT HEADER
// ============================================================================
class _ResultHeader extends StatelessWidget {
  final int count;
  final int total;
  final String search;

  const _ResultHeader({
    required this.count,
    required this.total,
    required this.search,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.list_alt_outlined, size: 16, color: _R.blue),
        const SizedBox(width: 6),
        Text(
          search.isEmpty ? 'Liste des invités' : 'Résultats',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _R.blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            search.isEmpty ? '$total' : '$count / $total',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _R.blue,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// GUEST CARD
// ============================================================================
class _GuestCard extends ConsumerStatefulWidget {
  final GuestModel guest;
  final String weddingId;

  const _GuestCard({required this.guest, required this.weddingId});

  @override
  ConsumerState<_GuestCard> createState() => _GuestCardState();
}

class _GuestCardState extends ConsumerState<_GuestCard> {
  bool _isToggling = false;

  Future<void> _togglePresent() async {
    setState(() => _isToggling = true);
    try {
      await ref.read(guestServiceProvider).togglePresent(
            widget.guest.id,
            !widget.guest.isPresent,
          );
      ref.invalidate(guestsProvider(widget.weddingId));
      ref.invalidate(dashboardStatsProvider(widget.weddingId));
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => _DeleteDialog(guest: widget.guest),
    );
    if (ok != true) return;

    try {
      await ref.read(guestServiceProvider).delete(widget.guest.id);
      ref.invalidate(guestsProvider(widget.weddingId));
      ref.invalidate(dashboardStatsProvider(widget.weddingId));
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ],
      ),
      backgroundColor: _R.rose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guest;
    final rsvp = _parseRsvp(g.rsvpStatus);
    final rsvpColor = _rsvpColor(rsvp);
    final groupColor = _groupColor(g.groupName);
    final isVip = (g.groupName ?? '').toLowerCase().contains('vip');
    final initial = g.name.isNotEmpty ? g.name[0].toUpperCase() : '?';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push('/thix-weeding/staff/${widget.weddingId}/invites/${g.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: g.isPresent
                  ? _R.green.withOpacity(0.4)
                  : isVip
                      ? _R.gold.withOpacity(0.4)
                      : _R.border,
              width: g.isPresent || isVip ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          groupColor.withOpacity(0.2),
                          groupColor.withOpacity(0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: groupColor.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: groupColor,
                        ),
                      ),
                    ),
                  ),
                  // Badge présence
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: g.isPresent ? _R.green : _R.text2,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: g.isPresent ? _R.greenSoft : _R.border,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
                            g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _R.text,
                            ),
                          ),
                        ),
                        if (isVip)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: _R.goldG,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.white, size: 10),
                                const SizedBox(width: 2),
                                Text(
                                  'VIP',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StatusDot(color: rsvpColor),
                        const SizedBox(width: 4),
                        Text(
                          _rsvpLabel(rsvp),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: rsvpColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.group, size: 10, color: _R.text2),
                        const SizedBox(width: 3),
                        Text(
                          '${g.guestsCount} pers.',
                          style: GoogleFonts.inter(fontSize: 10, color: _R.text2),
                        ),
                        if (g.groupName != null && g.groupName!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(_groupIcon(g.groupName), size: 10, color: groupColor),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              g.groupName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: groupColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (g.tableNumber != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _R.gold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _R.gold.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.table_restaurant, size: 10, color: _R.goldDark),
                                const SizedBox(width: 3),
                                Text(
                                  'Table ${g.tableNumber}',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: _R.goldDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (g.phone != null && g.phone!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _R.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone, size: 10, color: _R.green),
                                const SizedBox(width: 3),
                                Text(
                                  g.phone!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color: _R.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Quick toggle
              _isToggling
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _R.blue),
                    )
                  : Material(
                      color: g.isPresent ? _R.green.withOpacity(0.1) : Colors.grey.withOpacity(0.08),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _togglePresent,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            g.isPresent ? Icons.event_available : Icons.login,
                            size: 18,
                            color: g.isPresent ? _R.green : _R.text2,
                          ),
                        ),
                      ),
                    ),

              // Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: _R.text2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'toggle') _togglePresent();
                  if (v == 'edit') {
                    context.push('/thix-weeding/staff/${widget.weddingId}/invites/${g.id}/edit');
                  }
                  if (v == 'delete') _delete();
                  if (v == 'call' && g.phone != null) {
                    // url_launcher
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          g.isPresent ? Icons.exit_to_app : Icons.login,
                          size: 18,
                          color: g.isPresent ? _R.amber : _R.green,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          g.isPresent ? 'Marquer absent' : 'Marquer présent',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (g.phone != null && g.phone!.isNotEmpty)
                    PopupMenuItem(
                      value: 'call',
                      child: Row(
                        children: [
                          const Icon(Icons.call, size: 18, color: _R.green),
                          const SizedBox(width: 10),
                          Text('Appeler', style: GoogleFonts.inter(fontSize: 13)),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 18, color: _R.blue),
                        const SizedBox(width: 10),
                        Text('Modifier', style: GoogleFonts.inter(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 18, color: _R.rose),
                        const SizedBox(width: 10),
                        Text(
                          'Supprimer',
                          style: GoogleFonts.inter(fontSize: 13, color: _R.rose),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

  const _EmptyState({
    required this.hasSearch,
    required this.hasFilter,
    required this.weddingId,
  });

  @override
  Widget build(BuildContext context) {
    final icon = hasSearch ? Icons.search_off : (hasFilter ? Icons.filter_list_off : Icons.people_outline);
    final title = hasSearch
        ? 'Aucun résultat'
        : (hasFilter ? 'Aucun invité pour ce filtre' : 'Aucun invité');
    final subtitle = hasSearch
        ? 'Essayez avec d\'autres termes'
        : (hasFilter
            ? 'Modifiez vos filtres pour voir plus de résultats'
            : 'Commencez par ajouter vos premiers invités');

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _R.card(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_R.blue.withOpacity(0.15), _R.purple.withOpacity(0.1)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: _R.blue),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
          ),
          if (!hasSearch && !hasFilter) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showImportSheet(context, weddingId),
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('Import Excel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _R.blue,
                      side: const BorderSide(color: _R.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/thix-weeding/staff/$weddingId/invites/add'),
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Ajouter un invité'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _R.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// DIALOG SUPPRESSION
// ============================================================================
class _DeleteDialog extends StatelessWidget {
  final GuestModel guest;
  const _DeleteDialog({required this.guest});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: _R.roseG,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'Supprimer cet invité ?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _R.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${guest.name}" sera définitivement retiré de la liste. Son invitation et son QR code ne seront plus valides.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _R.text2),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _R.text,
                      side: const BorderSide(color: _R.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _R.rose,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// IMPORT EXCEL SHEET
// ============================================================================
void _showImportSheet(BuildContext context, String weddingId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ImportSheet(weddingId: weddingId),
  );
}

class _ImportSheet extends StatelessWidget {
  final String weddingId;
  const _ImportSheet({required this.weddingId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _R.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  gradient: _R.greenG,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(Icons.file_upload, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Importer une liste',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Option 1 : Excel/CSV
          _ImportOption(
            icon: Icons.table_chart,
            label: 'Fichier Excel (.xlsx)',
            subtitle: 'Colonnes : Nom, Téléphone, Email, Groupe',
            color: _R.green,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 10),
          _ImportOption(
            icon: Icons.description_outlined,
            label: 'Fichier CSV',
            subtitle: 'Séparé par virgules ou points-virgules',
            color: _R.blue,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 10),
          _ImportOption(
            icon: Icons.contacts,
            label: 'Depuis les contacts',
            subtitle: 'Importer depuis votre téléphone',
            color: _R.purple,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _R.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _R.amber.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: _R.amber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Un Thix ID unique sera généré automatiquement pour chaque invité importé.',
                    style: GoogleFonts.inter(fontSize: 11, color: _R.amber),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ImportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ImportOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _R.text2),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SCANNER QR
// ============================================================================
void _openScanner(BuildContext context, String weddingId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ScannerSheet(weddingId: weddingId),
  );
}

class _ScannerSheet extends StatefulWidget {
  final String weddingId;
  const _ScannerSheet({required this.weddingId});

  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  final _manualCtrl = TextEditingController();
  bool _isChecking = false;

  Future<void> _validate(String code) async {
    if (code.trim().isEmpty) return;
    setState(() => _isChecking = true);

    // Simuler validation (à connecter au QRCodeValidator de sécurité)
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() => _isChecking = false);

    if (!mounted) return;

    // Chercher l'invité par nom ou Thix ID
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: _R.greenG,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                'Code scanné',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _R.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  code,
                  style: GoogleFonts.inter(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: _R.text,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(backgroundColor: _R.blue),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _R.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  gradient: _R.royal,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Scanner QR Code',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Preview zone (à remplacer par mobile_scanner)
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 48),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Caméra QR',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Placez le QR code dans le cadre',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                // Cadre
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: _R.gold, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ou saisie manuelle
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: _R.border,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OU',
                  style: GoogleFonts.inter(fontSize: 11, color: _R.text2, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: _R.border,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _manualCtrl,
            style: GoogleFonts.inter(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Saisir le Thix ID manuellement...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: _R.text2),
              prefixIcon: const Icon(Icons.keyboard, color: _R.blue),
              filled: true,
              fillColor: _R.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isChecking ? null : () => _validate(_manualCtrl.text),
              icon: _isChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(_isChecking ? 'Vérification...' : 'Valider'),
              style: FilledButton.styleFrom(
                backgroundColor: _R.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle),
              child: const Icon(Icons.people, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement des invités...',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2),
            ),
          ],
        ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _R.rose.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, color: _R.rose, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Impossible de charger les invités',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: FilledButton.styleFrom(backgroundColor: _R.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
