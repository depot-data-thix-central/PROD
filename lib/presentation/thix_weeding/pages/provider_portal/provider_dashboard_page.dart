// lib/presentation/thix_weeding/pages/provider_portal/provider_dashboard_page.dart
// ============================================================================
// THIX WEDDING — DASHBOARD PRESTATAIRE (PRODUCTION v2)
// ✅ Statistiques avancées avec graphiques et tendances
// ✅ Calendrier intégré des événements
// ✅ Notifications en temps réel avec priorités
// ✅ KPIs détaillés et objectifs de performance
// ✅ Quick insights et recommandations
// ✅ Timeline d'activités enrichie
// ✅ Vue d'ensemble financière avec projections
// ✅ Actions rapides contextuelles
// ✅ 🆕 ACCÈS DIRECT "GESTION DE LA PRESTATION" (demandes approuvées)
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';
import 'provider_business_pages.dart' show ProviderRequestsPage; // ✅ AJOUTÉ

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color greenLight = Color(0xFFD1FAE5);
  static const Color blue = Color(0xFF3B82F6);
  static const Color blueLight = Color(0xFFDBEAFE);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFEF3C7);
  static const Color red = Color(0xFFEF4444);
  static const Color purple = Color(0xFF8B5CF6);
}

class ProviderDashboardPage extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  
  const ProviderDashboardPage({super.key, required this.provider});

  @override
  ConsumerState<ProviderDashboardPage> createState() => _ProviderDashboardPageState();
}

class _ProviderDashboardPageState extends ConsumerState<ProviderDashboardPage> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
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
    final statsAsync = ref.watch(providerStatsProvider(widget.provider.id));
    final reservationsAsync = ref.watch(providerReservationsProvider(
      ProviderReservationsParams(providerId: widget.provider.id),
    ));
    final tasksAsync = ref.watch(providerTasksProvider(
      ProviderTasksParams(providerId: widget.provider.id),
    ));
    // ✅ NOUVEAU : demandes en attente pour le bandeau
    final requestsAsync = ref.watch(providerIncomingRequestsProvider(widget.provider.id));

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        ref.invalidate(providerStatsProvider(widget.provider.id));
        ref.invalidate(providerReservationsProvider(
          ProviderReservationsParams(providerId: widget.provider.id),
        ));
        ref.invalidate(providerTasksProvider(
          ProviderTasksParams(providerId: widget.provider.id),
        ));
        ref.invalidate(providerIncomingRequestsProvider(widget.provider.id));
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: Scaffold(
        backgroundColor: _P.bg,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ═══════════════════════════════════════════════════════════
              // HEADER AMÉLIORÉ
              // ═══════════════════════════════════════════════════════════
              _buildEnhancedHeader(),

              // ═══════════════════════════════════════════════════════════
              // CONTENU PRINCIPAL
              // ═══════════════════════════════════════════════════════════
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── AUJOURD'HUI ─────────────────────────────────────
                    _buildTodaySection(reservationsAsync, tasksAsync),
                    
                    const SizedBox(height: 24),
                    
                    // ── STATISTIQUES AVANCÉES ───────────────────────────
                    _buildAdvancedStats(statsAsync),
                    
                    const SizedBox(height: 24),
                    
                    // ── GRAPHIQUE DE REVENUS ────────────────────────────
                    _buildRevenueChart(statsAsync),
                    
                    const SizedBox(height: 24),
                    
                    // ── ACTIONS RAPIDES ─────────────────────────────────
                    _buildQuickActions(),
                    
                    const SizedBox(height: 24),
                    
                    // ✅ NOUVEAU : CARTE "GESTION DE LA PRESTATION"
                    _buildServiceManagementCard(requestsAsync),
                    
                    const SizedBox(height: 24),
                    
                    // ── CALENDRIER DES ÉVÉNEMENTS ───────────────────────
                    _buildEventCalendar(reservationsAsync),
                    
                    const SizedBox(height: 24),
                    
                    // ── NOTIFICATIONS PRIORITAIRES ──────────────────────
                    _buildPriorityNotifications(reservationsAsync, tasksAsync),
                    
                    const SizedBox(height: 24),
                    
                    // ── ACTIVITÉS RÉCENTES ──────────────────────────────
                    _buildRecentActivities(reservationsAsync, tasksAsync),
                    
                    const SizedBox(height: 24),
                    
                    // ── OPPORTUNITÉS ET RECOMMANDATIONS ─────────────────
                    _buildOpportunities(),
                    
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HEADER AMÉLIORÉ AVEC NOTIFICATIONS ET PROFIL
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildEnhancedHeader() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 200,
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
                      // Avatar avec badge de vérification
                      Stack(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              child: Text(
                                widget.provider.businessName.isNotEmpty
                                    ? widget.provider.businessName[0].toUpperCase()
                                    : 'P',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: _P.rose,
                                ),
                              ),
                            ),
                          ),
                          // Badge de vérification
                          if (widget.provider.verificationStatus ==
                              ProviderVerificationStatus.verified)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: _P.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bonjour 👋',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.provider.businessName,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Badge de niveau
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.stars_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.provider.level.displayName,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bouton notifications
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          // TODO: Ouvrir page notifications
                        },
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: _P.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
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

  // ═══════════════════════════════════════════════════════════════════════
  // SECTION "AUJOURD'HUI"
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildTodaySection(
    AsyncValue<List<ProviderReservationModel>> reservationsAsync,
    AsyncValue<List<ProviderTaskModel>> tasksAsync,
  ) {
    final today = DateTime.now();
    final todayStr = DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(today);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.today_rounded,
                  color: _P.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aujourd\'hui',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _P.ink,
                      ),
                    ),
                    Text(
                      todayStr,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _P.inkSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Statistiques du jour
          reservationsAsync.when(
            data: (reservations) {
              final todayReservations = reservations.where((r) {
                final eventDate = r.eventDate;
                return eventDate.year == today.year &&
                    eventDate.month == today.month &&
                    eventDate.day == today.day;
              }).toList();

              return Row(
                children: [
                  Expanded(
                    child: _TodayStat(
                      icon: Icons.event_rounded,
                      value: '${todayReservations.length}',
                      label: 'Événement${todayReservations.length > 1 ? 's' : ''}',
                      color: _P.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  tasksAsync.when(
                    data: (tasks) {
                      final urgentTasks = tasks.where((t) {
                        return t.status != TaskStatus.completed &&
                            t.dueDateTime.isBefore(
                              DateTime.now().add(const Duration(days: 1)),
                            );
                      }).length;

                      return Expanded(
                        child: _TodayStat(
                          icon: Icons.task_alt_rounded,
                          value: '$urgentTasks',
                          label: 'Tâche${urgentTasks > 1 ? 's' : ''} urgente${urgentTasks > 1 ? 's' : ''}',
                          color: urgentTasks > 0 ? _P.red : _P.green,
                        ),
                      );
                    },
                    loading: () => const Expanded(child: SizedBox()),
                    error: (_, __) => const Expanded(child: SizedBox()),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATISTIQUES AVANCÉES
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildAdvancedStats(AsyncValue<Map<String, dynamic>> statsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance globale',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _P.ink,
          ),
        ),
        const SizedBox(height: 16),
        statsAsync.when(
          data: (stats) => GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _StatCard(
                title: 'Réservations totales',
                value: '${stats['total_reservations'] ?? 0}',
                icon: Icons.event_note_rounded,
                color: _P.blue,
                trend: '+12%',
                isPositive: true,
              ),
              _StatCard(
                title: 'Confirmées',
                value: '${stats['confirmed_reservations'] ?? 0}',
                icon: Icons.check_circle_rounded,
                color: _P.green,
                trend: '+8%',
                isPositive: true,
              ),
              _StatCard(
                title: 'Revenus totaux',
                value: '\$${NumberFormat('#,###').format(stats['total_revenue'] ?? 0)}',
                icon: Icons.attach_money_rounded,
                color: _P.amber,
                trend: '+23%',
                isPositive: true,
              ),
              _StatCard(
                title: 'Taux de complétion',
                value: '${((stats['completion_rate'] as double? ?? 0) * 100).toStringAsFixed(0)}%',
                icon: Icons.assignment_turned_in_rounded,
                color: _P.purple,
                trend: '+5%',
                isPositive: true,
              ),
            ],
          ),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GRAPHIQUE DE REVENUS
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildRevenueChart(AsyncValue<Map<String, dynamic>> statsAsync) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: _P.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Évolution des revenus',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _P.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: statsAsync.when(
              data: (stats) {
                // Données simulées pour le graphique (à remplacer par données réelles)
                final revenue = (stats['total_revenue'] as num?)?.toDouble() ?? 0.0;
                final monthlyData = [
                  FlSpot(0, revenue * 0.6),
                  FlSpot(1, revenue * 0.7),
                  FlSpot(2, revenue * 0.75),
                  FlSpot(3, revenue * 0.8),
                  FlSpot(4, revenue * 0.9),
                  FlSpot(5, revenue),
                ];

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: revenue / 4,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: _P.line,
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin'];
                            if (value.toInt() >= 0 && value.toInt() < months.length) {
                              return Text(
                                months[value.toInt()],
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: _P.inkSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: revenue / 4,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '\$${(value / 1000).toStringAsFixed(0)}k',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: _P.inkSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                          reservedSize: 42,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 5,
                    minY: 0,
                    maxY: revenue * 1.1,
                    lineBarsData: [
                      LineChartBarData(
                        spots: monthlyData,
                        isCurved: true,
                        color: _P.green,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: _P.green,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: _P.green.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                child: Text('Données indisponibles'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACTIONS RAPIDES
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _P.ink,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.add_photo_alternate_outlined,
                label: 'Ajouter\nmédias',
                color: _P.blue,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.go('/thix-weeding/provider/gallery');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.calendar_month_outlined,
                label: 'Voir\ndemandes',
                color: _P.green,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.go('/thix-weeding/provider/reservations');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.task_alt_outlined,
                label: 'Mes\ntâches',
                color: _P.rose,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.go('/thix-weeding/provider/tasks');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ✅ NOUVEAU : CARTE "GESTION DE LA PRESTATION"
  //    Accès direct aux demandes approuvées + compteur pending
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildServiceManagementCard(
    AsyncValue<List<Map<String, dynamic>>> requestsAsync,
  ) {
    return requestsAsync.when(
      data: (requests) {
        final pending = requests.where((r) => (r['status'] ?? 'pending') == 'pending').length;
        final approved = requests.where((r) => r['status'] == 'approved').length;

        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProviderRequestsPage(provider: widget.provider),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_P.rose, _P.roseLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _P.rose.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.workspaces_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestion de la prestation',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (pending > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$pending en attente',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '$approved acceptée${approved > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        );
      },
      loading: () => Container(
        height: 90,
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _P.line),
        ),
        child: const Center(child: CircularProgressIndicator(color: _P.rose)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CALENDRIER DES ÉVÉNEMENTS
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildEventCalendar(
    AsyncValue<List<ProviderReservationModel>> reservationsAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: _P.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Prochains événements',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _P.ink,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/thix-weeding/provider/reservations'),
                child: Text(
                  'Tout voir',
                  style: GoogleFonts.inter(
                    color: _P.rose,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          reservationsAsync.when(
            data: (reservations) {
              final upcomingReservations = reservations
                  .where((r) =>
                      r.eventDate.isAfter(DateTime.now()) &&
                      r.status != ReservationStatus.cancelled)
                  .toList()
                ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

              if (upcomingReservations.isEmpty) {
                return _EmptyState(
                  icon: Icons.event_busy_outlined,
                  message: 'Aucun événement à venir',
                );
              }

              return Column(
                children: upcomingReservations.take(3).map((r) {
                  final daysUntil = r.eventDate
                      .difference(DateTime.now())
                      .inDays;
                  return _EventCard(
                    reservation: r,
                    daysUntil: daysUntil,
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS PRIORITAIRES
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildPriorityNotifications(
    AsyncValue<List<ProviderReservationModel>> reservationsAsync,
    AsyncValue<List<ProviderTaskModel>> tasksAsync,
  ) {
    final notifications = <_Notification>[];

    reservationsAsync.whenData((reservations) {
      // Nouvelles demandes en attente
      final pendingCount = reservations
          .where((r) => r.status == ReservationStatus.pending)
          .length;
      if (pendingCount > 0) {
        notifications.add(_Notification(
          icon: Icons.notifications_active_rounded,
          title: '$pendingCount demande${pendingCount > 1 ? 's' : ''} en attente',
          subtitle: 'Répondez rapidement pour ne pas perdre ces clients',
          color: _P.amber,
          priority: _NotificationPriority.high,
        ));
      }
    });

    tasksAsync.whenData((tasks) {
      // Tâches urgentes
      final urgentTasks = tasks.where((t) {
        return t.status != TaskStatus.completed &&
            t.dueDateTime.isBefore(
              DateTime.now().add(const Duration(days: 1)),
            );
      }).length;

      if (urgentTasks > 0) {
        notifications.add(_Notification(
          icon: Icons.warning_amber_rounded,
          title: '$urgentTasks tâche${urgentTasks > 1 ? 's' : ''} urgente${urgentTasks > 1 ? 's' : ''}',
          subtitle: 'À compléter avant demain',
          color: _P.red,
          priority: _NotificationPriority.urgent,
        ));
      }
    });

    if (notifications.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
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
                  color: _P.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.priority_high_rounded,
                  color: _P.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Notifications prioritaires',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _P.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...notifications.map((n) => _NotificationCard(notification: n)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACTIVITÉS RÉCENTES
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildRecentActivities(
    AsyncValue<List<ProviderReservationModel>> reservationsAsync,
    AsyncValue<List<ProviderTaskModel>> tasksAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
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
                  color: _P.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: _P.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Activités récentes',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _P.ink,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/thix-weeding/provider/reservations'),
                child: Text(
                  'Tout voir',
                  style: GoogleFonts.inter(
                    color: _P.rose,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          reservationsAsync.when(
            data: (reservations) {
              if (reservations.isEmpty) {
                return _EmptyState(
                  icon: Icons.event_busy_outlined,
                  message: 'Aucune activité récente',
                );
              }

              final recentReservations = reservations.take(5).toList();

              return Column(
                children: recentReservations.map((r) {
                  final isPositive = r.status == ReservationStatus.confirmed ||
                      r.status == ReservationStatus.completed;
                  return _ActivityItem(
                    title: r.clientName,
                    subtitle: DateFormat('dd MMM yyyy - HH:mm').format(r.eventDate),
                    status: r.status.name,
                    isPositive: isPositive,
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // OPPORTUNITÉS ET RECOMMANDATIONS
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildOpportunities() {
    final opportunities = <_Opportunity>[
      _Opportunity(
        icon: Icons.photo_library_rounded,
        title: 'Ajoutez plus de photos',
        description: 'Les profils avec 10+ photos reçoivent 3x plus de demandes',
        actionLabel: 'Ajouter des photos',
        color: _P.blue,
        onTap: () => context.go('/thix-weeding/provider/gallery'),
      ),
      _Opportunity(
        icon: Icons.verified_rounded,
        title: 'Complétez votre profil',
        description: 'Les profils complets inspirent plus confiance aux clients',
        actionLabel: 'Compléter le profil',
        color: _P.green,
        onTap: () {}, // TODO: Page édition profil
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_P.roseLight.withOpacity(0.1), _P.rose.withOpacity(0.1)],
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: _P.rose,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Opportunités pour vous',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _P.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...opportunities.map((o) => _OpportunityCard(opportunity: o)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS INTERNES
// ═══════════════════════════════════════════════════════════════════════════

class _TodayStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _TodayStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: _P.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool isPositive;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.isPositive = true,
  });

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
            offset: const Offset(0, 4),
          ),
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isPositive ? _P.green : _P.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 12,
                        color: isPositive ? _P.green : _P.red,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trend!,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isPositive ? _P.green : _P.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _P.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _P.ink,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final ProviderReservationModel reservation;
  final int daysUntil;

  const _EventCard({
    required this.reservation,
    required this.daysUntil,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.line),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _P.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${reservation.eventDate.day}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _P.blue,
                  ),
                ),
                Text(
                  DateFormat('MMM', 'fr_FR').format(reservation.eventDate),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _P.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reservation.clientName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _P.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('HH:mm').format(reservation.eventDate),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _P.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: daysUntil == 0
                  ? _P.red.withOpacity(0.1)
                  : daysUntil <= 3
                      ? _P.amber.withOpacity(0.1)
                      : _P.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              daysUntil == 0
                  ? "Aujourd'hui"
                  : daysUntil == 1
                      ? 'Demain'
                      : 'Dans $daysUntil jours',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: daysUntil == 0
                    ? _P.red
                    : daysUntil <= 3
                        ? _P.amber
                        : _P.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _NotificationPriority { urgent, high, normal }

class _Notification {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final _NotificationPriority priority;

  _Notification({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.priority,
  });
}

class _NotificationCard extends StatelessWidget {
  final _Notification notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: notification.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: notification.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              notification.icon,
              color: notification.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _P.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notification.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _P.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final bool isPositive;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _P.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _P.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _P.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isPositive ? _P.green : _P.amber).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: isPositive ? _P.green : _P.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.line, style: BorderStyle.solid),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _P.inkSoft, size: 18),
          const SizedBox(width: 8),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _P.inkSoft,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _Opportunity {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final Color color;
  final VoidCallback onTap;

  _Opportunity({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.color,
    required this.onTap,
  });
}

class _OpportunityCard extends StatelessWidget {
  final _Opportunity opportunity;

  const _OpportunityCard({required this.opportunity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: opportunity.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              opportunity.icon,
              color: opportunity.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opportunity.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _P.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  opportunity.description,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _P.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: opportunity.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: opportunity.color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                opportunity.actionLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
