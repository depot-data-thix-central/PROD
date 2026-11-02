// lib/presentation/thix_weeding/pages/staff/prestataires/add_vendor_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — ADD VENDOR (PRODUCTION v3)
// ✅ MODE CATALOGUE : recherche un prestataire THIX existant (nom/catégorie/code)
//    → soumission d'une DEMANDE DE PRESTATION (thix_weeding_vendor_requests)
//    → le prestataire analyse puis approuve/refuse
//    → après approbation : suivi des étapes (contacté → devis → réservé → payé)
// ✅ MODE MANUEL : création directe (formulaire original conservé)
// ✅ Design royal + 15 catégories + animations + validation
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

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
  static const Color cream = Color(0xFFFFFBF5);
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
  static const LinearGradient roseG = LinearGradient(
    colors: [rose, Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient greenG = LinearGradient(
    colors: [green, greenSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration card({double r = 16}) => BoxDecoration(
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
// 15 CATÉGORIES (utilisées pour le filtre de recherche catalogue)
// ============================================================================
const List<_VendorCategory> _CATEGORIES = [
  _VendorCategory('organisateur', 'Organisateur', Icons.celebration, Color(0xFF6B46C1)),
  _VendorCategory('decorateur', 'Décorateur', Icons.auto_awesome, Color(0xFFFF6B9D)),
  _VendorCategory('photographe', 'Photographe', Icons.camera_alt_outlined, Color(0xFFE31C4E)),
  _VendorCategory('videaste', 'Vidéaste', Icons.videocam_outlined, Color(0xFFDB2777)),
  _VendorCategory('traiteur', 'Traiteur', Icons.restaurant, Color(0xFFD97706)),
  _VendorCategory('patissier', 'Pâtissier', Icons.cake_outlined, Color(0xFFBE185D)),
  _VendorCategory('maquilleur', 'Maquilleur', Icons.auto_fix_high, Color(0xFFEC4899)),
  _VendorCategory('coiffeur', 'Coiffeur', Icons.content_cut, Color(0xFF8B5CF6)),
  _VendorCategory('couturier', 'Couturier', Icons.checkroom, Color(0xFF0891B2)),
  _VendorCategory('dj', 'DJ / Orchestre', Icons.music_note, Color(0xFF7C3AED)),
  _VendorCategory('vehicule', 'Loueur véhicules', Icons.directions_car, Color(0xFF4338CA)),
  _VendorCategory('salle', 'Salle réception', Icons.place_outlined, Color(0xFF0B3B8F)),
  _VendorCategory('fleuriste', 'Fleuriste', Icons.local_florist, Color(0xFF059669)),
  _VendorCategory('securite', 'Sécurité', Icons.shield_outlined, Color(0xFF64748B)),
  _VendorCategory('materiel', 'Matériel événementiel', Icons.inventory_2_outlined, Color(0xFF78716C)),
];

class _VendorCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _VendorCategory(this.key, this.label, this.icon, this.color);
}

_VendorCategory _findCategory(String key) =>
    _CATEGORIES.firstWhere((c) => c.key == key || c.label == key, orElse: () => _CATEGORIES.last);

// ============================================================================
// STATUTS DE SUIVI (post-approbation)
// ============================================================================
const List<_VendorStatus> _STATUSES = [
  _VendorStatus('requested', 'Demande envoyée', Icons.send_outlined, Color(0xFF6B7280)),
  _VendorStatus('contacted', 'Contacté', Icons.phone_callback, Color(0xFF0B3B8F)),
  _VendorStatus('devis_envoye', 'Devis envoyé', Icons.description_outlined, Color(0xFF6B46C1)),
  _VendorStatus('booked', 'Réservé', Icons.event_available, Color(0xFF059669)),
  _VendorStatus('paid', 'Payé', Icons.payments, Color(0xFFD4AF37)),
  _VendorStatus('completed', 'Terminé', Icons.task_alt, Color(0xFF059669)),
];

class _VendorStatus {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _VendorStatus(this.key, this.label, this.icon, this.color);
}

_VendorStatus _findStatus(String key) =>
    _STATUSES.firstWhere((s) => s.key == key, orElse: () => _STATUSES[0]);

// ============================================================================
// PAGE PRINCIPALE — 2 MODES (Catalogue / Manuel)
// ============================================================================
class AddVendorPage extends ConsumerStatefulWidget {
  final String weddingId;
  final String? editVendorId;

  const AddVendorPage({super.key, required this.weddingId, this.editVendorId});

  @override
  ConsumerState<AddVendorPage> createState() => _AddVendorPageState();
}

class _AddVendorPageState extends ConsumerState<AddVendorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool get _isEdit => widget.editVendorId != null;

  @override
  void initState() {
    super.initState();
    // En mode édition → on ouvre directement l'onglet manuel
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: _isEdit ? 1 : 0);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      body: Column(
        children: [
          _TopBar(isEdit: _isEdit),
          if (!_isEdit) _ModeTabs(controller: _tabCtrl),
          Expanded(
            child: _isEdit
                ? _ManualTab(weddingId: widget.weddingId, editVendorId: widget.editVendorId)
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _CatalogTab(weddingId: widget.weddingId),
                      _ManualTab(weddingId: widget.weddingId, editVendorId: null),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TOP BAR
// ============================================================================
class _TopBar extends StatelessWidget {
  final bool isEdit;
  const _TopBar({required this.isEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: _R.royal),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
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
                      isEdit ? 'MODIFIER' : 'AJOUTER UN PRESTATAIRE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      isEdit ? 'Mettre à jour le prestataire' : 'Catalogue THIX ou création manuelle',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
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
}

// ============================================================================
// ONGLETS DE MODE
// ============================================================================
class _ModeTabs extends StatelessWidget {
  final TabController controller;
  const _ModeTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: controller,
        labelColor: _R.blue,
        unselectedLabelColor: _R.text2,
        indicatorColor: _R.blue,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(icon: Icon(Icons.travel_explore, size: 18), text: '  Catalogue THIX'),
          Tab(icon: Icon(Icons.edit_note, size: 18), text: '  Manuel'),
        ],
      ),
    );
  }
}

// ============================================================================
//  MODE CATALOGUE — Recherche prestataire + soumission de demande
// ============================================================================
class _CatalogTab extends ConsumerStatefulWidget {
  final String weddingId;
  const _CatalogTab({required this.weddingId});

  @override
  ConsumerState<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<_CatalogTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _categoryFilter;
  bool _loading = true;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final c = Supabase.instance.client;
      var q = c
          .from('thix_weeding_providers')
          .select('id, unique_code, business_name, category, city, phone, email, description, rating, review_count, min_price, currency, verification_status, level, gallery_urls')
          .neq('verification_status', 'rejected');

      if (_categoryFilter != null) {
        q = q.eq('category', _categoryFilter!);
      }
      if (_query.trim().isNotEmpty) {
        final s = _query.trim();
        q = q.or(
          'business_name.ilike.%$s%,unique_code.ilike.%$s%,city.ilike.%$s%,description.ilike.%$s%',
        );
      }

      final res = await q.order('created_at', ascending: false).limit(40);
      if (!mounted) return;
      setState(() {
        _results = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Erreur recherche: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _R.rose,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) {
              _query = v;
              _debouncedSearch();
            },
            textInputAction: TextInputAction.search,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Nom, code THIX-P, ville...',
              hintStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: _R.blue, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18, color: _R.text2),
                      onPressed: () {
                        _searchCtrl.clear();
                        _query = '';
                        _search();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _R.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _R.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _R.blue, width: 2),
              ),
            ),
          ),
        ),

        // Filtre catégories (chips scrollables)
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                label: 'Toutes',
                selected: _categoryFilter == null,
                onTap: () {
                  setState(() => _categoryFilter = null);
                  _search();
                },
              ),
              ..._CATEGORIES.map(
                (cat) => _FilterChip(
                  label: cat.label,
                  selected: _categoryFilter == cat.key,
                  onTap: () {
                    setState(() => _categoryFilter = cat.key);
                    _search();
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Résultats
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _R.blue))
              : _results.isEmpty
                  ? _EmptyCatalog(query: _query)
                  : RefreshIndicator(
                      color: _R.blue,
                      onRefresh: _search,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final p = _results[i];
                          return _ProviderResultCard(
                            provider: p,
                            onRequest: () => _openRequestSheet(p),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // Debounce simple pour la recherche
  bool _debouncing = false;
  void _debouncedSearch() {
    if (_debouncing) return;
    _debouncing = true;
    Future.delayed(const Duration(milliseconds: 350), () {
      _debouncing = false;
      if (mounted) _search();
    });
  }

  void _openRequestSheet(Map<String, dynamic> provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestSheet(
        weddingId: widget.weddingId,
        provider: provider,
        onSubmitted: () {
          _search();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Demande envoyée au prestataire ✓ En attente de sa réponse',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            backgroundColor: _R.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
        },
      ),
    );
  }
}

// ============================================================================
// CHIP DE FILTRE CATÉGORIE
// ============================================================================
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? _R.blue : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? _R.blue : _R.border),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _R.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CARTE RÉSULTAT DE RECHERCHE
// ============================================================================
class _ProviderResultCard extends StatelessWidget {
  final Map<String, dynamic> provider;
  final VoidCallback onRequest;
  const _ProviderResultCard({required this.provider, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    final cat = _findCategory(provider['category'] as String? ?? '');
    final name = provider['business_name'] as String? ?? 'Sans nom';
    final code = provider['unique_code'] as String? ?? '';
    final city = provider['city'] as String? ?? 'RDC';
    final rating = (provider['rating'] as num?)?.toDouble() ?? 0.0;
    final reviews = provider['review_count'] as int? ?? 0;
    final minPrice = (provider['min_price'] as num?)?.toDouble();
    final verified = provider['verification_status'] == 'verified';
    final gallery = (provider['gallery_urls'] as List?)?.cast<String>() ?? [];
    final cover = gallery.isNotEmpty ? gallery.first : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onRequest,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _R.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              // Avatar / cover
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [cat.color, cat.color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: cover != null
                    ? Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _icon(cat))
                    : _icon(cat),
              ),
              const SizedBox(width: 12),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _R.text),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, size: 14, color: _R.green),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cat.label} · $city',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 11, color: _R.text2, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: _R.gold),
                        const SizedBox(width: 2),
                        Text(
                          rating > 0 ? '${rating.toStringAsFixed(1)} ($reviews)' : 'Nouveau',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _R.text),
                        ),
                        const SizedBox(width: 10),
                        if (minPrice != null)
                          Text(
                            'Dès ${minPrice.toStringAsFixed(0)}\$',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _R.rose),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Bouton demander
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  gradient: _R.roseG,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Demander',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
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

  Widget _icon(_VendorCategory cat) => Icon(cat.icon, color: Colors.white, size: 26);
}

// ============================================================================
// EMPTY CATALOGUE
// ============================================================================
class _EmptyCatalog extends StatelessWidget {
  final String query;
  const _EmptyCatalog({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: _R.blue.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.travel_explore, size: 44, color: _R.blue),
            ),
            const SizedBox(height: 16),
            Text(
              query.isEmpty ? 'Explorez le catalogue THIX' : 'Aucun prestataire trouvé',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _R.text),
            ),
            const SizedBox(height: 6),
            Text(
              query.isEmpty
                  ? 'Recherchez un professionnel par nom, catégorie ou code THIX-P, puis envoyez-lui une demande de prestation.'
                  : 'Essayez un autre nom, une autre catégorie ou vérifiez l\'orthographe.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: _R.text2, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 🆕 BOTTOM SHEET — SOUMISSION D'UNE DEMANDE DE PRESTATION
// ============================================================================
class _RequestSheet extends ConsumerStatefulWidget {
  final String weddingId;
  final Map<String, dynamic> provider;
  final VoidCallback onSubmitted;

  const _RequestSheet({
    required this.weddingId,
    required this.provider,
    required this.onSubmitted,
  });

  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _priceCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  DateTime? _eventDate;
  bool _submitting = false;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _servicesCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now().add(const Duration(days: 60)),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1460)),
      helpText: 'Date de l\'événement',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _R.blue, onPrimary: Colors.white, surface: Colors.white, onSurface: _R.text),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final now = DateTime.now().toIso8601String();

      final data = <String, dynamic>{
        'wedding_id': widget.weddingId,
        'provider_id': widget.provider['id'] as String,
        'requested_by': user?.id,
        'event_date': _eventDate?.toIso8601String().split('T')[0],
        'proposed_price': double.tryParse(_priceCtrl.text.replaceAll(RegExp(r'\D'), '')),
        'currency': widget.provider['currency'] as String? ?? 'USD',
        'services_requested': _servicesCtrl.text.trim().isEmpty ? null : _servicesCtrl.text.trim(),
        'contact_name': _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim(),
        'contact_phone': _contactPhoneCtrl.text.trim().isEmpty ? null : _contactPhoneCtrl.text.trim(),
        'message': _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
        'status': 'pending',
        'stage': 'requested',
        'created_at': now,
        'updated_at': now,
      };

      await Supabase.instance.client
          .from('thix_weeding_vendor_requests')
          .insert(data);

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur envoi demande: $e'),
        backgroundColor: _R.rose,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = _findCategory(widget.provider['category'] as String? ?? '');
    final name = widget.provider['business_name'] as String? ?? 'Prestataire';
    final code = widget.provider['unique_code'] as String? ?? '';

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: _R.border, borderRadius: BorderRadius.circular(2)),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête prestataire
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [cat.color, cat.color.withOpacity(0.7)]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(cat.icon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _R.text)),
                              Text('${cat.label} · $code', style: GoogleFonts.inter(fontSize: 11, color: _R.text2, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _R.blue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _R.blue.withOpacity(0.15)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: _R.blue, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Le prestataire recevra votre demande et pourra l\'accepter ou la refuser. Vous serez notifié de sa réponse.',
                            style: GoogleFonts.inter(fontSize: 11, color: _R.blue, height: 1.4),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // Date
                    _Label('Date de l\'événement'),
                    _DateTile(date: _eventDate, onTap: _pickDate, onClear: () => setState(() => _eventDate = null)),
                    const SizedBox(height: 16),

                    // Prix proposé
                    _Label('Prix proposé (optionnel)'),
                    _Field(
                      controller: _priceCtrl,
                      hint: 'Ex: 350000',
                      icon: Icons.account_balance_wallet_outlined,
                      keyboard: TextInputType.number,
                      suffix: 'FCFA',
                      formatter: FilteringTextInputFormatter.digitsOnly,
                    ),
                    const SizedBox(height: 16),

                    // Prestations
                    _Label('Prestations souhaitées'),
                    _Field(
                      controller: _servicesCtrl,
                      hint: 'Ex: Reportage photo + vidéo cérémonie, 200 invités...',
                      icon: Icons.checklist_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Contact
                    _Label('Votre contact'),
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            controller: _contactNameCtrl,
                            hint: 'Nom',
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _contactPhoneCtrl,
                            hint: 'Téléphone',
                            icon: Icons.phone_outlined,
                            keyboard: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Message
                    _Label('Message au prestataire'),
                    _Field(
                      controller: _messageCtrl,
                      hint: 'Précisez vos attentes, contraintes, horaires...',
                      icon: Icons.chat_bubble_outline,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Bouton soumettre
                    _SubmitButton(
                      label: 'Envoyer la demande',
                      icon: Icons.send_rounded,
                      isLoading: _submitting,
                      gradient: _R.roseG,
                      onTap: _submit,
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

// ============================================================================
// WIDGETS FORMULAIRE PARTAGÉS
// ============================================================================
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _R.text)),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboard;
  final String? suffix;
  final TextInputFormatter? formatter;
  final String? Function(String?)? validator;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboard = TextInputType.text,
    this.suffix,
    this.formatter,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatter != null ? [formatter!] : null,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: _R.text2.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: _R.blue, size: 20),
        suffixText: suffix,
        suffixStyle: GoogleFonts.inter(color: _R.text2, fontWeight: FontWeight.w600, fontSize: 12),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.blue, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DateTile({required this.date, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasDate ? _R.gold.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hasDate ? _R.gold.withOpacity(0.4) : _R.border, width: hasDate ? 1.5 : 1),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: hasDate ? _R.goldG : null,
                color: hasDate ? null : _R.border.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_today, size: 18, color: hasDate ? Colors.white : _R.text2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasDate ? DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(date!) : 'Choisir une date',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: hasDate ? _R.text : _R.text2),
              ),
            ),
            if (hasDate)
              IconButton(icon: const Icon(Icons.clear, size: 18, color: _R.text2), onPressed: onClear)
            else
              const Icon(Icons.chevron_right, size: 20, color: _R.text2),
          ]),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final Gradient gradient;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: isLoading ? null : gradient,
        color: isLoading ? _R.border : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isLoading
            ? null
            : [BoxShadow(color: _R.blue.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🆕 MODE MANUEL — formulaire original (création directe d'un vendor)
// ============================================================================
class _ManualTab extends ConsumerStatefulWidget {
  final String weddingId;
  final String? editVendorId;
  const _ManualTab({required this.weddingId, this.editVendorId});

  @override
  ConsumerState<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends ConsumerState<_ManualTab> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _category = 'traiteur';
  String _status = 'requested';
  bool _isBooked = false;
  bool _isLoading = false;
  bool _isInitLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  bool get _isEdit => widget.editVendorId != null;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    if (_isEdit) _loadVendor();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVendor() async {
    setState(() => _isInitLoading = true);
    try {
      final v = await ref.read(vendorServiceProvider).getById(widget.editVendorId!);
      setState(() {
        _nameCtrl.text = v.name;
        _contactCtrl.text = v.contactName ?? '';
        _phoneCtrl.text = v.phone ?? '';
        _emailCtrl.text = v.email ?? '';
        _priceCtrl.text = v.price?.toStringAsFixed(0) ?? '';
        _notesCtrl.text = v.notes ?? '';
        _category = v.category.isNotEmpty ? v.category : 'traiteur';
        _status = v.status.isNotEmpty ? v.status : 'requested';
        _isBooked = v.isBooked;
      });
    } catch (e) {
      if (mounted) _showError('Erreur chargement: $e');
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'wedding_id': widget.weddingId,
      'name': _nameCtrl.text.trim(),
      'category': _category,
      'contact_name': _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
      'status': _status,
      'is_booked': _isBooked,
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };

    try {
      final service = ref.read(vendorServiceProvider);
      if (!_isEdit) {
        final created = await service.create(data);
        if (mounted) _showSuccess('Prestataire créé • ID: ${created.id.substring(0, 8)} ✓');
      } else {
        await service.update(widget.editVendorId!, data);
        if (mounted) _showSuccess('Prestataire mis à jour ✓');
      }
      ref.invalidate(vendorsProvider(widget.weddingId));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: _R.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _R.rose,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return _isInitLoading
        ? const Center(child: CircularProgressIndicator(color: _R.blue))
        : FadeTransition(
            opacity: _fadeAnim,
            child: Form(
              key: _formKey,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // ENTREPRISE
                  _SectionCard(
                    title: 'Entreprise',
                    icon: Icons.storefront_outlined,
                    color: _R.blue,
                    children: [
                      _Field(
                        controller: _nameCtrl,
                        hint: 'Ex: Studio Photo Royal',
                        icon: Icons.business_outlined,
                        validator: (v) => v == null || v.trim().length < 2 ? 'Nom requis (min 2 car.)' : null,
                      ),
                      const SizedBox(height: 14),
                      _CategorySelector(selected: _category, onChanged: (c) => setState(() => _category = c)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // CONTACT
                  _SectionCard(
                    title: 'Contact',
                    icon: Icons.person_outline,
                    color: _R.purple,
                    children: [
                      _Field(controller: _contactCtrl, hint: 'Ex: Jean Dupont', icon: Icons.person_outline),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _Field(controller: _phoneCtrl, hint: '+243 ...', icon: Icons.phone_outlined, keyboard: TextInputType.phone)),
                        const SizedBox(width: 12),
                        Expanded(child: _Field(controller: _emailCtrl, hint: 'pro@mail.com', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // CONTRAT & PRIX
                  _SectionCard(
                    title: 'Contrat & Tarif',
                    icon: Icons.payments_outlined,
                    color: _R.gold,
                    children: [
                      _Field(
                        controller: _priceCtrl,
                        hint: '350000',
                        icon: Icons.account_balance_wallet_outlined,
                        keyboard: TextInputType.number,
                        suffix: 'FCFA',
                        formatter: FilteringTextInputFormatter.digitsOnly,
                      ),
                      const SizedBox(height: 14),
                      _StatusSelector(selected: _status, onChanged: (s) => setState(() => _status = s)),
                      const SizedBox(height: 14),
                      _BookedToggle(value: _isBooked, onChanged: (v) => setState(() => _isBooked = v)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // NOTES
                  _SectionCard(
                    title: 'Notes & Détails',
                    icon: Icons.notes_outlined,
                    color: _R.text2,
                    children: [
                      _Field(controller: _notesCtrl, hint: 'Conditions, horaires, prestations incluses...', icon: Icons.edit_note_outlined, maxLines: 4),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _SubmitButton(
                    label: _isEdit ? 'Enregistrer les modifications' : 'Créer le prestataire',
                    icon: _isEdit ? Icons.check : Icons.storefront,
                    isLoading: _isLoading,
                    gradient: _isEdit ? _R.greenG : _R.royal,
                    onTap: _save,
                  ),
                ],
              ),
            ),
          );
  }
}

// ============================================================================
// SECTION CARD (mode manuel)
// ============================================================================
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.icon, required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ============================================================================
// CATEGORY SELECTOR (grille 3 colonnes — mode manuel)
// ============================================================================
class _CategorySelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategorySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.95,
      ),
      itemCount: _CATEGORIES.length,
      itemBuilder: (context, i) {
        final cat = _CATEGORIES[i];
        final isSelected = cat.key == selected || cat.label == selected;
        return Material(
          color: isSelected ? cat.color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onChanged(cat.key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? cat.color : _R.border, width: isSelected ? 2 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.25) : cat.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(cat.icon, size: 20, color: isSelected ? Colors.white : cat.color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : _R.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// STATUS SELECTOR (mode manuel)
// ============================================================================
class _StatusSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _StatusSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _STATUSES.map((s) {
        final isSelected = s.key == selected;
        return Material(
          color: isSelected ? s.color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => onChanged(s.key),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? s.color : _R.border, width: isSelected ? 1.5 : 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.icon, size: 14, color: isSelected ? Colors.white : s.color),
                  const SizedBox(width: 6),
                  Text(
                    s.label,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : _R.text),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================================
// BOOKED TOGGLE (mode manuel)
// ============================================================================
class _BookedToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BookedToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: value ? _R.green.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? _R.green : _R.border, width: 1.5),
      ),
      child: SwitchListTile(
        title: Text('Prestataire réservé', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: value ? _R.green : _R.text)),
        subtitle: Text(value ? 'Confirmé et bloqué pour l\'événement' : 'Pas encore confirmé', style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value ? _R.green.withOpacity(0.15) : _R.border.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(value ? Icons.event_available : Icons.event_busy, size: 18, color: value ? _R.green : _R.text2),
        ),
        value: value,
        activeColor: _R.green,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
