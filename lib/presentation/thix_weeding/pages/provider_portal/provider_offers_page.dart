// lib/presentation/thix_weeding/pages/provider_portal/offers/provider_offer_form_page.dart
// ============================================================================
// THIX WEDDING — PUBLICATION D'OFFRE RICHE (PRODUCTION v2)
// ✅ PHOTOS MULTIPLES : pickMultiImage + cases à cocher + "Tout sélectionner"
// ✅ VIDÉOS (galerie / caméra) — jusqu'à 3
// ✅ DESCRIPTION jusqu'à 5000 caractères (compteur)
// ✅ CATÉGORIE d'événement, POINTS FORTS, capacité, durée
// ✅ PROMOTION : % + prix barré + période de validité
// ✅ Upload Storage compatible Web + Android (uploadBinary, zéro dart:io)
// ✅ Rétro-compat : image_url = 1ère photo cochée (anciennes pages OK)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';
import '../provider_offers_page.dart' show offerTypeIcon, offerTypeColor;

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

const _offerCategories = [
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
// PAGE FORMULAIRE
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
  final _picker = ImagePicker();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _capCtrl;
  late final TextEditingController _durCtrl;
  late final TextEditingController _oldPriceCtrl;
  final _highlightCtrl = TextEditingController();

  late OfferType _type;
  String? _category;
  bool _isActive = true;
  bool _promo = false;
  int _promoPercent = 10;
  DateTime? _promoStart;
  DateTime? _promoEnd;
  List<String> _highlights = [];
  List<_Media> _images = [];
  List<_Media> _videos = [];

  bool _saving = false;
  String _saveStep = '';
  bool _loadingExisting = false;

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
    if (e != null) {
      _images = [
        if (e.imageUrl != null && e.imageUrl!.isNotEmpty)
          _Media(key: e.imageUrl!, url: e.imageUrl!, name: 'photo'),
      ];
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
    setState(() => _loadingExisting = true);
    try {
      final row = await Supabase.instance.client
          .from('thix_weeding_offers')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null || !mounted) return;
      final urls = List<String>.from(
          (row['image_urls'] as List?)?.cast<String>() ??
              ((row['image_url'] as String?) != null ? [row['image_url'] as String] : []));
      final vurls = List<String>.from((row['video_urls'] as List?)?.cast<String>() ?? []);
      setState(() {
        _images = urls.map((u) => _Media(key: u, url: u, name: 'photo')).toList();
        _videos = vurls.map((u) => _Media(key: u, url: u, name: 'vidéo')).toList();
        _category = row['category'] as String?;
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
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  // ── PICKERS ──
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

  // ── UPLOAD + ENREGISTREMENT ──
  String _ext(String name) {
    final e = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    return ['png', 'jpg', 'jpeg', 'webp'].contains(e) ? e : 'jpg';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveStep = 'Préparation…';
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
          setState(() => _saveStep = 'Upload photo ${i + 1}/${selImgs.length}…');
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
          setState(() => _saveStep = 'Upload vidéo ${i + 1}/${selVids.length}…');
          final path =
              'offers/${widget.provider.id}/videos/${DateTime.now().millisecondsSinceEpoch}_${i}.mp4';
          await c.storage
              .from('thix-provider-media')
              .uploadBinary(path, m.bytes!, fileOptions: const FileOptions(cacheControl: '3600', upsert: false, contentType: 'video/mp4'));
          vidUrls.add(c.storage.from('thix-provider-media').getPublicUrl(path));
        }
      }

      // 3) Payload complet
      setState(() => _saveStep = 'Enregistrement…');
      final now = DateTime.now().toIso8601String();
      final price = _priceCtrl.text.trim().isEmpty ? null : double.tryParse(_priceCtrl.text.trim());
      final payload = <String, dynamic>{
        'provider_id': widget.provider.id,
        'title': _titleCtrl.text.trim(),
        'offer_type': _type.name,
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'price': price,
        'currency': widget.provider.currency,
        'image_url': imgUrls.isNotEmpty ? imgUrls.first : null, // rétro-compat
        'image_urls': imgUrls,
        'video_urls': vidUrls,
        'category': _category,
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
        'is_active': _isActive,
        'updated_at': now,
      };

      if (widget.existing != null) {
        await c.from('thix_weeding_offers').update(payload).eq('id', widget.existing!.id);
      } else {
        payload['id'] = DateTime.now().millisecondsSinceEpoch.toString();
        payload['created_at'] = now;
        await c.from('thix_weeding_offers').insert(payload);
      }

      ref.invalidate(providerOffersProvider(widget.provider.id));
      ref.invalidate(activeOffersProvider);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          widget.existing == null
              ? 'Offre publiée ✔ Visible catalogue & accueil'
              : 'Offre mise à jour ✔',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _P.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (mounted) _toast('Erreur: $e', _P.red);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveStep = '';
        });
      }
    }
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
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

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.bg,
        elevation: 0,
        title: Text(
          widget.existing == null ? 'Publier une offre' : 'Modifier l\'offre',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink),
        ),
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator(color: _P.rose))
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── 1) PHOTOS ──
                    _sectionTitle('Photos (${_images.length}/$_maxPhotos)', Icons.photo_library_rounded, _P.rose),
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

                    // ── 2) VIDÉOS ──
                    _sectionTitle('Vidéos (${_videos.length}/$_maxVideos)', Icons.videocam_rounded, _P.blue),
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

                    // ── 3) INFORMATIONS ──
                    _sectionTitle('Informations', Icons.info_rounded, _P.ink),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => v == null || v.trim().length < 3 ? 'Titre requis (min 3 caractères)' : null,
                      decoration: _dec('Ex: Menu mariage 200 personnes', Icons.title_rounded),
                    ),
                    const SizedBox(height: 14),
                    Text('Type *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink)),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 14),
                    Text('Catégorie d\'événement', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _offerCategories.map((cat) {
                        final sel = _category == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _category = sel ? null : cat),
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
                    const SizedBox(height: 14),
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

                    // ── 4) PROMOTION ──
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

                    // ── 5) DESCRIPTION 5000 ──
                    _sectionTitle('Description détaillée', Icons.edit_note_rounded, _P.ink),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 10,
                      maxLength: _maxDesc,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _dec('Décrivez votre offre en détail (jusqu\'à 5000 caractères)…', Icons.edit_note_rounded),
                    ),
                    const SizedBox(height: 12),

                    // ── 6) POINTS FORTS ──
                    _sectionTitle('Points forts', Icons.star_rounded, _P.amber),
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

                    // ── 7) VISIBILITÉ ──
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

                    // ── SAVE ──
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _P.rose,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _saving
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                  const SizedBox(width: 12),
                                  Text(_saveStep, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                                ],
                              )
                            : Text(widget.existing == null ? 'Publier l\'offre' : 'Enregistrer',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
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
          color: m.selected ? _P.rose : _P.line,
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
                fillColor: MaterialStateProperty.all(_P.rose),
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

  Widget _sectionTitle(String label, IconData icon, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: _P.ink)),
      ],
    );
  }

  Widget _numField(String label, TextEditingController ctrl, IconData icon, {String? hint}) => TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _dec(label, icon, hint: hint),
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
