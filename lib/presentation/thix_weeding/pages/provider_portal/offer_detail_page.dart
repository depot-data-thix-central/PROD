// lib/presentation/thix_weeding/pages/provider_portal/offer_detail_page.dart
// ============================================================================
// THIX WEDDING — DÉTAIL D'UNE OFFRE / SERVICE (PRODUCTION v1)
// ✅ Ouvert au clic sur n'importe quelle offre (home, catalogue, fiche)
// ✅ TOUT s'affiche : photos (swipe + miniatures), vidéos, description
//    complète, prix + promo (prix barré + %), points forts, capacité,
//    durée, catégorie, fiche prestataire, CTA réservation fonctionnel
// ✅ Lecture directe de la ligne Supabase (colonnes étendues v5)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';
import 'provider_offers_page.dart' show offerTypeIcon, offerTypeColor;
import 'orders/orders_provider.dart' show ordersProvider;

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
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE
// ═══════════════════════════════════════════════════════════════════════════
class ProviderOfferDetailPage extends ConsumerStatefulWidget {
  final String providerId;
  final String offerId;
  const ProviderOfferDetailPage({
    super.key,
    required this.providerId,
    required this.offerId,
  });

  @override
  ConsumerState<ProviderOfferDetailPage> createState() =>
      _ProviderOfferDetailPageState();
}

class _ProviderOfferDetailPageState
    extends ConsumerState<ProviderOfferDetailPage> {
  Map<String, dynamic>? _row;
  bool _loading = true;
  String? _error;
  final _pageCtrl = PageController();
  int _currentImg = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await Supabase.instance.client
          .from('thix_weeding_offers')
          .select()
          .eq('id', widget.offerId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _row = row == null ? null : Map<String, dynamic>.from(row);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // ── Extracteurs tolérants (colonnes v5 ou anciennes) ──
  List<String> get _images {
    final r = _row;
    if (r == null) return [];
    final list = <String>[];
    final urls = (r['image_urls'] as List?)?.cast<String>() ?? [];
    list.addAll(urls.where((u) => u.isNotEmpty));
    final legacy = (r['gallery_urls'] as List?)?.cast<String>() ?? [];
    for (final u in legacy) {
      if (u.isNotEmpty && !list.contains(u)) list.add(u);
    }
    final cover = r['image_url'] as String?;
    if ((cover ?? '').isNotEmpty && !list.contains(cover)) list.insert(0, cover!);
    return list;
  }

  List<String> get _videos =>
      (_row?['video_urls'] as List?)?.cast<String>() ?? [];

  @override
  Widget build(BuildContext context) {
    final providerAsync = ref.watch(providerByIdProvider(widget.providerId));

    return Scaffold(
      backgroundColor: _P.bg,
      bottomNavigationBar: _row == null
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4)),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => providerAsync.valueOrNull != null
                        ? _openReservation(providerAsync.valueOrNull!)
                        : null,
                    icon: const Icon(Icons.event_available_rounded, size: 20),
                    label: Text('Réserver ce service',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _P.rose,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _P.rose))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: _P.red),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: _P.inkSoft)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : _row == null
                  ? const Center(child: Text('Offre introuvable'))
                  : _buildContent(providerAsync),
    );
  }

  Widget _buildContent(AsyncValue<ThixProviderModel?> providerAsync) {
    final r = _row!;
    final images = _images;
    final videos = _videos;
    final type = OfferType.values.firstWhere(
        (t) => t.name == (r['offer_type'] as String? ?? ''),
        orElse: () => OfferType.service);
    final color = offerTypeColor(type);
    final title = r['title'] as String? ?? 'Offre';
    final desc = r['description'] as String? ?? '';
    final price = (r['price'] as num?)?.toDouble();
    final promo = r['promo_active'] == true;
    final promoPercent = (r['promo_percent'] as int?) ?? 0;
    final oldPrice = (r['promo_old_price'] as num?)?.toDouble();
    final capacity = r['capacity'] as int?;
    final duration = r['duration_hours'] as int?;
    final eventCat = r['category'] as String?;
    final highlights = (r['highlights'] as List?)?.cast<String>() ?? [];
    final provider = providerAsync.valueOrNull;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ═══════════ HERO : GALERIE PHOTOS SWIPE ═══════════
        SliverAppBar(
          expandedHeight: images.isNotEmpty ? 320 : 120,
          pinned: true,
          backgroundColor: _P.bg,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, color: _P.ink, size: 20),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: images.isNotEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        controller: _pageCtrl,
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _currentImg = i),
                        itemBuilder: (_, i) => Image.network(images[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: color.withOpacity(0.15))),
                      ),
                      // Compteur
                      Positioned(
                        top: 56,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${_currentImg + 1}/${images.length}',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ),
                      // Badge type
                      Positioned(
                        top: 56,
                        left: 56,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(type.displayName.toUpperCase(),
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                      ),
                      // Indicateurs
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length > 8 ? 8 : images.length,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == (_currentImg % (images.length > 8 ? 8 : images.length)) ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(color: color.withOpacity(0.15)),
          ),
        ),

        // ═══════════ MINIATURES (accès direct) ═══════════
        if (images.length > 1)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _pageCtrl.animateToPage(i,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut),
                  child: Container(
                    width: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: i == _currentImg ? _P.rose : _P.line,
                          width: i == _currentImg ? 2 : 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(images[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: _P.line)),
                  ),
                ),
              ),
            ),
          ),

        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ═══════════ TITRE + PRIX + PROMO ═══════════
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _P.ink,
                            letterSpacing: -0.5)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (promo && oldPrice != null)
                        Text('${oldPrice.toStringAsFixed(0)}\$',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _P.inkSoft,
                                decoration: TextDecoration.lineThrough)),
                      Text(
                          price != null
                              ? '${price.toStringAsFixed(0)}\$'
                              : 'Sur devis',
                          style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: _P.rose)),
                    ],
                  ),
                ],
              ),
              if (promo) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_P.amber, const Color(0xFFFFB84D)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('PROMO −$promoPercent%',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      if (r['promo_end'] != null) ...[
                        const SizedBox(width: 8),
                        Text(
                            'jusqu\'au ${DateFormat('dd MMM', 'fr_FR').format(DateTime.tryParse(r['promo_end'] as String) ?? DateTime.now())}',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: Colors.white)),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // ═══════════ CHIPS INFOS ═══════════
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (eventCat != null)
                    _chip(eventCat, _P.purple, Icons.celebration_rounded),
                  if (capacity != null)
                    _chip('$capacity personnes', _P.blue, Icons.people_rounded),
                  if (duration != null)
                    _chip('$duration h', _P.teal(), Icons.schedule_rounded),
                  if (videos.isNotEmpty)
                    _chip('${videos.length} vidéo(s)', _P.red, Icons.videocam_rounded),
                  _chip('${images.length} photo(s)', _P.inkSoft,
                      Icons.photo_library_rounded),
                ],
              ),
              const SizedBox(height: 20),

              // ═══════════ DESCRIPTION COMPLÈTE ═══════════
              if (desc.isNotEmpty) ...[
                _sectionTitle('Description', Icons.description_rounded),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _P.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _P.line),
                  ),
                  child: Text(desc,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: _P.ink, height: 1.6)),
                ),
                const SizedBox(height: 20),
              ],

              // ═══════════ POINTS FORTS ═══════════
              if (highlights.isNotEmpty) ...[
                _sectionTitle('Points forts', Icons.star_rounded),
                const SizedBox(height: 10),
                ...highlights.map((h) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _P.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _P.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: _P.amber, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(h,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _P.ink))),
                        ],
                      ),
                    )),
                const SizedBox(height: 20),
              ],

              // ═══════════ VIDÉOS ═══════════
              if (videos.isNotEmpty) ...[
                _sectionTitle('Vidéos du service', Icons.videocam_rounded),
                const SizedBox(height: 10),
                ...videos.map((v) => GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(v);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _P.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _P.line),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _P.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.play_circle_fill_rounded,
                                  color: _P.red, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Regarder la vidéo',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _P.ink)),
                            ),
                            const Icon(Icons.open_in_new_rounded,
                                size: 16, color: _P.inkSoft),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 20),
              ],

              // ═══════════ PRESTATAIRE ═══════════
              if (provider != null) ...[
                _sectionTitle('Prestataire', Icons.storefront_rounded),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => context
                      .push('/thix-weeding/provider/detail/${provider.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _P.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _P.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_P.rose, _P.roseLight]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                                provider.businessName.isNotEmpty
                                    ? provider.businessName[0].toUpperCase()
                                    : 'P',
                                style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(provider.businessName,
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: _P.ink)),
                              Text(
                                  '${provider.category.displayName} • ${provider.city ?? 'RDC'} • ${provider.uniqueCode}',
                                  style: GoogleFonts.inter(
                                      fontSize: 11, color: _P.inkSoft)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: _P.inkSoft),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color color, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );

  Widget _sectionTitle(String label, IconData icon) => Row(
        children: [
          Container(
              width: 4,
              height: 18,
              decoration:
                  BoxDecoration(color: _P.rose, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Icon(icon, size: 16, color: _P.rose),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w900, color: _P.ink)),
        ],
      );

  void _openReservation(ThixProviderModel provider) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OfferReservationSheet(
        provider: provider,
        offerTitle: _row?['title'] as String? ?? 'Offre',
        offerId: widget.offerId,
        offerType: _row?['offer_type'] as String? ?? 'service',
        price: (_row?['price'] as num?)?.toDouble(),
      ),
    );
  }
}

extension _Teal on Color {
  Color teal() => const Color(0xFF14B8A6);
}

// ═══════════════════════════════════════════════════════════════════════════
// SHEET RÉSERVATION → crée la COMMANDE (wedding_orders)
// ═══════════════════════════════════════════════════════════════════════════
class _OfferReservationSheet extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  final String offerTitle;
  final String offerId;
  final String offerType;
  final double? price;
  const _OfferReservationSheet({
    required this.provider,
    required this.offerTitle,
    required this.offerId,
    required this.offerType,
    this.price,
  });

  @override
  ConsumerState<_OfferReservationSheet> createState() =>
      _OfferReservationSheetState();
}

class _OfferReservationSheetState extends ConsumerState<_OfferReservationSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _guestsCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 30));
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _guestsCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _toast(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating));
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().length < 2) {
      _toast('Indiquez votre nom complet', _P.amber);
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      _toast('Indiquez un téléphone', _P.amber);
      return;
    }
    setState(() => _busy = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await ref.read(ordersProvider(widget.provider.id).notifier).createOrder(
            offerId: widget.offerId,
            offerTitle: widget.offerTitle,
            clientId: user?.id ?? 'client_externe',
            clientName: _nameCtrl.text.trim(),
            clientEmail: _emailCtrl.text.trim().isEmpty
                ? '${_phoneCtrl.text.trim().replaceAll(RegExp(r'[^\w]'), '')}@client.thix'
                : _emailCtrl.text.trim(),
            clientPhone: _phoneCtrl.text.trim(),
            providerId: widget.provider.id,
            providerName: widget.provider.businessName,
            eventDate: _date,
            orderData: {
              'guest_count': int.tryParse(_guestsCtrl.text.trim()),
              'message': _msgCtrl.text.trim(),
              'offer_type': widget.offerType,
              'source': 'offre_detail',
            },
            totalAmount: widget.price ?? 0,
            notes: _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
            isTraiteur: widget.provider.category == ProviderCategory.traiteur ||
                widget.provider.category == ProviderCategory.patissier,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Demande envoyée ✓ Le prestataire va la confirmer',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: _P.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Envoi impossible: $e', _P.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _P.line, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              const Icon(Icons.event_available_rounded, color: _P.rose),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Réserver « ${widget.offerTitle} »',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w900, color: _P.ink)),
              ),
            ]),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                _field('Nom complet *', _nameCtrl, Icons.person_rounded),
                const SizedBox(height: 10),
                _field('Téléphone *', _phoneCtrl, Icons.phone_rounded,
                    keyboard: TextInputType.phone),
                const SizedBox(height: 10),
                _field('Email', _emailCtrl, Icons.email_rounded,
                    keyboard: TextInputType.emailAddress),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final p = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 730)));
                    if (p != null) setState(() => _date = p);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration:
                        BoxDecoration(color: _P.bg, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: _P.rose),
                      const SizedBox(width: 10),
                      Text(
                          'Date : ${DateFormat('EEEE dd MMM yyyy', 'fr_FR').format(_date)}',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                _field('Nombre d\'invités', _guestsCtrl, Icons.people_rounded,
                    keyboard: TextInputType.number),
                const SizedBox(height: 10),
                _field('Message', _msgCtrl, Icons.chat_bubble_outline_rounded,
                    maxLines: 3),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _P.rose,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Envoyer la demande',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
                  ),
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
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
          prefixIcon: Icon(icon, size: 18, color: _P.rose),
          filled: true,
          fillColor: _P.bg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      );
}
