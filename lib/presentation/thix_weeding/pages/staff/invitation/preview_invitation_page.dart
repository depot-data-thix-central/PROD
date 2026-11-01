// lib/presentation/thix_weeding/pages/staff/invitation/preview_invitation_page.dart
// ============================================================================
// THIX WEDDING — INVITATION STUDIO v5 (PRODUCTION)
// ✅ Erreur de build corrigée (FontFeature.smallCaps n'existe pas → supprimé)
// ✅ 10 modèles prêts, ultra propres / royal : 6 avec photo, 4 sans photo
// ✅ Aperçu live + miniatures réelles des 10 modèles
// ✅ Textes, heure, lieu, couleurs, photo → sauvegarde JSONB Supabase
// ✅ Rechargement automatique du design enregistré
// ============================================================================
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/thix_weeding_models.dart';

// ═══════════════════════════════════════════════════════════════════════════
// DESIGN SYSTEM & HELPERS
// ═══════════════════════════════════════════════════════════════════════════
class _R {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color gold = Color(0xFFD4AF37);
  static const Color rose = Color(0xFFE31C4E);
  static const Color green = Color(0xFF059669);
  static const Color cream = Color(0xFFFFFBF5);
  static const Color text = Color(0xFF111827);
  static const Color text2 = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  static BoxDecoration card() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      );
}

const List<String> _kMonths = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];
const List<String> _kDays = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

String _nm(String? s, String fb) {
  final t = (s ?? '').trim();
  return t.isEmpty ? fb : t;
}

String _ini(String s) {
  final t = s.trim();
  if (t.isEmpty) return '';
  return String.fromCharCode(t.runes.first).toUpperCase();
}

/// Couleur de texte lisible sur un fond donné
Color _on(Color bg) => bg.computeLuminance() > 0.45 ? const Color(0xFF23201C) : Colors.white;

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

// ═══════════════════════════════════════════════════════════════════════════
// CONFIG (stockée en JSONB : thix_weeding_weddings.invitation_config)
// ═══════════════════════════════════════════════════════════════════════════
class InvitationConfig {
  String templateId;
  String heroImageUrl;
  String titleText;
  String introText;
  String outroText;
  String timeText;
  String placeText;
  Color primaryColor;
  Color bgColor;
  String fontStyle;

  InvitationConfig({
    this.templateId = 'gold_ornate',
    this.heroImageUrl = '',
    this.titleText = 'Save The Date',
    this.introText = 'Nous avons l\'honneur de vous inviter au mariage de',
    this.outroText = 'Venez célébrer cet amour avec nous.',
    this.timeText = '',
    this.placeText = '',
    this.primaryColor = const Color(0xFFC9A24B),
    this.bgColor = const Color(0xFFFBF7EE),
    this.fontStyle = 'playfair_display',
  });

  InvitationConfig copyWith({Color? primaryColor, Color? bgColor, String? templateId}) {
    return InvitationConfig(
      templateId: templateId ?? this.templateId,
      heroImageUrl: heroImageUrl,
      titleText: titleText,
      introText: introText,
      outroText: outroText,
      timeText: timeText,
      placeText: placeText,
      primaryColor: primaryColor ?? this.primaryColor,
      bgColor: bgColor ?? this.bgColor,
      fontStyle: fontStyle,
    );
  }

  factory InvitationConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return InvitationConfig();

    Color parseColor(dynamic hex, Color fallback) {
      if (hex is! String || hex.isEmpty) return fallback;
      try {
        final clean = hex.replaceAll('#', '');
        return Color(int.parse('FF$clean', radix: 16));
      } catch (_) {
        return fallback;
      }
    }

    String str(String key, String fb) {
      final v = map[key];
      if (v is String && v.trim().isNotEmpty) return v;
      return fb;
    }

    final d = InvitationConfig();
    return InvitationConfig(
      templateId: str('template_id', d.templateId),
      heroImageUrl: (map['hero_image_url'] as String?) ?? '',
      titleText: str('title_text', d.titleText),
      introText: str('intro_text', d.introText),
      outroText: (map['outro_text'] as String?) ?? d.outroText,
      timeText: (map['time_text'] as String?) ?? '',
      placeText: (map['place_text'] as String?) ?? '',
      primaryColor: parseColor(map['primary_color'], d.primaryColor),
      bgColor: parseColor(map['background_color'], d.bgColor),
      fontStyle: str('font_style', d.fontStyle),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'template_id': templateId,
      'hero_image_url': heroImageUrl,
      'title_text': titleText,
      'intro_text': introText,
      'outro_text': outroText,
      'time_text': timeText,
      'place_text': placeText,
      'primary_color': _hex(primaryColor),
      'background_color': _hex(bgColor),
      'font_style': fontStyle,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LES 10 MODÈLES
// ═══════════════════════════════════════════════════════════════════════════
enum TemplateType {
  goldOrnate, //      1. Cadre ornemental or + photo fondue            (photo)
  blackFloral, //     2. Noir & or floral + photo en cercle            (photo)
  roseGarden, //      3. Paysage, roses blanches + photo               (photo)
  ringsScroll, //     4. Photo en haut + bandeau blanc ornemental      (photo)
  oliveWatercolor, // 5. Feuillage aquarelle olive & or                (sans photo)
  laurelMonogram, //  6. Monogramme dans couronne de laurier or        (sans photo)
  royalNavy, //       7. Bleu nuit royal, double cadre or              (sans photo)
  burgundyArch, //    8. Bordeaux & or, arche dorée                    (sans photo)
  arcWindow, //       9. Photo en arche, rose poudré                   (photo)
  midnightPhoto, //  10. Photo plein cadre, voile nuit & or            (photo)
}

extension TemplateExt on TemplateType {
  String get id {
    switch (this) {
      case TemplateType.goldOrnate: return 'gold_ornate';
      case TemplateType.blackFloral: return 'black_floral';
      case TemplateType.roseGarden: return 'rose_garden';
      case TemplateType.ringsScroll: return 'rings_scroll';
      case TemplateType.oliveWatercolor: return 'olive_watercolor';
      case TemplateType.laurelMonogram: return 'laurel_monogram';
      case TemplateType.royalNavy: return 'royal_navy';
      case TemplateType.burgundyArch: return 'burgundy_arch';
      case TemplateType.arcWindow: return 'arc_window';
      case TemplateType.midnightPhoto: return 'midnight_photo';
    }
  }

  String get label {
    switch (this) {
      case TemplateType.goldOrnate: return 'Or Ornemental';
      case TemplateType.blackFloral: return 'Noir & Or';
      case TemplateType.roseGarden: return 'Roses Garden';
      case TemplateType.ringsScroll: return 'Alliances';
      case TemplateType.oliveWatercolor: return 'Olive Aquarelle';
      case TemplateType.laurelMonogram: return 'Laurier';
      case TemplateType.royalNavy: return 'Bleu Royal';
      case TemplateType.burgundyArch: return 'Bordeaux Arche';
      case TemplateType.arcWindow: return 'Arche Photo';
      case TemplateType.midnightPhoto: return 'Nuit Royale';
    }
  }

  bool get hasPhoto {
    switch (this) {
      case TemplateType.oliveWatercolor:
      case TemplateType.laurelMonogram:
      case TemplateType.royalNavy:
      case TemplateType.burgundyArch:
        return false;
      default:
        return true;
    }
  }

  /// Ratio largeur / hauteur de la carte
  double get aspect => this == TemplateType.roseGarden ? 1.5 : (this == TemplateType.blackFloral || this == TemplateType.laurelMonogram || this == TemplateType.royalNavy || this == TemplateType.burgundyArch) ? 0.72 : 0.70;

  Color get bg {
    switch (this) {
      case TemplateType.goldOrnate: return const Color(0xFFFBF7EE);
      case TemplateType.blackFloral: return const Color(0xFFF7F6F3);
      case TemplateType.roseGarden: return const Color(0xFFF4F3F1);
      case TemplateType.ringsScroll: return Colors.white;
      case TemplateType.oliveWatercolor: return Colors.white;
      case TemplateType.laurelMonogram: return Colors.white;
      case TemplateType.royalNavy: return const Color(0xFF0F1B3D);
      case TemplateType.burgundyArch: return const Color(0xFF5B1428);
      case TemplateType.arcWindow: return const Color(0xFFFBF1EE);
      case TemplateType.midnightPhoto: return const Color(0xFF0B0B10);
    }
  }

  Color get accent {
    switch (this) {
      case TemplateType.goldOrnate: return const Color(0xFFC9A24B);
      case TemplateType.blackFloral: return const Color(0xFFC9A24B);
      case TemplateType.roseGarden: return const Color(0xFFB5476E);
      case TemplateType.ringsScroll: return const Color(0xFFD19A3A);
      case TemplateType.oliveWatercolor: return const Color(0xFF9A7B2F);
      case TemplateType.laurelMonogram: return const Color(0xFFC2A25C);
      case TemplateType.royalNavy: return const Color(0xFFD4AF37);
      case TemplateType.burgundyArch: return const Color(0xFFD9B66A);
      case TemplateType.arcWindow: return const Color(0xFFB98A5A);
      case TemplateType.midnightPhoto: return const Color(0xFFD4AF37);
    }
  }

  static TemplateType fromId(String? id) {
    for (final t in TemplateType.values) {
      if (t.id == id) return t;
    }
    return TemplateType.goldOrnate;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════════════════════════
final weddingInvitationProvider = FutureProvider.family<WeddingModel, String>((ref, weddingId) async {
  final data = await Supabase.instance.client.from('thix_weeding_weddings').select().eq('id', weddingId).single();
  return WeddingModel.fromJson(data);
});

// ═══════════════════════════════════════════════════════════════════════════
// DONNÉES D'AFFICHAGE (noms, date, lieu…)
// ═══════════════════════════════════════════════════════════════════════════
class _D {
  final InvitationConfig c;
  final String bride, groom, place, time;
  final DateTime? date;

  _D(this.c, WeddingModel w)
      : bride = _nm(w.brideName, 'Marie'),
        groom = _nm(w.groomName, 'Jean'),
        date = w.weddingDate,
        place = c.placeText.trim().isNotEmpty ? c.placeText.trim() : _nm(w.venue, ''),
        time = c.timeText.trim();

  String get dateLong => date == null ? 'Date à définir' : '${date!.day} ${_kMonths[date!.month - 1]} ${date!.year}';
  String get weekday => date == null ? '' : _kDays[date!.weekday - 1];
  String get dayNum => date == null ? '' : '${date!.day}';
  String get monthYear => date == null ? '' : '${_kMonths[date!.month - 1]} ${date!.year}';
  String get whenLine => time.isEmpty ? dateLong : '$dateLong  ·  $time';
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════
class PreviewInvitationPage extends ConsumerStatefulWidget {
  final String weddingId;
  const PreviewInvitationPage({super.key, required this.weddingId});

  @override
  ConsumerState<PreviewInvitationPage> createState() => _PreviewInvitationPageState();
}

class _PreviewInvitationPageState extends ConsumerState<PreviewInvitationPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _introCtrl;
  late final TextEditingController _outroCtrl;
  late final TextEditingController _timeCtrl;
  late final TextEditingController _placeCtrl;

  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  InvitationConfig _config = InvitationConfig();
  TemplateType _selectedTemplate = TemplateType.goldOrnate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: _config.titleText);
    _introCtrl = TextEditingController(text: _config.introText);
    _outroCtrl = TextEditingController(text: _config.outroText);
    _timeCtrl = TextEditingController(text: _config.timeText);
    _placeCtrl = TextEditingController(text: _config.placeText);
    _loadSaved();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _introCtrl.dispose();
    _outroCtrl.dispose();
    _timeCtrl.dispose();
    _placeCtrl.dispose();
    super.dispose();
  }

  /// Recharge le design déjà enregistré
  Future<void> _loadSaved() async {
    try {
      final row = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select('invitation_config')
          .eq('id', widget.weddingId)
          .maybeSingle();
      final raw = row?['invitation_config'];
      Map<String, dynamic>? map;
      if (raw is Map) {
        map = Map<String, dynamic>.from(raw);
      } else if (raw is String && raw.isNotEmpty) {
        try {
          map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        } catch (_) {}
      }
      if (map == null || map.isEmpty || !mounted) return;
      final cfg = InvitationConfig.fromMap(map);
      setState(() {
        _config = cfg;
        _selectedTemplate = TemplateExt.fromId(cfg.templateId);
        _titleCtrl.text = cfg.titleText;
        _introCtrl.text = cfg.introText;
        _outroCtrl.text = cfg.outroText;
        _timeCtrl.text = cfg.timeText;
        _placeCtrl.text = cfg.placeText;
      });
    } catch (e) {
      debugPrint('[Invitation] load error: $e');
    }
  }

  void _selectTemplate(TemplateType t) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTemplate = t;
      _config.templateId = t.id;
      _config.bgColor = t.bg;
      _config.primaryColor = t.accent;
    });
  }

  Future<void> _uploadHeroImage() async {
    if (_isUploadingPhoto) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 88);
      if (picked != null) {
        final fileName = '${widget.weddingId}_hero_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bytes = await picked.readAsBytes();
        final storage = Supabase.instance.client.storage.from('thix-weeding-gallery');
        await storage.uploadBinary(fileName, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
        final publicUrl = storage.getPublicUrl(fileName);
        if (!mounted) return;
        setState(() => _config.heroImageUrl = publicUrl);
        await _saveConfig();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur upload: $e'), backgroundColor: _R.rose));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveConfig() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      _config.titleText = _titleCtrl.text;
      _config.introText = _introCtrl.text;
      _config.outroText = _outroCtrl.text;
      _config.timeText = _timeCtrl.text;
      _config.placeText = _placeCtrl.text;
      _config.templateId = _selectedTemplate.id;

      await Supabase.instance.client
          .from('thix_weeding_weddings')
          .update({'invitation_config': _config.toMap()})
          .eq('id', widget.weddingId);

      ref.invalidate(weddingInvitationProvider(widget.weddingId));

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Design enregistré ✓', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: _R.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur sauvegarde: $e'), backgroundColor: _R.rose));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weddingAsync = ref.watch(weddingInvitationProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.cream,
      appBar: AppBar(
        title: const Text('Studio d\'Invitation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _saveConfig,
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _R.blue))
                : const Icon(Icons.save_alt, color: _R.blue),
            tooltip: 'Enregistrer',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: weddingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (wedding) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── APERÇU LIVE ───────────────────────────────────
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 22, spreadRadius: 1, offset: const Offset(0, 8))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AspectRatio(
                        aspectRatio: _selectedTemplate.aspect,
                        child: RepaintBoundary(child: _buildTemplate(_selectedTemplate, _config, wedding)),
                      ),
                    ),

                    // ── 10 MODÈLES (miniatures réelles) ───────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Row(
                        children: [
                          Text('Choisir un modèle', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _R.text)),
                          const Spacer(),
                          Text('10 modèles', style: GoogleFonts.inter(fontSize: 11, color: _R.text2, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 168,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: TemplateType.values.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _templateThumb(TemplateType.values[i], wedding),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── TEXTES ────────────────────────────────────────
                    _SectionCard(
                      title: 'Contenu Texte',
                      icon: Icons.text_fields,
                      children: [
                        _InputField(label: 'Titre Principal', controller: _titleCtrl, onChanged: (v) => setState(() => _config.titleText = v)),
                        const SizedBox(height: 12),
                        _InputField(label: 'Message d\'Accueil', controller: _introCtrl, maxLines: 2, onChanged: (v) => setState(() => _config.introText = v)),
                        const SizedBox(height: 12),
                        _InputField(label: 'Mot de Fin / RSVP', controller: _outroCtrl, maxLines: 2, onChanged: (v) => setState(() => _config.outroText = v)),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _InputField(label: 'Heure (ex : 14h00)', controller: _timeCtrl, onChanged: (v) => setState(() => _config.timeText = v))),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: _InputField(label: 'Lieu (sinon lieu du mariage)', controller: _placeCtrl, onChanged: (v) => setState(() => _config.placeText = v))),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── APPARENCE ─────────────────────────────────────
                    _SectionCard(
                      title: 'Apparence',
                      icon: Icons.palette_outlined,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ColorPickerTile(
                                label: 'Couleur Accent',
                                selected: _config.primaryColor,
                                colors: const [
                                  Color(0xFFC9A24B), Color(0xFFD4AF37), Color(0xFFB5476E), Color(0xFFE31C4E),
                                  Color(0xFF0B3B8F), Color(0xFF7A7A3A), Color(0xFF059669), Color(0xFF14110F),
                                ],
                                onChanged: (c) => setState(() => _config.primaryColor = c),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ColorPickerTile(
                                label: 'Arrière-plan',
                                selected: _config.bgColor,
                                colors: const [
                                  Colors.white, Color(0xFFFBF7EE), Color(0xFFFBF1EE), Color(0xFFF4F3F1),
                                  Color(0xFF0F1B3D), Color(0xFF5B1428), Color(0xFF0B0B10),
                                ],
                                onChanged: (c) => setState(() => _config.bgColor = c),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: _R.border)),
                          child: Row(children: [
                            Icon(_selectedTemplate.hasPhoto ? Icons.photo_camera_outlined : Icons.hide_image_outlined, size: 16, color: _R.text2),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedTemplate.hasPhoto ? 'Ce modèle affiche votre photo de couple.' : 'Ce modèle est sans photo (ultra épuré).',
                                style: GoogleFonts.inter(fontSize: 11, color: _R.text2, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isUploadingPhoto ? null : _uploadHeroImage,
                          icon: _isUploadingPhoto
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload_file),
                          label: Text(_config.heroImageUrl.isNotEmpty ? 'Changer la photo' : 'Ajouter une photo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _R.blue,
                            side: const BorderSide(color: _R.border),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                        if (_config.heroImageUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(image: NetworkImage(_config.heroImageUrl), fit: BoxFit.cover),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => setState(() => _config.heroImageUrl = ''),
                              icon: const Icon(Icons.delete_outline, size: 16, color: _R.rose),
                              label: const Text('Retirer la photo', style: TextStyle(color: _R.rose, fontSize: 12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Miniature RÉELLE du modèle (même rendu, réduit)
  Widget _templateThumb(TemplateType t, WeddingModel wedding) {
    final isSel = _selectedTemplate == t;
    final cfg = isSel ? _config : _config.copyWith(primaryColor: t.accent, bgColor: t.bg, templateId: t.id);
    return GestureDetector(
      onTap: () => _selectTemplate(t),
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 96,
              height: 126,
              padding: const EdgeInsets.all(4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSel ? _R.blue : _R.border, width: isSel ? 2.2 : 1),
                boxShadow: isSel ? [BoxShadow(color: _R.blue.withValues(alpha: 0.25), blurRadius: 10)] : [],
              ),
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(width: 300, height: 300 / t.aspect, child: _buildTemplate(t, cfg, wedding)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: isSel ? _R.blue : _R.text)),
            const SizedBox(height: 2),
            Text(t.hasPhoto ? 'Avec photo' : 'Sans photo', style: GoogleFonts.inter(fontSize: 9, color: _R.text2, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplate(TemplateType t, InvitationConfig cfg, WeddingModel wedding) {
    final d = _D(cfg, wedding);
    switch (t) {
      case TemplateType.goldOrnate: return _TplGoldOrnate(d);
      case TemplateType.blackFloral: return _TplBlackFloral(d);
      case TemplateType.roseGarden: return _TplRoseGarden(d);
      case TemplateType.ringsScroll: return _TplRingsScroll(d);
      case TemplateType.oliveWatercolor: return _TplOliveWatercolor(d);
      case TemplateType.laurelMonogram: return _TplLaurelMonogram(d);
      case TemplateType.royalNavy: return _TplRoyalNavy(d);
      case TemplateType.burgundyArch: return _TplBurgundyArch(d);
      case TemplateType.arcWindow: return _TplArcWindow(d);
      case TemplateType.midnightPhoto: return _TplMidnightPhoto(d);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS UI COMMUNS
// ═══════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: _R.blue),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final ValueChanged<String> onChanged;
  const _InputField({required this.label, required this.controller, this.maxLines = 1, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _R.text2)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _R.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _R.blue, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _ColorPickerTile extends StatelessWidget {
  final String label;
  final Color selected;
  final List<Color> colors;
  final ValueChanged<Color> onChanged;
  const _ColorPickerTile({required this.label, required this.selected, required this.colors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: _R.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _R.text2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: colors.map((c) {
              final isSelected = c.toARGB32() == selected.toARGB32();
              return GestureDetector(
                onTap: () => onChanged(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? _R.blue : _R.border, width: isSelected ? 2 : 1),
                    boxShadow: isSelected ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)] : [],
                  ),
                  child: isSelected ? Icon(Icons.check, size: 14, color: _on(c)) : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BRIQUES DES MODÈLES
// ═══════════════════════════════════════════════════════════════════════════

/// Facteur d'échelle : 1.0 pour une carte de 340 px de large
class _S {
  final double k;
  const _S(this.k);
  double call(double v) => v * k;
}

class _TplBase extends StatelessWidget {
  final Widget Function(BuildContext, _S, Size) builder;
  const _TplBase(this.builder);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 340.0;
      final h = box.maxHeight.isFinite ? box.maxHeight : w * 1.4;
      return builder(ctx, _S(w / 340), Size(w, h));
    });
  }
}

/// Réduit automatiquement le texte s'il dépasse (jamais d'overflow)
class _Fit extends StatelessWidget {
  final double width;
  final Widget child;
  const _Fit({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(width: width, child: child),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final String url;
  final Color accent;
  const _Photo({required this.url, required this.accent});

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => LayoutBuilder(builder: (c, b) {
          final m = math.min(b.maxWidth.isFinite ? b.maxWidth : 120.0, b.maxHeight.isFinite ? b.maxHeight : 120.0);
          return Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent.withValues(alpha: 0.30), accent.withValues(alpha: 0.10)],
              ),
            ),
            child: Icon(Icons.favorite_rounded, size: m * 0.22, color: accent.withValues(alpha: 0.65)),
          );
        });
    if (url.isEmpty) return placeholder();
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => placeholder(),
      loadingBuilder: (c, child, p) => p == null ? child : placeholder(),
    );
  }
}

class _Diamond extends StatelessWidget {
  final Color color;
  final double s;
  final double lineW;
  const _Diamond({required this.color, required this.s, this.lineW = 44});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: s * lineW, height: s * 1, color: color.withValues(alpha: 0.7)),
      SizedBox(width: s * 6),
      Transform.rotate(angle: math.pi / 4, child: Container(width: s * 5, height: s * 5, color: color)),
      SizedBox(width: s * 6),
      Container(width: s * lineW, height: s * 1, color: color.withValues(alpha: 0.7)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PEINTRES (ornements dessinés, aucun fichier image requis)
// ═══════════════════════════════════════════════════════════════════════════

/// Feuille / pétale : base → pointe
void _leaf(Canvas canvas, Offset base, double ang, double len, Paint fill, [Paint? stroke]) {
  final tip = base + Offset(math.cos(ang), math.sin(ang)) * len;
  final n = Offset(-math.sin(ang), math.cos(ang)) * len * 0.30;
  final mid = base + (tip - base) * 0.5;
  final path = Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, base.dx, base.dy);
  canvas.drawPath(path, fill);
  if (stroke != null) canvas.drawPath(path, stroke);
}

/// Un coin ornemental (origine = coin, axes vers l'intérieur)
void _paintCorner(Canvas canvas, Color color, double u, double w) {
  final line = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 1.5
    ..strokeCap = StrokeCap.round;
  final fill = Paint()..color = color;

  final outer = Path()
    ..moveTo(0, u * 0.72)
    ..quadraticBezierTo(u * 0.05, u * 0.05, u * 0.72, 0);
  final inner = Path()
    ..moveTo(u * 0.10, u * 0.46)
    ..quadraticBezierTo(u * 0.14, u * 0.14, u * 0.46, u * 0.10);
  canvas.drawPath(outer, line);
  canvas.drawPath(inner, line);

  canvas.drawCircle(Offset(u * 0.21, u * 0.21), u * 0.05, line);
  canvas.drawCircle(Offset(u * 0.21, u * 0.21), u * 0.02, fill);
  canvas.drawCircle(Offset(u * 0.33, u * 0.33), u * 0.014, fill);

  const th = math.pi * 0.35;
  _leaf(canvas, Offset(u * 0.07, u * 0.38), th, u * 0.17, fill);
  _leaf(canvas, Offset(u * 0.38, u * 0.07), math.pi / 2 - th, u * 0.17, fill);
  _leaf(canvas, Offset(u * 0.04, u * 0.56), 0.9, u * 0.13, fill);
  _leaf(canvas, Offset(u * 0.56, u * 0.04), math.pi / 2 - 0.9, u * 0.13, fill);
}

class _CornerFramePainter extends CustomPainter {
  final Color color;
  final double inset, corner, thin;
  const _CornerFramePainter({required this.color, required this.inset, required this.corner, required this.thin});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(inset, inset, size.width - 2 * inset, size.height - 2 * inset);
    canvas.drawRect(
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thin,
    );
    void corner0(Offset o, double sx, double sy) {
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.scale(sx, sy);
      _paintCorner(canvas, color, corner, thin);
      canvas.restore();
    }

    corner0(r.topLeft, 1, 1);
    corner0(r.topRight, -1, 1);
    corner0(r.bottomLeft, 1, -1);
    corner0(r.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _CornerFramePainter old) => old.color != color || old.inset != inset || old.corner != corner;
}

/// Branche de feuillage (aquarelle)
class _SprigPainter extends CustomPainter {
  final Color leafColor;
  final Color lineColor;
  const _SprigPainter({required this.leafColor, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p0 = Offset(w * 0.04, h * 0.96);
    final p1 = Offset(w * 0.30, h * 0.18);
    final p2 = Offset(w * 0.96, h * 0.06);

    Offset q(double t) => Offset(
          (1 - t) * (1 - t) * p0.dx + 2 * (1 - t) * t * p1.dx + t * t * p2.dx,
          (1 - t) * (1 - t) * p0.dy + 2 * (1 - t) * t * p1.dy + t * t * p2.dy,
        );
    double ang(double t) {
      final dx = 2 * (1 - t) * (p1.dx - p0.dx) + 2 * t * (p2.dx - p1.dx);
      final dy = 2 * (1 - t) * (p1.dy - p0.dy) + 2 * t * (p2.dy - p1.dy);
      return math.atan2(dy, dx);
    }

    final stem = Path()..moveTo(p0.dx, p0.dy);
    for (var i = 1; i <= 24; i++) {
      final o = q(i / 24);
      stem.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      stem,
      Paint()
        ..color = lineColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final fill = Paint()..color = leafColor.withValues(alpha: 0.32);
    final stroke = Paint()
      ..color = lineColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    const n = 9;
    for (var i = 1; i <= n; i++) {
      final t = i / (n + 1);
      final base = q(t);
      final a = ang(t);
      final len = math.min(w, h) * (0.26 - 0.12 * t);
      _leaf(canvas, base, a - 0.75, len, fill, stroke);
      _leaf(canvas, base, a + 0.75, len * 0.92, fill, stroke);
    }
    _leaf(canvas, q(1.0), ang(1.0), math.min(w, h) * 0.16, fill, stroke);
  }

  @override
  bool shouldRepaint(covariant _SprigPainter old) => old.leafColor != leafColor || old.lineColor != lineColor;
}

/// Couronne de laurier ouverte en haut
class _LaurelPainter extends CustomPainter {
  final Color color;
  const _LaurelPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height * 0.5;
    final rx = size.width * 0.40, ry = size.height * 0.40;
    final stemPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final fill = Paint()..color = color;

    for (final dir in [1.0, -1.0]) {
      final stem = Path();
      const steps = 20;
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final a = math.pi / 2 + dir * t * math.pi * 0.90;
        final pt = Offset(cx + rx * math.cos(a), cy + ry * math.sin(a));
        if (i == 0) {
          stem.moveTo(pt.dx, pt.dy);
        } else {
          stem.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(stem, stemPaint);

      for (var i = 1; i <= steps; i++) {
        final t = i / steps;
        final a = math.pi / 2 + dir * t * math.pi * 0.90;
        final base = Offset(cx + rx * math.cos(a), cy + ry * math.sin(a));
        final dx = dir * (-rx * math.sin(a));
        final dy = dir * (ry * math.cos(a));
        final tangent = math.atan2(dy, dx);
        final len = math.min(rx, ry) * (0.26 - 0.07 * t);
        _leaf(canvas, base, tangent - 0.65, len, fill);
        _leaf(canvas, base, tangent + 0.65, len * 0.9, fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LaurelPainter old) => old.color != color;
}

/// Fleur stylisée noir & or
class _FlowerPainter extends CustomPainter {
  final Color body;
  final Color line;
  const _FlowerPainter({required this.body, required this.line});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final fill = Paint()..color = body;
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.025;

    for (final a in [0.35, math.pi - 0.35, math.pi * 0.5 + 0.2]) {
      _leaf(canvas, c, a, r * 1.05, fill, stroke);
    }
    for (var k = 0; k < 5; k++) {
      final a = k * 2 * math.pi / 5 - math.pi / 2;
      _leaf(canvas, c, a, r * 0.78, fill, stroke);
    }
    canvas.drawCircle(c, r * 0.17, fill);
    canvas.drawCircle(c, r * 0.17, stroke);
    final dot = Paint()..color = line;
    for (var k = 0; k < 8; k++) {
      final a = k * 2 * math.pi / 8;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * 0.1, r * 0.018, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowerPainter old) => old.body != body || old.line != line;
}

class _SwooshPainter extends CustomPainter {
  final Color dark;
  final Color line;
  const _SwooshPainter({required this.dark, required this.line});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final shape = Path()
      ..moveTo(w, h * 0.74)
      ..cubicTo(w * 0.84, h * 0.78, w * 0.76, h * 0.90, w * 0.70, h)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(shape, Paint()..color = dark);
    final edge = Path()
      ..moveTo(w, h * 0.715)
      ..cubicTo(w * 0.82, h * 0.77, w * 0.73, h * 0.89, w * 0.665, h);
    canvas.drawPath(
      edge,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _SwooshPainter old) => old.dark != dark || old.line != line;
}

/// Rose blanche + feuilles + petites fleurs
class _RosePainter extends CustomPainter {
  final Color tint;
  const _RosePainter(this.tint);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * 0.70;
    final leafFill = Paint()..color = const Color(0xFF9DB89A).withValues(alpha: 0.85);
    for (final a in [-2.7, -0.6, 0.8, 2.1]) {
      _leaf(canvas, c, a, r * 1.55, leafFill);
    }
    final shades = [Colors.white, const Color(0xFFF6F0ED), Colors.white, const Color(0xFFEFE6E1)];
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.03
      ..color = const Color(0xFFBDB3AD);
    for (var i = 0; i < 4; i++) {
      final rr = r * (1.0 - i * 0.22);
      canvas.drawCircle(c, rr, Paint()..color = shades[i]);
      canvas.drawArc(Rect.fromCircle(center: c, radius: rr), i * 1.3, 3.8, false, line);
    }
    final pk = Paint()..color = tint.withValues(alpha: 0.50);
    canvas.drawCircle(c + Offset(r * 1.15, -r * 0.55), r * 0.26, pk);
    canvas.drawCircle(c + Offset(-r * 0.95, r * 0.85), r * 0.20, pk);
    canvas.drawCircle(c + Offset(r * 0.25, r * 1.2), r * 0.16, pk);
  }

  @override
  bool shouldRepaint(covariant _RosePainter old) => old.tint != tint;
}

/// Bandeau blanc avec bosse centrale + volutes (modèle « Alliances »)
class _PanelPainter extends CustomPainter {
  final Color panel;
  final Color ornament;
  const _PanelPainter({required this.panel, required this.ornament});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final by = h * 0.075;
    final path = Path()
      ..moveTo(0, by)
      ..lineTo(w * 0.27, by)
      ..cubicTo(w * 0.33, by, w * 0.33, 0, w * 0.41, 0)
      ..lineTo(w * 0.59, 0)
      ..cubicTo(w * 0.67, 0, w * 0.67, by, w * 0.73, by)
      ..lineTo(w, by)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, Paint()..color = panel);

    final p = Paint()
      ..color = ornament
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    void scroll(int dir) {
      final o = Offset(w * 0.5, by * 0.55);
      final path2 = Path()
        ..moveTo(o.dx, o.dy)
        ..cubicTo(o.dx + dir * w * 0.06, o.dy - by * 0.9, o.dx + dir * w * 0.14, o.dy + by * 0.6, o.dx + dir * w * 0.24, o.dy - by * 0.1)
        ..cubicTo(o.dx + dir * w * 0.30, o.dy - by * 0.5, o.dx + dir * w * 0.36, o.dy + by * 0.2, o.dx + dir * w * 0.40, o.dy + by * 0.55);
      canvas.drawPath(path2, p);
      canvas.drawCircle(Offset(o.dx + dir * w * 0.40, o.dy + by * 0.55), w * 0.008, Paint()..color = ornament);
    }

    scroll(1);
    scroll(-1);
    final f = Paint()..color = ornament;
    final c = Offset(w * 0.5, by * 0.55);
    for (var k = 0; k < 5; k++) {
      final a = k * 2 * math.pi / 5 - math.pi / 2;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * w * 0.016, w * 0.011, f);
    }
    canvas.drawCircle(c, w * 0.007, Paint()..color = panel);
  }

  @override
  bool shouldRepaint(covariant _PanelPainter old) => old.panel != panel || old.ornament != ornament;
}

class _ArchPainter extends CustomPainter {
  final Color color;
  final double inset, width;
  const _ArchPainter({required this.color, required this.inset, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final left = inset, right = size.width - inset, top = inset, bottom = size.height - inset;
    final r = (right - left) / 2;
    final path = Path()
      ..moveTo(left, bottom)
      ..lineTo(left, top + r)
      ..arcTo(Rect.fromLTWH(left, top, 2 * r, 2 * r), math.pi, math.pi, false)
      ..lineTo(right, bottom)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(covariant _ArchPainter old) => old.color != color || old.inset != inset || old.width != width;
}

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE 1 — OR ORNEMENTAL (avec photo fondue)
// ═══════════════════════════════════════════════════════════════════════════
class _TplGoldOrnate extends StatelessWidget {
  final _D d;
  const _TplGoldOrnate(this.d);

  @override
  Widget build(BuildContext context) {
    return _TplBase((ctx, s, size) {
      final c = d.c;
      final gold = c.primaryColor;
      final ink = _on(c.bgColor);
      return Container(
        color: c.bgColor,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _CornerFramePainter(color: gold, inset: s(12), corner: s(96), thin: s(1)))),
          Column(children: [
            SizedBox(height: s(40)),
            Expanded(
              flex: 46,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: s(40)),
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) => const RadialGradient(
                    center: Alignment(0, -0.15),
                    radius: 0.85,
                    colors: [Colors.black, Colors.black, Colors.transparent],
                    stops: [0.0, 0.62, 1.0],
                  ).createShader(r),
                  child: _Photo(url: c.heroImageUrl, accent: gold),
                ),
              ),
            ),
            Expanded(
              flex: 40,
              child: _Fit(
                width: size.width - s(96),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(c.titleText.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: s(9), letterSpacing: s(3), fontWeight: FontWeight.w700, color: ink.withValues(alpha: 0.8))),
                  SizedBox(height: s(8)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(d.bride.toUpperCase(), style: GoogleFonts.montserrat(fontSize: s(21), fontWeight: FontWeight.w800, color: ink)),
                      SizedBox(width: s(8)),
                      Text('&', style: GoogleFonts.playfairDisplay(fontSize: s(30), fontStyle: FontStyle.italic, color: gold)),
                      SizedBox(width: s(8)),
                      Text(d.groom.toUpperCase(), style: GoogleFonts.montserrat(fontSize: s(21), fontWeight: FontWeight.w800, color: ink)),
                    ]),
                  ),
                  SizedBox(height: s(10)),
                  Text(c.introText, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontSize: s(9.5), height: 1.5, color: ink.withValues(alpha: 0.72))),
                  SizedBox(height: s(12)),
                  Text(d.whenLine.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: s(10.5), letterSpacing: s(1.4), fontWeight: FontWeight.w600, color: ink)),
                  if (d.place.isNotEmpty) ...[
                    SizedBox(height: s(3)),
                    Text(d.place.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: s(10.5), letterSpacing: s(1), fontWeight: FontWeight.w800, color: ink)),
                  ],
                  if (c.outroText.trim().isNotEmpty) ...[
                    SizedBox(height: s(8)),
                    Text(c.outroText, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.playfairDisplay(fontSize: s(10), fontStyle: FontStyle.italic, color: gold)),
                  ],
                ]),
              ),
            ),
            SizedBox(height: s(28)),
          ]),
        ]),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE 2 — NOIR & OR FLORAL (photo en cercle)
// ═══════════════════════════════════════════════════════════════════════════
class _TplBlackFloral extends StatelessWidget {
  final _D d;
  const _TplBlackFloral(this.d);

  @override
  Widget build(BuildContext context) {
    return _TplBase((ctx, s, size) {
      final c = d.c;
      final gold = c.primaryColor;
      final ink = _on(c.bgColor);
      const dark = Color(0xFF14110F);
      final dia = size.width * 0.72;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.bgColor, Color.lerp(c.bgColor, Colors.grey, 0.12)!],
          ),
        ),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _SwooshPainter(dark: dark, line: gold))),
          Positioned(
            right: s(6),
            bottom: s(8),
            width: s(74),
            height: s(74),
            child: CustomPaint(painter: _FlowerPainter(body: dark, line: gold)),
          ),
          Positioned(
            top: s(22),
            left: size.width * 0.14,
            width: dia,
            height: dia,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: -s(6),
                top: -s(6),
                right: -s(6),
                bottom: -s(6),
                child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold, width: s(1)))),
              ),
              Positioned.fill(child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: dark, width: s(8))))),
              Positioned.fill(child: Padding(padding: EdgeInsets.all(s(8)), child: ClipOval(child: _Photo(url: c.heroImageUrl, accent: gold)))),
              Positioned(right: -s(18), bottom: s(4), width: s(86), height: s(86), child: CustomPaint(painter: _FlowerPainter(body: dark, line: gold))),
            ]),
          ),
          Positioned(
            left: s(22),
            right: s(22),
            top: s(22) + dia + s(16),
            bottom: s(34),
            child: _Fit(
              width: size.width - s(44),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(c.titleText.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.cormorantGaramond(fontSize: s(10.5), letterSpacing: s(2.5), fontWeight: FontWeight.w700, color: ink)),
                SizedBox(height: s(4)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${d.bride} & ${d.groom}', style: GoogleFonts.greatVibes(fontSize: s(42), color: gold)),
                ),
                SizedBox(height: s(2)),
                Text(c.introText.toUpperCase(), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(10), letterSpacing: s(1.2), fontWeight: FontWeight.w600, color: ink.withValues(alpha: 0.85))),
                SizedBox(height: s(8)),
                Text(d.whenLine.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.playfairDisplay(fontSize: s(16), letterSpacing: s(0.8), color: ink)),
                if (d.place.isNotEmpty) ...[
                  SizedBox(height: s(3)),
                  Text(d.place, textAlign: TextAlign.center, style: GoogleFonts.cormorantGaramond(fontSize: s(12), fontStyle: FontStyle.italic, color: ink.withValues(alpha: 0.8))),
                ],
                if (c.outroText.trim().isNotEmpty) ...[
                  SizedBox(height: s(6)),
                  Text(c.outroText, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(10.5), color: gold, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
          ),
        ]),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE 3 — ROSES GARDEN (paysage, photo + roses)
// ═══════════════════════════════════════════════════════════════════════════
class _TplRoseGarden extends StatelessWidget {
  final _D d;
  const _TplRoseGarden(this.d);

  @override
  Widget build(BuildContext context) {
    return _TplBase((ctx, s, size) {
      final c = d.c;
      final accent = c.primaryColor;
      final ink = _on(c.bgColor);
      return Container(
        color: c.bgColor,
        child: Stack(children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(s(7)),
              child: Container(decoration: BoxDecoration(border: Border.all(color: ink.withValues(alpha: 0.7), width: s(1)))),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(s(11)),
              child: Container(decoration: BoxDecoration(border: Border.all(color: ink.withValues(alpha: 0.25), width: s(0.8)))),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(s(24), s(22), s(16), s(22)),
              child: Row(children: [
                Expanded(
                  flex: 10,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned.fill(child: _Photo(url: c.heroImageUrl, accent: accent)),
                    Positioned(top: -s(16), left: -s(16), width: s(64), height: s(64), child: CustomPaint(painter: _RosePainter(accent))),
                    Positioned(bottom: -s(16), right: -s(12), width: s(64), height: s(64), child: CustomPaint(painter: _RosePainter(accent))),
                  ]),
                ),
                SizedBox(width: s(18)),
                Expanded(
                  flex: 13,
                  child: _Fit(
                    width: s(190),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(c.titleText.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.lora(fontSize: s(9.5), letterSpacing: s(2), color: ink.withValues(alpha: 0.8))),
                      SizedBox(height: s(4)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${d.bride} & ${d.groom}', style: GoogleFonts.alexBrush(fontSize: s(36), color: ink)),
                      ),
                      SizedBox(height: s(4)),
                      Text(c.introText.toUpperCase(), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.lora(fontSize: s(8.5), letterSpacing: s(1), height: 1.5, color: ink.withValues(alpha: 0.75))),
                      SizedBox(height: s(10)),
                      Container(
                        width: s(190),
                        padding: EdgeInsets.symmetric(vertical: s(6)),
                        decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: accent, width: s(1)))),
                        child: Text(d.time.isEmpty ? d.dateLong.toUpperCase() : '${d.dateLong.toUpperCase()} | ${d.time.toUpperCase()}', textAlign: TextAlign.center, style: GoogleFonts.lora(fontSize: s(10), fontWeight: FontWeight.w600, letterSpacing: s(0.6), color: ink)),
                      ),
                      SizedBox(height: s(10)),
                      Icon(Icons.church_outlined, size: s(20), color: accent),
                      SizedBox(height: s(4)),
                      if (d.place.isNotEmpty) Text(d.place.toUpperCase(), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.lora(fontSize: s(9.5), fontWeight: FontWeight.w700, letterSpacing: s(0.8), color: ink)),
                      if (c.outroText.trim().isNotEmpty) ...[
                        SizedBox(height: s(4)),
                        Text(c.outroText, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.lora(fontSize: s(8.5), fontStyle: FontStyle.italic, color: ink.withValues(alpha: 0.7))),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE 4 — ALLIANCES (photo en haut + bandeau ornemental)
// ═══════════════════════════════════════════════════════════════════════════
class _TplRingsScroll extends StatelessWidget {
  final _D d;
  const _TplRingsScroll(this.d);

  @override
  Widget build(BuildContext context) {
    return _TplBase((ctx, s, size) {
      final c = d.c;
      final accent = c.primaryColor;
      final ink = _on(c.bgColor);
      final panelTop = size.height * 0.45;
      return Container(
        color: const Color(0xFFEDEDED),
        child: Stack(children: [
          Positioned(top: 0, left: 0, right: 0, height: size.height * 0.53, child: _Photo(url: c.heroImageUrl, accent: accent)),
          Positioned(
            top: panelTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(painter: _PanelPainter(panel: c.bgColor, ornament: accent)),
          ),
          Positioned(
            top: panelTop + s(34),
            left: s(22),
            right: s(22),
            bottom: s(18),
            child: _Fit(
              width: size.width - s(44),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(c.introText.toUpperCase(), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontSize: s(7.5), letterSpacing: s(1.2), color: accent, fontWeight: FontWeight.w500)),
                SizedBox(height: s(4)),
                FittedBox(fit: BoxFit.scaleDown, child: Text('${d.bride} & ${d.groom}', style: GoogleFonts.pinyonScript(fontSize: s(40), color: accent))),
                SizedBox(height: s(6)),
                Container(width: s(150), height: s(1), color: accent.withValues(alpha: 0.5)),
                SizedBox(height: s(8)),
                Text(d.dateLong.toUpperCase(), style: GoogleFonts.montserrat(fontSize: s(10.5), letterSpacing: s(1.4), fontWeight: FontWeight.w700, color: accent)),
                if (d.time.isNotEmpty) ...[
                  SizedBox(height: s(3)),
                  Text(d.time.toUpperCase(), style: GoogleFonts.montserrat(fontSize: s(17), fontWeight: FontWeight.w800, color: ink.withValues(alpha: 0.85))),
                ],
                SizedBox(height: s(6)),
                Container(width: s(150), height: s(1), color: accent.withValues(alpha: 0.5)),
                SizedBox(height: s(6)),
                if (d.place.isNotEmpty) Text(d.place, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontSize: s(8.5), color: accent, fontWeight: FontWeight.w500)),
                if (c.outroText.trim().isNotEmpty) ...[
                  SizedBox(height: s(3)),
                  Text(c.outroText, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontSize: s(9), fontWeight: FontWeight.w700, color: ink.withValues(alpha: 0.8))),
                ],
              ]),
            ),
          ),
        ]),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE 5 — OLIVE AQUARELLE (sans photo)
// ═══════════════════════════════════════════════════════════════════════════
class _TplOliveWatercolor extends StatelessWidget {
  final _D d;
  const _TplOliveWatercolor(this.d);

  @override
  Widget build(BuildContext context) {
    return _TplBase((ctx, s, size) {
      final c = d.c;
      final gold = c.primaryColor;
      final ink = _on(c.bgColor);
      final olive = Color.lerp(gold, const Color(0xFF6B7B3A), 0.65)!;
      return Container(
        color: c.bgColor,
        child: Stack(children: [
          Positioned(top: -s(6), left: -s(10), width: s(200), height: s(170), child: CustomPaint(painter: _SprigPainter(leafColor: olive, lineColor: gold))),
          Positioned(
            bottom: -s(6),
            right: -s(10),
            width: s(200),
            height: s(170),
            child: Transform.rotate(angle: math.pi, child: CustomPaint(painter: _SprigPainter(leafColor: olive, lineColor: gold))),
          ),
          Positioned(
            bottom: s(6),
            left: -s(14),
            width: s(120),
            height: s(100),
            child: Transform.rotate(angle: -math.pi / 2.3, child: CustomPaint(painter: _SprigPainter(leafColor: olive, lineColor: gold))),
          ),
          Center(
            child: _Fit(
              width: size.width - s(110),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FittedBox(fit: BoxFit.scaleDown, child: Text(d.bride, style: GoogleFonts.pinyonScript(fontSize: s(38), color: gold))),
                Text('ET', style: GoogleFonts.cormorantGaramond(fontSize: s(10), letterSpacing: s(3), color: gold, fontWeight: FontWeight.w700)),
                FittedBox(fit: BoxFit.scaleDown, child: Text(d.groom, style: GoogleFonts.pinyonScript(fontSize: s(38), color: gold))),
                SizedBox(height: s(12)),
                Text(c.titleText.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: s(7), letterSpacing: s(1.6), color: ink.withValues(alpha: 0.65), fontWeight: FontWeight.w600)),
                SizedBox(height: s(4)),
                Text(c.introText.toUpperCase(), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontSize: s(6.8), letterSpacing: s(1.1), height: 1.6, color: ink.withValues(alpha: 0.6))),
                SizedBox(height: s(12)),
                if (d.weekday.isNotEmpty) Text(d.weekday.toUpperCase(), style: GoogleFonts.montserrat(fontSize: s(7.5), letterSpacing: s(2.4), color: ink.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
                SizedBox(height: s(4)),
                Row(children: [
                  Expanded(child: Container(height: s(1), color: ink.withValues(alpha: 0.55))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: s(12)),
                    child: Text(d.dayNum.isEmpty ? '—' : d.dayNum, style: GoogleFonts.cormorantGaramond(fontSize: s(34), color: ink, fontWeight: FontWeight.w500)),
                  ),
                  Expanded(child: Container(height: s(1), color: ink.withValues(alpha: 0.55))),
                ]),
                SizedBox(height: s(2)),
                Text(d.monthYear.toUpperCase(), style: GoogleFonts.montserrat(fontSize: s(7.5), letterSpacing: s(2), color: ink.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
                SizedBox(height: s(10)),
                if (d.time.isNotEmpty) Text(d.time.toUpperCase(), style: GoogleFonts.montserrat(fontSize: s(7.5), letterSpacing: s(1.2), color: ink.withValues(alpha: 0.7))),
                if (d.place.isNotEmpty) Text(d.place.toUpperCase(), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontSize: s(7.5), letterSpacing: s(1.2), color: ink.withValues(alpha: 0.7))),
                if (c.outroText.trim().isNotEmpty) ...[
                  SizedBox(height: s(8)),
                  Text(c.outroText, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(11), fontStyle: FontStyle.italic, color: gold)),
                ],
              ]),
            ),
          ),
        ]),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE 6 — LAURIER & MONOGRAMME (sans photo)
// ═══════════════════════════════════════════════════════════════════════════
class _TplLaurelMonogram extends StatelessWidget {
  final _D d;
  const _TplLaurelMonogram(this.d);

  @override
  Widget build(BuildContext context) {
    return _TplBase((ctx, s, size) {
      final c = d.c;
      final gold = c.primaryColor;
      final ink = _on(c.bgColor);
      final mono = '${_ini(d.bride)}${_ini(d.groom)}';
      return Container(
        color: c.bgColor,
        child: Column(children: [
          SizedBox(height: s(34)),
          SizedBox(
            height: size.height * 0.27,
            width: size.width * 0.74,
            child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(child: CustomPaint(painter: _LaurelPainter(gold))),
              Text(mono, style: GoogleFonts.allura(fontSize: s(50), color: ink.withValues(alpha: 0.82))),
            ]),
          ),
          SizedBox(height: s(6)),
          Expanded(
            child: _Fit(
              width: size.width - s(70),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FittedBox(fit: BoxFit.scaleDown, child: Text(d.bride.toUpperCase(), style: GoogleFonts.cormorantGaramond(fontSize: s(25), letterSpacing: s(5), fontWeight: FontWeight.w700, color: ink))),
                Text('et', style: GoogleFonts.cormorantGaramond(fontSize: s(14), fontStyle: FontStyle.italic, color: gold)),
                FittedBox(fit: BoxFit.scaleDown, child: Text(d.groom.toUpperCase(), style: GoogleFonts.cormorantGaramond(fontSize: s(25), letterSpacing: s(5), fontWeight: FontWeight.w700, color: ink))),
                SizedBox(height: s(14)),
                Text(c.titleText.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: s(7.5), letterSpacing: s(2.4), color: gold, fontWeight: FontWeight.w600)),
                SizedBox(height: s(8)),
                Text(c.introText, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(11.5), height: 1.5, color: ink.withValues(alpha: 0.78))),
                SizedBox(height: s(6)),
                Text(d.whenLine, textAlign: TextAlign.center, style: GoogleFonts.cormorantGaramond(fontSize: s(12.5), fontWeight: FontWeight.w700, color: ink)),
                if (d.place.isNotEmpty) ...[
                  SizedBox(height: s(6)),
                  Text(d.place, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.allura(fontSize: s(20), color: ink.withValues(alpha: 0.8))),
                ],
                if (c.outroText.trim().isNotEmpty) ...[
                  SizedBox(height: s(6)),
                  Text(c.outroText, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(11), fontStyle: FontStyle.italic, color: gold)),
                ],
              ]),
            ),
          ),
          SizedBox(height: s(26)),
        ]),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE 7 — BLEU ROYAL (sans photo)
// ═══════════════════════════════════════════════════════════════════════════
class _TplRoyalNavy extends StatelessWidget {
  final _D d;
  const _TplRoyalNavy(this.d);

  @override
  Widget build(BuildContext context) {
    return _TplBase((ctx, s, size) {
      final c = d.c;
      final gold = c.primaryColor;
      final ink = _on(c.bgColor);
      return Container(
        color: c.bgColor,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _CornerFramePainter(color: gold, inset: s(14), corner: s(70), thin: s(1.2)))),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(s(21)),
              child: Container(decoration: BoxDecoration(border: Border.all(color: gold.withValues(alpha: 0.45), width: s(0.8)))),
            ),
          ),
          Center(
            child: _Fit(
              width: size.width - s(100),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: s(62),
                  height: s(62),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold, width: s(1.2))),
                  child: Text('${_ini(d.bride)} ${_ini(d.groom)}', style: GoogleFonts.cinzel(fontSize: s(19), color: gold, fontWeight: FontWeight.w600)),
                ),
                SizedBox(height: s(14)),
                Text(c.titleText.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.cinzel(fontSize: s(9), letterSpacing: s(4), color: gold, fontWeight: FontWeight.w600)),
                SizedBox(height: s(14)),
                FittedBox(fit: BoxFit.scaleDown, child: Text(d.bride, style: GoogleFonts.cinzel(fontSize: s(25), color: ink, fontWeight: FontWeight.w500, letterSpacing: s(1.5)))),
                Text('&', style: GoogleFonts.cormorantGaramond(fontSize: s(30), fontStyle: FontStyle.italic, color: gold)),
                FittedBox(fit: BoxFit.scaleDown, child: Text(d.groom, style: GoogleFonts.cinzel(fontSize: s(25), color: ink, fontWeight: FontWeight.w500, letterSpacing: s(1.5)))),
                SizedBox(height: s(14)),
                _Diamond(color: gold, s: s.k),
                SizedBox(height: s(12)),
                Text(c.introText, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(12), fontStyle: FontStyle.italic, height: 1.45, color: ink.withValues(alpha: 0.85))),
                SizedBox(height: s(10)),
                Text(d.whenLine.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.cinzel(fontSize: s(11.5), letterSpacing: s(1.6), color: gold, fontWeight: FontWeight.w600)),
                if (d.place.isNotEmpty) ...[
                  SizedBox(height: s(4)),
                  Text(d.place, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(11.5), color: ink.withValues(alpha: 0.85))),
                ],
                if (c.outroText.trim().isNotEmpty) ...[
                  SizedBox(height: s(8)),
                  Text(c.outroText, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(10.5), fontStyle: FontStyle.italic, color: gold)),
                ],
              ]),
            ),
          ),
        ]),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE 8 — BORDEAUX & ARCHE DORÉE (sans photo)
// ═══════════════════════════════════════════════════════════════════════════
class _TplBurgundyArch extends StatelessWidget {
  final _D d;
  const _TplBurgundyArch(this.d);

  @override
  Widget build(BuildContext context) {
    return _TplBase((ctx, s, size) {
      final c = d.c;
      final gold = c.primaryColor;
      final ink = _on(c.bgColor);
      return Container(
        color: c.bgColor,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _ArchPainter(color: gold, inset: s(20), width: s(1.5)))),
          Positioned.fill(child: CustomPaint(painter: _ArchPainter(color: gold.withValues(alpha: 0.45), inset: s(28), width: s(0.8)))),
          Positioned(
            bottom: s(30),
            left: s(26),
            width: s(90),
            height: s(70),
            child: Transform.flip(flipY: true, child: CustomPaint(painter: _SprigPainter(leafColor: gold, lineColor: gold))),
          ),
          Positioned(
            bottom: s(30),
            right: s(26),
            width: s(90),
            height: s(70),
            child: Transform.flip(flipX: true, flipY: true, child: CustomPaint(painter: _SprigPainter(leafColor: gold, lineColor: gold))),
          ),
          Positioned(
            left: s(40),
            right: s(40),
            top: size.height * 0.16,
            bottom: s(96),
            child: _Fit(
              width: size.width - s(80),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(c.titleText.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.cormorantGaramond(fontSize: s(10.5), letterSpacing: s(3.5), color: gold, fontWeight: FontWeight.w700)),
                SizedBox(height: s(10)),
                FittedBox(fit: BoxFit.scaleDown, child: Text(d.bride, style: GoogleFonts.greatVibes(fontSize: s(46), color: gold))),
                Text('&', style: GoogleFonts.cormorantGaramond(fontSize: s(22), fontStyle: FontStyle.italic, color: ink.withValues(alpha: 0.9))),
                FittedBox(fit: BoxFit.scaleDown, child: Text(d.groom, style: GoogleFonts.greatVibes(fontSize: s(46), color: gold))),
                SizedBox(height: s(12)),
                _Diamond(color: gold, s: s.k, lineW: 36),
                SizedBox(height: s(10)),
                Text(c.introText, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(11.5), height: 1.45, color: ink.withValues(alpha: 0.88))),
                SizedBox(height: s(8)),
                Text(d.whenLine.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.cinzel(fontSize: s(11), letterSpacing: s(1.4), color: gold, fontWeight: FontWeight.w600)),
                if (d.place.isNotEmpty) ...[
                  SizedBox(height: s(4)),
                  Text(d.place, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(11), color: ink.withValues(alpha: 0.85))),
                ],
                if (c.outroText.trim().isNotEmpty) ...[
                  SizedBox(height: s(6)),
                  Text(c.outroText, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(10.5), fontStyle: FontStyle.italic, color: gold)),
                ],
              ]),
            ),
          ),
        ]),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE 9 — ARCHE PHOTO (rose poudré)
// ═══════════════════════════════════════════════════════════════════════════
class _TplArcWindow extends StatelessWidget {
  final _D d;
  const _TplArcWindow(this.d);

  @override
  Widget build(BuildContext context) {
    return _TplBase((ctx, s, size) {
      final c = d.c;
      final accent = c.primaryColor;
      final ink = _on(c.bgColor);
      final side = size.width * 0.17;
      final photoW = size.width - 2 * side;
      final photoH = size.height * 0.46;
      final top = s(30);
      return Container(
        color: c.bgColor,
        child: Stack(children: [
          Positioned(
            bottom: s(4),
            left: -s(16),
            width: s(120),
            height: s(100),
            child: Transform.flip(flipY: true, child: CustomPaint(painter: _SprigPainter(leafColor: accent, lineColor: accent))),
          ),
          Positioned(
            bottom: s(4),
            right: -s(16),
            width: s(120),
            height: s(100),
            child: Transform.flip(flipX: true, flipY: true, child: CustomPaint(painter: _SprigPainter(leafColor: accent, lineColor: accent))),
          ),
          Positioned(
            top: top - s(8),
            left: side - s(8),
            width: photoW + s(16),
            height: photoH + s(16),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: accent, width: s(1)),
                borderRadius: BorderRadius.vertical(top: Radius.circular(photoW / 2 + s(8))),
              ),
            ),
          ),
          Positioned(
            top: top,
            left: side,
            width: photoW,
            height: photoH,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(photoW / 2)),
              child: _Photo(url: c.heroImageUrl, accent: accent),
            ),
          ),
          Positioned(
            left: s(26),
            right: s(26),
            top: top + photoH + s(20),
            bottom: s(22),
            child: _Fit(
              width: size.width - s(52),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(c.titleText, textAlign: TextAlign.center, style: GoogleFonts.allura(fontSize: s(20), color: accent)),
                FittedBox(fit: BoxFit.scaleDown, child: Text('${d.bride.toUpperCase()}  &  ${d.groom.toUpperCase()}', style: GoogleFonts.montserrat(fontSize: s(15), letterSpacing: s(2.6), fontWeight: FontWeight.w600, color: ink))),
                SizedBox(height: s(6)),
                Text(c.introText, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.lora(fontSize: s(9), fontStyle: FontStyle.italic, height: 1.5, color: ink.withValues(alpha: 0.72))),
                SizedBox(height: s(8)),
                Text(d.whenLine.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: s(9.5), letterSpacing: s(1.8), fontWeight: FontWeight.w700, color: accent)),
                if (d.place.isNotEmpty) ...[
                  SizedBox(height: s(3)),
                  Text(d.place, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontSize: s(8.5), color: ink.withValues(alpha: 0.75))),
                ],
                if (c.outroText.trim().isNotEmpty) ...[
                  SizedBox(height: s(4)),
                  Text(c.outroText, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.lora(fontSize: s(8.5), fontStyle: FontStyle.italic, color: accent)),
                ],
              ]),
            ),
          ),
        ]),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE 10 — NUIT ROYALE (photo plein cadre + voile)
// ═══════════════════════════════════════════════════════════════════════════
class _TplMidnightPhoto extends StatelessWidget {
  final _D d;
  const _TplMidnightPhoto(this.d);

  @override
  Widget build(BuildContext context) {
    return _TplBase((ctx, s, size) {
      final c = d.c;
      final gold = c.primaryColor;
      return Container(
        color: c.bgColor,
        child: Stack(fit: StackFit.expand, children: [
          if (c.heroImageUrl.isNotEmpty)
            _Photo(url: c.heroImageUrl, accent: gold)
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(c.bgColor, gold, 0.18)!, c.bgColor],
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.35), Colors.black.withValues(alpha: 0.10), Colors.black.withValues(alpha: 0.88)],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _CornerFramePainter(color: gold, inset: s(14), corner: s(56), thin: s(1)))),
          Positioned(
            left: s(30),
            right: s(30),
            bottom: s(34),
            height: size.height * 0.44,
            child: _Fit(
              width: size.width - s(60),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(c.titleText.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.cinzel(fontSize: s(9.5), letterSpacing: s(4), color: gold, fontWeight: FontWeight.w600)),
                SizedBox(height: s(10)),
                FittedBox(fit: BoxFit.scaleDown, child: Text(d.bride, style: GoogleFonts.playfairDisplay(fontSize: s(32), fontStyle: FontStyle.italic, color: Colors.white))),
                Text('&', style: GoogleFonts.playfairDisplay(fontSize: s(24), color: gold)),
                FittedBox(fit: BoxFit.scaleDown, child: Text(d.groom, style: GoogleFonts.playfairDisplay(fontSize: s(32), fontStyle: FontStyle.italic, color: Colors.white))),
                SizedBox(height: s(12)),
                _Diamond(color: gold, s: s.k),
                SizedBox(height: s(10)),
                Text(c.introText, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(11.5), fontStyle: FontStyle.italic, color: Colors.white.withValues(alpha: 0.88))),
                SizedBox(height: s(8)),
                Text(d.whenLine.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.cinzel(fontSize: s(11.5), letterSpacing: s(1.6), color: gold, fontWeight: FontWeight.w600)),
                if (d.place.isNotEmpty) ...[
                  SizedBox(height: s(3)),
                  Text(d.place, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(11.5), color: Colors.white.withValues(alpha: 0.85))),
                ],
                if (c.outroText.trim().isNotEmpty) ...[
                  SizedBox(height: s(6)),
                  Text(c.outroText, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cormorantGaramond(fontSize: s(10.5), fontStyle: FontStyle.italic, color: gold)),
                ],
              ]),
            ),
          ),
        ]),
      );
    });
  }
}
