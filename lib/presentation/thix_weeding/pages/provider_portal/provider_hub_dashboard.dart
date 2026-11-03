// lib/presentation/thix_weeding/pages/provider_portal/provider_hub_dashboard.dart
// ============================================================================
// THIX WEDDING — HUB PRESTATAIRE (PRODUCTION v6)
// ✅ Agrège TOUT : demandes, commandes, réservations, offres, menus, tâches,
//    suggestions, revenus + ÉDITION DU PROFIL inline.
// ✅ Error-resilient : chaque section gère son propre état (valueOrNull).
// ✅ Navigation : onglets du shell (onOpenTab) + Navigator.push vers les pages
//    existantes (commandes, menus, suggestions, demandes, détail commande).
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';
import 'provider_business_pages.dart'
    show providerIncomingRequestsProvider, ProviderRequestsPage;
import 'provider_offers_page.dart' show offerTypeIcon, offerTypeColor;
import 'orders/order_models.dart' show WeddingOrder, OrderStatus;
import 'orders/orders_provider.dart' show ordersProvider, orderStatsProvider;
import 'orders/order_detail_page.dart' show OrderDetailPage;
import 'orders/provider_orders_page.dart' show ProviderOrdersPage;
import 'traiteur/menu_models.dart' show WeddingMenu, MenuStatus;
import 'traiteur/traiteur_menu_provider.dart' show menuProvider;
import 'traiteur/traiteur_menu_page.dart' show TraiteurMenuPage;
import 'suggestions/dg_suggestions_page.dart' show DGSuggestionsPage;

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
  static const Color teal = Color(0xFF14B8A6);
}

// ═══════════════════════════════════════════════════════════════════════════
// HUB — remplace ProviderDashboardPage dans le shell
// onOpenTab : indices du shell (1=Offres, 2=Galerie, 3=Résa, 4=Tâches, 5=Profil)
// ═══════════════════════════════════════════════════════════════════════════
class ProviderHubDashboard extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  final ValueChanged<int>? onOpenTab;
  const ProviderHubDashboard({super.key, required this.provider, this.onOpenTab});

  @override
  ConsumerState<ProviderHubDashboard> createState() => _ProviderHubDashboardState();
}

class _ProviderHubDashboardState extends ConsumerState<ProviderHubDashboard> {
  ThixProviderModel get p => widget.provider;

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(providerReservationsProvider(
        ProviderReservationsParams(providerId: p.id)));
    final tasksAsync = ref.watch(
        providerTasksProvider(ProviderTasksParams(providerId: p.id)));
    final offersAsync = ref.watch(providerOffersProvider(p.id));
    final requestsAsync = ref.watch(providerIncomingRequestsProvider(p.id));
    final ordersAsync = ref.watch(ordersProvider(p.id));

    final reservations = reservationsAsync.valueOrNull ?? [];
    final tasks = tasksAsync.valueOrNull ?? [];
    final offers = offersAsync.valueOrNull ?? [];
    final requests = requestsAsync.valueOrNull ?? [];
    final orders = ordersAsync.valueOrNull ?? [];

    // ── Calculs globaux ──
    final now = DateTime.now();
    final pendingRequests =
        requests.where((r) => (r['status'] ?? 'pending') == 'pending').toList();
    final pendingOrders =
        orders.where((o) => o.status == OrderStatus.pending).toList();
    final pendingRes =
        reservations.where((r) => r.status == ReservationStatus.pending).toList();
    final openTasks = tasks
        .where((t) =>
            t.status == TaskStatus.assigned || t.status == TaskStatus.inProgress)
        .toList();
    final urgentOrders = orders.where((o) => o.isUrgent).toList();
    final urgentRes = reservations.where((r) =>
        r.status != ReservationStatus.cancelled &&
        r.status != ReservationStatus.completed &&
        r.eventDate.difference(now).inDays <= 3 &&
        r.eventDate.difference(now).inDays >= 0).toList();

    final todayCount = reservations
            .where((r) =>
                r.eventDate.year == now.year &&
                r.eventDate.month == now.month &&
                r.eventDate.day == now.day)
            .length +
        orders
            .where((o) =>
                o.eventDate.year == now.year &&
                o.eventDate.month == now.month &&
                o.eventDate.day == now.day)
            .length;

    final revenue = reservations
            .where((r) => r.status != ReservationStatus.cancelled)
            .fold<double>(0, (s, r) => s + (r.totalPrice ?? 0)) +
        orders
            .where((o) => o.status != OrderStatus.cancelled)
            .fold<double>(0, (s, o) => s + o.totalAmount);

    final traiteurOrders = orders.where((o) => o.isTraiteur).toList();
    final isTraiteur = p.category == ProviderCategory.traiteur ||
        p.category == ProviderCategory.patissier;

    return RefreshIndicator(
      color: _P.rose,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        ref.invalidate(providerReservationsProvider(
            ProviderReservationsParams(providerId: p.id)));
        ref.invalidate(providerTasksProvider(
            ProviderTasksParams(providerId: p.id)));
        ref.invalidate(providerOffersProvider(p.id));
        ref.invalidate(providerIncomingRequestsProvider(p.id));
        ref.invalidate(ordersProvider(p.id));
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
                  // 1️⃣ KPIs
                  _KpiRow(
                    today: todayCount,
                    pending: pendingOrders.length +
                        pendingRes.length +
                        pendingRequests.length,
                    urgent: urgentOrders.length + urgentRes.length,
                    revenue: revenue,
                  ),
                  const SizedBox(height: 16),
                  // 2️⃣ Actions requises
                  _ActionRequired(
                    requests: pendingRequests.length,
                    orders: pendingOrders.length,
                    reservations: pendingRes.length,
                    tasks: openTasks.length,
                    onRequests: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProviderRequestsPage(provider: p))),
                    onOrders: () => _openOrders(),
                    onReservations: () => widget.onOpenTab?.call(3),
                    onTasks: () => widget.onOpenTab?.call(4),
                  ),
                  const SizedBox(height: 24),
                  // 3️⃣ Pipeline commandes
                  _OrdersSection(
                    provider: p,
                    ordersAsync: ordersAsync,
                    onOpenAll: _openOrders,
                    onQuickStatus: (o, s) => _quickOrderStatus(o, s),
                    onOpenMenu: (o) => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TraiteurMenuPage(orderId: o.id))),
                    onOpenSuggestions: (o) => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => DGSuggestionsPage(
                                  orderId: o.id,
                                  userId: Supabase.instance.client.auth
                                          .currentUser?.id ??
                                      '',
                                  userName: p.businessName,
                                  isStaff: true,
                                ))),
                    onOpenDetail: (o) => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) =>
                            OrderDetailPage(order: o, providerId: p.id))),
                  ),
                  const SizedBox(height: 24),
                  // 4️⃣ Réservations
                  _ReservationsSection(
                    reservations: reservations,
                    onOpenAll: () => widget.onOpenTab?.call(3),
                    onConfirm: (r) async {
                      await ref.read(updateReservationStatusProvider)(
                          r.id, ReservationStatus.confirmed, p.id);
                    },
                  ),
                  const SizedBox(height: 24),
                  // 5️⃣ Offres
                  _OffersSection(
                    offers: offers,
                    onPublish: () =>
                        context.push('/thix-weeding/provider/offers/new'),
                    onOpenAll: () => widget.onOpenTab?.call(1),
                  ),
                  const SizedBox(height: 24),
                  // 6️⃣ Menus traiteur
                  if (isTraiteur || traiteurOrders.isNotEmpty) ...[
                    _MenusSection(
                      provider: p,
                      traiteurOrders: traiteurOrders,
                      onOpenMenu: (o) => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => TraiteurMenuPage(orderId: o.id))),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // 7️⃣ Tâches
                  _TasksSection(
                    tasks: tasks,
                    onOpenAll: () => widget.onOpenTab?.call(4),
                    onToggle: (t) async {
                      final next = t.status == TaskStatus.completed
                          ? TaskStatus.inProgress
                          : TaskStatus.completed;
                      await ref.read(updateTaskStatusProvider)(
                          t.id, next, p.id);
                    },
                  ),
                  const SizedBox(height: 24),
                  // 8️⃣ Accès rapides
                  _QuickAccess(
                    provider: p,
                    onEditProfile: () => _openEditProfile(),
                    onOrders: _openOrders,
                    onRequests: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ProviderRequestsPage(provider: p))),
                    onGallery: () => widget.onOpenTab?.call(2),
                    onActivities: () =>
                        context.push('/thix-weeding/provider/activities'),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER : profil + édition + disponibilité ──
  Widget _buildHeader() {
    final verified =
        p.verificationStatus == ProviderVerificationStatus.verified;
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
                      Stack(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: CircleAvatar(
                              backgroundColor: Colors.white,
                              child: Text(
                                p.businessName.isNotEmpty
                                    ? p.businessName[0].toUpperCase()
                                    : 'P',
                                style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: _P.rose),
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
                                    color: _P.green, shape: BoxShape.circle),
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
                                Icon(Icons.location_on_rounded,
                                    size: 12, color: Colors.white70),
                                const SizedBox(width: 2),
                                Text(p.city ?? 'RDC',
                                    style: GoogleFonts.inter(
                                        fontSize: 11, color: Colors.white70,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // ✅ BOUTON ÉDITER LE PROFIL
                      GestureDetector(
                        onTap: _openEditProfile,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // ✅ Disponibilité toggle
                  Row(
                    children: [
                      Icon(
                        p.isAvailable
                            ? Icons.toggle_on_rounded
                            : Icons.toggle_off_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        p.isAvailable
                            ? 'Visible sur le catalogue'
                            : 'Invisible (pause)',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: p.isAvailable,
                        activeColor: _P.green,
                        onChanged: (v) async {
                          HapticFeedback.selectionClick();
                          await ref.read(updateProviderProvider)(
                            p.id,
                            ownerId: p.ownerId,
                            isAvailable: v,
                          );
                        },
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: p.uniqueCode));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Code ${p.uniqueCode} copié'),
                            backgroundColor: _P.green,
                            behavior: SnackBarBehavior.floating,
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.qr_code_2,
                                  color: _P.rose, size: 14),
                              const SizedBox(width: 5),
                              Text(p.uniqueCode,
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: _P.ink)),
                            ],
                          ),
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

  void _openOrders() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProviderOrdersPage(
              providerId: p.id,
              providerName: p.businessName,
            )));
  }

  Future<void> _quickOrderStatus(WeddingOrder o, OrderStatus s) async {
    HapticFeedback.mediumImpact();
    try {
      await ref
          .read(ordersProvider(p.id).notifier)
          .updateOrderStatus(
            orderId: o.id,
            newStatus: s,
            performedBy: p.businessName,
            performedByRole: 'provider',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Commande → ${s.name}'),
          backgroundColor: _P.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: _P.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ✅ ÉDITION DU PROFIL (bottom sheet)
  // ═════════════════════════════════════════════════════════════════════════
  Future<void> _openEditProfile() async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(provider: p),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHEET ÉDITION PROFIL → updateActivityProvider
// ═══════════════════════════════════════════════════════════════════════════
class _EditProfileSheet extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  const _EditProfileSheet({required this.provider});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _desc;
  late ProviderCategory _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _name = TextEditingController(text: p.businessName);
    _city = TextEditingController(text: p.city ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    _email = TextEditingController(text: p.email ?? '');
    _desc = TextEditingController(text: p.description ?? '');
    _category = p.category;
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _phone.dispose();
    _email.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(updateActivityProvider)(
        widget.provider.id,
        ownerId: widget.provider.ownerId,
        businessName: _name.text.trim(),
        category: _category.name,
        city: _city.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        description: _desc.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Profil mis à jour ✓',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: _P.line, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, color: _P.rose, size: 20),
                const SizedBox(width: 10),
                Text('Modifier mon profil',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _P.ink)),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                _field('Nom commercial *', _name, Icons.storefront_rounded),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProviderCategory>(
                  value: _category,
                  decoration: _dec('Métier (catégorie)', Icons.work_rounded),
                  items: ProviderCategory.values
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c.displayName)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 12),
                _field('Ville', _city, Icons.location_on_rounded),
                const SizedBox(height: 12),
                _field('Téléphone', _phone, Icons.phone_rounded,
                    keyboard: TextInputType.phone),
                const SizedBox(height: 12),
                _field('Email', _email, Icons.email_rounded,
                    keyboard: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field('Description', _desc, Icons.edit_note_rounded,
                    maxLines: 3),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _P.rose,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Enregistrer',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/thix-weeding/provider/activities');
                  },
                  child: Text('Gérer mes activités (multi-métiers)',
                      style: GoogleFonts.inter(
                          color: _P.inkSoft, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
          {TextInputType? keyboard, int maxLines = 1}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: _dec(label, icon),
      );

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
        prefixIcon: Icon(icon, size: 18, color: _P.rose),
        filled: true,
        fillColor: _P.bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// 1️⃣ KPIs
// ═══════════════════════════════════════════════════════════════════════════
class _KpiRow extends StatelessWidget {
  final int today, pending, urgent;
  final double revenue;
  const _KpiRow({
    required this.today,
    required this.pending,
    required this.urgent,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Kpi(icon: Icons.today_rounded, value: '$today', label: "Aujourd'hui", color: _P.blue),
        const SizedBox(width: 10),
        _Kpi(icon: Icons.hourglass_empty_rounded, value: '$pending', label: 'À traiter', color: pending > 0 ? _P.amber : _P.green),
        const SizedBox(width: 10),
        _Kpi(icon: Icons.warning_amber_rounded, value: '$urgent', label: 'Urgents', color: urgent > 0 ? _P.red : _P.green),
        const SizedBox(width: 10),
        _Kpi(icon: Icons.attach_money_rounded, value: '${revenue.toStringAsFixed(0)}\$', label: 'Revenus', color: _P.green),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _Kpi({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: GoogleFonts.inter(fontSize: 9.5, color: _P.inkSoft, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2️⃣ ACTIONS REQUISES
// ═══════════════════════════════════════════════════════════════════════════
class _ActionRequired extends StatelessWidget {
  final int requests, orders, reservations, tasks;
  final VoidCallback onRequests, onOrders, onReservations, onTasks;
  const _ActionRequired({
    required this.requests,
    required this.orders,
    required this.reservations,
    required this.tasks,
    required this.onRequests,
    required this.onOrders,
    required this.onReservations,
    required this.onTasks,
  });

  @override
  Widget build(BuildContext context) {
    final total = requests + orders + reservations + tasks;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _P.green.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _P.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: _P.green, size: 22),
            const SizedBox(width: 12),
            Text('Tout est à jour 🎉',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _P.green)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _P.amber.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _P.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.bolt_rounded, color: _P.amber, size: 20),
              ),
              const SizedBox(width: 10),
              Text('Actions requises ($total)',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _P.ink)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (requests > 0) _chip(context, '💌 $requests demande(s)', _P.amber, onRequests),
              if (orders > 0) _chip(context, '🛒 $orders commande(s) à confirmer', _P.red, onOrders),
              if (reservations > 0) _chip(context, '📅 $reservations résa. à confirmer', _P.blue, onReservations),
              if (tasks > 0) _chip(context, '✅ $tasks tâche(s)', _P.purple, onTasks),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3️⃣ COMMANDES (pipeline + workflow)
// ═══════════════════════════════════════════════════════════════════════════
class _OrdersSection extends StatelessWidget {
  final ThixProviderModel provider;
  final AsyncValue<List<WeddingOrder>> ordersAsync;
  final VoidCallback onOpenAll;
  final Function(WeddingOrder, OrderStatus) onQuickStatus;
  final Function(WeddingOrder) onOpenMenu;
  final Function(WeddingOrder) onOpenSuggestions;
  final Function(WeddingOrder) onOpenDetail;
  const _OrdersSection({
    required this.provider,
    required this.ordersAsync,
    required this.onOpenAll,
    required this.onQuickStatus,
    required this.onOpenMenu,
    required this.onOpenSuggestions,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.shopping_bag_rounded,
      color: _P.blue,
      title: 'Mes commandes',
      onSeeAll: onOpenAll,
      child: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return _miniEmpty('Aucune commande pour le moment');
          }
          final active = orders
              .where((o) =>
                  o.status != OrderStatus.completed &&
                  o.status != OrderStatus.cancelled)
              .toList()
            ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
          final counts = <OrderStatus, int>{};
          for (final o in orders) {
            counts[o.status] = (counts[o.status] ?? 0) + 1;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pipeline chips
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: OrderStatus.values.map((s) {
                    final c = counts[s] ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (s.getStatusColor()).withOpacity(c > 0 ? 0.12 : 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: s.getStatusColor().withOpacity(c > 0 ? 0.4 : 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.name,
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: s.getStatusColor())),
                          const SizedBox(width: 5),
                          Text('$c',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: s.getStatusColor())),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              ...active.take(3).map((o) => _OrderTile(
                    order: o,
                    onQuickStatus: onQuickStatus,
                    onOpenMenu: onOpenMenu,
                    onOpenSuggestions: onOpenSuggestions,
                    onOpenDetail: onOpenDetail,
                  )),
              if (active.isEmpty) _miniEmpty('Aucune commande active'),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.blue)),
        ),
        error: (e, _) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _P.amber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: _P.amber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Module commandes indisponible (table wedding_orders absente ?).\n$e',
                  style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniEmpty(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(msg,
            style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, fontStyle: FontStyle.italic)),
      );
}

class _OrderTile extends StatelessWidget {
  final WeddingOrder order;
  final Function(WeddingOrder, OrderStatus) onQuickStatus;
  final Function(WeddingOrder) onOpenMenu;
  final Function(WeddingOrder) onOpenSuggestions;
  final Function(WeddingOrder) onOpenDetail;
  const _OrderTile({
    required this.order,
    required this.onQuickStatus,
    required this.onOpenMenu,
    required this.onOpenSuggestions,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final color = order.getStatusColor();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _P.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: order.isUrgent ? _P.red.withOpacity(0.5) : _P.line,
            width: order.isUrgent ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(order.getStatusIcon(), color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.clientName,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                    Text(
                        '${order.offerTitle} • ${DateFormat('dd MMM yyyy', 'fr_FR').format(order.eventDate)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft)),
                  ],
                ),
              ),
              if (order.isUrgent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: _P.red.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('J-${order.daysUntilEvent}',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: _P.red)),
                ),
              const SizedBox(width: 6),
              Text('${order.totalAmount.toStringAsFixed(0)}\$',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: _P.green)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (order.nextStatus != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onQuickStatus(order, order.nextStatus!),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: order.nextStatus!.getStatusColor(),
                      side: BorderSide(color: order.nextStatus!.getStatusColor()),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(order.nextActionLabel ?? 'Action',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
              if (order.nextStatus != null) const SizedBox(width: 6),
              if (order.isTraiteur)
                _iconBtn(Icons.restaurant_menu_rounded, _P.amber, () => onOpenMenu(order)),
              const SizedBox(width: 6),
              _iconBtn(Icons.music_note_rounded, _P.purple, () => onOpenSuggestions(order)),
              const SizedBox(width: 6),
              _iconBtn(Icons.open_in_new_rounded, _P.inkSoft, () => onOpenDetail(order)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 16),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// 4️⃣ RÉSERVATIONS
// ═══════════════════════════════════════════════════════════════════════════
class _ReservationsSection extends StatelessWidget {
  final List<ProviderReservationModel> reservations;
  final VoidCallback onOpenAll;
  final Function(ProviderReservationModel) onConfirm;
  const _ReservationsSection({required this.reservations, required this.onOpenAll, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final upcoming = reservations
        .where((r) =>
            r.status != ReservationStatus.cancelled &&
            r.eventDate.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    final pending =
        reservations.where((r) => r.status == ReservationStatus.pending).length;

    return _SectionCard(
      icon: Icons.event_rounded,
      color: _P.rose,
      title: 'Réservations${pending > 0 ? ' • $pending en attente' : ''}',
      onSeeAll: onOpenAll,
      child: upcoming.isEmpty
          ? Text('Aucun événement à venir',
              style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, fontStyle: FontStyle.italic))
          : Column(
              children: upcoming.take(3).map((r) {
                final days = r.eventDate.difference(DateTime.now()).inDays;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _P.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _P.line)),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: _P.rose.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${r.eventDate.day}',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: _P.rose)),
                            Text(DateFormat('MMM', 'fr_FR').format(r.eventDate),
                                style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: _P.rose)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.clientName,
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                            Text(
                                '${r.eventType ?? 'Événement'} • ${r.guestCount ?? 0} pers. • J-$days',
                                style: GoogleFonts.inter(fontSize: 10.5, color: _P.inkSoft)),
                          ],
                        ),
                      ),
                      if (r.status == ReservationStatus.pending)
                        GestureDetector(
                          onTap: () => onConfirm(r),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(color: _P.green, borderRadius: BorderRadius.circular(10)),
                            child: Text('Confirmer',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        )
                      else
                        Text('${(r.totalPrice ?? 0).toStringAsFixed(0)}\$',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: _P.green)),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5️⃣ OFFRES
// ═══════════════════════════════════════════════════════════════════════════
class _OffersSection extends StatelessWidget {
  final List<ProviderOfferModel> offers;
  final VoidCallback onPublish;
  final VoidCallback onOpenAll;
  const _OffersSection({required this.offers, required this.onPublish, required this.onOpenAll});

  @override
  Widget build(BuildContext context) {
    final active = offers.where((o) => o.isActive).length;
    return _SectionCard(
      icon: Icons.local_offer_rounded,
      color: _P.purple,
      title: 'Offres & services • $active/${offers.length} actives',
      onSeeAll: onOpenAll,
      child: Column(
        children: [
          Row(
            children: OfferType.values.map((t) {
              final c = offers.where((o) => o.type == t).length;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: offerTypeColor(t).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: offerTypeColor(t).withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      Icon(offerTypeIcon(t), color: offerTypeColor(t), size: 18),
                      const SizedBox(height: 4),
                      Text('$c',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: offerTypeColor(t))),
                      Text(t.displayName,
                          style: GoogleFonts.inter(fontSize: 8.5, color: _P.inkSoft, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPublish,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('Publier une offre',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _P.rose,
                side: const BorderSide(color: _P.rose),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 6️⃣ MENUS TRAITEUR (statut par commande)
// ═══════════════════════════════════════════════════════════════════════════
class _MenusSection extends StatelessWidget {
  final ThixProviderModel provider;
  final List<WeddingOrder> traiteurOrders;
  final Function(WeddingOrder) onOpenMenu;
  const _MenusSection({required this.provider, required this.traiteurOrders, required this.onOpenMenu});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.restaurant_menu_rounded,
      color: _P.amber,
      title: 'Menus traiteur',
      onSeeAll: traiteurOrders.isEmpty ? null : () => onOpenMenu(traiteurOrders.first),
      child: traiteurOrders.isEmpty
          ? Text('Acceptez une demande de mariage pour créer un menu',
              style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, fontStyle: FontStyle.italic))
          : Column(
              children: traiteurOrders.take(3).map((o) => _MenuStatusTile(order: o, onOpen: () => onOpenMenu(o))).toList(),
            ),
    );
  }
}

class _MenuStatusTile extends ConsumerWidget {
  final WeddingOrder order;
  final VoidCallback onOpen;
  const _MenuStatusTile({required this.order, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuProvider(order.id));
    final menu = menuAsync.valueOrNull;
    final status = menu?.status;
    final color = status == null
        ? _P.inkSoft
        : status == MenuStatus.draft
            ? _P.inkSoft
            : status == MenuStatus.submitted
                ? _P.amber
                : status == MenuStatus.validated
                    ? _P.blue
                    : status == MenuStatus.public
                        ? _P.green
                        : _P.purple;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _P.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _P.line)),
        child: Row(
          children: [
            Icon(Icons.restaurant_rounded, color: _P.amber, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.clientName,
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: _P.ink)),
                  Text(menu?.title ?? 'Aucun menu créé',
                      style: GoogleFonts.inter(fontSize: 10.5, color: _P.inkSoft)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(
                menu == null ? 'À créer' : menu.statusDisplayName,
                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: color),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: _P.inkSoft, size: 18),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 7️⃣ TÂCHES
// ═══════════════════════════════════════════════════════════════════════════
class _TasksSection extends StatelessWidget {
  final List<ProviderTaskModel> tasks;
  final VoidCallback onOpenAll;
  final Function(ProviderTaskModel) onToggle;
  const _TasksSection({required this.tasks, required this.onOpenAll, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final open = tasks
        .where((t) => t.status == TaskStatus.assigned || t.status == TaskStatus.inProgress)
        .toList()
      ..sort((a, b) => a.dueDateTime.compareTo(b.dueDateTime));
    return _SectionCard(
      icon: Icons.task_alt_rounded,
      color: _P.teal,
      title: 'Tâches • ${open.length} ouvertes',
      onSeeAll: onOpenAll,
      child: open.isEmpty
          ? Text('Aucune tâche ouverte',
              style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, fontStyle: FontStyle.italic))
          : Column(
              children: open.take(3).map((t) {
                final late = t.dueDateTime.isBefore(DateTime.now());
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _P.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: late ? _P.red.withOpacity(0.4) : _P.line)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title,
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: _P.ink)),
                            Text(
                                DateFormat('dd MMM • HH:mm', 'fr_FR').format(t.dueDateTime) +
                                    (late ? '  (en retard)' : ''),
                                style: GoogleFonts.inter(fontSize: 10.5, color: late ? _P.red : _P.inkSoft)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onToggle(t),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: _P.green.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.check_rounded, color: _P.green, size: 16),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 8️⃣ ACCÈS RAPIDES
// ═══════════════════════════════════════════════════════════════════════════
class _QuickAccess extends StatelessWidget {
  final ThixProviderModel provider;
  final VoidCallback onEditProfile, onOrders, onRequests, onGallery, onActivities;
  const _QuickAccess({
    required this.provider,
    required this.onEditProfile,
    required this.onOrders,
    required this.onRequests,
    required this.onGallery,
    required this.onActivities,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accès rapides',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: [
            _tile(Icons.shopping_bag_outlined, 'Commandes', _P.blue, onOrders),
            _tile(Icons.mark_email_unread_rounded, 'Demandes', _P.amber, onRequests),
            _tile(Icons.photo_library_outlined, 'Galerie', _P.rose, onGallery),
            _tile(Icons.edit_rounded, 'Mon profil', _P.purple, onEditProfile),
            _tile(Icons.workspaces_rounded, 'Activités', _P.teal, onActivities),
            _tile(Icons.visibility_rounded, 'Ma fiche', _P.green,
                () => GoRouter.of(context).push(
                    '/thix-weeding/provider/detail/${provider.id}')),
          ],
        ),
      ],
    );
  }

  Widget _tile(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _P.ink)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE DE SECTION GÉNÉRIQUE
// ═══════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback? onSeeAll;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _P.ink)),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: Text('Tout voir',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
