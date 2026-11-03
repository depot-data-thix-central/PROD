// lib/presentation/thix_weeding/pages/provider_portal/provider_business_pages.dart
// ============================================================================
// THIX WEDDING PROVIDER BUSINESS (PRODUCTION v4 — COMPLET)
// ✅ Réservations : filtres, recherche, détails, actions rapides, stats
// ✅ Tâches : checklist interactive, priorités, tri, édition inline
// ✅ DEMANDES DE PRESTATION : bandeau d'alerte + page dédiée
//    → Approuver (crée le dossier vendor + redirige vers gestion)
//    → Refuser (motif obligatoire)
// ✅ GESTION POST-APPROBATION : espace spécifique par type de prestation
// ✅ MENUS TRAITEUR : liste de plats, validation par élément, mise en public
// ✅ PRÉFÉRENCES INVITÉS : vote sur les plats, affichage du plus populaire
// ✅ Pull-to-refresh, haptic feedback, animations fluides
// ============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFFFFBEB);
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
// ✅ NOUVEAU : PROVIDERS POUR LES MENUS (traiteurs)
// ═══════════════════════════════════════════════════════════════════════════
final vendorMenuItemsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, vendorId) async {
  try {
    final rows = await Supabase.instance.client
        .from('thix_weeding_menu_items')
        .select('*')
        .eq('vendor_id', vendorId)
        .order('position', ascending: true)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  } catch (e) {
    debugPrint('Erreur menu items: $e');
    return [];
  }
});

/// Stats de votes invités pour un menu
final menuItemVotesProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, weddingId) async {
  try {
    final rows = await Supabase.instance.client
        .from('thix_weeding_menu_votes')
        .select('menu_item_id')
        .eq('wedding_id', weddingId);
    final counts = <String, int>{};
    for (final r in rows) {
      final id = r['menu_item_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  } catch (_) {
    return {};
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// DEMANDES DE PRESTATION (staff → prestataire)
// ═══════════════════════════════════════════════════════════════════════════
final providerIncomingRequestsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, providerId) async {
    final c = Supabase.instance.client;
    final rows = await c
        .from('thix_weeding_vendor_requests')
        .select('*')
        .eq('provider_id', providerId)
        .order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(rows);
    if (list.isEmpty) return list;

    final pIds = list.map((r) => r['provider_id']).whereType<String>().toSet().toList();
    final wIds = list.map((r) => r['wedding_id']).whereType<String>().toSet().toList();
    final provMap = <String, Map<String, dynamic>>{};
    final wedMap = <String, Map<String, dynamic>>{};

    if (pIds.isNotEmpty) {
      try {
        final pr = await c
            .from('thix_weeding_providers')
            .select('id, business_name, unique_code, category, city, phone, email, verification_status')
            .inFilter('id', pIds);
        for (final p in List<Map<String, dynamic>>.from(pr)) provMap[p['id'] as String] = p;
      } catch (_) {}
    }

    if (wIds.isNotEmpty) {
      try {
        final wr = await c
            .from('thix_weeding_weddings')
            .select('id, bride_name, groom_name, wedding_date, venue')
            .inFilter('id', wIds);
        for (final w in List<Map<String, dynamic>>.from(wr)) wedMap[w['id'] as String] = w;
      } catch (_) {}
    }

    for (final r in list) {
      r['provider'] = provMap[r['provider_id'] as String? ?? ''] ?? <String, dynamic>{};
      r['wedding'] = wedMap[r['wedding_id'] as String? ?? ''] ?? <String, dynamic>{};
    }
    return list;
  },
);

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════
String _catLabel(String? key) {
  switch ((key ?? '').toLowerCase()) {
    case 'salle': return 'Salle de réception';
    case 'traiteur': return 'Traiteur';
    case 'photographe': return 'Photographe';
    case 'videaste': return 'Vidéaste';
    case 'decorateur': return 'Décorateur';
    case 'dj': return 'DJ / Sonorisation';
    case 'mc': return 'MC / Animateur';
    case 'maquilleur': return 'Maquillage / Coiffure';
    case 'patissier': return 'Pâtissier';
    case 'fleuriste': return 'Fleuriste';
    default: return key ?? 'Prestataire';
  }
}

String _mapVendorCategory(String? providerCat) {
  switch ((providerCat ?? '').toLowerCase()) {
    case 'salle': return 'salle';
    case 'traiteur': return 'traiteur';
    case 'photographe': return 'photographe';
    case 'videaste': return 'videaste';
    case 'decorateur': return 'decorateur';
    case 'dj': return 'dj';
    case 'mc': return 'dj';
    case 'maquilleur': return 'maquilleur';
    case 'patissier': return 'patissier';
    case 'fleuriste': return 'fleuriste';
    default: return (providerCat ?? '').trim().isEmpty ? 'organisateur' : providerCat!;
  }
}

/// Détermine le type de gestion post-approbation selon la catégorie
enum ServiceManagementType { menu, gallery, timeline, generic }

ServiceManagementType _managementTypeFor(String? category) {
  switch ((category ?? '').toLowerCase()) {
    case 'traiteur':
    case 'patissier':
      return ServiceManagementType.menu;
    case 'photographe':
    case 'videaste':
      return ServiceManagementType.gallery;
    case 'dj':
    case 'mc':
    case 'decorateur':
      return ServiceManagementType.timeline;
    default:
      return ServiceManagementType.generic;
  }
}

Color _reqColor(String? s) => switch (s) {
  'approved' => _P.green,
  'rejected' => _P.red,
  'cancelled' => _P.inkSoft,
  _ => _P.amber,
};

String _reqLabel(String? s) => switch (s) {
  'approved' => 'Acceptée',
  'rejected' => 'Refusée',
  'cancelled' => 'Retirée',
  _ => 'En attente',
};

IconData _reqIcon(String? s) => switch (s) {
  'approved' => Icons.check_circle_rounded,
  'rejected' => Icons.cancel_rounded,
  'cancelled' => Icons.do_not_disturb_on_rounded,
  _ => Icons.hourglass_top_rounded,
};

String _coupleNames(Map<String, dynamic> r) {
  final w = (r['wedding'] as Map?)?.cast<String, dynamic>() ?? {};
  final b = (w['bride_name'] as String? ?? '').trim();
  final g = (w['groom_name'] as String? ?? '').trim();
  if (b.isEmpty && g.isEmpty) return 'Mariage';
  if (g.isEmpty) return b;
  if (b.isEmpty) return g;
  return '$b & $g';
}

String _fmtWeddingDate(Map<String, dynamic> r) {
  final w = (r['wedding'] as Map?)?.cast<String, dynamic>() ?? {};
  final d = w['wedding_date'] as String?;
  if (d == null || d.isEmpty) return 'Date à définir';
  try {
    return DateFormat('dd MMM yyyy', 'fr_FR').format(DateTime.parse(d));
  } catch (_) {
    return d;
  }
}

String _venueOf(Map<String, dynamic> r) {
  final w = (r['wedding'] as Map?)?.cast<String, dynamic>() ?? {};
  return (w['venue'] as String? ?? '').trim().isEmpty
      ? 'Lieu à définir'
      : w['venue'] as String;
}

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
    final requestsAsync = ref.watch(providerIncomingRequestsProvider(widget.provider.id));

    return Scaffold(
      backgroundColor: _P.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // HEADER PREMIUM
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

          // BANDEAU DEMANDES
          requestsAsync.when(
            data: (list) {
              final pending =
                  list.where((r) => (r['status'] ?? 'pending') == 'pending').length;
              if (pending == 0) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ProviderRequestsPage(provider: widget.provider),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_P.amber, Color(0xFFFFB84D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _P.amber.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.mark_email_unread_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$pending demande${pending > 1 ? 's' : ''} de mariage à traiter',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Consultez, acceptez ou refusez les sollicitations des couples',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.92),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: Colors.white, size: 26),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // BARRE DE RECHERCHE
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

          // ONGLETS
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

          // LISTE
          reservationsAsync.when(
            data: (allReservations) {
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
          tasksAsync.when(
            data: (allTasks) {
              var filtered = allTasks;
              if (filter != null) {
                filtered = filtered.where((t) => t.status == filter).toList();
              }
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

              final urgent = filtered.where((t) => t.priority == 1).toList();
              final normal = filtered.where((t) => t.priority != 1).toList();

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

// ═══════════════════════════════════════════════════════════════════════════
// ✅ NOUVEAU : PAGE "DEMANDES DE PRESTATION" (reçues du staff / mariage)
//    Ouverte via le bandeau d'alerte de l'onglet Résa. (Navigator.push)
//    CORRIGÉ : ConsumerStatefulWidget + TabController créé/disposé proprement
// ═══════════════════════════════════════════════════════════════════════════
final _reqTabProvider = StateProvider<int>((ref) => 0); // 0=À traiter, 1=Historique

class ProviderRequestsPage extends ConsumerStatefulWidget {
  final ThixProviderModel provider;

  const ProviderRequestsPage({super.key, required this.provider});

  @override
  ConsumerState<ProviderRequestsPage> createState() =>
      _ProviderRequestsPageState();
}

class _ProviderRequestsPageState extends ConsumerState<ProviderRequestsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: ref.read(_reqTabProvider).clamp(0, 1),
    );
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        HapticFeedback.selectionClick();
        ref.read(_reqTabProvider.notifier).state = _tabCtrl.index;
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync =
        ref.watch(providerIncomingRequestsProvider(widget.provider.id));
    final tab = ref.watch(_reqTabProvider);

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.rose,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Demandes de prestation',
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref
                .invalidate(providerIncomingRequestsProvider(widget.provider.id)),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'À traiter'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: requestsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _P.rose)),
        error: (e, _) => _ErrorState(
          message: '$e',
          onRetry: () => ref
              .invalidate(providerIncomingRequestsProvider(widget.provider.id)),
        ),
        data: (all) {
          final pending =
              all.where((r) => (r['status'] ?? 'pending') == 'pending').toList();
          final history =
              all.where((r) => (r['status'] ?? 'pending') != 'pending').toList();
          final list = tab == 0 ? pending : history;

          if (list.isEmpty) {
            return tab == 0
                ? const _EmptyState(
                    icon: Icons.mark_email_read_rounded,
                    title: 'Aucune demande en attente',
                    subtitle:
                        'Quand un couple vous sollicitera depuis le catalogue, sa demande apparaîtra ici.',
                  )
                : const _EmptyState(
                    icon: Icons.history_rounded,
                    title: 'Aucun historique',
                    subtitle:
                        'Vos demandes traitées (acceptées ou refusées) s\'afficheront ici.',
                  );
          }

          return RefreshIndicator(
            color: _P.rose,
            onRefresh: () async => ref
                .invalidate(providerIncomingRequestsProvider(widget.provider.id)),
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _IncomingRequestCard(
                request: list[i],
                providerId: widget.provider.id,
                provider: widget.provider,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE D'UNE DEMANDE REÇUE
// ═══════════════════════════════════════════════════════════════════════════
class _IncomingRequestCard extends ConsumerWidget {
  final Map<String, dynamic> request;
  final String providerId;
  final ThixProviderModel provider;

  const _IncomingRequestCard({
    required this.request,
    required this.providerId,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = request['status'] as String? ?? 'pending';
    final color = _reqColor(status);
    final couple = _coupleNames(request);
    final prov =
        (request['provider'] as Map?)?.cast<String, dynamic>() ?? {};
    final catKey = prov['category'] as String?;
    final code = prov['unique_code'] as String? ?? '';
    final price = (request['proposed_price'] as num?)?.toDouble();
    final currency = request['currency'] as String? ?? 'USD';
    final message = (request['message'] as String? ?? '').trim();
    final response = (request['provider_response'] as String? ?? '').trim();
    final contactName = (request['contact_name'] as String? ?? '').trim();
    final contactPhone = (request['contact_phone'] as String? ?? '').trim();
    final venue = _venueOf(request);
    final dateStr = _fmtWeddingDate(request);
    final vendorId = request['vendor_id'] as String?;
    final weddingId = request['wedding_id'] as String? ?? '';
    final initials = couple
        .split(RegExp(r'[&\s]+'))
        .where((p) => p.trim().isNotEmpty)
        .take(2)
        .map((p) => p.trim()[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == 'pending' ? _P.amber.withOpacity(0.5) : _P.line,
          width: status == 'pending' ? 2 : 1,
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
          // En-tête : couple + statut
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_P.rose.withOpacity(0.85), _P.roseLight],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    initials.isEmpty ? '?' : initials,
                    style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      couple,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _P.ink),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 12, color: _P.inkSoft),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _P.inkSoft,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.place_rounded,
                            size: 12, color: _P.inkSoft),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            venue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _P.inkSoft,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_reqIcon(status), size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(
                      _reqLabel(status),
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Ligne catégorie + code + prix
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _P.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _catLabel(catKey),
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: _P.purple),
                ),
              ),
              if (code.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _P.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    code,
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _P.blue),
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _P.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  price != null && price > 0
                      ? '$price $currency'
                      : 'Prix à négocier',
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: price != null && price > 0
                          ? _P.green
                          : _P.inkSoft),
                ),
              ),
            ],
          ),

          // Message du staff
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _P.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _P.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message du couple',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _P.inkSoft),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: GoogleFonts.inter(
                        fontSize: 12.5, color: _P.ink, height: 1.45),
                  ),
                ],
              ),
            ),
          ],

          // Contact du staff
          if (contactName.isNotEmpty || contactPhone.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 14, color: _P.inkSoft),
                const SizedBox(width: 6),
                Text(
                  [
                    if (contactName.isNotEmpty) contactName,
                    if (contactPhone.isNotEmpty) contactPhone
                  ].join(' · '),
                  style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: _P.inkSoft,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],

          // Réponse déjà donnée (historique)
          if (response.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Votre réponse',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    response,
                    style: GoogleFonts.inter(
                        fontSize: 12.5, color: _P.ink, height: 1.45),
                  ),
                ],
              ),
            ),
          ],

          // Actions (uniquement si en attente)
          if (status == 'pending') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.check_circle_rounded,
                    label: 'Accepter',
                    color: _P.green,
                    onTap: () => _approveDialog(context, ref),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.cancel_rounded,
                    label: 'Refuser',
                    color: _P.red,
                    isOutlined: true,
                    onTap: () => _rejectDialog(context, ref),
                  ),
                ),
              ],
            ),
          ],

          // ✅ NOUVEAU : Bouton "Gérer la prestation" pour les demandes approuvées
          if (status == 'approved' && vendorId != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: _ActionButton(
                icon: Icons.settings_rounded,
                label: 'Gérer la prestation',
                color: _P.blue,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProviderServiceManagementPage(
                        vendorId: vendorId,
                        weddingId: weddingId,
                        provider: provider,
                        couple: couple,
                        managementType: _managementTypeFor(catKey),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── ACCEPTER : crée le dossier vendor + passe la demande en approved ──
  Future<void> _approveDialog(BuildContext context, WidgetRef ref) async {
    final prov =
        (request['provider'] as Map?)?.cast<String, dynamic>() ?? {};
    final priceCtrl = TextEditingController(
      text: (request['proposed_price'] as num?)?.toStringAsFixed(0) ?? '',
    );
    final respCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool busy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _P.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.check_circle_rounded,
                    color: _P.green, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Accepter la demande',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _P.ink),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Le dossier sera créé côté mariage et le suivi des étapes s\'ouvrira pour le couple.',
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: _P.inkSoft,
                        height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _sheetDec(
                      'Prix confirmé (optionnel)',
                      Icons.payments_rounded,
                      hint: 'Ex: 350000',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: respCtrl,
                    maxLines: 4,
                    decoration: _sheetDec(
                      'Vos conditions / message',
                      Icons.chat_bubble_outline_rounded,
                      hint:
                          'Ex: Disponible à cette date, acompte 40%, inclut montage...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: Text(
                'Annuler',
                style: GoogleFonts.inter(
                    color: _P.inkSoft, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setSt(() => busy = true);
                      HapticFeedback.mediumImpact();
                      try {
                        final c = Supabase.instance.client;
                        final now = DateTime.now().toIso8601String();
                        final weddingId = request['wedding_id'] as String;
                        final confirmedPrice = double.tryParse(
                            priceCtrl.text.replaceAll(RegExp(r'\D'), ''));
                        final resp = respCtrl.text.trim();
                        final staffMsg =
                            (request['message'] as String? ?? '').trim();
                        final vendorName =
                            (prov['business_name'] as String? ?? '').trim();

                        // 1) Créer le dossier prestataire lié au mariage
                        final vendorData = <String, dynamic>{
                          'wedding_id': weddingId,
                          'name': vendorName.isEmpty ? 'Prestataire THIX' : vendorName,
                          'category': _mapVendorCategory(prov['category'] as String?),
                          'contact_name': vendorName.isEmpty ? 'Prestataire THIX' : vendorName,
                          'phone': prov['phone'] as String?,
                          'email': prov['email'] as String?,
                          'price': confirmedPrice,
                          'status': 'contacted',
                          'is_booked': false,
                          'notes': [
                            if (staffMsg.isNotEmpty)
                              'Demande du couple : $staffMsg',
                            if (resp.isNotEmpty)
                              'Réponse prestataire : $resp',
                          ].join('\n'),
                        };

                        final vendorRes = await c
                            .from('thix_weeding_vendors')
                            .insert(vendorData)
                            .select()
                            .single();
                        final vendorId = vendorRes['id'] as String;

                        // 2) Valider la demande
                        await c
                            .from('thix_weeding_vendor_requests')
                            .update({
                              'status': 'approved',
                              'stage': 'contacted',
                              'vendor_id': vendorId,
                              'provider_response':
                                  resp.isEmpty ? null : resp,
                              'proposed_price':
                                  confirmedPrice ?? request['proposed_price'],
                              'responded_at': now,
                              'updated_at': now,
                            })
                            .eq('id', request['id'] as String);

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ref.invalidate(
                            providerIncomingRequestsProvider(providerId));

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                              'Demande acceptée ✓ Dossier créé',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700),
                            ),
                            backgroundColor: _P.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ));

                          // ✅ Redirection automatique vers l'espace de gestion
                          final catKey = prov['category'] as String?;
                          final couple = _coupleNames(request);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProviderServiceManagementPage(
                                vendorId: vendorId,
                                weddingId: weddingId,
                                provider: provider,
                                couple: couple,
                                managementType: _managementTypeFor(catKey),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setSt(() => busy = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Erreur: $e'),
                            backgroundColor: _P.red,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      }
                    },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(
                'Confirmer l\'acceptation',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
    priceCtrl.dispose();
    respCtrl.dispose();
  }

  // ── REFUSER : motif obligatoire ──
  Future<void> _rejectDialog(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool busy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _P.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.cancel_rounded,
                    color: _P.red, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Refuser la demande',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _P.ink),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: reasonCtrl,
              maxLines: 3,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Indiquez un motif (requis)'
                  : null,
              decoration: _sheetDec('Motif du refus',
                  Icons.info_outline_rounded,
                  hint:
                      'Ex: Date déjà réservée, hors zone géographique...'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: Text(
                'Annuler',
                style: GoogleFonts.inter(
                    color: _P.inkSoft, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setSt(() => busy = true);
                      HapticFeedback.mediumImpact();
                      try {
                        final now = DateTime.now().toIso8601String();
                        await Supabase.instance.client
                            .from('thix_weeding_vendor_requests')
                            .update({
                              'status': 'rejected',
                              'provider_response': reasonCtrl.text.trim(),
                              'responded_at': now,
                              'updated_at': now,
                            })
                            .eq('id', request['id'] as String);

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ref.invalidate(
                            providerIncomingRequestsProvider(providerId));

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                              'Demande refusée — le couple en sera informé',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700),
                            ),
                            backgroundColor: _P.amber,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ));
                        }
                      } catch (e) {
                        setSt(() => busy = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Erreur: $e'),
                            backgroundColor: _P.red,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      }
                    },
              icon: const Icon(Icons.block_rounded, size: 18),
              label: Text(
                'Refuser',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
    reasonCtrl.dispose();
  }

  InputDecoration _sheetDec(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
        hintStyle: GoogleFonts.inter(
            fontSize: 12, color: _P.inkSoft.withOpacity(0.6)),
        prefixIcon: Icon(icon, size: 18, color: _P.rose),
        filled: true,
        fillColor: _P.bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// ✅ NOUVEAU : PAGE DE GESTION POST-APPROBATION
// Redirige vers la bonne page selon le type de prestation
// ═══════════════════════════════════════════════════════════════════════════
class ProviderServiceManagementPage extends StatelessWidget {
  final String vendorId;
  final String weddingId;
  final ThixProviderModel provider;
  final String couple;
  final ServiceManagementType managementType;

  const ProviderServiceManagementPage({
    super.key,
    required this.vendorId,
    required this.weddingId,
    required this.provider,
    required this.couple,
    required this.managementType,
  });

  @override
  Widget build(BuildContext context) {
    // Router vers la bonne page selon le type de service
    switch (managementType) {
      case ServiceManagementType.menu:
        return ProviderMenuManagementPage(
          vendorId: vendorId,
          weddingId: weddingId,
          provider: provider,
          couple: couple,
        );
      case ServiceManagementType.gallery:
        return _GenericServicePage(
          vendorId: vendorId,
          weddingId: weddingId,
          provider: provider,
          couple: couple,
          title: 'Galerie & Médias',
          icon: Icons.photo_library_rounded,
          color: _P.blue,
          sections: const ['Photos', 'Vidéos', 'Albums'],
        );
      case ServiceManagementType.timeline:
        return _GenericServicePage(
          vendorId: vendorId,
          weddingId: weddingId,
          provider: provider,
          couple: couple,
          title: 'Programme & Timeline',
          icon: Icons.schedule_rounded,
          color: _P.purple,
          sections: const ['Préparatifs', 'Cérémonie', 'Soirée'],
        );
      case ServiceManagementType.generic:
        return _GenericServicePage(
          vendorId: vendorId,
          weddingId: weddingId,
          provider: provider,
          couple: couple,
          title: 'Gestion de la prestation',
          icon: Icons.settings_rounded,
          color: _P.rose,
          sections: const ['Détails', 'Documents', 'Paiements'],
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ✅ PAGE GÉNÉRIQUE (photo/vidéo/MC/DJ/salle...)
// ═══════════════════════════════════════════════════════════════════════════
class _GenericServicePage extends StatelessWidget {
  final String vendorId;
  final String weddingId;
  final ThixProviderModel provider;
  final String couple;
  final String title;
  final IconData icon;
  final Color color;
  final List<String> sections;

  const _GenericServicePage({
    required this.vendorId,
    required this.weddingId,
    required this.provider,
    required this.couple,
    required this.title,
    required this.icon,
    required this.color,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec couple
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withOpacity(0.1), color.withOpacity(0.05)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prestation pour',
                          style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
                        ),
                        Text(
                          couple,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _P.ink,
                          ),
                        ),
                        Text(
                          provider.businessName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _P.inkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sections
            ...sections.map((section) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GenericSectionCard(
                title: section,
                icon: icon,
                color: color,
                itemCount: 0, // À remplir dynamiquement
              ),
            )),

            const SizedBox(height: 20),

            // Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _P.blueLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _P.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: _P.blue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Les éléments validés ici pourront être rendus publics pour les invités par le staff du mariage.',
                      style: GoogleFonts.inter(fontSize: 12, color: _P.blue, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenericSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int itemCount;

  const _GenericSectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _P.ink)),
                Text(
                  '$itemCount élément${itemCount > 1 ? 's' : ''}',
                  style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: _P.blue),
            onPressed: () {
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Ajouter à $title (à implémenter)'),
                backgroundColor: _P.blue,
                behavior: SnackBarBehavior.floating,
              ));
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ✅ PAGE GESTION MENU (TRAITEURS / PÂTISSIERS)
// ═══════════════════════════════════════════════════════════════════════════
class ProviderMenuManagementPage extends ConsumerStatefulWidget {
  final String vendorId;
  final String weddingId;
  final ThixProviderModel provider;
  final String couple;

  const ProviderMenuManagementPage({
    super.key,
    required this.vendorId,
    required this.weddingId,
    required this.provider,
    required this.couple,
  });

  @override
  ConsumerState<ProviderMenuManagementPage> createState() =>
      _ProviderMenuManagementPageState();
}

class _ProviderMenuManagementPageState
    extends ConsumerState<ProviderMenuManagementPage> {
  Future<void> _addMenuItem() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Ajouter un plat',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom du plat *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Prix (optionnel)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _P.green, foregroundColor: Colors.white),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await Supabase.instance.client.from('thix_weeding_menu_items').insert({
          'vendor_id': widget.vendorId,
          'wedding_id': widget.weddingId,
          'name': nameCtrl.text.trim(),
          'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          'price': double.tryParse(priceCtrl.text) ?? 0,
          'is_validated': false,
          'is_public': false,
          'position': DateTime.now().millisecondsSinceEpoch,
        });
        ref.invalidate(vendorMenuItemsProvider(widget.vendorId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Plat ajouté ✓',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            backgroundColor: _P.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: _P.red),
          );
        }
      }
    }
    nameCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
  }

  Future<void> _toggleValidation(String itemId, bool current) async {
    try {
      await Supabase.instance.client
          .from('thix_weeding_menu_items')
          .update({'is_validated': !current})
          .eq('id', itemId);
      ref.invalidate(vendorMenuItemsProvider(widget.vendorId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(!current ? 'Plat validé ✓' : 'Validation retirée'),
          backgroundColor: !current ? _P.green : _P.amber,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _P.red),
        );
      }
    }
  }

  Future<void> _togglePublic(String itemId, bool current) async {
    try {
      await Supabase.instance.client
          .from('thix_weeding_menu_items')
          .update({'is_public': !current})
          .eq('id', itemId);
      ref.invalidate(vendorMenuItemsProvider(widget.vendorId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(!current
              ? 'Rendu public pour les invités ✓'
              : 'Retiré de la vue invités'),
          backgroundColor: !current ? _P.blue : _P.inkSoft,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _P.red),
        );
      }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce plat ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _P.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client
          .from('thix_weeding_menu_items')
          .delete()
          .eq('id', itemId);
      ref.invalidate(vendorMenuItemsProvider(widget.vendorId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _P.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(vendorMenuItemsProvider(widget.vendorId));
    final votesAsync = ref.watch(menuItemVotesProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.amber,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Menu & Plats',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(vendorMenuItemsProvider(widget.vendorId));
              ref.invalidate(menuItemVotesProvider(widget.weddingId));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _P.amber,
        foregroundColor: Colors.white,
        onPressed: _addMenuItem,
        icon: const Icon(Icons.add_rounded),
        label: Text('Ajouter un plat',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        color: _P.amber,
        onRefresh: () async {
          ref.invalidate(vendorMenuItemsProvider(widget.vendorId));
          ref.invalidate(menuItemVotesProvider(widget.weddingId));
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header couple
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_P.amber.withOpacity(0.15), _P.gold.withOpacity(0.1)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _P.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _P.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.restaurant_menu_rounded,
                          color: _P.amber, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Menu pour',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: _P.inkSoft)),
                          Text(widget.couple,
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _P.ink)),
                          Text(widget.provider.businessName,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _P.inkSoft,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Stats
            itemsAsync.when(
              data: (items) {
                final validated = items.where((i) => i['is_validated'] == true).length;
                final public = items.where((i) => i['is_public'] == true).length;
                final votes = votesAsync.valueOrNull ?? {};
                final totalVotes = votes.values.fold(0, (s, v) => s + v);

                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _MenuStatCard(
                          label: 'Total',
                          value: '${items.length}',
                          color: _P.blue,
                          icon: Icons.restaurant_rounded,
                        ),
                        const SizedBox(width: 8),
                        _MenuStatCard(
                          label: 'Validés',
                          value: '$validated',
                          color: _P.green,
                          icon: Icons.check_circle_rounded,
                        ),
                        const SizedBox(width: 8),
                        _MenuStatCard(
                          label: 'Publics',
                          value: '$public',
                          color: _P.purple,
                          icon: Icons.visibility_rounded,
                        ),
                        const SizedBox(width: 8),
                        _MenuStatCard(
                          label: 'Votes',
                          value: '$totalVotes',
                          color: _P.amber,
                          icon: Icons.favorite_rounded,
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Liste des plats
            itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyState(
                      icon: Icons.restaurant_menu_rounded,
                      title: 'Aucun plat',
                      subtitle: 'Ajoutez votre premier plat avec le bouton +',
                    ),
                  );
                }

                final votes = votesAsync.valueOrNull ?? {};

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];
                        final voteCount = votes[item['id'] as String] ?? 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MenuItemCard(
                            item: item,
                            voteCount: voteCount,
                            onValidate: () => _toggleValidation(
                              item['id'] as String,
                              item['is_validated'] as bool? ?? false,
                            ),
                            onTogglePublic: () => _togglePublic(
                              item['id'] as String,
                              item['is_public'] as bool? ?? false,
                            ),
                            onDelete: () => _deleteItem(item['id'] as String),
                          ),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _P.amber)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: _ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(vendorMenuItemsProvider(widget.vendorId)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MenuStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _P.line),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w900, color: _P.ink)),
            Text(label,
                style: GoogleFonts.inter(fontSize: 9, color: _P.inkSoft)),
          ],
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int voteCount;
  final VoidCallback onValidate;
  final VoidCallback onTogglePublic;
  final VoidCallback onDelete;

  const _MenuItemCard({
    required this.item,
    required this.voteCount,
    required this.onValidate,
    required this.onTogglePublic,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isValidated = item['is_validated'] as bool? ?? false;
    final isPublic = item['is_public'] as bool? ?? false;
    final name = item['name'] as String? ?? 'Sans nom';
    final desc = item['description'] as String? ?? '';
    final price = (item['price'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isValidated ? _P.green.withOpacity(0.4) : _P.line,
          width: isValidated ? 2 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _P.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_rounded, color: _P.amber, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w800, color: _P.ink)),
                    if (desc.isNotEmpty)
                      Text(desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: _P.inkSoft, height: 1.4)),
                  ],
                ),
              ),
              if (price != null && price > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _P.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${price.toStringAsFixed(0)}\$',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w800, color: _P.green)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Badges
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (isValidated)
                _Badge(
                  icon: Icons.check_circle_rounded,
                  label: 'Validé',
                  color: _P.green,
                ),
              if (isPublic)
                _Badge(
                  icon: Icons.visibility_rounded,
                  label: 'Public',
                  color: _P.blue,
                ),
              if (voteCount > 0)
                _Badge(
                  icon: Icons.favorite_rounded,
                  label: '$voteCount vote${voteCount > 1 ? 's' : ''}',
                  color: _P.rose,
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: isValidated ? Icons.close_rounded : Icons.check_rounded,
                  label: isValidated ? 'Retirer validation' : 'Valider',
                  color: isValidated ? _P.amber : _P.green,
                  isOutlined: isValidated,
                  onTap: onValidate,
                ),
              ),
              const SizedBox(width: 8),
              _ContactButton(
                icon: isPublic ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: isPublic ? _P.blue : _P.inkSoft,
                onTap: onTogglePublic,
              ),
              const SizedBox(width: 8),
              _ContactButton(
                icon: Icons.delete_outline_rounded,
                color: _P.red,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
