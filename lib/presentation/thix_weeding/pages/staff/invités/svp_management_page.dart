// lib/presentation/thix_weeding/pages/staff/invités/rsvp_management_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — RSVP MANAGEMENT (PRODUCTION)
// Design royal + Stats temps réel + Rappels bulk + Export + Filtres avancés
// Branché sur providers & services EXISTANTS du dépôt
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

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

  static BoxDecoration card({double r = 16}) => BoxDecoration(
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
// ENUM RSVP
// ============================================================================
enum _RsvpStatus { pending, confirmed, declined, maybe }

_RsvpStatus _parseRsvp(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'confirmed':
    case 'accepted':
    case 'yes':
    case 'oui':
      return _RsvpStatus.confirmed;
    case 'declined':
    case 'no':
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

IconData _rsvpIcon(_RsvpStatus s) {
  switch (s) {
    case _RsvpStatus.confirmed:
      return Icons.check_circle;
    case _RsvpStatus.declined:
      return Icons.cancel;
    case _RsvpStatus.maybe:
      return Icons.help;
    case _RsvpStatus.pending:
      return Icons.hourglass_empty;
  }
}

// ============================================================================
// COULEURS GROUPES
// ============================================================================
Color _groupColor(String? group) {
  final g = (group ?? '').toLowerCase();
  if (g.contains('marié') && !g.contains('mariée')) return _R.blue;
  if (g.contains('mariée')) return _R.rose;
  if (g.contains('vip')) return _R.gold;
  if (g.contains('ami')) return _R.purple;
  if (g.contains('collèg')) return _R.amber;
  return _R.blue;
}

// ============================================================================
// PAGE
// ============================================================================
class RsvpManagementPage extends ConsumerStatefulWidget {
  final String weddingId;
  const RsvpManagementPage({super.key, required this.weddingId});

  @override
  ConsumerState<RsvpManagementPage> createState() => _RsvpManagementPageState();
}

class _RsvpManagementPageState extends ConsumerState<RsvpManagementPage> {
  String _filter = 'all'; // all, confirmed, declined, maybe, pending
  String _search = '';

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
        data: (guests) => _RsvpContent(
          weddingId: widget.weddingId,
          guests: guests,
          filter: _filter,
          search: _search,
          onFilterChanged: (f) => setState(() => _filter = f),
          onSearchChanged: (s) => setState(() => _search = s),
          onRefresh: () async => ref.invalidate(guestsProvider(widget.weddingId)),
        ),
      ),
    );
  }
}

// ============================================================================
// CONTENU PRINCIPAL
// ============================================================================
class _RsvpContent extends StatelessWidget {
  final String weddingId;
  final List<GuestModel> guests;
  final String filter;
  final String search;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;

  const _RsvpContent({
    required this.weddingId,
    required this.guests,
    required this.filter,
    required this.search,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  // Calculs statistiques
  int get _total => guests.length;
  int get _totalSeats => guests.fold<int>(0, (s, g) => s + g.guestsCount);
  int get _confirmed => guests
      .where((g) => _parseRsvp(g.rsvpStatus) == _RsvpStatus.confirmed)
      .fold<int>(0, (s, g) => s + g.guestsCount);
  int get _declined => guests
      .where((g) => _parseRsvp(g.rsvpStatus) == _RsvpStatus.declined)
      .fold<int>(0, (s, g) => s + g.guestsCount);
  int get _pending => guests
      .where((g) => _parseRsvp(g.rsvpStatus) == _RsvpStatus.pending)
      .fold<int>(0, (s, g) => s + g.guestsCount);
  int get _maybe => guests
      .where((g) => _parseRsvp(g.rsvpStatus) == _RsvpStatus.maybe)
      .fold<int>(0, (s, g) => s + g.guestsCount);

  double get _responseRate {
    if (_total == 0) return 0;
    final responded = _confirmed + _declined + _maybe;
    return responded / _totalSeats.clamp(1, 999999);
  }

  List<GuestModel> get _filtered {
    return guests.where((g) {
      final rsvp = _parseRsvp(g.rsvpStatus);
      final matchFilter = filter == 'all' ||
          (filter == 'confirmed' && rsvp == _RsvpStatus.confirmed) ||
          (filter == 'declined' && rsvp == _RsvpStatus.declined) ||
          (filter == 'maybe' && rsvp == _RsvpStatus.maybe) ||
          (filter == 'pending' && rsvp == _RsvpStatus.pending);
      final matchSearch = search.isEmpty ||
          g.name.toLowerCase().contains(search.toLowerCase()) ||
          (g.phone ?? '').contains(search) ||
          (g.email ?? '').toLowerCase().contains(search.toLowerCase());
      return matchFilter && matchSearch;
    }).toList()
      ..sort((a, b) {
        // Tri : confirmés en premier, puis pending, puis maybe, puis declined
        final orderA = _sortOrder(_parseRsvp(a.rsvpStatus));
        final orderB = _sortOrder(_parseRsvp(b.rsvpStatus));
        if (orderA != orderB) return orderA.compareTo(orderB);
        return a.name.compareTo(b.name);
      });
  }

  int _sortOrder(_RsvpStatus s) {
    switch (s) {
      case _RsvpStatus.confirmed:
        return 0;
      case _RsvpStatus.maybe:
        return 1;
      case _RsvpStatus.pending:
        return 2;
      case _RsvpStatus.declined:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── APP BAR ─────────────────────────────────────────────────────
        _RoyalAppBar(
          total: _total,
          totalSeats: _totalSeats,
          responseRate: _responseRate,
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── HERO BANNER TAUX DE RÉPONSE ─────────────────────────
              _ResponseRateCard(
                rate: _responseRate,
                confirmed: _confirmed,
                declined: _declined,
                pending: _pending,
                maybe: _maybe,
                totalSeats: _totalSeats,
              ),
              const SizedBox(height: 16),

              // ── 4 STATS CARDS ───────────────────────────────────────
              _StatsGrid(
                confirmed: _confirmed,
                declined: _declined,
                pending: _pending,
                maybe: _maybe,
              ),
              const SizedBox(height: 16),

              // ── BREAKDOWN PAR GROUPE ────────────────────────────────
              _GroupBreakdownCard(guests: guests),
              const SizedBox(height: 16),

              // ── ACTIONS RAPIDES ─────────────────────────────────────
              _QuickActions(
                weddingId: weddingId,
                pendingCount: guests
                    .where((g) => _parseRsvp(g.rsvpStatus) == _RsvpStatus.pending)
                    .length,
              ),
              const SizedBox(height: 16),

              // ── SEARCH + FILTERS ────────────────────────────────────
              _SearchField(value: search, onChanged: onSearchChanged),
              const SizedBox(height: 12),
              _FilterRow(current: filter, onChanged: onFilterChanged),
              const SizedBox(height: 16),

              // ── HEADER LISTE ────────────────────────────────────────
              _ListHeader(
                count: filtered.length,
                total: _total,
                filter: filter,
              ),
              const SizedBox(height: 10),

              // ── LISTE / EMPTY ───────────────────────────────────────
              if (filtered.isEmpty)
                _EmptyState(filter: filter, search: search)
              else
                RefreshIndicator(
                  color: _R.blue,
                  onRefresh: onRefresh,
                  child: Column(
                    children: filtered
                        .map((g) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _GuestRsvpTile(
                                guest: g,
                                weddingId: weddingId,
                                onReminderSent: onRefresh,
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
// APP BAR
// ============================================================================
class _RoyalAppBar extends StatelessWidget {
  final int total;
  final int totalSeats;
  final double responseRate;

  const _RoyalAppBar({
    required this.total,
    required this.totalSeats,
    required this.responseRate,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
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
            onTap: () => _showExportSheet(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.file_download_outlined, color: _R.blue, size: 20),
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
                      Text(
                        'GESTION RSVP',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.85),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Suivi des confirmations',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _MiniStat(label: 'Invités', value: '$total'),
                          const SizedBox(width: 16),
                          _MiniStat(label: 'Places', value: '$totalSeats'),
                          const SizedBox(width: 16),
                          _MiniStat(
                            label: 'Taux',
                            value: '${(responseRate * 100).toInt()}%',
                          ),
                        ],
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// HERO CARD : TAUX DE RÉPONSE
// ============================================================================
class _ResponseRateCard extends StatelessWidget {
  final double rate;
  final int confirmed;
  final int declined;
  final int pending;
  final int maybe;
  final int totalSeats;

  const _ResponseRateCard({
    required this.rate,
    required this.confirmed,
    required this.declined,
    required this.pending,
    required this.maybe,
    required this.totalSeats,
  });

  @override
  Widget build(BuildContext context) {
    final responded = confirmed + declined + maybe;
    final percent = (rate * 100).toInt();
    final gradient = percent >= 80
        ? _R.greenG
        : percent >= 50
            ? _R.amberG
            : _R.roseG;
    final statusColor = percent >= 80
        ? _R.green
        : percent >= 50
            ? _R.amber
            : _R.rose;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Donut-like indicator
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: rate,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percent%',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'répondu',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Taux de réponse',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$responded / $totalSeats',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      percent >= 80
                          ? 'Excellent taux de réponse !'
                          : percent >= 50
                              ? 'Envoyez des rappels aux invités en attente'
                              : 'Beaucoup de réponses manquantes',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Barre empilée des réponses
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (confirmed > 0)
                    Expanded(
                      flex: confirmed,
                      child: Container(color: Colors.white),
                    ),
                  if (maybe > 0)
                    Expanded(
                      flex: maybe,
                      child: Container(color: Colors.white.withOpacity(0.7)),
                    ),
                  if (declined > 0)
                    Expanded(
                      flex: declined,
                      child: Container(color: Colors.white.withOpacity(0.4)),
                    ),
                  if (pending > 0)
                    Expanded(
                      flex: pending,
                      child: Container(color: Colors.white.withOpacity(0.15)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LegendChip(color: Colors.white, label: 'Confirmés'),
              _LegendChip(color: Colors.white.withOpacity(0.7), label: 'Peut-être'),
              _LegendChip(color: Colors.white.withOpacity(0.4), label: 'Déclinés'),
              _LegendChip(color: Colors.white.withOpacity(0.15), label: 'En attente'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.95),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STATS GRID (4 cards)
// ============================================================================
class _StatsGrid extends StatelessWidget {
  final int confirmed;
  final int declined;
  final int pending;
  final int maybe;

  const _StatsGrid({
    required this.confirmed,
    required this.declined,
    required this.pending,
    required this.maybe,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Confirmés',
                value: confirmed,
                icon: Icons.check_circle,
                gradient: _R.greenG,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Peut-être',
                value: maybe,
                icon: Icons.help_outline,
                gradient: _R.amberG,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'En attente',
                value: pending,
                icon: Icons.hourglass_empty,
                gradient: const LinearGradient(
                  colors: [Color(0xFF64748B), Color(0xFF475569)],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Déclinés',
                value: declined,
                icon: Icons.cancel_outlined,
                gradient: _R.roseG,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final LinearGradient gradient;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _R.card(r: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _R.text,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BREAKDOWN PAR GROUPE
// ============================================================================
class _GroupBreakdownCard extends StatelessWidget {
  final List<GuestModel> guests;
  const _GroupBreakdownCard({required this.guests});

  @override
  Widget build(BuildContext context) {
    // Agrégation par groupe
    final Map<String, _GroupStats> stats = {};
    for (final g in guests) {
      final group = g.groupName ?? 'Sans groupe';
      stats.putIfAbsent(group, () => _GroupStats());
      stats[group]!.total += g.guestsCount;
      final rsvp = _parseRsvp(g.rsvpStatus);
      if (rsvp == _RsvpStatus.confirmed) stats[group]!.confirmed += g.guestsCount;
    }

    if (stats.isEmpty) return const SizedBox.shrink();

    final sorted = stats.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: _R.royal,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: const Icon(Icons.group_outlined, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Répartition par groupe',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...sorted.map((entry) {
            final color = _groupColor(entry.key);
            final ratio = entry.value.total > 0
                ? entry.value.confirmed / entry.value.total
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value.confirmed}/${entry.value.total}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _R.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: ratio,
                      backgroundColor: color.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _GroupStats {
  int total = 0;
  int confirmed = 0;
}

// ============================================================================
// ACTIONS RAPIDES
// ============================================================================
class _QuickActions extends StatelessWidget {
  final String weddingId;
  final int pendingCount;

  const _QuickActions({required this.weddingId, required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: _R.goldG,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: const Icon(Icons.bolt, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Actions rapides',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.notifications_active_outlined,
                  label: 'Rappel',
                  subtitle: '$pendingCount en attente',
                  color: _R.amber,
                  onTap: pendingCount > 0
                      ? () => _showReminderDialog(context, weddingId)
                      : null,
                  badge: pendingCount,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.message_outlined,
                  label: 'Message',
                  subtitle: 'À tous',
                  color: _R.blue,
                  onTap: () => _showBulkMessageSheet(context, weddingId),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.file_download_outlined,
                  label: 'Export',
                  subtitle: 'PDF',
                  color: _R.rose,
                  onTap: () => _showExportSheet(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final int badge;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: disabled ? _R.border.withOpacity(0.3) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: disabled ? _R.border : color.withOpacity(0.3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: disabled ? _R.text2 : color),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: disabled ? _R.text2 : color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: disabled ? _R.text2.withOpacity(0.7) : _R.text2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$badge',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// SEARCH FIELD
// ============================================================================
class _SearchField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14, color: _R.text),
      decoration: InputDecoration(
        hintText: 'Rechercher par nom, téléphone, email...',
        hintStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: _R.blue, size: 20),
        suffixIcon: value.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18, color: _R.text2),
                onPressed: () => onChanged(''),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _R.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _R.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _R.blue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      _FilterDef('confirmed', 'Confirmés', Icons.check_circle, _R.green),
      _FilterDef('pending', 'En attente', Icons.hourglass_empty, _R.text2),
      _FilterDef('maybe', 'Peut-être', Icons.help, _R.amber),
      _FilterDef('declined', 'Déclinés', Icons.cancel, _R.rose),
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
                      Icon(f.icon, size: 14, color: selected ? Colors.white : f.color),
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
// LIST HEADER
// ============================================================================
class _ListHeader extends StatelessWidget {
  final int count;
  final int total;
  final String filter;

  const _ListHeader({required this.count, required this.total, required this.filter});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.people_alt_outlined, size: 16, color: _R.blue),
        const SizedBox(width: 6),
        Text(
          filter == 'all' ? 'Tous les invités' : 'Invités filtrés',
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
            filter == 'all' ? '$total' : '$count / $total',
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
// GUEST RSVP TILE
// ============================================================================
class _GuestRsvpTile extends ConsumerStatefulWidget {
  final GuestModel guest;
  final String weddingId;
  final VoidCallback onReminderSent;

  const _GuestRsvpTile({
    required this.guest,
    required this.weddingId,
    required this.onReminderSent,
  });

  @override
  ConsumerState<_GuestRsvpTile> createState() => _GuestRsvpTileState();
}

class _GuestRsvpTileState extends ConsumerState<_GuestRsvpTile> {
  bool _sendingReminder = false;

  Future<void> _sendReminder() async {
    setState(() => _sendingReminder = true);
    // Simule l'envoi d'un rappel (à connecter au service réel)
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _sendingReminder = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Rappel envoyé à ${widget.guest.name}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: _R.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _overrideStatus(_RsvpStatus newStatus) async {
    try {
      final statusStr = switch (newStatus) {
        _RsvpStatus.confirmed => 'confirmed',
        _RsvpStatus.declined => 'declined',
        _RsvpStatus.maybe => 'maybe',
        _RsvpStatus.pending => 'pending',
      };
      await Supabase.instance.client
          .from('thix_weeding_guests')
          .update({'rsvp_status': statusStr})
          .eq('id', widget.guest.id);
      ref.invalidate(guestsProvider(widget.weddingId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: _R.rose,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guest;
    final rsvp = _parseRsvp(g.rsvpStatus);
    final rsvpColor = _rsvpColor(rsvp);
    final groupColor = _groupColor(g.groupName);
    final isPending = rsvp == _RsvpStatus.pending;
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
              color: isPending ? _R.amber.withOpacity(0.4) : _R.border,
              width: isPending ? 1.5 : 1,
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      rsvpColor.withOpacity(0.2),
                      rsvpColor.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: rsvpColor.withOpacity(0.4), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: rsvpColor,
                    ),
                  ),
                ),
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
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(_rsvpIcon(rsvp), size: 12, color: rsvpColor),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: groupColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              g.groupName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: groupColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (g.phone != null && g.phone!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 10, color: _R.text2),
                          const SizedBox(width: 4),
                          Text(
                            g.phone!,
                            style: GoogleFonts.inter(fontSize: 10, color: _R.text2),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Actions
              if (isPending && !_sendingReminder)
                Material(
                  color: _R.amber.withOpacity(0.1),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _sendReminder,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.send, size: 16, color: _R.amber),
                    ),
                  ),
                )
              else if (_sendingReminder)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _R.amber),
                ),

              // Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: _R.text2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'override_confirmed') _overrideStatus(_RsvpStatus.confirmed);
                  if (v == 'override_declined') _overrideStatus(_RsvpStatus.declined);
                  if (v == 'override_maybe') _overrideStatus(_RsvpStatus.maybe);
                  if (v == 'override_pending') _overrideStatus(_RsvpStatus.pending);
                  if (v == 'details') {
                    context.push('/thix-weeding/staff/${widget.weddingId}/invites/${g.id}');
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    enabled: false,
                    child: Text(
                      'Modifier le statut',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'override_confirmed',
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: _R.green),
                        const SizedBox(width: 10),
                        Text('Marquer confirmé', style: GoogleFonts.inter(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'override_maybe',
                    child: Row(
                      children: [
                        const Icon(Icons.help, size: 16, color: _R.amber),
                        const SizedBox(width: 10),
                        Text('Marquer peut-être', style: GoogleFonts.inter(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'override_declined',
                    child: Row(
                      children: [
                        const Icon(Icons.cancel, size: 16, color: _R.rose),
                        const SizedBox(width: 10),
                        Text('Marquer décliné', style: GoogleFonts.inter(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'override_pending',
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_empty, size: 16, color: _R.text2),
                        const SizedBox(width: 10),
                        Text('Remettre en attente', style: GoogleFonts.inter(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'details',
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: _R.blue),
                        const SizedBox(width: 10),
                        Text('Voir détails', style: GoogleFonts.inter(fontSize: 13)),
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

// ============================================================================
// EMPTY STATE
// ============================================================================
class _EmptyState extends StatelessWidget {
  final String filter;
  final String search;

  const _EmptyState({required this.filter, required this.search});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _R.card(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _R.border.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              search.isNotEmpty ? Icons.search_off : Icons.people_outline,
              size: 40,
              color: _R.text2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            search.isNotEmpty
                ? 'Aucun résultat'
                : 'Aucun invité pour ce filtre',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            search.isNotEmpty
                ? 'Essayez avec d\'autres termes'
                : 'Modifiez vos filtres pour voir plus de résultats',
            style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DIALOG RAPPEL BULK
// ============================================================================
void _showReminderDialog(BuildContext context, String weddingId) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(gradient: _R.amberG, shape: BoxShape.circle),
              child: const Icon(Icons.notifications_active, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'Envoyer des rappels ?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Un message de rappel sera envoyé à tous les invités qui n\'ont pas encore répondu.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _R.text2),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _R.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _R.blue.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  _ChannelRow(icon: Icons.message, label: 'SMS', color: _R.green),
                  const SizedBox(height: 8),
                  _ChannelRow(icon: Icons.chat_bubble, label: 'THIX Chat', color: _R.blue),
                  const SizedBox(height: 8),
                  _ChannelRow(icon: Icons.email, label: 'Email', color: _R.purple),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _R.text,
                      side: const BorderSide(color: _R.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Rappels envoyés avec succès ✓'),
                          backgroundColor: _R.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Envoyer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _R.amber,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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

class _ChannelRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ChannelRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ============================================================================
// SHEET MESSAGE BULK
// ============================================================================
void _showBulkMessageSheet(BuildContext context, String weddingId) {
  final controller = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setS) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  child: const Icon(Icons.message, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Message groupé',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              maxLines: 4,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ex: N\'oubliez pas de confirmer votre présence pour notre mariage...',
                hintStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
                filled: true,
                fillColor: _R.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Message envoyé à tous les invités ✓'),
                      backgroundColor: _R.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Envoyer à tous'),
                style: FilledButton.styleFrom(
                  backgroundColor: _R.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================================
// SHEET EXPORT
// ============================================================================
void _showExportSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            'Exporter la liste RSVP',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          _ExportOption(
            icon: Icons.picture_as_pdf,
            label: 'Rapport PDF',
            subtitle: 'Document professionnel prêt à imprimer',
            color: _R.rose,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 10),
          _ExportOption(
            icon: Icons.table_chart,
            label: 'Excel (.xlsx)',
            subtitle: 'Pour analyse et tri personnalisé',
            color: _R.green,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 10),
          _ExportOption(
            icon: Icons.print_outlined,
            label: 'Liste d\'émargement',
            subtitle: 'Format jour J pour contrôle d\'accès',
            color: _R.blue,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ExportOption({
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
              decoration: const BoxDecoration(gradient: _R.royal, shape: BoxShape.circle),
              child: const Icon(Icons.mark_email_read, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement des RSVP...',
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
                'Impossible de charger',
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
