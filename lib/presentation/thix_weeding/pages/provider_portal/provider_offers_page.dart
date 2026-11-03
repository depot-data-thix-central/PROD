// lib/presentation/thix_weeding/pages/provider_portal/provider_offers_page.dart
// ============================================================================
// THIX WEDDING — GESTION DES OFFRES / SERVICES / MENUS (PRODUCTION v5)
// ✅ PHOTOS MULTIPLES : grille avec cases à cocher + "Tout sélectionner"
// ✅ VIDÉOS (galerie/caméra, max 3)
// ✅ DESCRIPTION jusqu'à 5000 caractères (compteur)
// ✅ CATÉGORIE d'événement (Mariage, Fiançailles, Anniversaire...)
// ✅ PROMOTION complète (% + prix barré + période)
// ✅ POINTS FORTS, capacité, durée
// ✅ UPLOAD WEB-COMPATIBLE : Uint8List + uploadBinary (zéro dart:io)
// ✅ Rétro-compat : image_url = 1ère photo cochée (anciens fichiers OK)
// ============================================================================
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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

const _offerEventCategories = [
  'Mariage',
  'Fiançailles',
  'Anniversaire',
  'Corporate',
  'Religieux',
  'Baptême',
  'Autre',
];

const _maxPhotos = 12;
const _maxVideos = 3;
const _maxDesc = 5000;

// ═══════════════════════════════════════════════════════════════════════════
// MÉDIA (photo ou vidéo) : déjà uploadé (url) OU en attente (bytes)
// ═══════════════════════════════════════════════════════════════════════════
class _Media {
  final String key;
  final String? url; // déjà en ligne
  final Uint8List? bytes; // en attente d'upload
  final String name;
  bool selected;

  _Media({
    required this.key,
    this.url,
    this.bytes,
    required this.name,
    this.selected = true,
  });

  bool get isPending => bytes != null;
}

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
// FORMULAIRE v5 — ✅ MULTI-PHOTOS + VIDÉOS + PROMO + 5000 CARACTÈRES
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
  late final TextEditingController _capCtrl;
  late final TextEditingController _durCtrl;
  late final TextEditingController _oldPriceCtrl;
  final _highlightCtrl = TextEditingController();
  late OfferType _type;

  // ✅ MULTI-CATÉGORIES (1 à 3 catégories par offre)
  final Set<ProviderCategory> _categories = {};

  // ✅ CATÉGORIE D'ÉVÉNEMENT
  String? _eventCategory;

  bool _isActive = true;
  bool _saving = false;

  // ✅ PROMOTION
  bool _promo = false;
  int _promoPercent = 10;
  DateTime? _promoStart;
  DateTime? _promoEnd;

  // ✅ POINTS FORTS
  List<String> _highlights = [];

  // ✅ MÉDIAS (photos + vidéos) avec sélection
  final List<_Media> _images = [];
  final List<_Media> _videos = [];
  bool _uploading = false;
  String _uploadStep = '';
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _priceCtrl = TextEditingController(text: e?.price != null ? e!.price!.toStringAsFixed(0) : '');
    _capCtrl = TextEditingController();
    _durCtrl = TextEditingController();
    _oldPriceCtrl = TextEditingController();
    _type = e?.type ?? OfferType.service;
    _isActive = e?.isActive ?? true;

    // ✅ Chargement initial des catégories
    if (e != null && e.categories.isNotEmpty) {
      _categories.addAll(e.categories);
    } else {
      _categories.add(widget.provider.category);
    }

    // Chargement initial des photos/vidéos
    if (e != null) {
      if (e.imageUrl != null && e.imageUrl!.isNotEmpty) {
        _images.add(_Media(key: e.imageUrl!, url: e.imageUrl!, name: 'photo'));
      }
      for (final u in e.galleryUrls) {
        if (u.isNotEmpty && !_images.any((m) => m.url == u)) {
          _images.add(_Media(key: u, url: u, name: 'photo'));
        }
      }
      _loadExistingRow(e.id);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _capCtrl.dispose();
    _durCtrl.dispose();
    _oldPriceCtrl.dispose();
    _highlightCtrl.dispose();
    super.dispose();
  }

  // ── Chargement des champs étendus (édition) ──
  Future<void> _loadExistingRow(String id) async {
    try {
      final row = await Supabase.instance.client
          .from('thix_weeding_offers')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null || !mounted) return;
      final vurls = List<String>.from((row['video_urls'] as List?)?.cast<String>() ?? []);
      setState(() {
        _videos.addAll(vurls.map((u) => _Media(key: u, url: u, name: 'vidéo')));
        _eventCategory = row['category'] as String?;
        _promo = row['promo_active'] == true;
        _promoPercent = (row['promo_percent'] as int?) ?? 10;
        final old = (row['promo_old_price'] as num?)?.toDouble();
        _oldPriceCtrl.text = old != null ? old.toStringAsFixed(0) : '';
        _promoStart = (row['promo_start'] as String?) != null ? DateTime.tryParse(row['promo_start']) : null;
        _promoEnd = (row['promo_end'] as String?) != null ? DateTime.tryParse(row['promo_end']) : null;
        _capCtrl.text = (row['capacity'] as int?)?.toString() ?? '';
        _durCtrl.text = (row['duration_hours'] as int?)?.toString() ?? '';
        _highlights = List<String>.from((row['highlights'] as List?)?.cast<String>() ?? []);
      });
    } catch (_) {}
  }

  // ── PICKERS PHOTOS (multi-sélection) ──
  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1600);
      if (files.isEmpty) return;
      for (final f in files) {
        if (_images.length >= _maxPhotos) break;
        final bytes = await f.readAsBytes();
        setState(() => _images.add(_Media(key: f.path, bytes: bytes, name: f.name)));
      }
      _toast('${files.length} photo(s) ajoutée(s) — cochez celles à publier', _P.blue);
    } catch (e) {
      _toast('Erreur sélection: $e', _P.red);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final f = await _picker.pickVideo(source: source, maxDuration: const Duration(minutes: 3));
      if (f == null) return;
      if (_videos.length >= _maxVideos) {
        _toast('Maximum $_maxVideos vidéos', _P.amber);
        return;
      }
      final bytes = await f.readAsBytes();
      setState(() => _videos.add(_Media(key: f.path, bytes: bytes, name: f.name)));
    } catch (e) {
      _toast('Erreur vidéo: $e', _P.red);
    }
  }

  // ── SÉLECTION GROUPÉE ──
  bool get _allImagesSelected => _images.isNotEmpty && _images.every((m) => m.selected);

  void _toggleAllImages(bool? v) {
    setState(() {
      for (final m in _images) {
        m.selected = v ?? true;
      }
    });
  }

  // ── SÉLECTION VIDÉOS ──
  bool get _allVideosSelected => _videos.isNotEmpty && _videos.every((m) => m.selected);

  void _toggleAllVideos(bool? v) {
    setState(() {
      for (final m in _videos) {
        m.selected = v ?? true;
      }
    });
  }

  // ── TOGGLE CATÉGORIE (1 min, 3 max) ──
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

  // ── UPLOAD + ENREGISTREMENT ──
  String _ext(String name) {
    final e = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    return ['png', 'jpg', 'jpeg', 'webp'].contains(e) ? e : 'jpg';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _uploadStep = 'Préparation…';
    });
    HapticFeedback.mediumImpact();

    try {
      final c = Supabase.instance.client;

      // 1) Upload des photos cochées
      final imgUrls = <String>[];
      final selImgs = _images.where((m) => m.selected).toList();
      for (var i = 0; i < selImgs.length; i++) {
        final m = selImgs[i];
        if (m.url != null) {
          imgUrls.add(m.url!);
        } else {
          setState(() => _uploadStep = 'Upload photo ${i + 1}/${selImgs.length}…');
          final path =
              'offers/${widget.provider.id}/${DateTime.now().millisecondsSinceEpoch}_${i}.${_ext(m.name)}';
          await c.storage
              .from('thix-provider-media')
              .uploadBinary(path, m.bytes!, fileOptions: const FileOptions(cacheControl: '3600', upsert: false));
          imgUrls.add(c.storage.from('thix-provider-media').getPublicUrl(path));
        }
      }

      // 2) Upload des vidéos cochées
      final vidUrls = <String>[];
      final selVids = _videos.where((m) => m.selected).toList();
      for (var i = 0; i < selVids.length; i++) {
        final m = selVids[i];
        if (m.url != null) {
          vidUrls.add(m.url!);
        } else {
          setState(() => _uploadStep = 'Upload vidéo ${i + 1}/${selVids.length}…');
          final path =
              'offers/${widget.provider.id}/videos/${DateTime.now().millisecondsSinceEpoch}_${i}.mp4';
          await c.storage
              .from('thix-provider-media')
              .uploadBinary(path, m.bytes!, fileOptions: const FileOptions(cacheControl: '3600', upsert: false, contentType: 'video/mp4'));
          vidUrls.add(c.storage.from('thix-provider-media').getPublicUrl(path));
        }
      }

      // 3) Payload complet
      setState(() => _uploadStep = 'Enregistrement…');
      final price = _priceCtrl.text.trim().isEmpty ? null : double.tryParse(_priceCtrl.text.trim());
      final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      final cover = imgUrls.isNotEmpty ? imgUrls.first : null;
      final gallery = imgUrls.length > 1 ? imgUrls.sublist(1) : <String>[];
      final categoriesList = _categories.toList();

      final extendedPayload = <String, dynamic>{
        'image_urls': imgUrls,
        'video_urls': vidUrls,
        'category': _eventCategory,
        'promo_active': _promo,
        'promo_percent': _promo ? _promoPercent : 0,
        'promo_old_price': _promo && _oldPriceCtrl.text.trim().isNotEmpty
            ? double.tryParse(_oldPriceCtrl.text.trim())
            : null,
        'promo_start': _promo ? (_promoStart ?? DateTime.now()).toIso8601String() : null,
        'promo_end': _promo ? _promoEnd?.toIso8601String() : null,
        'capacity': _capCtrl.text.trim().isEmpty ? null : int.tryParse(_capCtrl.text.trim()),
        'duration_hours': _durCtrl.text.trim().isEmpty ? null : int.tryParse(_durCtrl.text.trim()),
        'highlights': _highlights,
      };

      if (widget.existing == null) {
        await ref.read(createOfferProvider)(
          providerId: widget.provider.id,
          title: _titleCtrl.text.trim(),
          type: _type,
          description: desc,
          price: price,
          imageUrl: cover,
          galleryUrls: gallery,
          categories: categoriesList,
          isActive: _isActive,
        );
        // Mise à jour des champs étendus
        final id = (await c.from('thix_weeding_offers').select('id').eq('provider_id', widget.provider.id).order('created_at', ascending: false).limit(1).single())['id'] as String;
        await c.from('thix_weeding_offers').update(extendedPayload).eq('id', id);
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
          categories: categoriesList,
          isActive: _isActive,
        );
        await c.from('thix_weeding_offers').update(extendedPayload).eq('id', widget.existing!.id);
      }

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            widget.existing == null
                ? 'Offre publiée ✔ ${imgUrls.length} photo(s), ${vidUrls.length} vidéo(s) — Visible catalogue & accueil'
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
      if (mounted) setState(() {
        _saving = false;
        _uploadStep = '';
      });
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

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _promoStart : _promoEnd) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => isStart ? _promoStart = picked : _promoEnd = picked);
  }

  void _addHighlight() {
    final v = _highlightCtrl.text.trim();
    if (v.isEmpty || _highlights.contains(v)) return;
    setState(() {
      _highlights.add(v);
      _highlightCtrl.clear();
    });
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
                // ═══════════════════════════════════════════════════════════
                // ✅ PHOTOS MULTIPLES AVEC CASES À COCHER
                // ═══════════════════════════════════════════════════════════
                Row(
                  children: [
                    Expanded(
                      child: Text('Photos (${_images.length}/$_maxPhotos)',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                    ),
                    if (_images.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _P.rose.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('${_images.where((m) => m.selected).length} sélectionnée(s)',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _P.rose)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _allImagesSelected,
                      onChanged: _images.isEmpty ? null : _toggleAllImages,
                      fillColor: MaterialStateProperty.all(_P.rose),
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    Text('Tout sélectionner',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _P.ink)),
                    const Spacer(),
                    Text('Seules les photos cochées sont publiées',
                        style: GoogleFonts.inter(fontSize: 10, color: _P.inkSoft)),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    ..._images.map((m) => _mediaTile(m, isVideo: false)),
                    if (_images.length < _maxPhotos)
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _P.rose.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _P.rose.withOpacity(0.4), width: 1.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_outlined, color: _P.rose, size: 26),
                              const SizedBox(height: 4),
                              Text('Ajouter\n(plusieurs)',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: _P.rose)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // ═══════════════════════════════════════════════════════════
                // ✅ VIDÉOS
                // ═══════════════════════════════════════════════════════════
                Row(
                  children: [
                    Expanded(
                      child: Text('Vidéos (${_videos.length}/$_maxVideos)',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                    ),
                    if (_videos.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _P.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('${_videos.where((m) => m.selected).length} sélectionnée(s)',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _P.blue)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_videos.isNotEmpty)
                  Row(
                    children: [
                      Checkbox(
                        value: _allVideosSelected,
                        onChanged: _toggleAllVideos,
                        fillColor: MaterialStateProperty.all(_P.blue),
                        checkColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      Text('Tout sélectionner',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _P.ink)),
                    ],
                  ),
                const SizedBox(height: 8),
                ..._videos.map((m) => _mediaTile(m, isVideo: true)),
                if (_videos.length < _maxVideos)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickVideo(ImageSource.gallery),
                          icon: const Icon(Icons.video_library_outlined, size: 16),
                          label: Text('Galerie', style: GoogleFonts.inter(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickVideo(ImageSource.camera),
                          icon: const Icon(Icons.videocam_outlined, size: 16),
                          label: Text('Caméra', style: GoogleFonts.inter(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                // ═══════════════════════════════════════════════════════════
                // TITRE + TYPE + CATÉGORIE ÉVÉNEMENT
                // ═══════════════════════════════════════════════════════════
                Text('Titre de l\'offre *',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().length < 3 ? 'Titre requis (min 3 caractères)' : null,
                  decoration: _dec('Ex: Menu mariage 200 personnes', Icons.title_rounded),
                ),
                const SizedBox(height: 18),

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
                            Text(t.displayName,
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : _P.ink)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // ✅ CATÉGORIE D'ÉVÉNEMENT
                Text('Catégorie d\'événement', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _offerEventCategories.map((cat) {
                    final sel = _eventCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _eventCategory = sel ? null : cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? _P.purple : _P.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: sel ? _P.purple : _P.line),
                        ),
                        child: Text(cat,
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : _P.ink)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // ✅ MULTI-CATÉGORIES (1 à 3)
                Row(
                  children: [
                    Expanded(
                      child: Text('Catégories * (1 à 3)',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _P.rose.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('${_categories.length}/3',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _P.rose)),
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
                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : _P.ink)),
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

                // PRIX + CAPACITÉ + DURÉE
                Row(
                  children: [
                    Expanded(child: _numField('Prix (USD)', _priceCtrl, Icons.attach_money_rounded, hint: 'Vide = sur devis')),
                    const SizedBox(width: 10),
                    Expanded(child: _numField('Capacité (pers.)', _capCtrl, Icons.people_rounded, hint: 'Ex: 250')),
                    const SizedBox(width: 10),
                    Expanded(child: _numField('Durée (h)', _durCtrl, Icons.schedule_rounded, hint: 'Ex: 8')),
                  ],
                ),
                const SizedBox(height: 20),

                // ═══════════════════════════════════════════════════════════
                // ✅ PROMOTION
                // ═══════════════════════════════════════════════════════════
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _P.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _promo ? _P.amber : _P.line, width: _promo ? 2 : 1),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _promo,
                        activeColor: _P.amber,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Promotion en cours',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _P.ink)),
                        subtitle: Text('Badge promo + prix barré sur le catalogue',
                            style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft)),
                        onChanged: (v) => setState(() => _promo = v),
                      ),
                      if (_promo) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Remise : $_promoPercent%',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _P.amber)),
                                  Slider(
                                    value: _promoPercent.toDouble(),
                                    min: 5,
                                    max: 70,
                                    divisions: 13,
                                    activeColor: _P.amber,
                                    onChanged: (v) => setState(() => _promoPercent = v.toInt()),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: _numField('Prix barré', _oldPriceCtrl, Icons.local_offer_rounded, hint: 'Ex: 2000'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(child: _dateChip('Début', _promoStart, () => _pickDate(true))),
                            const SizedBox(width: 8),
                            Expanded(child: _dateChip('Fin', _promoEnd, () => _pickDate(false))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ═══════════════════════════════════════════════════════════
                // ✅ DESCRIPTION 5000 CARACTÈRES
                // ═══════════════════════════════════════════════════════════
                Text('Description détaillée',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 10,
                  maxLength: _maxDesc,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Décrivez votre offre en détail (jusqu\'à 5000 caractères)…', Icons.edit_note_rounded),
                ),
                const SizedBox(height: 12),

                // ═══════════════════════════════════════════════════════════
                // ✅ POINTS FORTS
                // ═══════════════════════════════════════════════════════════
                Text('Points forts', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
                const SizedBox(height: 8),
                if (_highlights.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _highlights
                        .map((h) => Chip(
                              label: Text(h, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                              backgroundColor: _P.amber.withOpacity(0.12),
                              side: BorderSide(color: _P.amber.withOpacity(0.4)),
                              deleteIcon: const Icon(Icons.close_rounded, size: 14),
                              onDeleted: () => setState(() => _highlights.remove(h)),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _highlightCtrl,
                        decoration: _dec('Ex: Montage inclus, Équipe de 10…', Icons.add_rounded),
                        onFieldSubmitted: (_) => _addHighlight(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addHighlight,
                      icon: const Icon(Icons.add_circle_rounded, color: _P.amber, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // VISIBILITÉ
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _P.line)),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_rounded, color: _isActive ? _P.green : _P.inkSoft, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Visible sur le catalogue et l\'accueil',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink))),
                      Switch(value: _isActive, activeColor: _P.green, onChanged: (v) => setState(() => _isActive = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // SAVE
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
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              const SizedBox(width: 12),
                              Text(_uploadStep.isEmpty ? 'Enregistrement…' : _uploadStep,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          )
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

  // ═════════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ═════════════════════════════════════════════════════════════════════════
  Widget _mediaTile(_Media m, {required bool isVideo}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: m.selected ? (isVideo ? _P.blue : _P.rose) : _P.line,
          width: m.selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!isVideo && m.bytes != null)
            Image.memory(m.bytes!, fit: BoxFit.cover)
          else if (!isVideo && m.url != null)
            Image.network(m.url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _P.line))
          else
            Container(
              color: _P.blue.withOpacity(0.12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_fill_rounded, color: _P.blue, size: 28),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(m.isPending ? 'Nouvelle vidéo' : 'Vidéo en ligne',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w700, color: _P.blue)),
                  ),
                ],
              ),
            ),
          // ✅ CASE À COCHER (sélection multiple)
          Positioned(
            top: 4,
            left: 4,
            child: Material(
              color: Colors.transparent,
              child: Checkbox(
                value: m.selected,
                onChanged: (v) => setState(() => m.selected = v ?? true),
                fillColor: MaterialStateProperty.all(isVideo ? _P.blue : _P.rose),
                checkColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          // Supprimer
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() {
                if (isVideo) {
                  _videos.remove(m);
                } else {
                  _images.remove(m);
                }
              }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
              ),
            ),
          ),
          if (m.isPending)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _P.amber, borderRadius: BorderRadius.circular(6)),
                child: Text('À uploader', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dateChip(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: _P.bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 14, color: _P.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(date) : '$label…',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _P.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl, IconData icon, {String? hint}) => TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _dec(hint ?? label, icon),
    );

  InputDecoration _dec(String hint, IconData icon, {String? hint2}) => InputDecoration(
        hintText: hint2 ?? hint,
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
                  Container(width: 4, height: 20, decoration: BoxDecoration(color: _P.rose, borderRadius: BorderRadius.circular(2))),
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
