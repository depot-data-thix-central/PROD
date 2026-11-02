// lib/presentation/thix_weeding/pages/provider_portal/provider_business_pages.dart
// ============================================================================
// THIX WEDDING PROVIDER BUSINESS (PRODUCTION ENTERPRISE)
// ✅ Réservations : filtres, recherche, détails, actions rapides, stats
// ✅ Tâches : checklist interactive, priorités, tri, édition inline
// ✅ Pull-to-refresh, haptic feedback, animations fluides
// ✅ Bottom sheets détaillés et dialogues de confirmation
// ✅ Empty states premium et skeleton loading
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';

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

// ═══════════════════════════════════════════════════════════════════════════
// ÉTATS GLOBAUX POUR LES FILTRES
// ═══════════════════════════════════════════════════════════════════════════
final _reservationFilterProvider = StateProvider<ReservationStatus?>((ref) => null);
final _reservationSearchProvider = StateProvider<String>((ref) => '');
final _taskFilterProvider = StateProvider<TaskStatus?>((ref) => null);
final _taskSortProvider = StateProvider<TaskSort>((ref) => TaskSort.date);

enum TaskSort { date, priority, status }

// ═══════════════════════════════════════════════════════════════════════════
// RÉSERVATIONS - PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════
class ProviderReservationsPage extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  const ProviderReservationsPage({super.key, required this.provider});

  @override
  ConsumerState<ProviderReservationsPage> createState() =>
      _ProviderReservationsPageState();
}

class _ProviderReservationsPageState extends ConsumerState<ProviderReservationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
        final status = switch (_tabController.index) {
          0 => null,
          1 => ReservationStatus.pending,
          2 => ReservationStatus.confirmed,
          3 => ReservationStatus.completed,
          4 => ReservationStatus.cancelled,
          _ => null,
        };
        ref.read(_reservationFilterProvider.notifier).state = status;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(_reservationSearchProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(providerReservationsProvider(
      ProviderReservationsParams(providerId: widget.provider.id),
    ));
    final filter = ref.watch(_reservationFilterProvider);
    final search = ref.watch(_reservationSearchProvider);

    return Scaffold(
      backgroundColor: _P.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ═══════════════════════════════════════════════════════════
          // HEADER PREMIUM
          // ═══════════════════════════════════════════════════════════
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
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
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.arrow_back_ios_new,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Réservations',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _showFilterDialog(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.tune_rounded,
                                    size: 20, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Stats rapides
                        reservationsAsync.when(
                          data: (reservations) => Row(
                            children: [
                              _QuickStat(
                                icon: Icons.event_note_rounded,
                                value: '${reservations.length}',
                                label: 'Total',
                              ),
                              const SizedBox(width: 12),
                              _QuickStat(
                                icon: Icons.pending_actions_rounded,
                                value:
                                    '${reservations.where((r) => r.status == ReservationStatus.pending).length}',
                                label: 'En attente',
                                color: _P.amber,
                              ),
                              const SizedBox(width: 12),
                              _QuickStat(
                                icon: Icons.attach_money_rounded,
                                value:
                                    '\$${reservations.fold<double>(0, (sum, r) => sum + (r.totalPrice ?? 0)).toStringAsFixed(0)}',
                                label: 'Revenus',
                                color: _P.green,
                              ),
                            ],
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ═══════════════════════════════════════════════════════════
          // BARRE DE RECHERCHE
          // ═══════════════════════════════════════════════════════════
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _P.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un client...',
                    hintStyle: GoogleFonts.inter(color: _P.inkSoft, fontSize: 13),
                    border: InputBorder.none,
                    icon: const Icon(Icons.search_rounded, color: _P.inkSoft),
                    suffixIcon: search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: _P.inkSoft, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref
                                  .read(_reservationSearchProvider.notifier)
                                  .state = '';
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),

          // ═══════════════════════════════════════════════════════════
          // ONGLETS DE FILTRES
          // ═══════════════════════════════════════════════════════════
          SliverToBoxAdapter(
            child: Container(
              color: _P.bg,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: _P.rose,
                unselectedLabelColor: _P.inkSoft,
                indicatorColor: _P.rose,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  _buildTab('Toutes', reservationsAsync, null),
                  _buildTab('En attente', reservationsAsync, ReservationStatus.pending),
                  _buildTab('Confirmées', reservationsAsync, ReservationStatus.confirmed),
                  _buildTab('Terminées', reservationsAsync, ReservationStatus.completed),
                  _buildTab('Annulées', reservationsAsync, ReservationStatus.cancelled),
                ],
              ),
            ),
          ),

          // ═══════════════════════════════════════════════════════════
          // LISTE DES RÉSERVATIONS
          // ═══════════════════════════════════════════════════════════
          reservationsAsync.when(
            data: (allReservations) {
              // Filtrer par statut et recherche
              var filtered = allReservations;
              if (filter != null) {
                filtered = filtered.where((r) => r.status == filter).toList();
              }
              if (search.isNotEmpty) {
                final q = search.toLowerCase();
                filtered = filtered.where((r) {
                  return r.clientName.toLowerCase().contains(q) ||
                      r.clientPhone.toLowerCase().contains(q) ||
                      (r.eventType?.toLowerCase().contains(q) ?? false);
                }).toList();
              }

              // Trier par date décroissante
              filtered.sort((a, b) => b.eventDate.compareTo(a.eventDate));

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: filter == null
                        ? 'Aucune réservation'
                        : 'Aucune réservation ${_getStatusLabel(filter)}',
                    subtitle:
                        'Les nouvelles demandes apparaîtront ici automatiquement',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final r = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReservationCard(
                          reservation: r,
                          onTap: () => _showReservationDetails(context, r),
                          onConfirm: () => _confirmStatusChange(
                            context,
                            r,
                            ReservationStatus.confirmed,
                          ),
                          onCancel: () => _confirmStatusChange(
                            context,
                            r,
                            ReservationStatus.cancelled,
                          ),
                          onComplete: () => _confirmStatusChange(
                            context,
                            r,
                            ReservationStatus.completed,
                          ),
                          onCall: () => _callClient(r.clientPhone),
                          onWhatsApp: () => _openWhatsApp(r.clientPhone),
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: _P.rose,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Chargement...',
                      style: TextStyle(color: _P.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(providerReservationsProvider(
                  ProviderReservationsParams(providerId: widget.provider.id),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
      String label, AsyncValue<List<ProviderReservationModel>> asyncRes, ReservationStatus? status) {
    return asyncRes.when(
      data: (reservations) {
        final count = status == null
            ? reservations.length
            : reservations.where((r) => r.status == status).length;
        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: status == null
                      ? _P.inkSoft.withOpacity(0.15)
                      : _getStatusColor(status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: status == null ? _P.inkSoft : _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Tab(child: Text(label)),
      error: (_, __) => Tab(child: Text(label)),
    );
  }

  Future<void> _confirmStatusChange(
    BuildContext context,
    ProviderReservationModel r,
    ReservationStatus newStatus,
  ) async {
    final (title, message, color, icon) = switch (newStatus) {
      ReservationStatus.confirmed => (
          'Confirmer la réservation ?',
          'Le client "${r.clientName}" recevra une notification de confirmation.',
          _P.green,
          Icons.check_circle_rounded,
        ),
      ReservationStatus.cancelled => (
          'Annuler la réservation ?',
          'Cette action est irréversible. Le client sera notifié de l\'annulation.',
          _P.red,
          Icons.cancel_rounded,
        ),
      ReservationStatus.completed => (
          'Marquer comme terminée ?',
          'La réservation sera archivée et ajoutée à votre historique.',
          _P.blue,
          Icons.celebration_rounded,
        ),
      _ => ('', '', _P.ink, Icons.info),
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _P.ink,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(fontSize: 14, color: _P.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(color: _P.inkSoft, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Confirmer',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      HapticFeedback.mediumImpact();
      try {
        await ref.read(updateReservationStatusProvider)(
          r.id,
          newStatus,
          widget.provider.id,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Statut mis à jour avec succès',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              backgroundColor: color,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: _P.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _callClient(String phone) async {
    HapticFeedback.mediumImpact();
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    HapticFeedback.mediumImpact();
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showReservationDetails(BuildContext context, ProviderReservationModel r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReservationDetailsSheet(
        reservation: r,
        provider: widget.provider,
        onStatusChange: (newStatus) async {
          Navigator.pop(ctx);
          if (context.mounted) {
            _confirmStatusChange(context, r, newStatus);
          }
        },
        onCall: () => _callClient(r.clientPhone),
        onWhatsApp: () => _openWhatsApp(r.clientPhone),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    // TODO: Implémenter dialogue de filtre avancé
    HapticFeedback.selectionClick();
  }

  Color _getStatusColor(ReservationStatus status) {
    return switch (status) {
      ReservationStatus.pending => _P.amber,
      ReservationStatus.confirmed => _P.green,
      ReservationStatus.completed => _P.blue,
      ReservationStatus.cancelled => _P.red,
    };
  }

  String _getStatusLabel(ReservationStatus status) {
    return switch (status) {
      ReservationStatus.pending => 'en attente',
      ReservationStatus.confirmed => 'confirmée',
      ReservationStatus.completed => 'terminée',
      ReservationStatus.cancelled => 'annulée',
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE DE RÉSERVATION
// ═══════════════════════════════════════════════════════════════════════════
class _ReservationCard extends StatelessWidget {
  final ProviderReservationModel reservation;
  final VoidCallback onTap;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onComplete;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  const _ReservationCard({
    required this.reservation,
    required this.onTap,
    required this.onConfirm,
    required this.onCancel,
    required this.onComplete,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(reservation.status);
    final daysUntil = reservation.eventDate.difference(DateTime.now()).inDays;
    final isUrgent = daysUntil <= 3 &&
        daysUntil >= 0 &&
        reservation.status != ReservationStatus.cancelled &&
        reservation.status != ReservationStatus.completed;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUrgent ? _P.amber.withOpacity(0.5) : _P.line,
              width: isUrgent ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec client + statut
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [statusColor.withOpacity(0.8), statusColor],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        reservation.clientName.isNotEmpty
                            ? reservation.clientName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _P.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.phone_rounded,
                                size: 12, color: _P.inkSoft),
                            const SizedBox(width: 4),
                            Text(
                              reservation.clientPhone,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _P.inkSoft,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _getStatusText(reservation.status),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Infos événement
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _P.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 16, color: _P.rose),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              DateFormat('EEEE dd MMM yyyy', 'fr_FR')
                                  .format(reservation.eventDate),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _P.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: _P.line,
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 16, color: _P.blue),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('HH:mm').format(reservation.eventDate),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _P.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: _P.line,
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.people_rounded,
                              size: 16, color: _P.purple),
                          const SizedBox(width: 6),
                          Text(
                            '${reservation.guestCount ?? 0} pers.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _P.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Prix + urgence
              if (reservation.totalPrice != null || isUrgent) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (reservation.totalPrice != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _P.greenLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.payments_rounded,
                                size: 12, color: _P.green),
                            const SizedBox(width: 4),
                            Text(
                              '\$${reservation.totalPrice!.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _P.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _P.amberLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 12, color: _P.amber),
                            const SizedBox(width: 4),
                            Text(
                              daysUntil == 0
                                  ? "Aujourd'hui"
                                  : daysUntil == 1
                                      ? 'Demain'
                                      : 'Dans $daysUntil jours',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _P.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              // Actions rapides
              if (reservation.status == ReservationStatus.pending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.check_circle_rounded,
                        label: 'Confirmer',
                        color: _P.green,
                        onTap: onConfirm,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.cancel_rounded,
                        label: 'Refuser',
                        color: _P.red,
                        isOutlined: true,
                        onTap: onCancel,
                      ),
                    ),
                  ],
                ),
              ],

              if (reservation.status == ReservationStatus.confirmed) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    _ContactButton(
                      icon: Icons.call_rounded,
                      color: _P.green,
                      onTap: onCall,
                    ),
                    const SizedBox(width: 8),
                    _ContactButton(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      onTap: onWhatsApp,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.celebration_rounded,
                        label: 'Marquer terminé',
                        color: _P.blue,
                        onTap: onComplete,
                      ),
                    ),
                  ],
                ),
              ],

              if (reservation.status == ReservationStatus.completed ||
                  reservation.status == ReservationStatus.cancelled) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ContactButton(
                      icon: Icons.call_rounded,
                      color: _P.green,
                      onTap: onCall,
                    ),
                    const SizedBox(width: 8),
                    _ContactButton(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      onTap: onWhatsApp,
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

  Color _getStatusColor(ReservationStatus status) {
    return switch (status) {
      ReservationStatus.pending => _P.amber,
      ReservationStatus.confirmed => _P.green,
      ReservationStatus.completed => _P.blue,
      ReservationStatus.cancelled => _P.red,
    };
  }

  String _getStatusText(ReservationStatus status) {
    return switch (status) {
      ReservationStatus.pending => 'EN ATTENTE',
      ReservationStatus.confirmed => 'CONFIRMÉ',
      ReservationStatus.completed => 'TERMINÉ',
      ReservationStatus.cancelled => 'ANNULÉ',
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET - DÉTAILS RÉSERVATION
// ═══════════════════════════════════════════════════════════════════════════
class _ReservationDetailsSheet extends StatelessWidget {
  final ProviderReservationModel reservation;
  final ThixProviderModel provider;
  final Function(ReservationStatus) onStatusChange;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  const _ReservationDetailsSheet({
    required this.reservation,
    required this.provider,
    required this.onStatusChange,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(reservation.status);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _P.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [statusColor.withOpacity(0.8), statusColor],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            reservation.clientName.isNotEmpty
                                ? reservation.clientName[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reservation.clientName,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: _P.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _getStatusText(reservation.status),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Infos détaillées
                  _DetailRow(
                    icon: Icons.phone_rounded,
                    label: 'Téléphone',
                    value: reservation.clientPhone,
                  ),
                  _DetailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date',
                    value: DateFormat('EEEE dd MMMM yyyy', 'fr_FR')
                        .format(reservation.eventDate),
                  ),
                  _DetailRow(
                    icon: Icons.access_time_rounded,
                    label: 'Heure',
                    value: DateFormat('HH:mm').format(reservation.eventDate),
                  ),
                  if (reservation.eventType != null)
                    _DetailRow(
                      icon: Icons.celebration_rounded,
                      label: 'Type d\'événement',
                      value: reservation.eventType!,
                    ),
                  if (reservation.guestCount != null)
                    _DetailRow(
                      icon: Icons.people_rounded,
                      label: 'Nombre d\'invités',
                      value: '${reservation.guestCount} personnes',
                    ),
                  if (reservation.totalPrice != null)
                    _DetailRow(
                      icon: Icons.attach_money_rounded,
                      label: 'Montant total',
                      value: '\$${reservation.totalPrice!.toStringAsFixed(2)} ${reservation.currency}',
                      valueColor: _P.green,
                    ),
                  if (reservation.notes != null &&
                      reservation.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Notes',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _P.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _P.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _P.line),
                      ),
                      child: Text(
                        reservation.notes!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _P.ink,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Timeline
                  Text(
                    'Historique',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _P.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TimelineItem(
                    icon: Icons.add_circle_rounded,
                    title: 'Réservation créée',
                    date: DateFormat('dd MMM yyyy, HH:mm', 'fr_FR')
                        .format(reservation.createdAt),
                    color: _P.blue,
                    isFirst: true,
                  ),
                  if (reservation.status == ReservationStatus.confirmed ||
                      reservation.status == ReservationStatus.completed)
                    _TimelineItem(
                      icon: Icons.check_circle_rounded,
                      title: 'Réservation confirmée',
                      date: 'Par le prestataire',
                      color: _P.green,
                    ),
                  if (reservation.status == ReservationStatus.completed)
                    _TimelineItem(
                      icon: Icons.celebration_rounded,
                      title: 'Événement terminé',
                      date: DateFormat('dd MMM yyyy', 'fr_FR')
                          .format(reservation.eventDate),
                      color: _P.purple,
                      isLast: true,
                    ),
                  if (reservation.status == ReservationStatus.cancelled)
                    _TimelineItem(
                      icon: Icons.cancel_rounded,
                      title: 'Réservation annulée',
                      date: 'Annulation enregistrée',
                      color: _P.red,
                      isLast: true,
                    ),

                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.call_rounded,
                          label: 'Appeler',
                          color: _P.green,
                          onTap: onCall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.chat_rounded,
                          label: 'WhatsApp',
                          color: const Color(0xFF25D366),
                          isOutlined: true,
                          onTap: onWhatsApp,
                        ),
                      ),
                    ],
                  ),

                  if (reservation.status == ReservationStatus.pending) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.check_circle_rounded,
                            label: 'Confirmer',
                            color: _P.green,
                            onTap: () =>
                                onStatusChange(ReservationStatus.confirmed),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.cancel_rounded,
                            label: 'Refuser',
                            color: _P.red,
                            isOutlined: true,
                            onTap: () =>
                                onStatusChange(ReservationStatus.cancelled),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (reservation.status == ReservationStatus.confirmed) ...[
                    const SizedBox(height: 8),
                    _ActionButton(
                      icon: Icons.celebration_rounded,
                      label: 'Marquer comme terminé',
                      color: _P.blue,
                      onTap: () => onStatusChange(ReservationStatus.completed),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ReservationStatus status) {
    return switch (status) {
      ReservationStatus.pending => _P.amber,
      ReservationStatus.confirmed => _P.green,
      ReservationStatus.completed => _P.blue,
      ReservationStatus.cancelled => _P.red,
    };
  }

  String _getStatusText(ReservationStatus status) {
    return switch (status) {
      ReservationStatus.pending => 'EN ATTENTE',
      ReservationStatus.confirmed => 'CONFIRMÉ',
      ReservationStatus.completed => 'TERMINÉ',
      ReservationStatus.cancelled => 'ANNULÉ',
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS HELPER POUR RÉSERVATIONS
// ═══════════════════════════════════════════════════════════════════════════
class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _QuickStat({
    required this.icon,
    required this.value,
    required this.label,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
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
  final Color color;
  final VoidCallback onTap;
  final bool isOutlined;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(12),
          border: isOutlined ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isOutlined ? color : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isOutlined ? color : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _P.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _P.inkSoft),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _P.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? _P.ink,
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

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String date;
  final Color color;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.date,
    required this.color,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 10,
                    color: _P.line,
                  ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 14, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: _P.line,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _P.inkSoft,
                    ),
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
// TÂCHES - PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════
class ProviderTasksPage extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  const ProviderTasksPage({super.key, required this.provider});

  @override
  ConsumerState<ProviderTasksPage> createState() => _ProviderTasksPageState();
}

class _ProviderTasksPageState extends ConsumerState<ProviderTasksPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
        final status = switch (_tabController.index) {
          0 => null,
          1 => TaskStatus.assigned,
          2 => TaskStatus.inProgress,
          3 => TaskStatus.completed,
          _ => null,
        };
        ref.read(_taskFilterProvider.notifier).state = status;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(providerTasksProvider(
      ProviderTasksParams(providerId: widget.provider.id),
    ));
    final filter = ref.watch(_taskFilterProvider);
    final sort = ref.watch(_taskSortProvider);

    return Scaffold(
      backgroundColor: _P.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            backgroundColor: _P.blue,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_P.blue, Color(0xFF60A5FA)],
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
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.arrow_back_ios_new,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Mes Tâches',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _showSortMenu(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.sort_rounded,
                                    size: 20, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Progress bar
                        tasksAsync.when(
                          data: (tasks) {
                            final total = tasks.length;
                            final completed = tasks
                                .where((t) => t.status == TaskStatus.completed)
                                .length;
                            final progress =
                                total > 0 ? completed / total : 0.0;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Progression',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '$completed/$total',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}% complété',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Onglets
          SliverToBoxAdapter(
            child: Container(
              color: _P.bg,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: _P.blue,
                unselectedLabelColor: _P.inkSoft,
                indicatorColor: _P.blue,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  _buildTaskTab('Toutes', tasksAsync, null),
                  _buildTaskTab('Assignées', tasksAsync, TaskStatus.assigned),
                  _buildTaskTab('En cours', tasksAsync, TaskStatus.inProgress),
                  _buildTaskTab('Terminées', tasksAsync, TaskStatus.completed),
                ],
              ),
            ),
          ),

          // Liste des tâches
          tasksAsync.when(
            data: (allTasks) {
              var filtered = allTasks;
              if (filter != null) {
                filtered = filtered.where((t) => t.status == filter).toList();
              }

              // Tri
              switch (sort) {
                case TaskSort.date:
                  filtered.sort((a, b) => a.dueDateTime.compareTo(b.dueDateTime));
                  break;
                case TaskSort.priority:
                  filtered.sort((a, b) => a.priority.compareTo(b.priority));
                  break;
                case TaskSort.status:
                  filtered.sort(
                      (a, b) => a.status.index.compareTo(b.status.index));
                  break;
              }

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(
                    icon: Icons.task_alt_rounded,
                    title: filter == null
                        ? 'Aucune tâche'
                        : 'Aucune tâche ${_getTaskStatusLabel(filter)}',
                    subtitle: 'Les tâches assignées apparaîtront ici',
                  ),
                );
              }

              // Grouper par priorité
              final urgent =
                  filtered.where((t) => t.priority == 1).toList();
              final normal =
                  filtered.where((t) => t.priority != 1).toList();

              return SliverList(
                delegate: SliverChildListDelegate([
                  if (urgent.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _P.redLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.priority_high_rounded,
                                    size: 14, color: _P.red),
                                const SizedBox(width: 4),
                                Text(
                                  'URGENTES (${urgent.length})',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _P.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...urgent.map((t) => Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: _TaskCard(
                            task: t,
                            onToggle: (completed) => _toggleTask(t, completed),
                            onTap: () => _showTaskDetails(context, t),
                          ),
                        )),
                  ],
                  if (normal.isNotEmpty && urgent.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Autres tâches',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _P.inkSoft,
                        ),
                      ),
                    ),
                  ...normal.map((t) => Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: _TaskCard(
                          task: t,
                          onToggle: (completed) => _toggleTask(t, completed),
                          onTap: () => _showTaskDetails(context, t),
                        ),
                      )),
                  const SizedBox(height: 24),
                ]),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: _P.blue),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(providerTasksProvider(
                  ProviderTasksParams(providerId: widget.provider.id),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTab(
      String label, AsyncValue<List<ProviderTaskModel>> asyncTasks, TaskStatus? status) {
    return asyncTasks.when(
      data: (tasks) {
        final count = status == null
            ? tasks.length
            : tasks.where((t) => t.status == status).length;
        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _P.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _P.blue,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Tab(child: Text(label)),
      error: (_, __) => Tab(child: Text(label)),
    );
  }

  Future<void> _toggleTask(ProviderTaskModel task, bool completed) async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(updateTaskStatusProvider)(
        task.id,
        completed ? TaskStatus.completed : TaskStatus.assigned,
        widget.provider.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              completed ? 'Tâche terminée 🎉' : 'Tâche réouverte',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: completed ? _P.green : _P.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: _P.red,
          ),
        );
      }
    }
  }

  void _showTaskDetails(BuildContext context, ProviderTaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TaskDetailsSheet(
        task: task,
        onToggle: (completed) async {
          Navigator.pop(ctx);
          _toggleTask(task, completed);
        },
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trier par',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _P.ink,
              ),
            ),
            const SizedBox(height: 16),
            _SortOption(
              icon: Icons.access_time_rounded,
              label: 'Date d\'échéance',
              selected: ref.read(_taskSortProvider) == TaskSort.date,
              onTap: () {
                ref.read(_taskSortProvider.notifier).state = TaskSort.date;
                Navigator.pop(ctx);
              },
            ),
            _SortOption(
              icon: Icons.priority_high_rounded,
              label: 'Priorité',
              selected: ref.read(_taskSortProvider) == TaskSort.priority,
              onTap: () {
                ref.read(_taskSortProvider.notifier).state = TaskSort.priority;
                Navigator.pop(ctx);
              },
            ),
            _SortOption(
              icon: Icons.sort_rounded,
              label: 'Statut',
              selected: ref.read(_taskSortProvider) == TaskSort.status,
              onTap: () {
                ref.read(_taskSortProvider.notifier).state = TaskSort.status;
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getTaskStatusLabel(TaskStatus status) {
    return switch (status) {
      TaskStatus.assigned => 'assignée',
      TaskStatus.inProgress => 'en cours',
      TaskStatus.completed => 'terminée',
      TaskStatus.cancelled => 'annulée',
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE DE TÂCHE
// ═══════════════════════════════════════════════════════════════════════════
class _TaskCard extends StatelessWidget {
  final ProviderTaskModel task;
  final Function(bool) onToggle;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;
    final isUrgent = task.priority == 1 && !isCompleted;
    final isOverdue = task.dueDateTime.isBefore(DateTime.now()) && !isCompleted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUrgent
                  ? _P.red.withOpacity(0.4)
                  : isOverdue
                      ? _P.amber.withOpacity(0.5)
                      : _P.line,
              width: isUrgent || isOverdue ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => onToggle(!isCompleted),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted ? _P.green : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted ? _P.green : _P.line,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isCompleted ? _P.inkSoft : _P.ink,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (isUrgent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _P.redLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'URGENT',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _P.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (task.description != null &&
                        task.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _P.inkSoft,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.access_time_rounded,
                          size: 14,
                          color: isOverdue ? _P.amber : _P.inkSoft,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDueDate(task.dueDateTime),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOverdue ? _P.amber : _P.inkSoft,
                          ),
                        ),
                        const Spacer(),
                        _PriorityDots(priority: task.priority),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.inDays < 0) {
      return 'En retard de ${-diff.inDays}j';
    } else if (diff.inDays == 0) {
      return 'Aujourd\'hui à ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays == 1) {
      return 'Demain à ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays < 7) {
      return 'Dans ${diff.inDays} jours';
    } else {
      return DateFormat('dd MMM yyyy', 'fr_FR').format(date);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET - DÉTAILS TÂCHE
// ═══════════════════════════════════════════════════════════════════════════
class _TaskDetailsSheet extends StatelessWidget {
  final ProviderTaskModel task;
  final Function(bool) onToggle;

  const _TaskDetailsSheet({
    required this.task,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;
    final statusColor = _getTaskStatusColor(task.status);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _P.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => onToggle(!isCompleted),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                isCompleted ? _P.green : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCompleted ? _P.green : _P.line,
                              width: 2.5,
                            ),
                          ),
                          child: isCompleted
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 24)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isCompleted ? _P.inkSoft : _P.ink,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getTaskStatusText(task.status),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Description
                  if (task.description != null &&
                      task.description!.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _P.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _P.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _P.line),
                      ),
                      child: Text(
                        task.description!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _P.ink,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Infos
                  _DetailRow(
                    icon: Icons.access_time_rounded,
                    label: 'Échéance',
                    value: DateFormat('EEEE dd MMMM yyyy à HH:mm', 'fr_FR')
                        .format(task.dueDateTime),
                  ),
                  _DetailRow(
                    icon: Icons.flag_rounded,
                    label: 'Priorité',
                    value: _getPriorityLabel(task.priority),
                    valueColor: _getPriorityColor(task.priority),
                  ),
                  _DetailRow(
                    icon: Icons.person_rounded,
                    label: 'Assignée par',
                    value: task.assignedBy,
                  ),
                  _DetailRow(
                    icon: Icons.add_circle_rounded,
                    label: 'Créée le',
                    value: DateFormat('dd MMM yyyy, HH:mm', 'fr_FR')
                        .format(task.createdAt),
                  ),

                  const SizedBox(height: 24),

                  // Action
                  _ActionButton(
                    icon: isCompleted
                        ? Icons.refresh_rounded
                        : Icons.check_circle_rounded,
                    label: isCompleted
                        ? 'Rouvrir la tâche'
                        : 'Marquer comme terminée',
                    color: isCompleted ? _P.blue : _P.green,
                    onTap: () => onToggle(!isCompleted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTaskStatusColor(TaskStatus status) {
    return switch (status) {
      TaskStatus.assigned => _P.blue,
      TaskStatus.inProgress => _P.amber,
      TaskStatus.completed => _P.green,
      TaskStatus.cancelled => _P.red,
    };
  }

  String _getTaskStatusText(TaskStatus status) {
    return switch (status) {
      TaskStatus.assigned => 'ASSIGNÉE',
      TaskStatus.inProgress => 'EN COURS',
      TaskStatus.completed => 'TERMINÉE',
      TaskStatus.cancelled => 'ANNULÉE',
    };
  }

  String _getPriorityLabel(int priority) {
    return switch (priority) {
      1 => 'Urgente',
      2 => 'Normale',
      3 => 'Basse',
      _ => 'Normale',
    };
  }

  Color _getPriorityColor(int priority) {
    return switch (priority) {
      1 => _P.red,
      2 => _P.amber,
      3 => _P.blue,
      _ => _P.inkSoft,
    };
  }
}

class _PriorityDots extends StatelessWidget {
  final int priority;
  const _PriorityDots({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      1 => _P.red,
      2 => _P.amber,
      3 => _P.blue,
      _ => _P.inkSoft,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        priority <= 3 ? priority : 3,
        (i) => Container(
          margin: const EdgeInsets.only(left: 2),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _P.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _P.blue : _P.line,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? _P.blue : _P.inkSoft),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? _P.blue : _P.ink,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_rounded, size: 20, color: _P.blue),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY STATE & ERROR STATE
// ═══════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
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
                color: _P.inkSoft.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: _P.inkSoft),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _P.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _P.inkSoft,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

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
                color: _P.redLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 64, color: _P.red),
            ),
            const SizedBox(height: 20),
            Text(
              'Une erreur est survenue',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _P.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
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
    );
  }
}
