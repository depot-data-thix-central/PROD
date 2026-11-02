// lib/presentation/thix_weeding/pages/staff/prestataires/vendors_list_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — VENDORS LIST (PRODUCTION v3)
// ✅ 2 ONGLETS : Prestataires (liste locale) + Demandes (catalogue THIX)
// ✅ Badge "THIX" sur les pros issus d'une demande approuvée
// ✅ Onglet Demandes : statut live (pending/approved/rejected/cancelled),
//    motif de refus, actions Retirer / Renvoyer / Voir la fiche prestataire
// ✅ Compteur de demandes en attente sur l'onglet
// Design royal + 15 Catégories + Stats live + Recherche debounce + Typed
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

// ============================================================================
// ✅ NOUVEAU : PROVIDER DES DEMANDES DU MARIAGE (jointure prestataire THIX)
// ============================================================================
final vendorRequestsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, weddingId) async {
  try {
    final res = await Supabase.instance.client
        .from('thix_weeding_vendor_requests')
        .select(
            '*, provider:thix_weeding_providers(business_name, unique_code, category, city, verification_status)')
        .eq('wedding_id', weddingId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  } catch (_) {
    return [];
  }
});

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
  static const LinearGradient greenG = LinearGradient(
    colors: [green, greenSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient roseG = LinearGradient(
    colors: [rose, Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration card({double r = 14}) => BoxDecoration(
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
// 15 CATÉGORIES DYNAMIQUES
// ============================================================================
const List<_CatDef> _CATEGORIES = [
  _CatDef('organisateur', 'Organisateur', Icons.celebration, Color(0xFF6B46C1)),
  _CatDef('decorateur', 'Décorateur', Icons.auto_awesome, Color(0xFFFF6B9D)),
  _CatDef('photographe', 'Photographe', Icons.camera_alt_outlined, Color(0xFFE31C4E)),
  _CatDef('videaste', 'Vidéaste', Icons.videocam_outlined, Color(0xFFDB2777)),
  _CatDef('traiteur', 'Traiteur', Icons.restaurant, Color(0xFFD97706)),
  _CatDef('patissier', 'Pâtissier', Icons.cake_outlined, Color(0xFFBE185D)),
  _CatDef('maquilleur', 'Maquilleur', Icons.auto_fix_high, Color(0xFFEC4899)),
  _CatDef('coiffeur', 'Coiffeur', Icons.content_cut, Color(0xFF8B5CF6)),
  _CatDef('couturier', 'Couturier', Icons.checkroom, Color(0xFF0891B2)),
  _CatDef('dj', 'DJ / Musique', Icons.music_note, Color(0xFF7C3AED)),
  _CatDef('vehicule', 'Véhicules', Icons.directions_car, Color(0xFF4338CA)),
  _CatDef('salle', 'Salle', Icons.place_outlined, Color(0xFF0B3B8F)),
  _CatDef('fleuriste', 'Fleuriste', Icons.local_florist, Color(0xFF059669)),
  _CatDef('securite', 'Sécurité', Icons.shield_outlined, Color(0xFF64748B)),
  _CatDef('materiel', 'Matériel', Icons.inventory_2_outlined, Color(0xFF78716C)),
];

class _CatDef {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _CatDef(this.key, this.label, this.icon, this.color);
}

_CatDef _findCat(String? raw) {
  if (raw == null || raw.isEmpty) return _CatDef('autre', 'Autre', Icons.store_outlined, _R.text2);
  final lower = raw.toLowerCase();
  for (final c in _CATEGORIES) {
    if (c.key == lower || c.label.toLowerCase() == lower) return c;
  }
  return _CatDef(raw, raw, Icons.store_outlined, _R.blue);
}

// ============================================================================
// STATUTS PRESTATAIRE (liste locale)
// ============================================================================
const Map<String, _StatusDef> _STATUS_MAP = {
  'requested': _StatusDef('Demande envoyée', Icons.send_outlined, Color(0xFF6B7280)),
  'pending': _StatusDef('En attente', Icons.hourglass_empty, Color(0xFF6B7280)),
  'contacted': _StatusDef('Contacté', Icons.phone_callback, Color(0xFF0B3B8F)),
  'devis_envoye': _StatusDef('Devis envoyé', Icons.description_outlined, Color(0xFF6B46C1)),
  'booked': _StatusDef('Réservé', Icons.event_available, Color(0xFF059669)),
  'paid': _StatusDef('Payé', Icons.payments, Color(0xFFD4AF37)),
  'completed': _StatusDef('Terminé', Icons.task_alt, Color(0xFF059669)),
  'cancelled': _StatusDef('Annulé', Icons.cancel_outlined, Color(0xFFE31C4E)),
};

class _StatusDef {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusDef(this.label, this.icon, this.color);
}

_StatusDef _getStatus(String? key) =>
    _STATUS_MAP[key ?? ''] ?? _StatusDef(key ?? 'Inconnu', Icons.info_outline, _R.text2);

// ============================================================================
// ✅ STATUTS DE DEMANDE (onglet Demandes)
// ============================================================================
class _ReqStatusDef {
  final String label;
  final IconData icon;
  final Color color;
  const _ReqStatusDef(this.label, this.icon, this.color);
}

_ReqStatusDef _reqStatus(String? key) {
  switch (key) {
    case 'approved':
      return const _ReqStatusDef('Acceptée', Icons.check_circle, _R.green);
    case 'rejected':
      return const _ReqStatusDef('Refusée', Icons.cancel, _R.rose);
    case 'cancelled':
      return const _ReqStatusDef('Retirée', Icons.do_not_disturb_on, _R.text2);
    case 'pending':
    default:
      return const _ReqStatusDef('En attente', Icons.hourglass_top, _R.amber);
  }
}

// ============================================================================
// PAGE PRINCIPALE — 2 ONGLETS
// ============================================================================
class VendorsListPage extends ConsumerStatefulWidget {
  final String weddingId;
  const VendorsListPage({super.key, required this.weddingId});

  @override
  ConsumerState<VendorsListPage> createState() => _VendorsListPageState();
}

class _VendorsListPageState extends ConsumerState<VendorsListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsProvider(widget.weddingId));
    final requestsAsync = ref.watch(vendorRequestsProvider(widget.weddingId));

    final requests = requestsAsync.valueOrNull ?? [];
    final pendingCount = requests.where((r) => (r['status'] ?? 'pending') == 'pending').length;
    // vendor_id liés à une demande ACCEPTÉE → badge THIX sur la carte prestataire
    final thixVendorIds = requests
        .where((r) => r['status'] == 'approved' && r['vendor_id'] != null)
        .map((r) => r['vendor_id'] as String)
        .toSet();

    return Scaffold(
      backgroundColor: _R.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/thix-weeding/staff/${widget.weddingId}/prestataires/add'),
        backgroundColor: _R.blue,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_business, size: 20),
        label: Text('Ajouter', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          _GlobalHeader(
            weddingId: widget.weddingId,
            tabCtrl: _tabCtrl,
            pendingCount: pendingCount,
            vendorsCount: vendorsAsync.valueOrNull?.length ?? 0,
          ),
          Expanded(
            child: vendorsAsync.when(
              loading: () => const _LoadingView(),
              error: (e, _) => _ErrorView(
                message: '$e',
                onRetry: () {
                  ref.invalidate(vendorsProvider(widget.weddingId));
                  ref.invalidate(vendorRequestsProvider(widget.weddingId));
                },
              ),
              data: (vendors) => TabBarView(
                controller: _tabCtrl,
                children: [
                  _PrestatairesTab(
  weddingId: widget.weddingId,
  vendors: vendors,
  thixVendorIds: thixVendorIds,
  // 👇 Modifie cette ligne
  onRefresh: () async {
    ref.invalidate(vendorsProvider(widget.weddingId));
  },
),
                  _DemandesTab(
                    weddingId: widget.weddingId,
                    requestsAsync: requestsAsync,
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

// ============================================================================
// HEADER GLOBAL (gradient royal + TabBar)
// ============================================================================
class _GlobalHeader extends StatelessWidget {
  final String weddingId;
  final TabController tabCtrl;
  final int pendingCount;
  final int vendorsCount;

  const _GlobalHeader({
    required this.weddingId,
    required this.tabCtrl,
    required this.pendingCount,
    required this.vendorsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: _R.royal),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRESTATAIRES',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.85),
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          'Gestion & demandes',
                          style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.storefront, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text('$vendorsCount', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    ]),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: tabCtrl,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.65),
              indicatorColor: _R.gold,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                const Tab(text: 'Prestataires'),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Demandes'),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _R.gold, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            '$pendingCount',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: _R.blue),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 🅐 ONGLET PRESTATAIRES (liste locale + recherche + filtres + badge THIX)
// ============================================================================
class _PrestatairesTab extends ConsumerStatefulWidget {
  final String weddingId;
  final List<VendorModel> vendors;
  final Set<String> thixVendorIds;
  final Future<void> Function() onRefresh;

  const _PrestatairesTab({
    required this.weddingId,
    required this.vendors,
    required this.thixVendorIds,
    required this.onRefresh,
  });

  @override
  ConsumerState<_PrestatairesTab> createState() => _PrestatairesTabState();
}

class _PrestatairesTabState extends ConsumerState<_PrestatairesTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _filterCat = 'all';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _search = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final vendors = widget.vendors;
    final total = vendors.length;
    final booked = vendors.where((v) => v.isBooked).length;
    final totalBudget = vendors.fold<double>(0, (s, v) => s + (v.price ?? 0));

    final activeCategories = <String>{};
    for (final v in vendors) {
      if (v.category.isNotEmpty) activeCategories.add(v.category);
    }

    final filtered = vendors.where((v) {
      final matchSearch = _search.isEmpty ||
          v.name.toLowerCase().contains(_search) ||
          (v.contactName ?? '').toLowerCase().contains(_search) ||
          v.category.toLowerCase().contains(_search);
      final matchCat = _filterCat == 'all' ||
          v.category.toLowerCase() == _filterCat.toLowerCase() ||
          _findCat(v.category).key == _filterCat;
      return matchSearch && matchCat;
    }).toList()
      ..sort((a, b) {
        if (a.isBooked != b.isBooked) return a.isBooked ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return RefreshIndicator(
      color: _R.blue,
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Recherche
                Container(
                  height: 46,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _R.border)),
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.inter(fontSize: 14, color: _R.text),
                    decoration: InputDecoration(
                      hintText: 'Rechercher nom, catégorie...',
                      hintStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: _R.blue, size: 20),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchCtrl,
                        builder: (_, v, __) => v.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: _searchCtrl.clear)
                            : const SizedBox.shrink(),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _StatsBar(total: total, booked: booked, totalBudget: totalBudget),
                const SizedBox(height: 12),

                _CategoryFilterRow(
                  selected: _filterCat,
                  activeCategories: activeCategories,
                  onChanged: (f) => setState(() => _filterCat = f),
                ),
                const SizedBox(height: 16),

                _ListHeader(count: filtered.length, total: total, search: _search),
                const SizedBox(height: 10),

                if (filtered.isEmpty)
                  _EmptyVendors(hasSearch: _search.isNotEmpty, hasFilter: _filterCat != 'all', weddingId: widget.weddingId)
                else
                  ...filtered.map((v) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _VendorCard(
                          vendor: v,
                          weddingId: widget.weddingId,
                          isThix: widget.thixVendorIds.contains(v.id),
                        ),
                      )),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 🅑 ONGLET DEMANDES (catalogue THIX — statut live + actions)
// ============================================================================
class _DemandesTab extends ConsumerStatefulWidget {
  final String weddingId;
  final AsyncValue<List<Map<String, dynamic>>> requestsAsync;

  const _DemandesTab({required this.weddingId, required this.requestsAsync});

  @override
  ConsumerState<_DemandesTab> createState() => _DemandesTabState();
}

class _DemandesTabState extends ConsumerState<_DemandesTab> {
  String _filter = 'all'; // all | pending | approved | rejected

  void _refresh() => ref.invalidate(vendorRequestsProvider(widget.weddingId));

  Future<void> _setStatus(String requestId, String status, String toast) async {
    HapticFeedback.selectionClick();
    try {
      await Supabase.instance.client
          .from('thix_weeding_vendor_requests')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', requestId);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(toast, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: status == 'cancelled' ? _R.amber : _R.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _R.blue)),
      error: (e, _) => Center(child: Text('Erreur: $e', style: GoogleFonts.inter(color: _R.rose))),
      data: (requests) {
        if (requests.isEmpty) {
          return _EmptyRequests(weddingId: widget.weddingId);
        }

        final counts = <String, int>{
          'pending': requests.where((r) => (r['status'] ?? 'pending') == 'pending').length,
          'approved': requests.where((r) => r['status'] == 'approved').length,
          'rejected': requests.where((r) => r['status'] == 'rejected').length,
        };

        final filtered = requests.where((r) {
          if (_filter == 'all') return true;
          return (r['status'] ?? 'pending') == _filter;
        }).toList();

        return RefreshIndicator(
          color: _R.blue,
          onRefresh: () async => _refresh(),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            children: [
              // Résumé des statuts
              Row(
                children: [
                  _ReqStatChip(label: 'En attente', value: counts['pending']!, color: _R.amber, selected: _filter == 'pending', onTap: () => setState(() => _filter = _filter == 'pending' ? 'all' : 'pending')),
                  const SizedBox(width: 8),
                  _ReqStatChip(label: 'Acceptées', value: counts['approved']!, color: _R.green, selected: _filter == 'approved', onTap: () => setState(() => _filter = _filter == 'approved' ? 'all' : 'approved')),
                  const SizedBox(width: 8),
                  _ReqStatChip(label: 'Refusées', value: counts['rejected']!, color: _R.rose, selected: _filter == 'rejected', onTap: () => setState(() => _filter = _filter == 'rejected' ? 'all' : 'rejected')),
                ],
              ),
              const SizedBox(height: 14),
              if (_filter != 'all')
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _filter = 'all'),
                      icon: const Icon(Icons.filter_alt_off, size: 16),
                      label: const Text('Tout afficher'),
                      style: TextButton.styleFrom(foregroundColor: _R.blue),
                    ),
                  ),
                ),
              ...filtered.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RequestCard(
                      request: r,
                      onWithdraw: () => _setStatus(r['id'] as String, 'cancelled', 'Demande retirée'),
                      onResend: () => _setStatus(r['id'] as String, 'pending', 'Demande renvoyée ✓'),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _ReqStatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ReqStatChip({required this.label, required this.value, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? color : _R.border, width: selected ? 1.5 : 1),
            ),
            child: Column(children: [
              Text('$value', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: selected ? Colors.white : color)),
              Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: selected ? Colors.white : _R.text2)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CARTE DE DEMANDE
// ============================================================================
class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onWithdraw;
  final VoidCallback onResend;

  const _RequestCard({required this.request, required this.onWithdraw, required this.onResend});

  @override
  Widget build(BuildContext context) {
    final prov = (request['provider'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = prov['business_name'] as String? ?? 'Prestataire';
    final code = prov['unique_code'] as String? ?? '';
    final cat = _findCat(prov['category'] as String?);
    final city = prov['city'] as String? ?? 'RDC';
    final verified = prov['verification_status'] == 'verified';
    final statusKey = request['status'] as String? ?? 'pending';
    final st = _reqStatus(statusKey);
    final eventDate = request['event_date'] as String?;
    final price = (request['proposed_price'] as num?)?.toDouble();
    final currency = request['currency'] as String? ?? 'USD';
    final message = request['message'] as String?;
    final response = request['provider_response'] as String?;
    final providerId = request['provider_id'] as String?;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: st.color.withOpacity(0.35), width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [cat.color, cat.color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(12)),
                  child: Icon(cat.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _R.text))),
                        if (verified) ...[const SizedBox(width: 5), const Icon(Icons.verified, size: 14, color: _R.green)],
                      ]),
                      Text('$city · $code', style: GoogleFonts.inter(fontSize: 10.5, color: _R.text2, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: st.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(st.icon, size: 12, color: st.color),
                    const SizedBox(width: 4),
                    Text(st.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: st.color)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Détails de la demande
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (eventDate != null)
                  _DetailPill(icon: Icons.event, text: _fmtShortDate(eventDate), color: _R.blue),
                if (price != null && price > 0)
                  _DetailPill(icon: Icons.payments, text: '${_fmtMoney(price)} $currency', color: _R.gold),
                if ((request['guest_count'] as num?) != null)
                  _DetailPill(icon: Icons.group, text: '${request['guest_count']} invités', color: _R.purple),
              ],
            ),

            if (message != null && message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('« $message »', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11.5, color: _R.text2, fontStyle: FontStyle.italic, height: 1.35)),
            ],

            // Réponse du prestataire
            if (response != null && response.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: st.color.withOpacity(0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: st.color.withOpacity(0.25))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Réponse du prestataire', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: st.color)),
                  const SizedBox(height: 3),
                  Text(response, style: GoogleFonts.inter(fontSize: 11.5, color: _R.text, height: 1.4)),
                ]),
              ),
            ],
            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                if (providerId != null)
                  Expanded(
                    child: _ReqAction(
                      icon: Icons.travel_explore,
                      label: 'Fiche',
                      color: _R.blue,
                      onTap: () => context.push('/thix-weeding/provider/detail/$providerId'),
                    ),
                  ),
                if (statusKey == 'pending' || statusKey == 'cancelled') ...[
                  if (providerId != null) const SizedBox(width: 8),
                  Expanded(
                    child: _ReqAction(
                      icon: statusKey == 'cancelled' ? Icons.restart_alt : Icons.close,
                      label: statusKey == 'cancelled' ? 'Renvoyer' : 'Retirer',
                      color: statusKey == 'cancelled' ? _R.green : _R.rose,
                      onTap: statusKey == 'cancelled' ? onResend : onWithdraw,
                    ),
                  ),
                ],
                if (statusKey == 'approved') ...[
                  if (providerId != null) const SizedBox(width: 8),
                  Expanded(
                    child: _ReqAction(
                      icon: Icons.arrow_forward,
                      label: 'Détail',
                      color: _R.green,
                      onTap: () {
                        final vid = request['vendor_id'] as String?;
                        if (vid != null) {
                          context.push('/thix-weeding/staff/${request['wedding_id']}/prestataires/$vid');
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _DetailPill({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _R.text)),
    ]);
  }
}

class _ReqAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ReqAction({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// APP BAR / STATS / FILTRES / HEADER (réutilisés, inchangés de logique)
// ============================================================================
class _StatsBar extends StatelessWidget {
  final int total;
  final int booked;
  final double totalBudget;
  const _StatsBar({required this.total, required this.booked, required this.totalBudget});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _R.card(),
      child: Row(
        children: [
          _MiniStat(icon: Icons.storefront, label: 'Total', value: '$total', color: _R.blue),
          _MiniStat(icon: Icons.event_available, label: 'Réservés', value: '$booked', color: _R.green),
          _MiniStat(icon: Icons.account_balance_wallet, label: 'Budget', value: '${_fmtMoney(totalBudget)}', color: _R.gold),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 14, color: color)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: _R.text2)),
      ]),
    );
  }
}

class _CategoryFilterRow extends StatelessWidget {
  final String selected;
  final Set<String> activeCategories;
  final ValueChanged<String> onChanged;
  const _CategoryFilterRow({required this.selected, required this.activeCategories, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _FilterChip(label: 'Tous', icon: Icons.all_inbox, color: _R.blue, isSelected: selected == 'all', onTap: () => onChanged('all')),
      ),
    ];
    for (final catKey in activeCategories) {
      final cat = _findCat(catKey);
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _FilterChip(label: cat.label, icon: cat.icon, color: cat.color, isSelected: selected == cat.key, onTap: () => onChanged(cat.key)),
      ));
    }
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: chips));
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.icon, required this.color, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? color : _R.border, width: isSelected ? 1.5 : 1)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : _R.text)),
          ]),
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  final int count;
  final int total;
  final String search;
  const _ListHeader({required this.count, required this.total, required this.search});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(Icons.list_alt_outlined, size: 16, color: _R.blue),
      const SizedBox(width: 6),
      Text(search.isEmpty ? 'Liste des prestataires' : 'Résultats', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: _R.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Text(search.isEmpty ? '$total' : '$count / $total', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _R.blue)),
      ),
    ]);
  }
}

// ============================================================================
// CARTE PRESTATAIRE (+ badge THIX)
// ============================================================================
class _VendorCard extends StatelessWidget {
  final VendorModel vendor;
  final String weddingId;
  final bool isThix;
  const _VendorCard({required this.vendor, required this.weddingId, required this.isThix});

  @override
  Widget build(BuildContext context) {
    final cat = _findCat(vendor.category);
    final status = _getStatus(vendor.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push('/thix-weeding/staff/$weddingId/prestataires/${vendor.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: vendor.isBooked ? _R.green.withOpacity(0.4) : _R.border, width: vendor.isBooked ? 1.5 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [cat.color, cat.color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(12)),
                child: Icon(cat.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(vendor.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _R.text)),
                      ),
                      // ✅ Badge origine
                      if (isThix)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _R.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: _R.gold.withOpacity(0.4))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.verified, size: 9, color: _R.goldDark),
                            const SizedBox(width: 2),
                            Text('THIX', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: _R.goldDark)),
                          ]),
                        ),
                      if (vendor.isBooked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(gradient: _R.goldG, borderRadius: BorderRadius.circular(6)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.star, color: Colors.white, size: 10),
                            const SizedBox(width: 2),
                            Text('RÉSERVÉ', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                          ]),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: status.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: status.color.withOpacity(0.3))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(status.icon, size: 10, color: status.color),
                          const SizedBox(width: 3),
                          Text(status.label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: status.color)),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      if (vendor.price != null && vendor.price! > 0) ...[
                        Icon(Icons.payments_outlined, size: 10, color: _R.gold),
                        const SizedBox(width: 3),
                        Text('${_fmtMoney(vendor.price!)} FCFA', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _R.gold)),
                      ],
                      const SizedBox(width: 6),
                      if (vendor.contactName != null && vendor.contactName!.isNotEmpty) ...[
                        Icon(Icons.person_outline, size: 10, color: _R.text2),
                        const SizedBox(width: 3),
                        Expanded(child: Text(vendor.contactName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10, color: _R.text2))),
                      ],
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: _R.text2, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATES
// ============================================================================
class _EmptyVendors extends StatelessWidget {
  final bool hasSearch;
  final bool hasFilter;
  final String weddingId;
  const _EmptyVendors({required this.hasSearch, required this.hasFilter, required this.weddingId});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _R.card(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [_R.blue.withOpacity(0.15), _R.purple.withOpacity(0.1)]), shape: BoxShape.circle),
          child: Icon(hasSearch ? Icons.search_off : Icons.storefront_outlined, size: 40, color: _R.blue),
        ),
        const SizedBox(height: 16),
        Text(hasSearch ? 'Aucun résultat' : (hasFilter ? 'Aucun prestataire pour ce filtre' : 'Aucun prestataire'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(hasSearch ? 'Essayez avec d\'autres termes' : 'Ajoutez un pro du catalogue THIX ou saisissez-en un manuellement', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: _R.text2)),
        if (!hasSearch && !hasFilter) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/thix-weeding/staff/$weddingId/prestataires/add'),
            icon: const Icon(Icons.add_business, size: 18),
            label: const Text('Ajouter un prestataire'),
            style: FilledButton.styleFrom(backgroundColor: _R.blue, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ]),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  final String weddingId;
  const _EmptyRequests({required this.weddingId});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [_R.gold.withOpacity(0.18), _R.rose.withOpacity(0.1)]), shape: BoxShape.circle),
            child: const Icon(Icons.send_outlined, size: 44, color: _R.gold),
          ),
          const SizedBox(height: 16),
          Text('Aucune demande envoyée', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _R.text)),
          const SizedBox(height: 6),
          Text(
            'Sollicitez un professionnel du catalogue THIX : onglet Prestataires → Ajouter → Catalogue THIX.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12.5, color: _R.text2, height: 1.45),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/thix-weeding/staff/$weddingId/prestataires/add'),
            icon: const Icon(Icons.travel_explore, size: 18),
            label: const Text('Explorer le catalogue'),
            style: FilledButton.styleFrom(backgroundColor: _R.blue, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
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
    return const Center(child: CircularProgressIndicator(color: _R.blue));
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _R.rose.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, color: _R.rose, size: 40)),
          const SizedBox(height: 16),
          Text('Impossible de charger', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: _R.text2)),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer'), style: FilledButton.styleFrom(backgroundColor: _R.blue)),
        ]),
      ),
    );
  }
}

// ============================================================================
// UTILITAIRES
// ============================================================================
String _fmtMoney(double v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  var c = 0;
  for (var i = s.length - 1; i >= 0; i--) {
    buf.write(s[i]);
    c++;
    if (c % 3 == 0 && i > 0) buf.write(' ');
  }
  return buf.toString().split('').reversed.join();
}

String _fmtShortDate(String iso) {
  try {
    final dt = DateTime.parse(iso);
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return iso;
  }
}
