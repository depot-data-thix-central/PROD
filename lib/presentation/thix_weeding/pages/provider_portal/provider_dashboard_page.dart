// lib/presentation/thix_weeding/pages/provider_portal/provider_dashboard_page.dart
// ============================================================================
// THIX WEDDING PROVIDER DASHBOARD (PRODUCTION ENTERPRISE)
// ✅ Stats temps réel (Revenus, Réservations, Tâches)
// ✅ Design glassmorphism blanc/rose premium
// ✅ Actions rapides et alertes de validation
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE GLASSMORPHISM
// ═══════════════════════════════════════════════════════════════════════════
class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color roseSoft = Color(0xFFFFF0F3);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
}

class ProviderDashboardPage extends ConsumerWidget {
  final ThixProviderModel provider;

  const ProviderDashboardPage({super.key, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(providerStatsProvider(provider.id));
    final tasksAsync = ref.watch(providerTasksProvider(
      ProviderTasksParams(providerId: provider.id),
    ));
    final reservationsAsync = ref.watch(providerReservationsProvider(
      ProviderReservationsParams(providerId: provider.id),
    ));

    return Scaffold(
      backgroundColor: _P.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HEADER ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _DashboardHeader(provider: provider),
          ),

          // ── ALERTES (Validation en attente) ────────────────────────────
          if (provider.verificationStatus == ProviderVerificationStatus.pending)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _ValidationAlertCard(),
              ),
            ),

          // ── STATS CARDS ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: statsAsync.when(
                data: (stats) => _StatsGrid(stats: stats),
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator(color: _P.rose)),
                ),
                error: (e, _) => Center(child: Text('Erreur stats: $e')),
              ),
            ),
          ),

          // ── PROCHAINES RÉSERVATIONS ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionTitle(title: 'Prochains événements', icon: Icons.event_note),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 160,
              child: reservationsAsync.when(
                data: (reservations) {
                  final upcoming = reservations
                      .where((r) => r.status == ReservationStatus.confirmed || r.status == ReservationStatus.pending)
                      .take(5)
                      .toList();
                  if (upcoming.isEmpty) {
                    return const _EmptyState(message: 'Aucune réservation à venir');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: upcoming.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _ReservationCard(reservation: upcoming[i]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: _P.rose)),
                error: (e, _) => Center(child: Text('Erreur: $e')),
              ),
            ),
          ),

          // ── TÂCHES RÉCENTES ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _SectionTitle(title: 'Tâches à faire', icon: Icons.checklist_rtl),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: tasksAsync.when(
              data: (tasks) {
                final activeTasks = tasks.where((t) => t.status != TaskStatus.completed).take(5).toList();
                if (activeTasks.isEmpty) {
                  return SliverToBoxAdapter(
                    child: const _EmptyState(message: 'Aucune tâche en cours').toSliver,
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TaskCard(task: activeTasks[i]),
                    ),
                    childCount: activeTasks.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator(color: _P.rose)),
              ),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Erreur: $e'))),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════
class _DashboardHeader extends StatelessWidget {
  final ThixProviderModel provider;
  const _DashboardHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, topPad + 20, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_P.rose, _P.roseLight],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour 👋',
                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.businessName,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                ],
              ),
              _VerificationBadge(level: provider.level, status: provider.verificationStatus),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Votre Code Unique',
                      style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      provider.uniqueCode,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final TrackingLevel level;
  final ProviderVerificationStatus status;
  const _VerificationBadge({required this.level, required this.status});

  @override
  Widget build(BuildContext context) {
    String label = level.displayName;
    Color bgColor = Colors.white.withOpacity(0.2);
    Icon icon = Icons.verified_outlined;

    if (status == ProviderVerificationStatus.pending) {
      label = 'En attente';
      bgColor = Colors.amber.withOpacity(0.8);
      icon = Icons.hourglass_empty;
    } else if (status == ProviderVerificationStatus.rejected) {
      label = 'Rejeté';
      bgColor = Colors.red.withOpacity(0.8);
      icon = Icons.error_outline;
    } else if (level == TrackingLevel.platinum) {
      bgColor = Colors.white.withOpacity(0.9);
      icon = Icons.workspace_premium;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATS GRID
// ═══════════════════════════════════════════════════════════════════════════
class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final revenue = (stats['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final reservations = stats['total_reservations'] as int? ?? 0;
    final tasks = stats['total_tasks'] as int? ?? 0;
    final completedTasks = stats['completed_tasks'] as int? ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Revenus',
            value: '\$${revenue.toStringAsFixed(0)}',
            icon: Icons.attach_money,
            color: _P.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Réservations',
            value: '$reservations',
            icon: Icons.event_available,
            color: _P.rose,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Tâches',
            value: '$completedTasks/$tasks',
            icon: Icons.task_alt,
            color: _P.amber,
          ),
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

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _P.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _P.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARDS
// ═══════════════════════════════════════════════════════════════════════════
class _ReservationCard extends StatelessWidget {
  final ProviderReservationModel reservation;
  const _ReservationCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy', 'fr_FR').format(reservation.eventDate);
    final isPending = reservation.status == ReservationStatus.pending;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isPending ? _P.amber : _P.line),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: isPending ? _P.amber : _P.green),
              const SizedBox(width: 6),
              Text(
                dateStr,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _P.ink),
              ),
            ],
          ),
          const Spacer(),
          Text(
            reservation.clientName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _P.ink),
          ),
          const SizedBox(height: 4),
          Text(
            reservation.eventType ?? 'Événement',
            style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPending ? _P.amber.withOpacity(0.1) : _P.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isPending ? 'En attente' : 'Confirmé',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isPending ? _P.amber : _P.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final ProviderTaskModel task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final isHighPriority = task.priority == 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isHighPriority ? _P.rose.withOpacity(0.1) : _P.roseSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isHighPriority ? Icons.priority_high : Icons.task,
              color: _P.rose,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _P.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM, HH:mm', 'fr_FR').format(task.dueDateTime),
                  style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: _P.inkSoft),
        ],
      ),
    );
  }
}

class _ValidationAlertCard extends StatelessWidget {
  const _ValidationAlertCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.pending_actions, color: Color(0xFFD97706), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validation en cours',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF92400E)),
                ),
                Text(
                  'Votre dossier est en cours de vérification par notre équipe.',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB45309)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _P.rose),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink, letterSpacing: -0.3),
        ),
        const Spacer(),
        Text('Voir tout', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _P.rose)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: _P.line),
          const SizedBox(height: 8),
          Text(message, style: GoogleFonts.inter(color: _P.inkSoft, fontSize: 14)),
        ],
      ),
    );
  }
}

// Helper pour convertir Widget en Sliver (usage interne simple)
extension WidgetToSliver on Widget {
  Widget get toSliver => SliverToBoxAdapter(child: this);
}
