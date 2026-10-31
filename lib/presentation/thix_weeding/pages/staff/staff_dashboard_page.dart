import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

/// Dashboard Staff ultra royal - Version Production
/// Design premium avec animations, mode offline, et scanner QR intégré
class StaffDashboardPage extends ConsumerStatefulWidget {
  final String weddingId;
  const StaffDashboardPage({super.key, required this.weddingId});

  @override
  ConsumerState<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends ConsumerState<StaffDashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weddingAsync = ref.watch(weddingProvider(widget.weddingId));
    final statsAsync = ref.watch(dashboardStatsProvider(widget.weddingId));
    final budgetAsync = ref.watch(paymentsSummaryProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: weddingAsync.when(
          loading: () => const _RoyalLoadingView(),
          error: (e, _) => _RoyalErrorView(
            message: '$e',
            onRetry: () {
              ref.invalidate(weddingProvider(widget.weddingId));
              ref.invalidate(dashboardStatsProvider(widget.weddingId));
              ref.invalidate(paymentsSummaryProvider(widget.weddingId));
            },
          ),
          data: (wedding) {
            final stats = statsAsync.valueOrNull;
            final budget = budgetAsync.valueOrNull;

            int daysLeft = 0;
            String dateLabel = 'Date à définir';
            final d = wedding.weddingDate;
            if (d != null) {
              daysLeft = d.difference(DateTime.now()).inDays.clamp(0, 9999);
              dateLabel =
                  '${d.day.toString().padLeft(2, '0')}/'
                  '${d.month.toString().padLeft(2, '0')}/'
                  '${d.year}';
            }

            final totalBudget = budget?['budget'] ?? 0.0;
            final totalSpent = budget?['spent'] ?? 0.0;

            return RefreshIndicator(
              color: const Color(0xFF0B3B8F),
              onRefresh: () async {
                ref.invalidate(weddingProvider(widget.weddingId));
                ref.invalidate(dashboardStatsProvider(widget.weddingId));
                ref.invalidate(paymentsSummaryProvider(widget.weddingId));
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // AppBar Royal Premium
                  _RoyalAppBar(
                    coupleNames: wedding.coupleNames,
                    weddingId: widget.weddingId,
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Compte à rebours royal
                        SlideTransition(
                          position: _slideAnimation,
                          child: _RoyalCountdownCard(
                            coupleNames: wedding.coupleNames,
                            venue: wedding.venue,
                            dateLabel: dateLabel,
                            daysLeft: daysLeft,
                            eventDate: wedding.weddingDate,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Bouton Scanner QR Premium
                        _RoyalScannerButton(weddingId: widget.weddingId),
                        const SizedBox(height: 20),

                        // Stats en grille
                        _RoyalStatsGrid(stats: stats),
                        const SizedBox(height: 20),

                        // Budget royal
                        _RoyalBudgetCard(
                          totalBudget: totalBudget,
                          totalSpent: totalSpent,
                        ),
                        const SizedBox(height: 20),

                        // Actions rapides premium
                        _RoyalQuickActions(weddingId: widget.weddingId),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// AppBar Royal Premium avec dégradé
class _RoyalAppBar extends StatelessWidget {
  final String coupleNames;
  final String weddingId;

  const _RoyalAppBar({
    required this.coupleNames,
    required this.weddingId,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0B3B8F),
              const Color(0xFF6B46C1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Stack(
          children: [
            // Motifs décoratifs
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                ),
              ),
            ),
            // Contenu
            FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'THIX EVENTS',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.8),
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Staff Access',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _RoyalIconButton(
                              icon: Icons.notifications_outlined,
                              onTap: () => context.push(
                                  '/thix-weeding/staff/$weddingId/messages'),
                            ),
                            const SizedBox(width: 8),
                            _RoyalIconButton(
                              icon: Icons.qr_code_scanner,
                              onTap: () => context.push(
                                  '/thix-weeding/staff/$weddingId/scanner'),
                              badge: 0,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      coupleNames.isEmpty ? 'Événement' : coupleNames,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bouton icône royal
class _RoyalIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  const _RoyalIconButton({
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE31C4E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$badge',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Carte compte à rebours royal
class _RoyalCountdownCard extends StatefulWidget {
  final String coupleNames;
  final String? venue;
  final String dateLabel;
  final int daysLeft;
  final DateTime? eventDate;

  const _RoyalCountdownCard({
    required this.coupleNames,
    this.venue,
    required this.dateLabel,
    required this.daysLeft,
    this.eventDate,
  });

  @override
  State<_RoyalCountdownCard> createState() => _RoyalCountdownCardState();
}

class _RoyalCountdownCardState extends State<_RoyalCountdownCard> {
  late Stream<Duration> _countdownStream;

  @override
  void initState() {
    super.initState();
    if (widget.eventDate != null) {
      _countdownStream = Stream.periodic(
        const Duration(seconds: 1),
        (_) => widget.eventDate!.difference(DateTime.now()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEventDay = widget.daysLeft == 0;
    final isPast = widget.eventDate?.isBefore(DateTime.now()) ?? false;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isEventDay
            ? const LinearGradient(
                colors: [Color(0xFFE31C4E), Color(0xFFFF6B9D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : isPast
                ? LinearGradient(
                    colors: [Colors.grey.shade600, Colors.grey.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEventDay ? Icons.celebration : Icons.timer,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                isEventDay
                    ? "C'EST LE JOUR J !"
                    : isPast
                        ? 'ÉVÉNEMENT TERMINÉ'
                        : 'COMPTE À REBOURS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.coupleNames.isEmpty ? 'Mariage' : widget.coupleNames,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                color: Colors.white.withOpacity(0.9),
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [
                    if (widget.venue != null && widget.venue!.isNotEmpty)
                      widget.venue!,
                    widget.dateLabel,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
          if (!isPast) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: widget.eventDate != null
                  ? StreamBuilder<Duration>(
                      stream: _countdownStream,
                      initialData: widget.eventDate!.difference(DateTime.now()),
                      builder: (context, snapshot) {
                        final countdown = snapshot.data ?? Duration.zero;
                        final days = countdown.inDays;
                        final hours = countdown.inHours % 24;
                        final minutes = countdown.inMinutes % 60;
                        final seconds = countdown.inSeconds % 60;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _CountdownUnit(
                              value: days,
                              label: 'JOURS',
                            ),
                            _CountdownSeparator(),
                            _CountdownUnit(
                              value: hours,
                              label: 'HEURES',
                            ),
                            _CountdownSeparator(),
                            _CountdownUnit(
                              value: minutes,
                              label: 'MIN',
                            ),
                            _CountdownSeparator(),
                            _CountdownUnit(
                              value: seconds,
                              label: 'SEC',
                            ),
                          ],
                        );
                      },
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _CountdownUnit(value: widget.daysLeft, label: 'JOURS'),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  final int value;
  final String label;

  const _CountdownUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _CountdownSeparator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      ':',
      style: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: Colors.white.withOpacity(0.6),
      ),
    );
  }
}

// Bouton Scanner QR Premium
class _RoyalScannerButton extends StatelessWidget {
  final String weddingId;

  const _RoyalScannerButton({required this.weddingId});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () =>
            context.push('/thix-weeding/staff/$weddingId/scanner'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B3B8F), Color(0xFF6B46C1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B3B8F).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scanner une invitation',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contrôle d\'accès rapide et sécurisé',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Grille de statistiques royale
class _RoyalStatsGrid extends StatelessWidget {
  final Map<String, dynamic>? stats;

  const _RoyalStatsGrid({this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _RoyalStatCard(
                label: 'Invités',
                value: '${stats?['guests'] ?? '—'}',
                icon: Icons.people,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B3B8F), Color(0xFF6B46C1)],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoyalStatCard(
                label: 'Présents',
                value: '${stats?['present'] ?? '—'}',
                icon: Icons.check_circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                ),
                trend: _calculatePercentage(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _RoyalStatCard(
                label: 'Prestataires',
                value: '${stats?['vendors'] ?? '—'}',
                icon: Icons.storefront,
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoyalStatCard(
                label: 'Tâches',
                value: '${stats?['pendingTasks'] ?? '—'}',
                icon: Icons.task_alt,
                gradient: const LinearGradient(
                  colors: [Color(0xFFE31C4E), Color(0xFFFF6B9D)],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String? _calculatePercentage() {
    if (stats == null) return null;
    final guests = stats!['guests'] as int?;
    final present = stats!['present'] as int?;
    if (guests == null || present == null || guests == 0) return null;
    final percentage = ((present / guests) * 100).toStringAsFixed(0);
    return '$percentage%';
  }
}

// Carte statistique royale
class _RoyalStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  final String? trend;

  const _RoyalStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              if (trend != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trend!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

// Carte Budget Royale
class _RoyalBudgetCard extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;

  const _RoyalBudgetCard({
    required this.totalBudget,
    required this.totalSpent,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = totalBudget > 0 ? (totalSpent / totalBudget) : 0.0;
    final remaining = totalBudget - totalSpent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: const Color(0xFF111827),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BudgetAmount(
                label: 'Dépensé',
                amount: totalSpent,
                color: const Color(0xFFE31C4E),
              ),
              _BudgetAmount(
                label: 'Total',
                amount: totalBudget,
                color: const Color(0xFF0B3B8F),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: percentage.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF059669),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Restant',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                ),
              ),
              Text(
                '${remaining.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: remaining >= 0
                      ? const Color(0xFF059669)
                      : const Color(0xFFE31C4E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetAmount extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _BudgetAmount({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount.toStringAsFixed(0),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

// Actions rapides royales
class _RoyalQuickActions extends StatelessWidget {
  final String weddingId;

  const _RoyalQuickActions({required this.weddingId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions Rapides',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _QuickActionCard(
              icon: Icons.people_outline,
              label: 'Liste invités',
              gradient: const LinearGradient(
                colors: [Color(0xFF0B3B8F), Color(0xFF6B46C1)],
              ),
              onTap: () => context.push(
                  '/thix-weeding/staff/$weddingId/invites'),
            ),
            _QuickActionCard(
              icon: Icons.storefront_outlined,
              label: 'Prestataires',
              gradient: const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
              ),
              onTap: () => context.push(
                  '/thix-weeding/staff/$weddingId/prestataires'),
            ),
            _QuickActionCard(
              icon: Icons.checklist_outlined,
              label: 'Checklist',
              gradient: const LinearGradient(
                colors: [Color(0xFFE31C4E), Color(0xFFFF6B9D)],
              ),
              onTap: () => context.push(
                  '/thix-weeding/staff/$weddingId/checklist'),
            ),
            _QuickActionCard(
              icon: Icons.payments_outlined,
              label: 'Paiements',
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
              ),
              onTap: () => context.push(
                  '/thix-weeding/staff/$weddingId/paiements'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Vue de chargement royale
class _RoyalLoadingView extends StatelessWidget {
  const _RoyalLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B3B8F), Color(0xFF6B46C1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.celebration,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Chargement...',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B3B8F)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// Vue d'erreur royale
class _RoyalErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RoyalErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE31C4E).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Color(0xFFE31C4E),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Impossible de charger',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B3B8F),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
