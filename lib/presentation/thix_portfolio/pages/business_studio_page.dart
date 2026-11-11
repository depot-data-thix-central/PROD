// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — STUDIO D'ÉDITION (OWNER)
//  Fichier  : lib/presentation/thix_portfolio/pages/business_studio_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.5.0 — Novembre 2026 (sections toujours affichées)
// ════════════════════════════════════════════════════════════════════════════
//
//  Route : /business/edit/:id
//
//  ✅ v1.5 : FIX « Sections vides » — le Studio fusionne les sections de la
//            base avec les 8 sections par défaut. Les 8 lignes sont donc
//            TOUJOURS affichées et éditables ; une section absente de la base
//            est créée au premier enregistrement / toggle / déplacement.
//  ✅ v1.3 : + carte « Rubriques avancées » (10 rubriques, photos + vidéos)
//  ✅ v1.2 : upload de photos PARTOUT.
//  ✅ v1.3.1 : i18n FR/EN inline.
//
//  Upload → bucket Supabase `business-media` (public).
// ════════════════════════════════════════════════════════════════════════════

import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../data/business_repository.dart';
import '../models/business_bundle.dart';
import 'business_extras_studio.dart';

// ─── i18n minimaliste FR/EN ─────────────────────────────────────────────────
String _lang(BuildContext c) =>
    Localizations.localeOf(c).languageCode.toLowerCase();

/// Retourne la chaîne française si la locale courante est `fr`, sinon l'anglaise.
String _s(BuildContext c, String fr, String en) =>
    _lang(c) == 'fr' ? fr : en;

/// Helper pour les types de contact (fallback sur `name` si non traduit).
String _contactLabel(BuildContext c, ContactChannelType t) {
  switch (t.name) {
    case 'phone':
      return _s(c, 'Téléphone', 'Phone');
    case 'email':
      return _s(c, 'Email', 'Email');
    case 'whatsapp':
      return _s(c, 'WhatsApp', 'WhatsApp');
    case 'website':
      return _s(c, 'Site web', 'Website');
    case 'address':
      return _s(c, 'Adresse', 'Address');
    case 'instagram':
      return _s(c, 'Instagram', 'Instagram');
    case 'facebook':
      return _s(c, 'Facebook', 'Facebook');
    default:
      return t.name;
  }
}
// ────────────────────────────────────────────────────────────────────────────

const String _kThemeRoute = '/business/theme';
String _kPublicRoute(String thixId) => '/b/$thixId';

// ============================================================================
// PALETTE
// ============================================================================

class _Prism {
  _Prism._();
  static const Color bg = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE6E9F2);
  static const Color ink = Color(0xFF0B1220);
  static const Color inkSoft = Color(0xFF3E4C63);
  static const Color inkMuted = Color(0xFF8A94A6);
}

class _StudioLogger {
  static const _tag = 'BizStudio';
  static void info(String m) {
    if (kDebugMode) debugPrint('[$_tag] $m');
  }

  static void error(String m, Object e) => debugPrint('[$_tag] $m : $e');
}

// ============================================================================
// UPLOAD GÉNÉRIQUE (Storage) — utilisé par TOUTES les images du studio
// ============================================================================

/// Envoie [file] vers le bucket public `business-media` et retourne l'URL.
Future<String> uploadBusinessImage(XFile file, String folder) async {
  final bytes = await file.readAsBytes();
  final ext = file.name.contains('.')
      ? file.name.split('.').last.toLowerCase()
      : 'jpg';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final rand = Random().nextInt(9999).toString().padLeft(4, '0');
  final path = '$folder/sections-$stamp-$rand.$ext';
  final bucket = Supabase.instance.client.storage.from('business-media');
  await bucket.uploadBinary(
    path,
    bytes,
    fileOptions: FileOptions(
      contentType: (file.mimeType == null || file.mimeType!.isEmpty)
          ? 'image/$ext'
          : file.mimeType,
      upsert: true,
    ),
  );
  return bucket.getPublicUrl(path);
}

/// Ouvre la galerie, compresse, envoie et retourne l'URL (null si annulé).
Future<String?> pickAndUploadImage(
  BuildContext context, {
  required String folder,
}) async {
  final picker = ImagePicker();
  final XFile? file = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
    maxWidth: 1400,
  );
  if (file == null) return null;
  return uploadBusinessImage(file, folder);
}

// ============================================================================
// CHAMP IMAGE = URL + BOUTON UPLOAD + MINIATURE
// ============================================================================

class _ImageField extends StatelessWidget {
  const _ImageField({
    required this.controller,
    required this.label,
    required this.onPick,
    this.uploading = false,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onPick;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final url = value.text.trim();
          final hasImage = url.startsWith('http');
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const ColoredBox(color: _Prism.border),
                          errorWidget: (_, __, ___) => const ColoredBox(
                              color: _Prism.border,
                              child: Icon(Icons.broken_image_outlined,
                                  size: 18, color: _Prism.inkMuted)),
                        )
                      : const ColoredBox(
                          color: _Prism.border,
                          child: Icon(Icons.image_outlined,
                              size: 18, color: _Prism.inkMuted),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    isDense: true,
                    filled: true,
                    fillColor: _Prism.bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _Prism.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _Prism.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: ThixPolicy.primary, width: 2)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    tooltip: _s(context, 'Téléverser une image', 'Upload an image'),
                    icon: uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.photo_camera_rounded,
                            size: 20, color: Colors.white),
                    onPressed: uploading ? null : onPick,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// PAGE
// ============================================================================

class BusinessStudioPage extends ConsumerStatefulWidget {
  const BusinessStudioPage({super.key, required this.businessId});
  final String businessId;

  @override
  ConsumerState<BusinessStudioPage> createState() =>
      _BusinessStudioPageState();
}

class _BusinessStudioPageState extends ConsumerState<BusinessStudioPage> {
  Business? _business;

  /// Sections réellement présentes en base.
  List<BusinessSection> _sections = [];
  bool _loading = true;
  bool _saving = false;

  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _claim = TextEditingController();
  late final TextEditingController _description = TextEditingController();
  late final TextEditingController _sector = TextEditingController();
  late final TextEditingController _city = TextEditingController();
  late final TextEditingController _sinceYear = TextEditingController();
  late final TextEditingController _employees = TextEditingController();
  late final TextEditingController _website = TextEditingController();
  late final TextEditingController _phone = TextEditingController();
  late final TextEditingController _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name, _claim, _description, _sector, _city,
      _sinceYear, _employees, _website, _phone, _email,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      ref.invalidate(ownerBusinessBundleProvider(widget.businessId));
      final bundle =
          await ref.read(ownerBusinessBundleProvider(widget.businessId).future);
      final b = bundle.business;
      _name.text = b.name;
      _claim.text = b.claim ?? '';
      _description.text = b.description ?? '';
      _sector.text = b.sector ?? '';
      _city.text = b.city ?? '';
      _sinceYear.text = b.sinceYear?.toString() ?? '';
      _employees.text = b.employees?.toString() ?? '';
      _website.text = b.website ?? '';
      _phone.text = b.phone ?? '';
      _email.text = b.email ?? '';
      if (!mounted) return;
      setState(() {
        _business = b;
        _sections = List<BusinessSection>.from(bundle.sections)
          ..sort((a, c) => a.position.compareTo(c.position));
        _loading = false;
      });
    } catch (e) {
      _StudioLogger.error('load', e);
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(_s(context, 'Erreur de chargement : $e', 'Load error: $e'),
          error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? ThixPolicy.danger : ThixPolicy.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  BusinessRepository get _repo => ref.read(businessRepositoryProvider);

  // ── Sections par défaut (ids vides = pas encore en base) ──
  // ⚠️ Si le constructeur de BusinessSection diffère chez toi, ajuste ICI.
  List<BusinessSection> _defaultSections() {
    final id = widget.businessId;
    final fr = _lang(context) == 'fr';
    BusinessSection mk(
      int position,
      BusinessSectionType type,
      BusinessSectionContent content,
    ) =>
        BusinessSection(
          id: '',
          businessId: id,
          type: type,
          visible: true,
          position: position,
          content: content,
        );
    return [
      mk(
        0,
        BusinessSectionType.about,
        AboutContent(
          title: fr ? 'À propos' : 'About',
          tagline: null,
          body: '',
          imageUrl: null,
        ),
      ),
      mk(
        1,
        BusinessSectionType.services,
        ServicesContent(title: fr ? 'Nos services' : 'Services', items: const []),
      ),
      mk(
        2,
        BusinessSectionType.products,
        ProductsContent(title: fr ? 'Produits' : 'Products', items: const []),
      ),
      mk(
        3,
        BusinessSectionType.gallery,
        GalleryContent(title: fr ? 'Galerie' : 'Gallery', images: const []),
      ),
      mk(
        4,
        BusinessSectionType.team,
        TeamContent(title: fr ? 'Équipe' : 'Team', members: const []),
      ),
      mk(
        5,
        BusinessSectionType.news,
        NewsContent(title: fr ? 'Actualités' : 'News', posts: const []),
      ),
      mk(
        6,
        BusinessSectionType.testimonials,
        TestimonialsContent(
            title: fr ? 'Témoignages' : 'Testimonials', items: const []),
      ),
      mk(
        7,
        BusinessSectionType.contact,
        ContactContent(title: 'Contact', channels: const []),
      ),
    ];
  }

  /// ✅ v1.5 : sections de la base + sections par défaut manquantes.
  /// Cette liste n'est JAMAIS vide : c'est elle qui est affichée.
  List<BusinessSection> _displaySections() {
    final existing = List<BusinessSection>.from(_sections)
      ..sort((a, b) => a.position.compareTo(b.position));
    final have = existing.map((s) => s.type).toSet();
    final missing =
        _defaultSections().where((d) => !have.contains(d.type)).toList();
    return [...existing, ...missing];
  }

  // ── Sauvegarde identité ──
  Future<void> _saveIdentity() async {
    if (_business == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final updated = _business!.copyWith(
        name: _name.text.trim(),
        claim: _claim.text.trim().isEmpty ? null : _claim.text.trim(),
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        sector: _sector.text.trim().isEmpty ? null : _sector.text.trim(),
        city: _city.text.trim().isEmpty ? null : _city.text.trim(),
        sinceYear: int.tryParse(_sinceYear.text.trim()),
        employees: int.tryParse(_employees.text.trim()),
        website: _website.text.trim().isEmpty ? null : _website.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      );
      final saved = await _repo.updateBusiness(
          businessId: widget.businessId, business: updated);
      if (!mounted) return;
      setState(() {
        _business = saved;
        _saving = false;
      });
      _snack(_s(context, 'Enregistré ✓', 'Saved ✓'));
    } catch (e) {
      _StudioLogger.error('saveIdentity', e);
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(_s(context, 'Erreur : $e', 'Error: $e'), error: true);
    }
  }

  // ── Upload logo / cover ──
  Future<void> _pickAndUpload({required bool isLogo}) async {
    if (_business == null) return;
    setState(() => _saving = true);
    try {
      final url = await pickAndUploadImage(context, folder: widget.businessId);
      if (url == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      final updated = _business!.copyWith(
        logoUrl: isLogo ? url : _business!.logoUrl,
        coverUrl: isLogo ? _business!.coverUrl : url,
      );
      final saved = await _repo.updateBusiness(
          businessId: widget.businessId, business: updated);
      if (!mounted) return;
      setState(() {
        _business = saved;
        _saving = false;
      });
      _snack(_s(context, 'Enregistré ✓', 'Saved ✓'));
    } catch (e) {
      _StudioLogger.error('upload', e);
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(_s(context, 'Échec de l\'upload : $e', 'Upload failed: $e'),
          error: true);
    }
  }

  // ── Sections : visibilité / ordre / contenu ──

  /// Normalise les positions (0..n-1), affiche tout de suite, puis envoie à
  /// la base. Les sections sans id sont créées par le repository.
  Future<bool> _commitSections(List<BusinessSection> next) async {
    final normalized = [
      for (var i = 0; i < next.length; i++) next[i].copyWith(position: i),
    ];
    setState(() => _sections = normalized);
    try {
      final saved = await _repo.upsertSections(
          businessId: widget.businessId, sections: normalized);
      if (!mounted) return false;
      setState(() => _sections = List<BusinessSection>.from(saved)
        ..sort((a, b) => a.position.compareTo(b.position)));
      return true;
    } catch (e) {
      _StudioLogger.error('commitSections', e);
      _snack(_s(context, 'Erreur : $e', 'Error: $e'), error: true);
      return false;
    }
  }

  void _toggleVisible(int index, bool visible) {
    final next = _displaySections();
    next[index] = next[index].copyWith(visible: visible);
    _commitSections(next);
  }

  void _move(int index, int delta) {
    final next = _displaySections();
    final target = index + delta;
    if (target < 0 || target >= next.length) return;
    final tmp = next[index];
    next[index] = next[target];
    next[target] = tmp;
    _commitSections(next);
  }

  Future<void> _editSection(int index) async {
    final current = _displaySections();
    final section = current[index];
    final result = await showModalBottomSheet<BusinessSectionContent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SectionEditorSheet(section: section),
    );
    if (result == null) return;
    final next = _displaySections();
    final i = next.indexWhere((s) => s.type == section.type);
    if (i < 0) return;
    next[i] = next[i].copyWith(content: result);
    final ok = await _commitSections(next);
    if (ok) _snack(_s(context, 'Section enregistrée', 'Section saved'));
  }

  // ── Publication ──
  Future<void> _togglePublish() async {
    if (_business == null) return;
    setState(() => _saving = true);
    try {
      final saved = _business!.isPublished
          ? await _repo.unpublish(widget.businessId)
          : await _repo.publish(widget.businessId);
      if (!mounted) return;
      setState(() {
        _business = saved;
        _saving = false;
      });
      _snack(saved.isPublished
          ? _s(context, 'Site publié ✓', 'Site published ✓')
          : _s(context, 'Site dépublié', 'Site unpublished'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('$e', error: true);
    }
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _Prism.bg,
        appBar: AppBar(title: Text(_s(context, 'Studio', 'Studio'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final b = _business;
    if (b == null) {
      return Scaffold(
        backgroundColor: _Prism.bg,
        appBar: AppBar(title: Text(_s(context, 'Studio', 'Studio'))),
        body: Center(
            child: Text(_s(context, 'Chargement impossible', 'Load failed'))),
      );
    }

    final shown = _displaySections();

    return Scaffold(
      backgroundColor: _Prism.bg,
      appBar: AppBar(
        title: Text(_s(context, 'Studio', 'Studio'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: _s(context, 'Aperçu', 'Preview'),
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => context.push(_kPublicRoute(b.thixId)),
          ),
          IconButton(
            tooltip: _s(context, 'Thème & style', 'Theme & style'),
            icon: const Icon(Icons.palette_rounded),
            onPressed: () => context.push('$_kThemeRoute/${b.id}'),
          ),
          IconButton(
            tooltip: b.isPublished
                ? _s(context, 'Dépublier', 'Unpublish')
                : _s(context, 'Publier', 'Publish'),
            icon: Icon(b.isPublished
                ? Icons.cloud_off_rounded
                : Icons.cloud_upload_rounded),
            onPressed: _saving ? null : _togglePublish,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _StatusBanner(business: b),
          const SizedBox(height: 16),

          _StudioCard(
            title: _s(context, 'Identité', 'Identity'),
            icon: Icons.badge_rounded,
            child: Column(
              children: [
                _tf(_name, _s(context, "Nom de l'entreprise", 'Business name')),
                _tf(_claim, _s(context, 'Slogan', 'Tagline')),
                _tf(_description, _s(context, 'Description', 'Description'),
                    maxLines: 4),
                Row(
                  children: [
                    Expanded(
                        child: _tf(
                            _sector, _s(context, 'Secteur', 'Sector'))),
                    const SizedBox(width: 10),
                    Expanded(child: _tf(_city, _s(context, 'Ville', 'City'))),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                        child: _tf(
                            _sinceYear,
                            _s(context, 'Année de création',
                                'Year founded'),
                            numeric: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _tf(
                            _employees,
                            _s(context, 'Employés', 'Employees'),
                            numeric: true)),
                  ],
                ),
                _tf(_website, _s(context, 'Site web', 'Website')),
                Row(
                  children: [
                    Expanded(
                        child:
                            _tf(_phone, _s(context, 'Téléphone', 'Phone'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _tf(_email, _s(context, 'Email', 'Email'))),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveIdentity,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_s(context, 'Enregistrer', 'Save')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _StudioCard(
            title: _s(context, 'Médias', 'Media'),
            icon: Icons.image_rounded,
            child: Column(
              children: [
                _MediaRow(
                  label: _s(context, 'Logo', 'Logo'),
                  imageUrl: b.logoUrl,
                  round: true,
                  onChange: () => _pickAndUpload(isLogo: true),
                ),
                const SizedBox(height: 12),
                _MediaRow(
                  label: _s(context, 'Couverture', 'Cover'),
                  imageUrl: b.coverUrl,
                  round: false,
                  onChange: () => _pickAndUpload(isLogo: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ✅ v1.5 : toujours les 8 sections, même si la base est vide
          _StudioCard(
            title: _s(context, 'Sections', 'Sections'),
            icon: Icons.view_agenda_rounded,
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++)
                  _SectionRow(
                    key: ValueKey('section-${shown[i].type.name}'),
                    section: shown[i],
                    canUp: i > 0,
                    canDown: i < shown.length - 1,
                    onUp: () => _move(i, -1),
                    onDown: () => _move(i, 1),
                    onVisible: (v) => _toggleVisible(i, v),
                    onEdit: () => _editSection(i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ✅ v1.3 : 10 rubriques avancées (photos + vidéos)
          BusinessExtrasStudioCard(businessId: widget.businessId),
        ],
      ),
    );
  }

  Widget _tf(TextEditingController ctrl, String label,
      {int maxLines = 1, bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: _Prism.bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _Prism.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _Prism.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: ThixPolicy.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// BANNIÈRE STATUT
// ============================================================================

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.business});
  final Business business;

  @override
  Widget build(BuildContext context) {
    final published = business.isPublished;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: published
            ? ThixPolicy.success.withValues(alpha: 0.10)
            : const Color(0xFFF59E0B).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: published
              ? ThixPolicy.success.withValues(alpha: 0.35)
              : const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            published ? Icons.cloud_done_rounded : Icons.edit_note_rounded,
            color: published ? ThixPolicy.success : const Color(0xFFB45309),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  published
                      ? _s(context, 'Publié', 'Published')
                      : _s(context, 'Brouillon', 'Draft'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: published
                        ? ThixPolicy.success
                        : const Color(0xFFB45309),
                  ),
                ),
                SelectableText(
                  business.thixId,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CARTE GÉNÉRIQUE
// ============================================================================

class _StudioCard extends StatelessWidget {
  const _StudioCard(
      {required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Prism.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Prism.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: ThixPolicy.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ============================================================================
// LIGNE MÉDIA (logo / cover)
// ============================================================================

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.label,
    required this.imageUrl,
    required this.round,
    required this.onChange,
  });
  final String label;
  final String? imageUrl;
  final bool round;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final has = imageUrl != null && imageUrl!.isNotEmpty;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(round ? 40 : 12),
          child: SizedBox(
            width: round ? 64 : 96,
            height: 64,
            child: has
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ColoredBox(color: _Prism.border),
                    errorWidget: (_, __, ___) =>
                        const ColoredBox(color: _Prism.border),
                  )
                : const ColoredBox(
                    color: _Prism.border,
                    child: Icon(Icons.add_photo_alternate_outlined,
                        color: _Prism.inkMuted),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: onChange,
                icon: const Icon(Icons.photo_camera_rounded, size: 16),
                label: Text(_s(context, 'Changer', 'Change'),
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// LIGNE SECTION
// ============================================================================

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.section,
    required this.canUp,
    required this.canDown,
    required this.onUp,
    required this.onDown,
    required this.onVisible,
    required this.onEdit,
  });
  final BusinessSection section;
  final bool canUp;
  final bool canDown;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final ValueChanged<bool> onVisible;
  final VoidCallback onEdit;

  IconData get _icon {
    switch (section.type) {
      case BusinessSectionType.about:
        return Icons.info_outline_rounded;
      case BusinessSectionType.services:
        return Icons.miscellaneous_services_rounded;
      case BusinessSectionType.products:
        return Icons.inventory_2_outlined;
      case BusinessSectionType.gallery:
        return Icons.photo_library_outlined;
      case BusinessSectionType.team:
        return Icons.groups_outlined;
      case BusinessSectionType.news:
        return Icons.article_outlined;
      case BusinessSectionType.testimonials:
        return Icons.rate_review_outlined;
      case BusinessSectionType.contact:
        return Icons.mail_outline_rounded;
    }
  }

  String _title(BuildContext context) {
    final c = section.content;
    if (c is AboutContent) return c.title;
    if (c is ServicesContent) return c.title;
    if (c is ProductsContent) return c.title;
    if (c is GalleryContent) return c.title;
    if (c is TeamContent) return c.title;
    if (c is NewsContent) return c.title;
    if (c is TestimonialsContent) return c.title;
    if (c is ContactContent) return c.title;
    switch (section.type) {
      case BusinessSectionType.about:
        return _s(context, 'À propos', 'About');
      case BusinessSectionType.services:
        return _s(context, 'Nos services', 'Services');
      case BusinessSectionType.products:
        return _s(context, 'Produits', 'Products');
      case BusinessSectionType.gallery:
        return _s(context, 'Galerie', 'Gallery');
      case BusinessSectionType.team:
        return _s(context, 'Équipe', 'Team');
      case BusinessSectionType.news:
        return _s(context, 'Actualités', 'News');
      case BusinessSectionType.testimonials:
        return _s(context, 'Témoignages', 'Testimonials');
      case BusinessSectionType.contact:
        return _s(context, 'Contact', 'Contact');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(_icon, size: 20, color: ThixPolicy.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_title(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            onPressed: canUp ? onUp : null,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_downward_rounded, size: 18),
            onPressed: canDown ? onDown : null,
          ),
          Switch(value: section.visible, onChanged: onVisible),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ÉDITEUR DE SECTION (bottom sheet) — uploads partout
// ============================================================================

class _SectionEditorSheet extends StatefulWidget {
  const _SectionEditorSheet({required this.section});
  final BusinessSection section;

  @override
  State<_SectionEditorSheet> createState() => _SectionEditorSheetState();
}

class _SectionEditorSheetState extends State<_SectionEditorSheet> {
  // Champs « À propos »
  late final TextEditingController _title = TextEditingController();
  late final TextEditingController _tagline = TextEditingController();
  late final TextEditingController _body = TextEditingController();
  late final TextEditingController _aboutImage = TextEditingController();

  // Listes d'items : contrôleurs par item
  final List<List<TextEditingController>> _items = [];
  final List<ContactChannelType> _contactTypes = [];

  /// Clé du champ image en cours d'upload (spinner)
  String _uploadingKey = '';

  @override
  void initState() {
    super.initState();
    final c = widget.section.content;
    if (c is AboutContent) {
      _title.text = c.title;
      _tagline.text = c.tagline ?? '';
      _body.text = c.body;
      _aboutImage.text = c.imageUrl ?? '';
    } else if (c is ServicesContent) {
      _title.text = c.title;
      for (final it in c.items) {
        _items.add(_ctrls([
          it.title, it.description ?? '', it.price ?? '', it.imageUrl ?? ''
        ]));
      }
    } else if (c is ProductsContent) {
      _title.text = c.title;
      for (final it in c.items) {
        _items.add(_ctrls([
          it.title, it.description ?? '', it.price ?? '',
          it.imageUrl ?? '', it.url ?? ''
        ]));
      }
    } else if (c is GalleryContent) {
      _title.text = c.title;
      for (final it in c.images) {
        _items.add(_ctrls([it.url, it.caption ?? '']));
      }
    } else if (c is TeamContent) {
      _title.text = c.title;
      for (final it in c.members) {
        _items.add(_ctrls([
          it.name, it.role ?? '', it.bio ?? '', it.photoUrl ?? ''
        ]));
      }
    } else if (c is NewsContent) {
      _title.text = c.title;
      for (final it in c.posts) {
        _items.add(_ctrls([
          it.title, it.excerpt ?? '', it.imageUrl ?? '', it.url ?? ''
        ]));
      }
    } else if (c is TestimonialsContent) {
      _title.text = c.title;
      for (final it in c.items) {
        _items.add(_ctrls([
          it.quote, it.author ?? '', it.role ?? '',
          it.rating?.toString() ?? ''
        ]));
      }
    } else if (c is ContactContent) {
      _title.text = c.title;
      for (final it in c.channels) {
        _items.add(_ctrls([it.value, it.label ?? '']));
        _contactTypes.add(it.type);
      }
    }
  }

  List<TextEditingController> _ctrls(List<String> values) =>
      values.map((v) => TextEditingController(text: v)).toList();

  String _v(List<TextEditingController> l, int i) =>
      l.length > i ? l[i].text.trim() : '';

  @override
  void dispose() {
    _title.dispose();
    _tagline.dispose();
    _body.dispose();
    _aboutImage.dispose();
    for (final group in _items) {
      for (final c in group) {
        c.dispose();
      }
    }
    super.dispose();
  }

  // Upload vers Storage puis injection de l'URL dans le controller
  Future<void> _pickFor(TextEditingController target, String key) async {
    setState(() => _uploadingKey = key);
    try {
      final url = await pickAndUploadImage(
        context,
        folder: widget.section.businessId,
      );
      if (!mounted) return;
      if (url != null) {
        target.text = url;
        target.selection = TextSelection.collapsed(offset: url.length);
      }
      setState(() => _uploadingKey = '');
    } catch (e) {
      _StudioLogger.error('section upload', e);
      if (!mounted) return;
      setState(() => _uploadingKey = '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_s(context, 'Échec de l\'upload : $e', 'Upload failed: $e')),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _addItem() {
    setState(() {
      switch (widget.section.type) {
        case BusinessSectionType.services:
          _items.add(_ctrls(['', '', '', '']));
        case BusinessSectionType.products:
          _items.add(_ctrls(['', '', '', '', '']));
        case BusinessSectionType.gallery:
          _items.add(_ctrls(['', '']));
        case BusinessSectionType.team:
          _items.add(_ctrls(['', '', '', '']));
        case BusinessSectionType.news:
          _items.add(_ctrls(['', '', '', '']));
        case BusinessSectionType.testimonials:
          _items.add(_ctrls(['', '', '', '']));
        case BusinessSectionType.contact:
          _items.add(_ctrls(['', '']));
          _contactTypes.add(ContactChannelType.phone);
        default:
          break;
      }
    });
  }

  void _removeItem(int i) {
    setState(() {
      for (final c in _items[i]) {
        c.dispose();
      }
      _items.removeAt(i);
      if (widget.section.type == BusinessSectionType.contact) {
        _contactTypes.removeAt(i);
      }
    });
  }

  BusinessSectionContent _build() {
    final t = _title.text.trim();
    switch (widget.section.type) {
      case BusinessSectionType.about:
        return AboutContent(
          title: t.isEmpty ? _s(context, 'À propos', 'About') : t,
          tagline: _tagline.text.trim().isEmpty ? null : _tagline.text.trim(),
          body: _body.text,
          imageUrl:
              _aboutImage.text.trim().isEmpty ? null : _aboutImage.text.trim(),
        );
      case BusinessSectionType.services:
        return ServicesContent(
          title: t.isEmpty ? _s(context, 'Nos services', 'Services') : t,
          items: [
            for (final it in _items)
              if (_v(it, 0).isNotEmpty)
                ServiceItem(
                  title: _v(it, 0),
                  description: _v(it, 1).isEmpty ? null : _v(it, 1),
                  price: _v(it, 2).isEmpty ? null : _v(it, 2),
                  imageUrl: _v(it, 3).isEmpty ? null : _v(it, 3),
                ),
          ],
        );
      case BusinessSectionType.products:
        return ProductsContent(
          title: t.isEmpty ? _s(context, 'Produits', 'Products') : t,
          items: [
            for (final it in _items)
              if (_v(it, 0).isNotEmpty)
                ProductItem(
                  title: _v(it, 0),
                  description: _v(it, 1).isEmpty ? null : _v(it, 1),
                  price: _v(it, 2).isEmpty ? null : _v(it, 2),
                  imageUrl: _v(it, 3).isEmpty ? null : _v(it, 3),
                  url: _v(it, 4).isEmpty ? null : _v(it, 4),
                ),
          ],
        );
      case BusinessSectionType.gallery:
        return GalleryContent(
          title: t.isEmpty ? _s(context, 'Galerie', 'Gallery') : t,
          images: [
            for (final it in _items)
              if (_v(it, 0).isNotEmpty)
                GalleryImage(
                  url: _v(it, 0),
                  caption: _v(it, 1).isEmpty ? null : _v(it, 1),
                ),
          ],
        );
      case BusinessSectionType.team:
        return TeamContent(
          title: t.isEmpty ? _s(context, 'Équipe', 'Team') : t,
          members: [
            for (final it in _items)
              if (_v(it, 0).isNotEmpty)
                TeamMember(
                  name: _v(it, 0),
                  role: _v(it, 1).isEmpty ? null : _v(it, 1),
                  bio: _v(it, 2).isEmpty ? null : _v(it, 2),
                  photoUrl: _v(it, 3).isEmpty ? null : _v(it, 3),
                ),
          ],
        );
      case BusinessSectionType.news:
        return NewsContent(
          title: t.isEmpty ? _s(context, 'Actualités', 'News') : t,
          posts: [
            for (final it in _items)
              if (_v(it, 0).isNotEmpty)
                NewsPost(
                  title: _v(it, 0),
                  excerpt: _v(it, 1).isEmpty ? null : _v(it, 1),
                  imageUrl: _v(it, 2).isEmpty ? null : _v(it, 2),
                  url: _v(it, 3).isEmpty ? null : _v(it, 3),
                ),
          ],
        );
      case BusinessSectionType.testimonials:
        return TestimonialsContent(
          title: t.isEmpty ? _s(context, 'Témoignages', 'Testimonials') : t,
          items: [
            for (final it in _items)
              if (_v(it, 0).isNotEmpty)
                TestimonialItem(
                  quote: _v(it, 0),
                  author: _v(it, 1).isEmpty ? null : _v(it, 1),
                  role: _v(it, 2).isEmpty ? null : _v(it, 2),
                  rating: int.tryParse(_v(it, 3)),
                ),
          ],
        );
      case BusinessSectionType.contact:
        return ContactContent(
          title: t.isEmpty ? _s(context, 'Contact', 'Contact') : t,
          channels: [
            for (var i = 0; i < _items.length; i++)
              if (_v(_items[i], 0).isNotEmpty)
                ContactChannel(
                  type: _contactTypes[i],
                  value: _v(_items[i], 0),
                  label: _v(_items[i], 1).isEmpty ? null : _v(_items[i], 1),
                ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.section.type;
    final isList = type != BusinessSectionType.about;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: _Prism.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                    color: _Prism.border,
                    borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_s(context, 'Modifier la section', 'Edit section'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  _sheetField(_title, _s(context, 'Titre', 'Title')),
                  if (type == BusinessSectionType.about) ...[
                    _sheetField(_tagline, _s(context, 'Slogan', 'Tagline')),
                    _ImageField(
                      controller: _aboutImage,
                      label:
                          _s(context, "URL de l'image", 'Image URL'),
                      uploading: _uploadingKey == 'about-img',
                      onPick: () => _pickFor(_aboutImage, 'about-img'),
                    ),
                    _sheetField(_body, _s(context, 'Corps', 'Body'),
                        maxLines: 6),
                  ],
                  if (isList)
                    for (var i = 0; i < _items.length; i++) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _Prism.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _Prism.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text('${i + 1}.',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                const Spacer(),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: ThixPolicy.danger),
                                  onPressed: () => _removeItem(i),
                                ),
                              ],
                            ),
                            ..._fieldsFor(type, i),
                          ],
                        ),
                      ),
                    ],
                  if (isList)
                    OutlinedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(_s(context, 'Ajouter un élément', 'Add an item')),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _build()),
                    child: Text(_s(context, 'Enregistrer', 'Save')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fieldsFor(BusinessSectionType type, int i) {
    final it = _items[i];
    Widget f(int idx, String label, {int maxLines = 1}) =>
        _sheetField(it[idx], label, maxLines: maxLines);

    // Champ image = URL + upload + miniature
    Widget img(int idx, String label, String key) => _ImageField(
          controller: it[idx],
          label: label,
          uploading: _uploadingKey == key,
          onPick: () => _pickFor(it[idx], key),
        );

    switch (type) {
      case BusinessSectionType.services:
        return [
          f(0, _s(context, 'Titre', 'Title')),
          f(1, _s(context, 'Description', 'Description'), maxLines: 3),
          f(2, _s(context, 'Prix', 'Price')),
          img(3, _s(context, "URL de l'image", 'Image URL'), 's$i-img'),
        ];
      case BusinessSectionType.products:
        return [
          f(0, _s(context, 'Titre', 'Title')),
          f(1, _s(context, 'Description', 'Description'), maxLines: 3),
          f(2, _s(context, 'Prix', 'Price')),
          img(3, _s(context, "URL de l'image", 'Image URL'), 'p$i-img'),
          f(4, _s(context, 'Lien', 'Link')),
        ];
      case BusinessSectionType.gallery:
        return [
          img(0, _s(context, "URL de l'image", 'Image URL'), 'g$i-img'),
          f(1, _s(context, 'Légende', 'Caption')),
        ];
      case BusinessSectionType.team:
        return [
          f(0, _s(context, 'Nom', 'Name')),
          f(1, _s(context, 'Rôle', 'Role')),
          f(2, _s(context, 'Biographie', 'Bio'), maxLines: 3),
          img(3, _s(context, 'URL de la photo', 'Photo URL'), 't$i-img'),
        ];
      case BusinessSectionType.news:
        return [
          f(0, _s(context, 'Titre', 'Title')),
          f(1, _s(context, 'Résumé', 'Excerpt'), maxLines: 3),
          img(2, _s(context, "URL de l'image", 'Image URL'), 'n$i-img'),
          f(3, _s(context, 'Lien', 'Link')),
        ];
      case BusinessSectionType.testimonials:
        return [
          f(0, _s(context, 'Citation', 'Quote'), maxLines: 4),
          f(1, _s(context, 'Auteur', 'Author')),
          f(2, _s(context, 'Rôle', 'Role')),
          f(3, _s(context, 'Note (1-5)', 'Rating (1-5)')),
        ];
      case BusinessSectionType.contact:
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<ContactChannelType>(
              initialValue: _contactTypes[i],
              decoration: InputDecoration(
                labelText: _s(context, 'Type', 'Type'),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              items: [
                for (final t in ContactChannelType.values)
                  DropdownMenuItem(
                      value: t, child: Text(_contactLabel(context, t))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _contactTypes[i] = v);
              },
            ),
          ),
          f(0, _s(context, 'Valeur', 'Value')),
          f(1, _s(context, 'Label', 'Label')),
        ];
      default:
        return [];
    }
  }

  Widget _sheetField(TextEditingController ctrl, String label,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: _Prism.bg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _Prism.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _Prism.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: ThixPolicy.primary, width: 2)),
        ),
      ),
    );
  }
}
