// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — STUDIO D'ÉDITION (OWNER)
//  Fichier  : lib/presentation/thix_portfolio/pages/business_studio_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.0 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//
//  Route : /business/edit/:id
//
//  Fonctionnalités :
//    • Édition identité (nom, slogan, description, secteur, ville, contacts…)
//    • Upload logo + cover (Supabase Storage bucket `business-media`)
//    • Gestion des 8 sections : visibilité, ordre (↑/↓), édition du contenu
//    • Publication / dépublication (checklist côté repository)
//    • Accès direct au Theme Studio (/business/theme/:id) et à l'aperçu public
//
//  Contraintes CI respectées :
//    • Aucun package hors pubspec.yaml
//    • Animations natives uniquement
//    • l10n via l10n.t(...) avec args: []
// ════════════════════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../data/business_repository.dart';
import '../models/business_bundle.dart';
import '../models/business_theme.dart';

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
// PAGE
// ============================================================================

class BusinessStudioPage extends ConsumerStatefulWidget {
  const BusinessStudioPage({super.key, required this.businessId});
  final String businessId;

  @override
  ConsumerState<BusinessStudioPage> createState() => _BusinessStudioPageState();
}

class _BusinessStudioPageState extends ConsumerState<BusinessStudioPage> {
  Business? _business;
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
      final bundle = await ref
          .read(ownerBusinessBundleProvider(widget.businessId).future);
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
        _sections = bundle.sections;
        _loading = false;
      });
    } catch (e) {
      _StudioLogger.error('load', e);
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Erreur de chargement : $e', error: true);
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
      _snack(AppLocalizations.of(context).t('biz_studio_saved'));
    } catch (e) {
      _StudioLogger.error('saveIdentity', e);
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(
          AppLocalizations.of(context)
              .t('biz_studio_error', args: ['$e'.length > 90 ? '${'$e'.substring(0, 90)}…' : '$e']),
          error: true);
    }
  }

  // ── Upload média (Storage) ──
  Future<void> _pickAndUpload({required bool isLogo}) async {
    if (_business == null) return;
    final l10n = AppLocalizations.of(context);
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1400,
    );
    if (file == null) return;

    setState(() => _saving = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';
      final kind = isLogo ? 'logo' : 'cover';
      final path =
          '${widget.businessId}/$kind-${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bucket = Supabase.instance.client.storage.from('business-media');
      await bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: (file.mimeType == null || file.mimeType!.isEmpty) ? 'image/$ext' : file.mimeType,
          upsert: true,
        ),
      );
      final url = bucket.getPublicUrl(path);

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
      _snack(l10n.t('biz_studio_saved'));
    } catch (e) {
      _StudioLogger.error('upload', e);
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(l10n.t('biz_studio_error', args: ['$e']), error: true);
    }
  }

  // ── Sections : visibilité / ordre / contenu ──
  Future<void> _persistSections(List<BusinessSection> next) async {
    try {
      final saved = await _repo.upsertSections(
          businessId: widget.businessId, sections: next);
      if (!mounted) return;
      setState(() => _sections = saved);
    } catch (e) {
      _StudioLogger.error('persistSections', e);
      _snack(
          AppLocalizations.of(context).t('biz_studio_error', args: ['$e']),
          error: true);
    }
  }

  void _toggleVisible(int index, bool visible) {
    final next = List<BusinessSection>.from(_sections);
    next[index] = next[index].copyWith(visible: visible);
    setState(() => _sections = next);
    _persistSections(next);
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _sections.length) return;
    final next = List<BusinessSection>.from(_sections);
    final a = next[index];
    final b = next[target];
    next[index] = b.copyWith(position: a.position);
    next[target] = a.copyWith(position: b.position);
    next.sort((x, y) => x.position.compareTo(y.position));
    setState(() => _sections = next);
    _persistSections(next);
  }

  Future<void> _editSection(int index) async {
    final section = _sections[index];
    final result = await showModalBottomSheet<BusinessSectionContent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SectionEditorSheet(section: section),
    );
    if (result == null) return;
    final next = List<BusinessSection>.from(_sections);
    next[index] = next[index].copyWith(content: result);
    setState(() => _sections = next);
    await _persistSections(next);
    _snack(AppLocalizations.of(context).t('biz_studio_section_saved'));
  }

  // ── Publication ──
  Future<void> _togglePublish() async {
    if (_business == null) return;
    final l10n = AppLocalizations.of(context);
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
          ? l10n.t('biz_studio_published')
          : l10n.t('biz_studio_unpublished'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('$e', error: true);
    }
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: _Prism.bg,
        appBar: AppBar(title: Text(l10n.t('biz_studio_title'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final b = _business;
    if (b == null) {
      return Scaffold(
        backgroundColor: _Prism.bg,
        appBar: AppBar(title: Text(l10n.t('biz_studio_title'))),
        body: Center(
          child: Text(l10n.t('biz_mine_error_title')),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _Prism.bg,
      appBar: AppBar(
        title: Text(
          l10n.t('biz_studio_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: l10n.t('biz_studio_preview'),
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => context.push(_kPublicRoute(b.thixId)),
          ),
          IconButton(
            tooltip: l10n.t('biz_studio_theme'),
            icon: const Icon(Icons.palette_rounded),
            onPressed: () => context.push('$_kThemeRoute/${b.id}'),
          ),
          IconButton(
            tooltip: b.isPublished
                ? l10n.t('biz_studio_unpublish')
                : l10n.t('biz_studio_publish'),
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
          // ── Statut ──
          _StatusBanner(business: b),
          const SizedBox(height: 16),

          // ── Identité ──
          _StudioCard(
            title: l10n.t('biz_studio_identity'),
            icon: Icons.badge_rounded,
            child: Column(
              children: [
                _tf(_name, l10n.t('biz_studio_field_name')),
                _tf(_claim, l10n.t('biz_studio_claim')),
                _tf(_description, l10n.t('biz_studio_description'),
                    maxLines: 4),
                Row(
                  children: [
                    Expanded(child: _tf(_sector, l10n.t('biz_studio_sector'))),
                    const SizedBox(width: 10),
                    Expanded(child: _tf(_city, l10n.t('biz_studio_city'))),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                        child: _tf(_sinceYear, l10n.t('biz_studio_since'),
                            numeric: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _tf(
                            _employees, l10n.t('biz_studio_employees'),
                            numeric: true)),
                  ],
                ),
                _tf(_website, l10n.t('biz_studio_website')),
                Row(
                  children: [
                    Expanded(child: _tf(_phone, l10n.t('biz_studio_phone'))),
                    const SizedBox(width: 10),
                    Expanded(child: _tf(_email, l10n.t('biz_studio_email'))),
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
                    label: Text(l10n.t('biz_studio_save')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Médias ──
          _StudioCard(
            title: l10n.t('biz_studio_media'),
            icon: Icons.image_rounded,
            child: Column(
              children: [
                _MediaRow(
                  label: l10n.t('biz_studio_logo'),
                  imageUrl: b.logoUrl,
                  round: true,
                  onChange: () => _pickAndUpload(isLogo: true),
                ),
                const SizedBox(height: 12),
                _MediaRow(
                  label: l10n.t('biz_studio_cover'),
                  imageUrl: b.coverUrl,
                  round: false,
                  onChange: () => _pickAndUpload(isLogo: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Sections ──
          _StudioCard(
            title: l10n.t('biz_studio_sections'),
            icon: Icons.view_agenda_rounded,
            child: Column(
              children: [
                for (var i = 0; i < _sections.length; i++)
                  _SectionRow(
                    section: _sections[i],
                    canUp: i > 0,
                    canDown: i < _sections.length - 1,
                    onUp: () => _move(i, -1),
                    onDown: () => _move(i, 1),
                    onVisible: (v) => _toggleVisible(i, v),
                    onEdit: () => _editSection(i),
                  ),
              ],
            ),
          ),
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
    final l10n = AppLocalizations.of(context);
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
                      ? l10n.t('biz_mine_filter_published')
                      : l10n.t('biz_mine_filter_draft'),
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
  const _StudioCard({required this.title, required this.icon, required this.child});
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
    final l10n = AppLocalizations.of(context);
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
                : ColoredBox(
                    color: _Prism.border,
                    child: const Icon(Icons.add_photo_alternate_outlined,
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
              OutlinedButton(
                onPressed: onChange,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(l10n.t('biz_studio_change'),
                    style: const TextStyle(fontSize: 12)),
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

  String _title(AppLocalizations l10n) {
    final c = section.content;
    if (c is AboutContent) return c.title;
    if (c is ServicesContent) return c.title;
    if (c is ProductsContent) return c.title;
    if (c is GalleryContent) return c.title;
    if (c is TeamContent) return c.title;
    if (c is NewsContent) return c.title;
    if (c is TestimonialsContent) return c.title;
    if (c is ContactContent) return c.title;
    return section.type.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(_icon, size: 20, color: ThixPolicy.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_title(l10n),
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
// ÉDITEUR DE SECTION (bottom sheet)
// ============================================================================

class _SectionEditorSheet extends StatefulWidget {
  const _SectionEditorSheet({required this.section});
  final BusinessSection section;

  @override
  State<_SectionEditorSheet> createState() => _SectionEditorSheetState();
}

class _SectionEditorSheetState extends State<_SectionEditorSheet> {
  // Champs "en-tête" (about)
  late final TextEditingController _title = TextEditingController();
  late final TextEditingController _tagline = TextEditingController();
  late final TextEditingController _body = TextEditingController();

  // Listes d'items : contrôleurs par item
  final List<List<TextEditingController>> _items = [];
  final List<ContactChannelType> _contactTypes = [];

  @override
  void initState() {
    super.initState();
    final c = widget.section.content;
    if (c is AboutContent) {
      _title.text = c.title;
      _tagline.text = c.tagline ?? '';
      _body.text = c.body;
    } else if (c is ServicesContent) {
      _title.text = c.title;
      for (final it in c.items) {
        _items.add(_ctrls([it.title, it.description ?? '', it.price ?? '']));
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
        _items.add(_ctrls([it.title, it.excerpt ?? '', it.url ?? '']));
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
    for (final group in _items) {
      for (final c in group) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      switch (widget.section.type) {
        case BusinessSectionType.services:
          _items.add(_ctrls(['', '', '']));
        case BusinessSectionType.products:
          _items.add(_ctrls(['', '', '', '', '']));
        case BusinessSectionType.gallery:
          _items.add(_ctrls(['', '']));
        case BusinessSectionType.team:
          _items.add(_ctrls(['', '', '', '']));
        case BusinessSectionType.news:
          _items.add(_ctrls(['', '', '']));
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
          title: t.isEmpty ? 'À propos' : t,
          tagline: _tagline.text.trim().isEmpty ? null : _tagline.text.trim(),
          body: _body.text,
        );
      case BusinessSectionType.services:
        return ServicesContent(
          title: t.isEmpty ? 'Nos services' : t,
          items: [
            for (final it in _items)
              if (_v(it, 0).isNotEmpty)
                ServiceItem(
                  title: _v(it, 0),
                  description: _v(it, 1).isEmpty ? null : _v(it, 1),
                  price: _v(it, 2).isEmpty ? null : _v(it, 2),
                ),
          ],
        );
      case BusinessSectionType.products:
        return ProductsContent(
          title: t.isEmpty ? 'Produits' : t,
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
          title: t.isEmpty ? 'Galerie' : t,
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
          title: t.isEmpty ? 'Équipe' : t,
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
          title: t.isEmpty ? 'Actualités' : t,
          posts: [
            for (final it in _items)
              if (_v(it, 0).isNotEmpty)
                NewsPost(
                  title: _v(it, 0),
                  excerpt: _v(it, 1).isEmpty ? null : _v(it, 1),
                  url: _v(it, 2).isEmpty ? null : _v(it, 2),
                ),
          ],
        );
      case BusinessSectionType.testimonials:
        return TestimonialsContent(
          title: t.isEmpty ? 'Témoignages' : t,
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
          title: t.isEmpty ? 'Contact' : t,
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
    final l10n = AppLocalizations.of(context);
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
                    child: Text(l10n.t('biz_studio_edit_section'),
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
                  _sheetField(_title, l10n.t('biz_studio_field_title')),
                  if (type == BusinessSectionType.about) ...[
                    _sheetField(_tagline, l10n.t('biz_studio_field_tagline')),
                    _sheetField(_body, l10n.t('biz_studio_field_body'),
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
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 18, color: ThixPolicy.danger),
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
                      label: Text(l10n.t('biz_studio_add_item')),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _build()),
                    child: Text(l10n.t('biz_studio_save')),
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
    final l10n = AppLocalizations.of(context);
    final it = _items[i];
    Widget f(int idx, String label, {int maxLines = 1}) =>
        _sheetField(it[idx], label, maxLines: maxLines);

    switch (type) {
      case BusinessSectionType.services:
        return [
          f(0, l10n.t('biz_studio_field_title')),
          f(1, l10n.t('biz_studio_field_description'), maxLines: 3),
          f(2, l10n.t('biz_studio_field_price')),
        ];
      case BusinessSectionType.products:
        return [
          f(0, l10n.t('biz_studio_field_title')),
          f(1, l10n.t('biz_studio_field_description'), maxLines: 3),
          f(2, l10n.t('biz_studio_field_price')),
          f(3, l10n.t('biz_studio_field_image_url')),
          f(4, l10n.t('biz_studio_field_url')),
        ];
      case BusinessSectionType.gallery:
        return [
          f(0, l10n.t('biz_studio_field_image_url')),
          f(1, l10n.t('biz_studio_field_caption')),
        ];
      case BusinessSectionType.team:
        return [
          f(0, l10n.t('biz_studio_field_name')),
          f(1, l10n.t('biz_studio_field_role')),
          f(2, l10n.t('biz_studio_field_bio'), maxLines: 3),
          f(3, l10n.t('biz_studio_field_photo_url')),
        ];
      case BusinessSectionType.news:
        return [
          f(0, l10n.t('biz_studio_field_title')),
          f(1, l10n.t('biz_studio_field_excerpt'), maxLines: 3),
          f(2, l10n.t('biz_studio_field_url')),
        ];
      case BusinessSectionType.testimonials:
        return [
          f(0, l10n.t('biz_studio_field_quote'), maxLines: 4),
          f(1, l10n.t('biz_studio_field_author')),
          f(2, l10n.t('biz_studio_field_role')),
          f(3, l10n.t('biz_studio_field_rating')),
        ];
      case BusinessSectionType.contact:
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<ContactChannelType>(
              initialValue: _contactTypes[i],
              decoration: InputDecoration(
                labelText: l10n.t('biz_studio_field_type'),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              items: [
                for (final t in ContactChannelType.values)
                  DropdownMenuItem(value: t, child: Text(t.name)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _contactTypes[i] = v);
              },
            ),
          ),
          f(0, l10n.t('biz_studio_field_value')),
          f(1, l10n.t('biz_studio_field_label')),
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
