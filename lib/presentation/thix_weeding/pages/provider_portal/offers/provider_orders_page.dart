// lib/presentation/thix_weeding/pages/provider_portal/orders/provider_orders_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'order_models.dart';
import 'orders_provider.dart';
import 'order_detail_page.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// THIX WEDDING — PAGE COMMANDES PRESTATAIRE (Production v2)
/// ✅ Liste commandes avec filtres par statut
/// ✅ Statistiques en temps réel
/// ✅ Workflow de statut
/// ✅ Recherche et tri
/// ✅ Indicateurs d'urgence
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
  static const Color blue = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color red = Color(0xFFEF4444);
}

class ProviderOrdersPage extends ConsumerStatefulWidget {
  final String providerId;
  final String providerName;

  const ProviderOrdersPage({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  @override
  ConsumerState<ProviderOrdersPage> createState() => _ProviderOrdersPageState();
}

class _ProviderOrdersPageState extends ConsumerState<ProviderOrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  OrderStatus? _statusFilter;
  bool _showUrgentOnly = false;
  SortOption _sortOption = SortOption.eventDateAsc;

  final List<Tab> _tabs = const [
    Tab(text: 'Toutes'),
    Tab(text: 'En attente'),
    Tab(text: 'En cours'),
    Tab(text: 'Terminées'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _statusFilter = _getStatusFilterForTab(_tabController.index);
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  OrderStatus? _getStatusFilterForTab(int index) {
    switch (index) {
      case 0:
        return null;
      case 1:
        return OrderStatus.pending;
      case 2:
        return OrderStatus.inProgress;
      case 3:
        return OrderStatus.completed;
      default:
        return null;
    }
  }

  List<WeddingOrder> _filterAndSortOrders(List<WeddingOrder> orders) {
    var filtered = orders;

    // Filtre par statut (onglet)
    if (_statusFilter != null) {
      filtered = filtered.where((o) => o.status == _statusFilter).toList();
    }

    // Recherche
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((o) {
        return o.clientName.toLowerCase().contains(query) ||
            o.offerTitle.toLowerCase().contains(query) ||
            o.id.toLowerCase().contains(query);
      }).toList();
    }

    // Urgences uniquement
    if (_showUrgentOnly) {
      filtered = filtered.where((o) => o.isUrgent).toList();
    }

    // Tri
    switch (_sortOption) {
      case SortOption.eventDateAsc:
        filtered.sort((a, b) => a.eventDate.compareTo(b.eventDate));
        break;
      case SortOption.eventDateDesc:
        filtered.sort((a, b) => b.eventDate.compareTo(a.eventDate));
        break;
      case SortOption.amountDesc:
        filtered.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        break;
      case SortOption.amountAsc:
        filtered.sort((a, b) => a.totalAmount.compareTo(b.totalAmount));
        break;
      case SortOption.priority:
        filtered.sort((a, b) => b.priority.index.compareTo(a.priority.index));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider(widget.providerId));
    final stats = ref.watch(orderStatsProvider(widget.providerId));

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.bg,
        elevation: 0,
        title: Text(
          'Mes commandes',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _P.ink),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: _P.ink),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded, color: _P.ink),
            onPressed: _showSortDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: _P.rose,
          unselectedLabelColor: _P.inkSoft,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          indicatorColor: _P.rose,
          indicatorWeight: 3,
          tabs: _tabs,
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche et filtres rapides
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Recherche
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Rechercher client, offre, ID...',
                    hintStyle: GoogleFonts.inter(color: _P.inkSoft, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: _P.inkSoft),
                    filled: true,
                    fillColor: _P.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: _P.inkSoft),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Filtres rapides
                Row(
                  children: [
                    // Urgences
                    FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: _showUrgentOnly ? Colors.white : _P.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Urgentes (${stats.urgent})',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _showUrgentOnly ? Colors.white : _P.red,
                            ),
                          ),
                        ],
                      ),
                      selected: _showUrgentOnly,
                      selectedColor: _P.red,
                      backgroundColor: _P.red.withOpacity(0.1),
                      onSelected: (v) => setState(() => _showUrgentOnly = v),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    const SizedBox(width: 8),

                    // En attente
                    FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hourglass_empty_rounded,
                            size: 14,
                            color: _statusFilter == OrderStatus.pending ? Colors.white : _P.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'En attente (${stats.pending})',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _statusFilter == OrderStatus.pending ? Colors.white : _P.amber,
                            ),
                          ),
                        ],
                      ),
                      selected: _statusFilter == OrderStatus.pending,
                      selectedColor: _P.amber,
                      backgroundColor: _P.amber.withOpacity(0.1),
                      onSelected: (v) {
                        setState(() {
                          _statusFilter = v ? OrderStatus.pending : null;
                        });
                      },
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Statistiques rapides
          if (stats.total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _QuickStats(stats: stats),
            ),

          // Liste des commandes
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final filteredOrders = _filterAndSortOrders(orders);

                if (filteredOrders.isEmpty) {
                  return _EmptyState(
                    hasOrders: orders.isNotEmpty,
                    searchQuery: _searchQuery,
                    onClearFilters: () {
                      setState(() {
                        _searchQuery = '';
                        _statusFilter = null;
                        _showUrgentOnly = false;
                        _tabController.animateTo(0);
                      });
                    },
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    ref.invalidate(ordersProvider(widget.providerId));
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      return _OrderCard(
                        order: filteredOrders[index],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailPage(
                                order: filteredOrders[index],
                                providerId: widget.providerId,
                              ),
                            ),
                          );
                        },
                        onQuickAction: (newStatus) {
                          _quickUpdateStatus(filteredOrders[index], newStatus);
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: _P.rose),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 60, color: _P.red),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur de chargement',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _P.ink),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(ordersProvider(widget.providerId)),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _P.rose,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    );
  }

  Future<void> _quickUpdateStatus(WeddingOrder order, OrderStatus newStatus) async {
    try {
      await ref.read(ordersProvider(widget.providerId).notifier).updateOrderStatus(
            orderId: order.id,
            newStatus: newStatus,
            performedBy: widget.providerName,
            performedByRole: 'provider',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Statut mis à jour: ${newStatus.name}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: _P.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Filtrer par statut',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FilterOption(
              title: 'Toutes les commandes',
              icon: Icons.list_rounded,
              selected: _statusFilter == null,
              onTap: () {
                setState(() => _statusFilter = null);
                Navigator.pop(context);
              },
            ),
            ...OrderStatus.values.map((status) {
              return _FilterOption(
                title: status.displayName,
                icon: status.icon,
                color: status.color,
                selected: _statusFilter == status,
                onTap: () {
                  setState(() => _statusFilter = status);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Trier par',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SortOption.values.map((option) {
            return _FilterOption(
              title: option.displayName,
              icon: option.icon,
              selected: _sortOption == option,
              onTap: () {
                setState(() => _sortOption = option);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

enum SortOption {
  eventDateAsc,
  eventDateDesc,
  amountDesc,
  amountAsc,
  priority,
}

extension SortOptionExtension on SortOption {
  String get displayName {
    switch (this) {
      case SortOption.eventDateAsc:
        return 'Date événement (proche)';
      case SortOption.eventDateDesc:
        return 'Date événement (lointain)';
      case SortOption.amountDesc:
        return 'Montant (élevé)';
      case SortOption.amountAsc:
        return 'Montant (faible)';
      case SortOption.priority:
        return 'Priorité';
    }
  }

  IconData get icon {
    switch (this) {
      case SortOption.eventDateAsc:
        return Icons.calendar_today_rounded;
      case SortOption.eventDateDesc:
        return Icons.calendar_month_rounded;
      case SortOption.amountDesc:
        return Icons.arrow_downward_rounded;
      case SortOption.amountAsc:
        return Icons.arrow_upward_rounded;
      case SortOption.priority:
        return Icons.flag_rounded;
    }
  }
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.confirmed:
        return 'Confirmée';
      case OrderStatus.inProgress:
        return 'En cours';
      case OrderStatus.ready:
        return 'Prête';
      case OrderStatus.delivered:
        return 'Livrée';
      case OrderStatus.completed:
        return 'Terminée';
      case OrderStatus.cancelled:
        return 'Annulée';
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.pending:
        return Icons.hourglass_empty_rounded;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.inProgress:
        return Icons.sync_rounded;
      case OrderStatus.ready:
        return Icons.check_circle_rounded;
      case OrderStatus.delivered:
        return Icons.local_shipping_rounded;
      case OrderStatus.completed:
        return Icons.verified_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.confirmed:
        return const Color(0xFF3B82F6);
      case OrderStatus.inProgress:
        return const Color(0xFFF59E0B);
      case OrderStatus.ready:
        return const Color(0xFF10B981);
      case OrderStatus.delivered:
        return const Color(0xFF14B8A6);
      case OrderStatus.completed:
        return const Color(0xFF059669);
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _QuickStats extends StatelessWidget {
  final OrderStats stats;

  const _QuickStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_P.rose, _P.roseLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _P.rose.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: '${stats.total}',
            label: 'Total',
            icon: Icons.receipt_long_rounded,
          ),
          _StatItem(
            value: '${stats.pending}',
            label: 'En attente',
            icon: Icons.hourglass_empty_rounded,
          ),
          _StatItem(
            value: '${stats.inProgress}',
            label: 'En cours',
            icon: Icons.sync_rounded,
          ),
          _StatItem(
            value: '${stats.completed}',
            label: 'Terminées',
            icon: Icons.check_circle_rounded,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final WeddingOrder order;
  final VoidCallback onTap;
  final Function(OrderStatus) onQuickAction;

  const _OrderCard({
    required this.order,
    required this.onTap,
    required this.onQuickAction,
  });

  @override
  Widget build(BuildContext context) {
    final daysUntil = order.daysUntilEvent;
    final isUrgent = order.isUrgent;
    final statusColor = order.status.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent ? _P.red.withOpacity(0.5) : _P.line,
          width: isUrgent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header : Client + Badge urgence
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(order.status.icon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.clientName,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _P.ink,
                          ),
                        ),
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
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _P.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 12, color: _P.red),
                          const SizedBox(width: 4),
                          Text(
                            'URGENT',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: _P.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Badge statut + Montant
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${order.totalAmount.toStringAsFixed(0)}\$',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _P.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Informations événement
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _P.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: _P.inkSoft),
                        const SizedBox(width: 6),
                        Text(
                          'Événement: ${DateFormat('dd MMM yyyy', 'fr_FR').format(order.eventDate)}',
                          style: GoogleFonts.inter(fontSize: 12, color: _P.ink),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: daysUntil <= 3
                                ? _P.red.withOpacity(0.1)
                                : daysUntil <= 7
                                    ? _P.amber.withOpacity(0.1)
                                    : _P.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            daysUntil == 0
                                ? "Aujourd'hui"
                                : daysUntil == 1
                                    ? 'Demain'
                                    : 'J-$daysUntil',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: daysUntil <= 3
                                  ? _P.red
                                  : daysUntil <= 7
                                      ? _P.amber
                                      : _P.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (order.eventLocation != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: _P.inkSoft),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              order.eventLocation!,
                              style: GoogleFonts.inter(fontSize: 12, color: _P.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (order.isTraiteur) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.restaurant_rounded, size: 14, color: _P.amber),
                          const SizedBox(width: 6),
                          Text(
                            'Commande traiteur',
                            style: GoogleFonts.inter(fontSize: 12, color: _P.amber, fontWeight: FontWeight.w600),
                          ),
                          if (order.menuValidated) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle_rounded, size: 14, color: _P.green),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Actions rapides
              if (order.nextStatus != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onQuickAction(order.nextStatus!),
                        icon: Icon(order.nextStatus!.icon, size: 16),
                        label: Text(order.nextActionLabel ?? 'Action'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: order.nextStatus!.color,
                          side: BorderSide(color: order.nextStatus!.color),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onTap,
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      color: _P.inkSoft,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasOrders;
  final String searchQuery;
  final VoidCallback onClearFilters;

  const _EmptyState({
    required this.hasOrders,
    required this.searchQuery,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _P.rose.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasOrders ? Icons.search_off_rounded : Icons.shopping_basket_outlined,
                size: 56,
                color: _P.rose,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasOrders
                  ? 'Aucun résultat'
                  : 'Aucune commande',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _P.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasOrders
                  ? searchQuery.isNotEmpty
                      ? 'Aucune commande ne correspond à "$searchQuery"'
                      : 'Modifiez vos filtres pour voir plus de résultats'
                  : 'Les commandes de vos clients apparaîtront ici',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _P.inkSoft,
                height: 1.4,
              ),
            ),
            if (hasOrders) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Réinitialiser les filtres'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.rose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterOption({
    required this.title,
    required this.icon,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _P.rose.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? _P.rose : (color ?? _P.inkSoft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _P.rose : _P.ink,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, size: 18, color: _P.rose),
          ],
        ),
      ),
    );
  }
}
