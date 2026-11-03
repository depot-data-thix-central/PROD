// lib/presentation/thix_weeding/pages/provider_portal/provider_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';
import 'orders/order_models.dart';
import 'orders/orders_provider.dart';
import 'orders/provider_orders_page.dart';
import 'traiteur/traiteur_menu_page.dart';
import 'suggestions/dg_suggestions_page.dart';
import 'provider_offers_page.dart';
/// ═══════════════════════════════════════════════════════════════════════
/// THIX WEDDING — DASHBOARD PRESTATAIRE (Production v3)
/// ✅ Statistiques commandes en temps réel
/// ✅ Commandes urgentes avec alertes
/// ✅ Workflow complet intégré
/// ✅ Menu traiteur accessible
/// ✅ Suggestions DG
/// ✅ Graphiques de revenus
/// ✅ Actions rapides contextuelles
/// ═══════════════════════════════════════════════════════════════════════

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
  static const Color redLight = Color(0xFFFEE2E2);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleLight = Color(0xFFEDE9FE);
}

class ProviderDashboardPage extends ConsumerStatefulWidget {
  final ThixProviderModel provider;

  const ProviderDashboardPage({
    super.key,
    required this.provider,
  });

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
    final ordersAsync = ref.watch(ordersProvider(widget.provider.id));
    final stats = ref.watch(orderStatsProvider(widget.provider.id));
    final urgentOrders = ref.watch(urgentOrdersProvider(widget.provider.id));
    final pendingOrders = ref.watch(pendingOrdersProvider(widget.provider.id));
    final offersAsync = ref.watch(providerOffersProvider(widget.provider.id));

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        ref.invalidate(ordersProvider(widget.provider.id));
        ref.invalidate(providerOffersProvider(widget.provider.id));
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: Scaffold(
        backgroundColor: _P.bg,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ═══════════════ HEADER ═══════════════
              _buildHeader(),

              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ═══════════════ AUJOURD'HUI ═══════════════
                    _TodaySection(
                      ordersAsync: ordersAsync,
                      stats: stats,
                    ),
                    const SizedBox(height: 24),

                    // ═══════════════ ALERTES URGENTES ═══════════════
                    if (urgentOrders.isNotEmpty)
                      _UrgentAlertsSection(
                        urgentOrders: urgentOrders,
                        onViewAll: () => _navigateToOrders(),
                      ),
                    if (urgentOrders.isNotEmpty) const SizedBox(height: 24),

                    // ═══════════════ COMMANDES EN ATTENTE ═══════════════
                    if (pendingOrders.isNotEmpty)
                      _PendingOrdersSection(
                        pendingOrders: pendingOrders,
                        onViewAll: () => _navigateToOrders(),
                      ),
                    if (pendingOrders.isNotEmpty) const SizedBox(height: 24),

                    // ═══════════════ STATISTIQUES ═══════════════
                    _StatsSection(stats: stats),
                    const SizedBox(height: 24),

                    // ═══════════════ GRAPHIQUE REVENUS ═══════════════
                    _RevenueChart(ordersAsync: ordersAsync),
                    const SizedBox(height: 24),

                    // ═══════════════ ACTIONS RAPIDES ═══════════════
                    _QuickActions(
                      provider: widget.provider,
                      offersCount: offersAsync.value?.length ?? 0,
                      pendingOrdersCount: pendingOrders.length,
                    ),
                    const SizedBox(height: 24),

                    // ═══════════════ SERVICES SPÉCIAUX ═══════════════
                    _SpecialServices(provider: widget.provider),
                    const SizedBox(height: 24),

                    // ═══════════════ PROCHAINS ÉVÉNEMENTS ═══════════════
                    _UpcomingEventsSection(ordersAsync: ordersAsync),
                    const SizedBox(height: 24),

                    // ═══════════════ RECOMMANDATIONS ═══════════════
                    _RecommendationsSection(provider: widget.provider),
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

  Widget _buildHeader() {
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
                      // Avatar
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
                                  const Icon(
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

  void _navigateToOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderOrdersPage(
          providerId: widget.provider.id,
          providerName: widget.provider.businessName,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WIDGETS SECTIONS
// ═══════════════════════════════════════════════════════════════════════

class _TodaySection extends StatelessWidget {
  final AsyncValue<List<WeddingOrder>> ordersAsync;
  final OrderStats stats;

  const _TodaySection({
    required this.ordersAsync,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
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
          ordersAsync.when(
            data: (orders) {
              final todayOrders = orders.where((o) {
                return o.eventDate.year == today.year &&
                    o.eventDate.month == today.month &&
                    o.eventDate.day == today.day;
              }).toList();

              final urgentCount = stats.urgent;
              final pendingCount = stats.pending;

              return Row(
                children: [
                  Expanded(
                    child: _TodayStat(
                      icon: Icons.event_rounded,
                      value: '${todayOrders.length}',
                      label: 'Événement${todayOrders.length > 1 ? 's' : ''}',
                      color: _P.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TodayStat(
                      icon: Icons.hourglass_empty_rounded,
                      value: '$pendingCount',
                      label: 'En attente',
                      color: pendingCount > 0 ? _P.amber : _P.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TodayStat(
                      icon: Icons.warning_amber_rounded,
                      value: '$urgentCount',
                      label: 'Urgente${urgentCount > 1 ? 's' : ''}',
                      color: urgentCount > 0 ? _P.red : _P.green,
                    ),
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
}

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

class _UrgentAlertsSection extends StatelessWidget {
  final List<WeddingOrder> urgentOrders;
  final VoidCallback onViewAll;

  const _UrgentAlertsSection({
    required this.urgentOrders,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: _P.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Commandes urgentes (${urgentOrders.length})',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _P.red,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: Text(
                  'Voir tout',
                  style: GoogleFonts.inter(
                    color: _P.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...urgentOrders.take(3).map((order) {
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _P.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.priority_high_rounded,
                      color: _P.red,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.clientName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _P.ink,
                          ),
                        ),
                        Text(
                          order.offerTitle,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _P.inkSoft,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _P.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.daysUntilEvent == 0
                          ? "Aujourd'hui"
                          : 'J-${order.daysUntilEvent}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _P.red,
                      ),
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

class _PendingOrdersSection extends StatelessWidget {
  final List<WeddingOrder> pendingOrders;
  final VoidCallback onViewAll;

  const _PendingOrdersSection({
    required this.pendingOrders,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.hourglass_empty_rounded,
                  color: _P.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'En attente de confirmation (${pendingOrders.length})',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _P.amber,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: Text(
                  'Voir tout',
                  style: GoogleFonts.inter(
                    color: _P.amber,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...pendingOrders.take(2).map((order) {
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _P.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      color: _P.amber,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.clientName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _P.ink,
                          ),
                        ),
                        Text(
                          '${order.totalAmount.toStringAsFixed(0)}\$ • ${DateFormat('dd MMM', 'fr_FR').format(order.eventDate)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _P.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: _P.amber,
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

class _StatsSection extends StatelessWidget {
  final OrderStats stats;

  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
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
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _StatCard(
              title: 'Commandes totales',
              value: '${stats.total}',
              icon: Icons.receipt_long_rounded,
              color: _P.blue,
            ),
            _StatCard(
              title: 'Confirmées',
              value: '${stats.confirmed + stats.inProgress + stats.ready}',
              icon: Icons.check_circle_rounded,
              color: _P.green,
            ),
            _StatCard(
              title: 'Revenus totaux',
              value: '\$${stats.totalRevenue.toStringAsFixed(0)}',
              icon: Icons.attach_money_rounded,
              color: _P.amber,
            ),
            _StatCard(
              title: 'Terminées',
              value: '${stats.completed}',
              icon: Icons.verified_rounded,
              color: _P.purple,
            ),
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

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
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

class _RevenueChart extends StatelessWidget {
  final AsyncValue<List<WeddingOrder>> ordersAsync;

  const _RevenueChart({required this.ordersAsync});

  @override
  Widget build(BuildContext context) {
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
            child: ordersAsync.when(
              data: (orders) {
                // Calculer les revenus par mois
                final monthlyRevenue = <int, double>{};
                final now = DateTime.now();

                for (var i = 5; i >= 0; i--) {
                  final month = DateTime(now.year, now.month - i, 1);
                  monthlyRevenue[month.month] = 0;
                }

                for (var order in orders) {
                  if (order.status != OrderStatus.cancelled) {
                    final month = order.orderDate.month;
                    if (monthlyRevenue.containsKey(month)) {
                      monthlyRevenue[month] = monthlyRevenue[month]! + order.totalAmount;
                    }
                  }
                }

                final spots = <FlSpot>[];
                var index = 0;
                monthlyRevenue.forEach((month, revenue) {
                  spots.add(FlSpot(index.toDouble(), revenue));
                  index++;
                });

                if (spots.isEmpty || spots.every((s) => s.y == 0)) {
                  return Center(
                    child: Text(
                      'Pas encore de données',
                      style: GoogleFonts.inter(color: _P.inkSoft),
                    ),
                  );
                }

                final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2;

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 4,
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
                            const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
                            final monthIndex = (value.toInt() + now.month - 5) % 12;
                            if (monthIndex >= 0 && monthIndex < months.length) {
                              return Text(
                                months[monthIndex],
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
                          interval: maxY / 4,
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
}

class _QuickActions extends StatelessWidget {
  final ThixProviderModel provider;
  final int offersCount;
  final int pendingOrdersCount;

  const _QuickActions({
    required this.provider,
    required this.offersCount,
    required this.pendingOrdersCount,
  });

  @override
  Widget build(BuildContext context) {
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
                label: 'Publier\nune offre',
                color: _P.blue,
                badge: offersCount > 0 ? '$offersCount' : null,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.push('/thix-weeding/provider/offers/new');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.receipt_long_rounded,
                label: 'Mes\ncommandes',
                color: _P.green,
                badge: pendingOrdersCount > 0 ? '$pendingOrdersCount' : null,
                badgeColor: _P.amber,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderOrdersPage(
                        providerId: provider.id,
                        providerName: provider.businessName,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.photo_library_outlined,
                label: 'Ma\ngalerie',
                color: _P.rose,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.go('/thix-weeding/provider/gallery');
                },
              ),
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

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    this.badge,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
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
        child: Stack(
          children: [
            Column(
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
            if (badge != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor ?? color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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

class _SpecialServices extends StatelessWidget {
  final ThixProviderModel provider;

  const _SpecialServices({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isTraiteur = provider.category == ProviderCategory.traiteur;
    final isDJ = provider.category == ProviderCategory.dj;

    if (!isTraiteur && !isDJ) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Services spéciaux',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _P.ink,
          ),
        ),
        const SizedBox(height: 16),
        if (isTraiteur)
          _ServiceCard(
            icon: Icons.restaurant_menu_rounded,
            title: 'Menu traiteur',
            subtitle: 'Créez et gérez vos menus, validation staff, votes invités',
            color: _P.amber,
            onTap: () {
              // TODO: Naviguer vers la liste des menus
            },
          ),
        if (isDJ) ...[
          if (isTraiteur) const SizedBox(height: 12),
          _ServiceCard(
            icon: Icons.music_note_rounded,
            title: 'Suggestions DG',
            subtitle: 'Recevez les suggestions de chansons et ambiances',
            color: _P.purple,
            onTap: () {
              // TODO: Naviguer vers les suggestions
            },
          ),
        ],
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _P.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _P.inkSoft,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingEventsSection extends StatelessWidget {
  final AsyncValue<List<WeddingOrder>> ordersAsync;

  const _UpcomingEventsSection({required this.ordersAsync});

  @override
  Widget build(BuildContext context) {
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
            ],
          ),
          const SizedBox(height: 16),
          ordersAsync.when(
            data: (orders) {
              final upcomingOrders = orders
                  .where((o) =>
                      o.eventDate.isAfter(DateTime.now()) &&
                      o.status != OrderStatus.cancelled)
                  .toList()
                ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

              if (upcomingOrders.isEmpty) {
                return _EmptyState(
                  icon: Icons.event_busy_outlined,
                  message: 'Aucun événement à venir',
                );
              }

              return Column(
                children: upcomingOrders.take(3).map((order) {
                  final daysUntil = order.daysUntilEvent;

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
                                '${order.eventDate.day}',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _P.blue,
                                ),
                              ),
                              Text(
                                DateFormat('MMM', 'fr_FR').format(order.eventDate),
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
                                order.clientName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _P.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                order.offerTitle,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _P.inkSoft,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
}

class _RecommendationsSection extends StatelessWidget {
  final ThixProviderModel provider;

  const _RecommendationsSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final recommendations = [
      _Recommendation(
        icon: Icons.photo_library_rounded,
        title: 'Ajoutez plus de photos',
        description: 'Les profils avec 10+ photos reçoivent 3x plus de demandes',
        actionLabel: 'Ajouter',
        color: _P.blue,
        onTap: () => context.go('/thix-weeding/provider/gallery'),
      ),
      _Recommendation(
        icon: Icons.verified_rounded,
        title: 'Complétez votre profil',
        description: 'Les profils complets inspirent plus confiance aux clients',
        actionLabel: 'Compléter',
        color: _P.green,
        onTap: () {},
      ),
      _Recommendation(
        icon: Icons.videocam_rounded,
        title: 'Ajoutez une vidéo',
        description: 'Les offres avec vidéo ont 2x plus de conversions',
        actionLabel: 'Ajouter',
        color: _P.purple,
        onTap: () => context.push('/thix-weeding/provider/offers/new'),
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
                'Recommandations',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _P.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...recommendations.map((rec) => _RecommendationCard(recommendation: rec)),
        ],
      ),
    );
  }
}

class _Recommendation {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final Color color;
  final VoidCallback onTap;

  const _Recommendation({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.color,
    required this.onTap,
  });
}

class _RecommendationCard extends StatelessWidget {
  final _Recommendation recommendation;

  const _RecommendationCard({required this.recommendation});

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
              color: recommendation.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              recommendation.icon,
              color: recommendation.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _P.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  recommendation.description,
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
            onTap: recommendation.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: recommendation.color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                recommendation.actionLabel,
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.message,
  });

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
