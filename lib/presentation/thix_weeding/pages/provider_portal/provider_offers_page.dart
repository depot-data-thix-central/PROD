// lib/presentation/thix_weeding/pages/provider_portal/provider_offers_page.dart
// ============================================================================
// THIX WEDDING — GESTION DES OFFRES / SERVICES / MENUS (PRODUCTION)
// ✅ Onglet "Offres" du dashboard : liste, toggle actif, édition, suppression
// ✅ Formulaire de publication complet
// ✅ Widget réutilisable pour le HOME (ThixHomeOffersSection)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const Color blue = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color red = Color(0xFFEF4444);
}

IconData offerTypeIcon(OfferType t) => switch (t) {
      OfferType.service => Icons.build_rounded,
      OfferType.menu => Icons.restaurant_menu_rounded,
      OfferType.package => Icons.card_giftcard_rounded,
      OfferType.promo => Icons.local_offer_rounded,
    };

Color offerTypeColor(OfferType t) => switch (t) {
      OfferType.service => _P.blue,
      OfferType.menu => _P.amber,
      OfferType.package => _P.purple,
      OfferType.promo => _P.rose,
    };

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET "OFFRES" DU DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════
class ProviderOffersPage extends ConsumerWidget {
  final ThixProviderModel provider;
  const ProviderOffersPage({super.key, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(providerOffersProvider(provider.id));

    return Scaffold(
      backgroundColor: _P.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/thix-weeding/provider/offers/new');
        },
        backgroundColor: _P.rose,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Publier une offre', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: _P.bg,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Text('Mes offres & services', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _P.ink)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: offersAsync.when(
              data: (offers) {
                if (offers.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: _P.rose.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.local_offer_outlined, size: 56, color: _P.rose),
                            ),
                            const SizedBox(height: 20),
                            Text('Publiez votre première offre', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
                            const SizedBox(height: 8),
                            Text('Services, menus, formules ou promos : tout ce que vous publiez ici apparaît sur le catalogue et la page d\'accueil.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft, height: 1.5)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OfferCard(offer: offers[i], providerId: provider.id),
                    ),
                    childCount: offers.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: _P.rose))),
              error: (e, _) => SliverFillRemaining(child: Center(child: Text('Erreur: $e', style: GoogleFonts.inter(color: _P.inkSoft)))),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE D'OFFRE (liste du dashboard)
// ═══════════════════════════════════════════════════════════════════════════
class _OfferCard extends ConsumerWidget {
  final ProviderOfferModel offer;
  final String providerId;
  const _OfferCard({required this.offer, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = offerTypeColor(offer.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _P.line),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(offerTypeIcon(offer.type), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(offer.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _P.ink)),
                    const SizedBox(height: 2),
                    Text(offer.type.displayName, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
              ),
              // Toggle visibilité
              Switch(
                value: offer.isActive,
                activeColor: _P.green,
                onChanged: (v) async {
                  HapticFeedback.selectionClick();
                  await ref.read(updateOfferProvider)(offer.id, providerId, isActive: v);
                },
              ),
            ],
          ),
          if ((offer.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(offer.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, height: 1.4)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _P.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  offer.price != null ? '${offer.price!.toStringAsFixed(0)}\$' : 'Sur devis',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: _P.green),
                ),
              ),
              const SizedBox(height: 0),
              const Spacer(),
              IconButton(
                onPressed: () => context.push('/thix-weeding/provider/offers/edit/${offer.id}'),
                icon: const Icon(Icons.edit_outlined, size: 18, color: _P.inkSoft),
              ),
              IconButton(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _P.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Supprimer cette offre ?', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text('"${offer.title}" sera définitivement retirée du catalogue.', style: GoogleFonts.inter(color: _P.inkSoft, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: GoogleFonts.inter(color: _P.inkSoft))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _P.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Supprimer', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(deleteOfferProvider)(offer.id, providerId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Offre supprimée', style: GoogleFonts.inter(fontWeight: FontWeight.w600)), backgroundColor: _P.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FORMULAIRE DE PUBLICATION / ÉDITION
// ═══════════════════════════════════════════════════════════════════════════
class ProviderOfferFormPage extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  final ProviderOfferModel? existing; // null = création

  const ProviderOfferFormPage({super.key, required this.provider, this.existing});

  @override
  ConsumerState<ProviderOfferFormPage> createState() => _ProviderOfferFormPageState();
}

class _ProviderOfferFormPageState extends ConsumerState<ProviderOfferFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _imgCtrl;
  late OfferType _type;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _priceCtrl = TextEditingController(text: e?.price != null ? e!.price!.toStringAsFixed(0) : '');
    _imgCtrl = TextEditingController(text: e?.imageUrl ?? '');
    _type = e?.type ?? OfferType.service;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _imgCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final price = _priceCtrl.text.trim().isEmpty ? null : double.tryParse(_priceCtrl.text.trim());
      final img = _imgCtrl.text.trim().isEmpty ? null : _imgCtrl.text.trim();
      final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

      if (widget.existing == null) {
        await ref.read(createOfferProvider)(
          providerId: widget.provider.id,
          title: _titleCtrl.text.trim(),
          type: _type,
          description: desc,
          price: price,
          imageUrl: img,
          isActive: _isActive,
        );
      } else {
        await ref.read(updateOfferProvider)(
          widget.existing!.id,
          widget.provider.id,
          title: _titleCtrl.text.trim(),
          type: _type,
          description: desc,
          price: price,
          imageUrl: img,
          isActive: _isActive,
        );
      }

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existing == null ? 'Offre publiée ✔ Visible sur le catalogue & l\'accueil' : 'Offre mise à jour ✔', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          backgroundColor: _P.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _P.rose, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.bg,
        elevation: 0,
        title: Text(widget.existing == null ? 'Publier une offre' : 'Modifier l\'offre', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre
                Text('Titre de l\'offre *', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().length < 3 ? 'Titre requis (min 3 caractères)' : null,
                  decoration: _dec('Ex: Menu mariage 200 personnes', Icons.title_rounded),
                ),
                const SizedBox(height: 18),

                // Type
                Text('Type *', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: OfferType.values.map((t) {
                    final sel = _type == t;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _type = t);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? offerTypeColor(t) : _P.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? offerTypeColor(t) : _P.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(offerTypeIcon(t), size: 15, color: sel ? Colors.white : _P.inkSoft),
                            const SizedBox(width: 6),
                            Text(t.displayName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : _P.ink)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Prix
                Text('Prix (USD) — laisser vide pour "Sur devis"', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v != null && v.isNotEmpty && (double.tryParse(v) ?? -1) < 0) return 'Prix invalide';
                    return null;
                  },
                  decoration: _dec('Ex: 1500', Icons.attach_money_rounded),
                ),
                const SizedBox(height: 18),

                // Description
                Text('Description', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  maxLength: 400,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Décrivez votre offre en détail...', Icons.edit_note_rounded),
                ),
                const SizedBox(height: 12),

                // Image
                Text('URL de l\'image (optionnel)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _imgCtrl,
                  keyboardType: TextInputType.url,
                  decoration: _dec('https://...', Icons.image_outlined),
                ),
                const SizedBox(height: 18),

                // Visibilité
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _P.line)),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_rounded, color: _isActive ? _P.green : _P.inkSoft, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Visible sur le catalogue et l\'accueil', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink))),
                      Switch(value: _isActive, activeColor: _P.green, onChanged: (v) => setState(() => _isActive = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _saving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(widget.existing == null ? 'Publier l\'offre' : 'Enregistrer', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: _P.inkSoft, fontSize: 13),
        prefixIcon: Icon(icon, color: _P.rose, size: 20),
        filled: true,
        fillColor: _P.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET POUR LE HOME : "OFFRES DU MOMENT"
// ═══════════════════════════════════════════════════════════════════════════
class ThixHomeOffersSection extends ConsumerWidget {
  const ThixHomeOffersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(activeOffersProvider);

    return offersAsync.when(
      data: (offers) {
        if (offers.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(width: 4, height: 20, decoration: BoxDecoration(color: _P.rose, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text('Offres du moment', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: offers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _HomeOfferCard(offer: offers[i]),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _HomeOfferCard extends StatelessWidget {
  final ProviderOfferModel offer;
  const _HomeOfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final color = offerTypeColor(offer.type);
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push('/thix-weeding/provider/detail/${offer.providerId}');
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _P.line),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  offer.imageUrl != null
                      ? Image.network(offer.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: color.withOpacity(0.15), child: Icon(offerTypeIcon(offer.type), size: 40, color: color)))
                      : Container(color: color.withOpacity(0.15), child: Icon(offerTypeIcon(offer.type), size: 40, color: color)),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                      child: Text(offer.type.displayName.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(offer.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                        const SizedBox(height: 2),
                        Text(offer.providerBusinessName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10.5, color: _P.inkSoft, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Text(
                      offer.price != null ? '${offer.price!.toStringAsFixed(0)}\$' : 'Sur devis',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: _P.rose),
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
