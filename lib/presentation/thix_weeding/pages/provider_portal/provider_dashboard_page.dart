// lib/presentation/thix_weeding/pages/provider_portal/provider_dashboard_page.dart
// ============================================================================
// THIX WEDDING — DASHBOARD PRESTATAIRE (PRODUCTION v4 — CORRIGÉ)
// ✅ FIX runtime : plus aucune requête sur 'wedding_orders' (table inexistante)
//    → tout est basé sur les RÉSERVATIONS (thix_weeding_reservations) qui marchent
// ✅ Header profil + badge vérification + niveau
// ✅ Stats du jour + alertes urgentes + en attente
// ✅ Graphique revenus (6 mois) basé sur les réservations
// ✅ Actions rapides (offres / galerie / résa / tâches / profil)
// ✅ Prochains événements + recommandations
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';
import 'provider_business_pages.dart' show providerIncomingRequestsProvider;

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color blue = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color purple = Color(0xFF8B5CF6);
}

class ProviderDashboardPage extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  const ProviderDashboardPage({super.key, required this.provider});

  @override
  ConsumerState<ProviderDashboardPage> createState() =>
      _ProviderDashboardPageState();
}

class _ProviderDashboardPageState extends ConsumerState<ProviderDashboardPage> {
  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(providerReservationsProvider(
      ProviderReservationsParams(providerId: widget.provider.id),
    ));
    final tasksAsync = ref.watch(providerTasksProvider(
      ProviderTasksParams(providerId: widget.provider.id),
    ));
    final offersAsync = ref.watch(providerOffersProvider(widget.provider.id));
    final requestsAsync =
        ref.watch(providerIncomingRequestsProvider(widget.provider.id));

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        ref.invalidate(providerReservationsProvider(
          ProviderReservationsParams(providerId: widget.provider.id),
        ));
        ref.invalidate(providerTasksProvider(
          ProviderTasksParams(providerId: widget.provider.id),
        ));
        ref.invalidate(providerOffersProvider(widget.provider.id));
        ref.invalidate(providerIncomingRequestsProvider(widget.provider.id));
        await Future.delayed(const Duration(milliseconds: 400));
      },
      child: Scaffold(
        backgroundColor: _P.bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  reservationsAsync.when(
                    data: (reservations) {
                      final pending = reservations
                          .where((r) => r.status == ReservationStatus.pending)
                          .toList();
                      final urgent = reservations
                          .where((r) =>
                              r.status != ReservationStatus.cancelled &&
                              r.status != ReservationStatus.completed &&
                              r.eventDate
                                  .difference(DateTime.now())
                                  .inDays <=
                                  3 &&
                              r.eventDate
                                  .difference(DateTime.now())
                                  .inDays >=
                                  0)
                          .toList()
                        ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TodaySection(reservations: reservations),
                          const SizedBox(height: 16),
                          if (urgent.isNotEmpty) ...[
                            _UrgentAlertsSection(
                              urgent: urgent,
                              onViewAll: () => context.go(
                                  '/thix-weeding/provider/reservations'),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (pending.isNotEmpty) ...[
                            _PendingSection(
                              pending: pending,
                              onViewAll: () => context.go(
                                  '/thix-weeding/provider/reservations'),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _StatsGrid(reservations: reservations),
                          const SizedBox(height: 24),
                          _RevenueChart(reservations: reservations),
                          const SizedBox(height: 24),
                          _QuickActions(
                            offersCount: offersAsync.valueOrNull?.length ?? 0,
                            pendingCount: pending.length,
                          ),
                          const SizedBox(height: 24),
                          _UpcomingEvents(reservations: reservations),
                          const SizedBox(height: 24),
                          _Recommendations(),
                          const SizedBox(height: 40),
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child: CircularProgressIndicator(color: _P.rose)),
                    ),
                    error: (e, _) => _ErrorBox(message: '$e'),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final p = widget.provider;
    final verified =
        p.verificationStatus == ProviderVerificationStatus.verified;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 190,
      backgroundColor: _P.rose,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_P.rose, _P.roseLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white,
                              child: Text(
                                p.businessName.isNotEmpty
                                    ? p.businessName[0].toUpperCase()
                                    : 'P',
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: _P.rose,
                                ),
                              ),
                            ),
                          ),
                          if (verified)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: _P.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bonjour 👋',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.85),
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(p.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.stars_rounded,
                                          size: 12, color: Colors.white),
                                      const SizedBox(width: 3),
                                      Text(p.level.displayName,
                                          style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded,
                                        size: 12, color: Colors.white70),
                                    const SizedBox(width: 2),
                                    Text(p.city ?? 'RDC',
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
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
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION AUJOURD'HUI
// ═══════════════════════════════════════════════════════════════════════════
class _TodaySection extends StatelessWidget {
  final List<ProviderReservationModel> reservations;
  const _TodaySection({required this.reservations});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayRes = reservations
        .where((r) =>
            r.eventDate.year == today.year &&
            r.eventDate.month == today.month &&
            r.eventDate.day == today.day)
        .toList();
    final pending = reservations
        .where((r) => r.status == ReservationStatus.pending)
        .length;
    final urgent = reservations
        .where((r) =>
            r.status != ReservationStatus.cancelled &&
            r.status != ReservationStatus.completed &&
            r.eventDate.difference(today).inDays <= 3 &&
            r.eventDate.difference(today).inDays >= 0)
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _P.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.today_rounded,
                    color: _P.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Aujourd'hui",
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _P.ink)),
                    Text(DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(today),
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _P.inkSoft,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _TodayStat(
                  icon: Icons.event_rounded,
                  value: '${todayRes.length}',
                  label: 'Événement${todayRes.length > 1 ? 's' : ''}',
                  color: _P.blue),
              const SizedBox(width: 10),
              _TodayStat(
                  icon: Icons.hourglass_empty_rounded,
                  value: '$pending',
                  label: 'En attente',
                  color: pending > 0 ? _P.amber : _P.green),
              const SizedBox(width: 10),
              _TodayStat(
                  icon: Icons.warning_amber_rounded,
                  value: '$urgent',
                  label: 'Urgent${urgent > 1 ? 's' : ''}',
                  color: urgent > 0 ? _P.red : _P.green),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _TodayStat(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color)),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: _P.inkSoft,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ALERTES URGENTES
// ═══════════════════════════════════════════════════════════════════════════
class _UrgentAlertsSection extends StatelessWidget {
  final List<ProviderReservationModel> urgent;
  final VoidCallback onViewAll;
  const _UrgentAlertsSection({required this.urgent, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _P.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _P.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.warning_amber_rounded,
                    color: _P.red, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Réservations urgentes (${urgent.length})',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _P.red)),
              ),
              TextButton(
                onPressed: onViewAll,
                child: Text('Voir tout',
                    style: GoogleFonts.inter(
                        color: _P.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...urgent.take(3).map((r) {
            final days = r.eventDate.difference(DateTime.now()).inDays;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _P.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.priority_high_rounded,
                      color: _P.red, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.clientName,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _P.ink)),
                        Text(r.eventType ?? 'Événement',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: _P.inkSoft)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: _P.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                        days == 0
                            ? "Aujourd'hui"
                            : days == 1
                                ? 'Demain'
                                : 'J-$days',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _P.red)),
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

// ═══════════════════════════════════════════════════════════════════════════
// EN ATTENTE
// ═══════════════════════════════════════════════════════════════════════════
class _PendingSection extends StatelessWidget {
  final List<ProviderReservationModel> pending;
  final VoidCallback onViewAll;
  const _PendingSection({required this.pending, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _P.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _P.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.hourglass_empty_rounded,
                    color: _P.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('À confirmer (${pending.length})',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _P.amber)),
              ),
              TextButton(
                onPressed: onViewAll,
                child: Text('Voir tout',
                    style: GoogleFonts.inter(
                        color: _P.amber,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...pending.take(2).map((r) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _P.amber.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      color: _P.amber, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.clientName,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _P.ink)),
                        Text(
                            '${(r.totalPrice ?? 0).toStringAsFixed(0)}\$ • ${DateFormat('dd MMM', 'fr_FR').format(r.eventDate)}',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: _P.inkSoft)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: _P.amber),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GRILLE DE STATS
// ═══════════════════════════════════════════════════════════════════════════
class _StatsGrid extends StatelessWidget {
  final List<ProviderReservationModel> reservations;
  const _StatsGrid({required this.reservations});

  @override
  Widget build(BuildContext context) {
    final total = reservations.length;
    final confirmed = reservations
        .where((r) => r.status == ReservationStatus.confirmed)
        .length;
    final completed = reservations
        .where((r) => r.status == ReservationStatus.completed)
        .length;
    final revenue = reservations.fold<double>(
        0, (s, r) => s + (r.totalPrice ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Performance globale',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800, color: _P.ink)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _StatCard(
                title: 'Réservations',
                value: '$total',
                icon: Icons.receipt_long_rounded,
                color: _P.blue),
            _StatCard(
                title: 'Confirmées',
                value: '$confirmed',
                icon: Icons.check_circle_rounded,
                color: _P.green),
            _StatCard(
                title: 'Revenus',
                value: '${revenue.toStringAsFixed(0)}\$',
                icon: Icons.attach_money_rounded,
                color: _P.amber),
            _StatCard(
                title: 'Terminées',
                value: '$completed',
                icon: Icons.verified_rounded,
                color: _P.purple),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _P.ink,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _P.inkSoft)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GRAPHIQUE REVENUS (6 mois, basé sur réservations)
// ═══════════════════════════════════════════════════════════════════════════
class _RevenueChart extends StatelessWidget {
  final List<ProviderReservationModel> reservations;
  const _RevenueChart({required this.reservations});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthly = <int, double>{};
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      monthly[m.month] = 0;
    }
    for (final r in reservations) {
      if (r.status == ReservationStatus.cancelled) continue;
      final m = r.eventDate.month;
      if (monthly.containsKey(m)) {
        monthly[m] = monthly[m]! + (r.totalPrice ?? 0);
      }
    }

    final spots = <FlSpot>[];
    var idx = 0;
    monthly.forEach((_, v) {
      spots.add(FlSpot(idx.toDouble(), v));
      idx++;
    });
    final hasData = spots.any((s) => s.y > 0);
    final maxY = hasData
        ? spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2
        : 100.0;

    const monthsFr = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _P.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.trending_up_rounded,
                    color: _P.green, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Évolution des revenus',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _P.ink)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: !hasData
                ? Center(
                    child: Text('Pas encore de données',
                        style: GoogleFonts.inter(
                            color: _P.inkSoft, fontSize: 13)),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (v) =>
                            FlLine(color: _P.line, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles:
                            AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles:
                            AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final mi = (now.month - 5 + value.toInt() - 1) % 12;
                              final label =
                                  monthsFr[(mi < 0 ? mi + 12 : mi)];
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(label,
                                    style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: _P.inkSoft,
                                        fontWeight: FontWeight.w600)),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: maxY / 4,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text(
                                '${(value / 1000).toStringAsFixed(0)}k',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: _P.inkSoft,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 5,
                      minY: 0,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: _P.green,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: _P.green,
                            ),
                          ),
                          belowBarData: BarAreaData(
                              show: true,
                              color: _P.green.withOpacity(0.1)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACTIONS RAPIDES
// ═══════════════════════════════════════════════════════════════════════════
class _QuickActions extends StatelessWidget {
  final int offersCount;
  final int pendingCount;
  const _QuickActions({required this.offersCount, required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions rapides',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800, color: _P.ink)),
        const SizedBox(height: 14),
        Row(
          children: [
            _ActionTile(
              icon: Icons.add_photo_alternate_outlined,
              label: 'Publier\nune offre',
              color: _P.blue,
              badge: offersCount > 0 ? '$offersCount' : null,
              onTap: () =>
                  context.go('/thix-weeding/provider/offers/new'),
            ),
            const SizedBox(width: 10),
            _ActionTile(
              icon: Icons.event_note_rounded,
              label: 'Mes\nréservations',
              color: _P.green,
              badge: pendingCount > 0 ? '$pendingCount' : null,
              badgeColor: _P.amber,
              onTap: () =>
                  context.go('/thix-weeding/provider/reservations'),
            ),
            const SizedBox(width: 10),
            _ActionTile(
              icon: Icons.photo_library_outlined,
              label: 'Ma\ngalerie',
              color: _P.rose,
              onTap: () => context.go('/thix-weeding/provider/gallery'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.color,
      this.badge,
      this.badgeColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          height: 104,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _P.line),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _P.ink,
                          height: 1.2)),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: badgeColor ?? color,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(badge!,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROCHAINS ÉVÉNEMENTS
// ═══════════════════════════════════════════════════════════════════════════
class _UpcomingEvents extends StatelessWidget {
  final List<ProviderReservationModel> reservations;
  const _UpcomingEvents({required this.reservations});

  @override
  Widget build(BuildContext context) {
    final upcoming = reservations
        .where((r) =>
            r.eventDate.isAfter(DateTime.now()) &&
            r.status != ReservationStatus.cancelled)
        .toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _P.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.event_available_rounded,
                    color: _P.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Prochains événements',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _P.ink)),
            ],
          ),
          const SizedBox(height: 14),
          if (upcoming.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _P.bg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_busy_outlined,
                      color: _P.inkSoft, size: 18),
                  const SizedBox(width: 8),
                  Text('Aucun événement à venir',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _P.inkSoft,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            )
          else
            ...upcoming.take(3).map((r) {
              final days = r.eventDate.difference(DateTime.now()).inDays;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _P.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _P.line)),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: _P.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${r.eventDate.day}',
                              style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: _P.blue)),
                          Text(DateFormat('MMM', 'fr_FR').format(r.eventDate),
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: _P.blue)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.clientName,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _P.ink)),
                          Text(r.eventType ?? 'Événement',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: _P.inkSoft)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: days == 0
                            ? _P.red.withOpacity(0.1)
                            : days <= 3
                                ? _P.amber.withOpacity(0.1)
                                : _P.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                          days == 0
                              ? "Aujourd'hui"
                              : days == 1
                                  ? 'Demain'
                                  : 'Dans $days j',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: days == 0
                                  ? _P.red
                                  : days <= 3
                                      ? _P.amber
                                      : _P.green)),
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

// ═══════════════════════════════════════════════════════════════════════════
// RECOMMANDATIONS
// ═══════════════════════════════════════════════════════════════════════════
class _Recommendations extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final recs = [
      _Rec(
          icon: Icons.photo_library_rounded,
          title: 'Ajoutez plus de photos',
          desc: 'Les profils avec 10+ photos reçoivent 3x plus de demandes',
          action: 'Ajouter',
          color: _P.blue,
          onTap: () => context.go('/thix-weeding/provider/gallery')),
      _Rec(
          icon: Icons.sell_outlined,
          title: 'Publiez une offre',
          desc: 'Les offres avec photos + prix convertissent 2x mieux',
          action: 'Publier',
          color: _P.green,
          onTap: () => context.go('/thix-weeding/provider/offers/new')),
      _Rec(
          icon: Icons.badge_rounded,
          title: 'Complétez votre profil',
          desc: 'Un profil complet inspire confiance aux couples',
          action: 'Compléter',
          color: _P.purple,
          onTap: () => context.go('/thix-weeding/provider/profile')),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_P.roseLight.withOpacity(0.1), _P.rose.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.rose.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _P.rose.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.lightbulb_outline_rounded,
                    color: _P.rose, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Recommandations',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _P.ink)),
            ],
          ),
          const SizedBox(height: 14),
          ...recs.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _P.line)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: r.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(r.icon, color: r.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _P.ink)),
                          const SizedBox(height: 2),
                          Text(r.desc,
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: _P.inkSoft)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: r.onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: r.color,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(r.action,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _Rec {
  final IconData icon;
  final String title;
  final String desc;
  final String action;
  final Color color;
  final VoidCallback onTap;
  _Rec(
      {required this.icon,
      required this.title,
      required this.desc,
      required this.action,
      required this.color,
      required this.onTap});
}

// ═══════════════════════════════════════════════════════════════════════════
// BOX ERREUR
// ═══════════════════════════════════════════════════════════════════════════
class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _P.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: _P.red, size: 32),
          const SizedBox(height: 10),
          Text('Erreur de chargement',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _P.ink)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft)),
        ],
      ),
    );
  }
}
