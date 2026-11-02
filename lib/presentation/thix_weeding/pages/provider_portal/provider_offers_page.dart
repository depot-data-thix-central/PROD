// lib/presentation/thix_weeding/pages/provider_portal/provider_offers_page.dart
// ============================================================================
// THIX WEDDING — GESTION DES OFFRES / SERVICES / MENUS (PRODUCTION v4)
// ✅ MULTI-PHOTOS : galerie horizontale (cover + gallery) avec ajout/suppression
// ✅ UPLOAD WEB-COMPATIBLE : Uint8List + uploadBinary (plus de dart:io File)
// ✅ Preview locale instantanée avant upload
// ✅ MULTI-CATÉGORIES : 1 à 3 catégories par offre (chips multi-sélection)
// ✅ Widget HOME : ThixHomeOffersSection
// ============================================================================
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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

IconData _categoryIcon(ProviderCategory c) => switch (c) {
      ProviderCategory.salle => Icons.meeting_room_rounded,
      ProviderCategory.traiteur => Icons.restaurant_rounded,
      ProviderCategory.photographe => Icons.camera_alt_rounded,
      ProviderCategory.videaste => Icons.videocam_rounded,
      ProviderCategory.decorateur => Icons.palette_rounded,
      ProviderCategory.dj => Icons.music_note_rounded,
      ProviderCategory.mc => Icons.mic_rounded,
      ProviderCategory.maquilleur => Icons.face_rounded,
      ProviderCategory.patissier => Icons.cake_rounded,
      ProviderCategory.fleuriste => Icons.local_florist_rounded,
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
            title: Text('Mes offres & services',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _P.ink)),
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
                            Text('Publiez votre première offre',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
                            const SizedBox(height: 8),
                            Text(
                                'Services, menus, formules ou promos : tout ce que vous publiez ici apparaît sur le catalogue et la page d\'accueil.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft, height: 1.5)),
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
              loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: _P.rose))),
              error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('Erreur: $e', style: GoogleFonts.inter(color: _P.inkSoft)))),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE D'OFFRE (liste du dashboard) — ✅ AVEC GALERIE MULTI-PHOTOS
// ═══════════════════════════════════════════════════════════════════════════
class _OfferCard extends ConsumerWidget {
  final ProviderOfferModel offer;
  final String providerId;
  const _OfferCard({required this.offer, required this.providerId});

  List<String> get _allImages {
    final list = <String>[];
    if ((offer.imageUrl ?? '').isNotEmpty) list.add(offer.imageUrl!);
    for (final u in offer.galleryUrls) {
      if (u.isNotEmpty && !list.contains(u)) list.add(u);
    }
    return list;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = offerTypeColor(offer.type);
    final images = _allImages;

    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _P.line),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            Stack(
              children: [
                SizedBox(
                  height: 140,
                  child: PageView.builder(
                    itemCount: images.length,
                    controller: PageController(viewportFraction: 1.0),
                    itemBuilder: (_, i) => Image.network(
                      images[i],
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 140,
                        color: color.withOpacity(0.1),
                        child: Center(child: Icon(offerTypeIcon(offer.type), size: 40, color: color)),
                      ),
                    ),
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('${images.length} photos',
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                    child: Text(offer.type.displayName.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
                // ✅ Badges catégories (1 à 3)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: offer.categories.take(2).map((c) {
                      return Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(c.displayName,
                            style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white)),
                      );
                    }).toList(),
                  ),
                ),
                if (!offer.isActive)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                          child: Icon(Icons.visibility_off_rounded, color: Colors.white, size: 40)),
                    ),
                  ),
              ],
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)])),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration:
                        BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: Icon(offerTypeIcon(offer.type), color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(offer.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _P.ink)),
                        const SizedBox(height: 2),
                        Text(offer.type.displayName,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                      ],
                    ),
                  ),
                  Switch(
                    value: offer.isActive,
                    activeColor: _P.green,
                    onChanged: (v) async {
                      HapticFeedback.selectionClick();
                      await ref.read(updateOfferProvider)(offer.id, providerId, isActive: v);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(offer.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _P.ink)),
                    ),
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
                  const SizedBox(height: 6),
                  Text(offer.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, height: 1.4)),
                ],
                // ✅ Ligne des catégories
                if (offer.categories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: offer.categories.map((c) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _P.rose.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _P.rose.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_categoryIcon(c), size: 11, color: _P.rose),
                            const SizedBox(width: 4),
                            Text(c.displayName,
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _P.rose)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration:
                          BoxDecoration(color: _P.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        offer.price != null ? '${offer.price!.toStringAsFixed(0)}\$' : 'Sur devis',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: _P.green),
                      ),
                    ),
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
        content: Text('"${offer.title}" sera définitivement retirée du catalogue.',
            style: GoogleFonts.inter(color: _P.inkSoft, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler', style: GoogleFonts.inter(color: _P.inkSoft))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _P.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Supprimer', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(deleteOfferProvider)(offer.id, providerId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Offre supprimée', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FORMULAIRE — ✅ MULTI-PHOTOS + MULTI-CATÉGORIES + UPLOAD WEB-COMPATIBLE
// ═══════════════════════════════════════════════════════════════════════════
class ProviderOfferFormPage extends ConsumerStatefulWidget {
  final ThixProviderModel provider;
  final ProviderOfferModel? existing;
  const ProviderOfferFormPage({super.key, required this.provider, this.existing});

  @override
  ConsumerState<ProviderOfferFormPage> createState() => _ProviderOfferFormPageState();
}

class _ProviderOfferFormPageState extends ConsumerState<ProviderOfferFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late OfferType _type;

  // ✅ MULTI-CATÉGORIES (1 à 3 catégories par offre)
  final Set<ProviderCategory> _categories = {};

  bool _isActive = true;
  bool _saving = false;

  final List<String> _imageUrls = [];
  final List<Uint8List> _localBytes = [];
  bool _uploading = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _priceCtrl =
        TextEditingController(text: e?.price != null ? e!.price!.toStringAsFixed(0) : '');
    _type = e?.type ?? OfferType.service;
    _isActive = e?.isActive ?? true;

    // ✅ Chargement initial des catégories
    if (e != null && e.categories.isNotEmpty) {
      _categories.addAll(e.categories);
    } else {
      // Fallback : catégorie du prestataire
      _categories.add(widget.provider.category);
    }

    // Chargement initial des photos
    if (e?.imageUrl != null && e!.imageUrl!.isNotEmpty) _imageUrls.add(e.imageUrl!);
    if (e != null) {
      for (final u in e.galleryUrls) {
        if (u.isNotEmpty) _imageUrls.add(u);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      setState(() {
        _localBytes.add(bytes);
        _imageUrls.add('');
      });
      await _uploadBytes(bytes, ext, _imageUrls.length - 1);
    } catch (e) {
      _toast('Erreur sélection image: $e', _P.red);
    }
  }

  Future<void> _uploadBytes(Uint8List bytes, String ext, int slot) async {
    setState(() => _uploading = true);
    try {
      final c = Supabase.instance.client;
      final safeExt = ['png', 'webp', 'jpg', 'jpeg'].contains(ext) ? ext : 'jpg';
      final filename =
          '${widget.provider.id}/offers/${DateTime.now().millisecondsSinceEpoch}_${slot}.$safeExt';

      await c.storage.from('thix-provider-media').uploadBinary(
            filename,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              contentType: 'image/$safeExt',
              upsert: false,
            ),
          );

      final url = c.storage.from('thix-provider-media').getPublicUrl(filename);
      if (!mounted) return;
      setState(() {
        _imageUrls[slot] = url;
      });
      _toast('Photo ${slot + 1} uploadée ✓', _P.green);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (slot < _imageUrls.length) {
          _imageUrls.removeAt(slot);
          _localBytes.removeAt(slot);
        }
      });
      _toast('Erreur upload: $e', _P.red);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _imageUrls.length) _imageUrls.removeAt(index);
      if (index < _localBytes.length) _localBytes.removeAt(index);
    });
  }

  // ✅ TOGGLE CATÉGORIE (1 min, 3 max)
  void _toggleCategory(ProviderCategory c) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_categories.contains(c)) {
        if (_categories.length > 1) {
          _categories.remove(c);
        } else {
          _toast('Au moins 1 catégorie requise', _P.amber);
        }
      } else {
        if (_categories.length < 3) {
          _categories.add(c);
        } else {
          _toast('Maximum 3 catégories par annonce', _P.amber);
        }
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final price = _priceCtrl.text.trim().isEmpty ? null : double.tryParse(_priceCtrl.text.trim());
      final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

      final cover = _imageUrls.isNotEmpty ? _imageUrls.first : null;
      final gallery = _imageUrls.length > 1 ? _imageUrls.sublist(1) : <String>[];
      final categoriesList = _categories.toList();

      if (widget.existing == null) {
        await ref.read(createOfferProvider)(
          providerId: widget.provider.id,
          title: _titleCtrl.text.trim(),
          type: _type,
          description: desc,
          price: price,
          imageUrl: cover,
          galleryUrls: gallery,
          categories: categoriesList, // ✅ MULTI-CATÉGORIES
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
          imageUrl: cover,
          galleryUrls: gallery,
          categories: categoriesList, // ✅ MULTI-CATÉGORIES
          isActive: _isActive,
        );
      }

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            widget.existing == null
                ? 'Offre publiée ✔ ${_imageUrls.length} photo(s), ${_categories.length} catégorie(s) — Visible catalogue & accueil'
                : 'Offre mise à jour ✔',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: _P.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: _P.rose,
          behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.bg,
        elevation: 0,
        title: Text(widget.existing == null ? 'Publier une offre' : 'Modifier l\'offre',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ ZONE MULTI-PHOTOS
                Row(
                  children: [
                    Expanded(
                      child: Text('Photos de l\'offre',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                    ),
                    if (_imageUrls.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: _P.rose.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('${_imageUrls.length} photo(s)',
                            style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w700, color: _P.rose)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildMultiImageUploadZone(),
                const SizedBox(height: 18),

                // Titre
                Text('Titre de l\'offre *',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().length < 3 ? 'Titre requis (min 3 caractères)' : null,
                  decoration: _dec('Ex: Menu mariage 200 personnes', Icons.title_rounded),
                ),
                const SizedBox(height: 18),

                // Type
                Text('Type *',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
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
                            Text(t.displayName,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: sel ? Colors.white : _P.ink)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // ✅ NOUVEAU : MULTI-CATÉGORIES (1 à 3)
                Row(
                  children: [
                    Expanded(
                      child: Text('Catégories * (1 à 3)',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: _P.rose.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('${_categories.length}/3',
                          style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w700, color: _P.rose)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Choisissez où cette annonce apparaîtra (home + catalogue)',
                    style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft, height: 1.3)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ProviderCategory.values.map((c) {
                    final sel = _categories.contains(c);
                    return GestureDetector(
                      onTap: () => _toggleCategory(c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: sel ? _P.rose : _P.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: sel ? _P.rose : _P.line),
                          boxShadow: sel
                              ? [BoxShadow(color: _P.rose.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_categoryIcon(c), size: 14, color: sel ? Colors.white : _P.inkSoft),
                            const SizedBox(width: 6),
                            Text(c.displayName,
                                style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: sel ? Colors.white : _P.ink)),
                            if (sel) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Prix
                Text('Prix (USD) — laisser vide pour "Sur devis"',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
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
                Text('Description',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  maxLength: 400,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Décrivez votre offre en détail...', Icons.edit_note_rounded),
                ),
                const SizedBox(height: 18),

                // Visibilité
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _P.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _P.line)),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_rounded, color: _isActive ? _P.green : _P.inkSoft, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text('Visible sur le catalogue et l\'accueil',
                              style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink))),
                      Switch(value: _isActive, activeColor: _P.green, onChanged: (v) => setState(() => _isActive = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving || _uploading ? null : _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _P.rose,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _saving || _uploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(widget.existing == null ? 'Publier l\'offre' : 'Enregistrer',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiImageUploadZone() {
    final items = <Widget>[];

    for (var i = 0; i < _imageUrls.length; i++) {
      final url = _imageUrls[i];
      final bytes = i < _localBytes.length ? _localBytes[i] : null;
      final hasUrl = url.isNotEmpty;
      items.add(_PhotoCard(
        index: i,
        imageUrl: hasUrl ? url : null,
        localBytes: (!hasUrl && bytes != null) ? bytes : null,
        isCover: i == 0,
        onRemove: () => _removeImage(i),
        isUploading: !hasUrl,
      ));
    }

    items.add(_AddPhotoCard(
      onPickGallery: () => _pickImage(ImageSource.gallery),
      onPickCamera: () => _pickImage(ImageSource.camera),
      uploading: _uploading,
    ));

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => items[i],
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
// CARTE PHOTO (uploadée ou en cours)
// ═══════════════════════════════════════════════════════════════════════════
class _PhotoCard extends StatelessWidget {
  final int index;
  final String? imageUrl;
  final Uint8List? localBytes;
  final bool isCover;
  final VoidCallback onRemove;
  final bool isUploading;

  const _PhotoCard({
    required this.index,
    required this.imageUrl,
    required this.localBytes,
    required this.isCover,
    required this.onRemove,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Container(
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isCover ? _P.rose : _P.line, width: isCover ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.network(imageUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallback())
            else if (localBytes != null)
              Image.memory(localBytes!, fit: BoxFit.cover)
            else
              _fallback(),

            if (isUploading && imageUrl == null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: const Center(
                      child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))),
                ),
              ),

            if (isCover)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _P.rose, borderRadius: BorderRadius.circular(6)),
                  child: Text('COUVERTURE',
                      style: GoogleFonts.inter(
                          fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3)),
                ),
              ),

            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        color: _P.inkSoft.withOpacity(0.1),
        child: const Icon(Icons.image_outlined, color: _P.inkSoft, size: 32),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// BOUTON "AJOUTER UNE PHOTO" (ouvre Gallery/Camera)
// ═══════════════════════════════════════════════════════════════════════════
class _AddPhotoCard extends StatelessWidget {
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final bool uploading;

  const _AddPhotoCard({
    required this.onPickGallery,
    required this.onPickCamera,
    required this.uploading,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : _showSourceChoice(context),
      child: SizedBox(
        width: 130,
        child: Container(
          decoration: BoxDecoration(
            color: _P.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _P.rose.withOpacity(0.4), style: BorderStyle.solid),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _P.rose.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.add_photo_alternate_outlined, color: _P.rose, size: 24),
                ),
                const SizedBox(height: 6),
                Text('Ajouter',
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w800, color: _P.ink)),
                Text('une photo',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _P.inkSoft)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  VoidCallback? _showSourceChoice(BuildContext context) => () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined, color: _P.rose),
                    title: Text('Depuis la galerie',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(ctx);
                      onPickGallery();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined, color: _P.rose),
                    title: Text('Prendre une photo',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(ctx);
                      onPickCamera();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET POUR LE HOME : "OFFRES DU MOMENT"
// ═══════════════════════════════════════════════════════════════════════════
class ThixHomeOffersSection extends ConsumerWidget {
  const ThixHomeOffersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(activeOffersProvider(null));

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
                  Container(
                      width: 4, height: 20, decoration: BoxDecoration(color: _P.rose, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text('Offres du moment',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink)),
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
    final allImages = <String>[];
    if ((offer.imageUrl ?? '').isNotEmpty) allImages.add(offer.imageUrl!);
    for (final u in offer.galleryUrls) {
      if (u.isNotEmpty && !allImages.contains(u)) allImages.add(u);
    }

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
                  allImages.isNotEmpty
                      ? PageView.builder(
                          itemCount: allImages.length,
                          itemBuilder: (_, i) => Image.network(
                            allImages[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: color.withOpacity(0.15),
                                child: Icon(offerTypeIcon(offer.type), size: 40, color: color)),
                          ),
                        )
                      : Container(
                          color: color.withOpacity(0.15),
                          child: Icon(offerTypeIcon(offer.type), size: 40, color: color)),
                  if (allImages.length > 1)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.photo_library_rounded, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('${allImages.length}',
                              style: GoogleFonts.inter(
                                  fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                        ]),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                      child: Text(offer.type.displayName.toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
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
                        Text(offer.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                        const SizedBox(height: 2),
                        Text(offer.providerBusinessName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 10.5, color: _P.inkSoft, fontWeight: FontWeight.w600)),
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
