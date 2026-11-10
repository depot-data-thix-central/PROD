// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — STUDIO : RUBRIQUES AVANCÉES (OWNER)
//  Fichier  : lib/presentation/thix_portfolio/pages/business_extras_studio.dart
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.1 — Novembre 2026 (i18n FR/EN inline)
// ════════════════════════════════════════════════════════════════════════════
//  Carte « Rubriques avancées » à placer dans le Studio.
//  10 rubriques : visibilité + édition + upload photo ET vidéo.
//  Upload → bucket Supabase `business-media` (public).
// ════════════════════════════════════════════════════════════════════════════

import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../data/business_extras.dart';

// ─── i18n minimaliste FR/EN ─────────────────────────────────────────────────
String _lang(BuildContext c) =>
    Localizations.localeOf(c).languageCode.toLowerCase();

/// Retourne la chaîne française si la locale courante est `fr`, sinon l'anglaise.
String _s(BuildContext c, String fr, String en) =>
    _lang(c) == 'fr' ? fr : en;
// ────────────────────────────────────────────────────────────────────────────

const int _kMaxVideoBytes = 50 * 1024 * 1024; // 50 Mo

class _P {
  _P._();
  static const Color bg = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE6E9F2);
  static const Color inkMuted = Color(0xFF8A94A6);
}

// ─────────────────────────────────────────────────────────────────────────────
// Exception typée pour la limite de taille vidéo (permet i18n au point de catch)
// ─────────────────────────────────────────────────────────────────────────────

class MediaTooLargeException implements Exception {
  final int maxBytes;
  const MediaTooLargeException(this.maxBytes);
  @override
  String toString() => 'MediaTooLargeException(maxBytes: $maxBytes)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload photo / vidéo
// ─────────────────────────────────────────────────────────────────────────────

Future<String> _uploadMedia(
  XFile file,
  String folder, {
  required bool video,
}) async {
  final bytes = await file.readAsBytes();
  if (video && bytes.length > _kMaxVideoBytes) {
    throw const MediaTooLargeException(_kMaxVideoBytes);
  }
  final ext = file.name.contains('.')
      ? file.name.split('.').last.toLowerCase()
      : (video ? 'mp4' : 'jpg');
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final rand = Random().nextInt(9999).toString().padLeft(4, '0');
  final path = '$folder/extras-$stamp-$rand.$ext';
  final bucket = Supabase.instance.client.storage.from('business-media');
  final mime = (file.mimeType != null && file.mimeType!.isNotEmpty)
      ? file.mimeType!
      : (video ? 'video/$ext' : 'image/$ext');
  await bucket.uploadBinary(
    path,
    bytes,
    fileOptions: FileOptions(contentType: mime, upsert: true),
  );
  return bucket.getPublicUrl(path);
}

Future<String?> _pickAndUpload(String folder, {required bool video}) async {
  final picker = ImagePicker();
  final XFile? file = video
      ? await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 5),
        )
      : await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1400,
        );
  if (file == null) return null;
  return _uploadMedia(file, folder, video: video);
}

// ─────────────────────────────────────────────────────────────────────────────
// CARTE « RUBRIQUES AVANCÉES »
// ─────────────────────────────────────────────────────────────────────────────

class BusinessExtrasStudioCard extends ConsumerStatefulWidget {
  const BusinessExtrasStudioCard({super.key, required this.businessId});
  final String businessId;

  @override
  ConsumerState<BusinessExtrasStudioCard> createState() =>
      _BusinessExtrasStudioCardState();
}

class _BusinessExtrasStudioCardState
    extends ConsumerState<BusinessExtrasStudioCard> {
  bool _loading = true;
  final Map<String, BizExtra> _byKind = {};

  BusinessExtrasRepository get _repo =>
      ref.read(businessExtrasRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _repo.fetch(widget.businessId);
    final map = {for (final r in rows) r.kind: r};
    for (var i = 0; i < kBizKinds.length; i++) {
      final k = kBizKinds[i].key;
      map.putIfAbsent(k, () => BizExtra(kind: k, position: i));
    }
    if (!mounted) return;
    setState(() {
      _byKind
        ..clear()
        ..addAll(map);
      _loading = false;
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? ThixPolicy.danger : ThixPolicy.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _persist(BizExtra e) async {
    try {
      await _repo.save(widget.businessId, e);
      ref.invalidate(businessExtrasProvider(widget.businessId));
    } catch (err) {
      _snack(_s(context, 'Erreur : $err', 'Error: $err'), error: true);
    }
  }

  Future<void> _toggle(BizExtra e, bool v) async {
    setState(() => e.visible = v);
    await _persist(e);
  }

  Future<void> _edit(BizKindSpec spec) async {
    final current = _byKind[spec.key]!;
    final result = await showModalBottomSheet<BizExtra>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExtraEditorSheet(
        extra: current.copy(),
        spec: spec,
        businessId: widget.businessId,
      ),
    );
    if (result == null) return;
    setState(() => _byKind[spec.key] = result);
    await _persist(result);
    _snack(_s(context, 'Rubrique enregistrée', 'Section saved'));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dashboard_customize_rounded,
                  size: 20, color: ThixPolicy.primary),
              const SizedBox(width: 8),
              Text(
                  _s(context, 'Rubriques avancées (10)',
                      'Advanced sections (10)'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _s(
                context,
                'Active une rubrique, ajoute tes éléments avec photos / vidéos.',
                'Enable a section, add your items with photos / videos.'),
            style: const TextStyle(fontSize: 12, color: _P.inkMuted),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()))
          else
            for (final spec in kBizKinds) _row(spec, _byKind[spec.key]!),
        ],
      ),
    );
  }

  Widget _row(BizKindSpec spec, BizExtra e) {
    final count =
        e.items.where((i) => (i['title'] ?? '').trim().isNotEmpty).length;
    final specName = _lang(context) == 'fr' ? spec.fr : spec.en;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(spec.icon, size: 20, color: ThixPolicy.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(specName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                    _s(context, '$count élément(s)', '$count item(s)'),
                    style: const TextStyle(
                        fontSize: 11, color: _P.inkMuted)),
              ],
            ),
          ),
          Switch(value: e.visible, onChanged: (v) => _toggle(e, v)),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: () => _edit(spec),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ÉDITEUR DE RUBRIQUE (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _ExtraEditorSheet extends StatefulWidget {
  const _ExtraEditorSheet({
    required this.extra,
    required this.spec,
    required this.businessId,
  });

  final BizExtra extra;
  final BizKindSpec spec;
  final String businessId;

  @override
  State<_ExtraEditorSheet> createState() => _ExtraEditorSheetState();
}

class _ExtraEditorSheetState extends State<_ExtraEditorSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.extra.title ?? '');
  final List<Map<String, TextEditingController>> _items = [];
  String _uploadingKey = '';

  @override
  void initState() {
    super.initState();
    for (final it in widget.extra.items) {
      _items.add(_ctrls(it));
    }
    if (_items.isEmpty) _items.add(_ctrls(const {}));
  }

  Map<String, TextEditingController> _ctrls(Map<String, String> src) => {
        for (final f in widget.spec.fields)
          f: TextEditingController(text: src[f] ?? ''),
      };

  @override
  void dispose() {
    _title.dispose();
    for (final m in _items) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _pick(
      TextEditingController target, String key, bool video) async {
    setState(() => _uploadingKey = key);
    try {
      final url = await _pickAndUpload(widget.businessId, video: video);
      if (!mounted) return;
      if (url != null) {
        target.text = url;
        target.selection = TextSelection.collapsed(offset: url.length);
      }
      setState(() => _uploadingKey = '');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingKey = '');
      final String msg;
      if (e is MediaTooLargeException) {
        final mb = e.maxBytes ~/ (1024 * 1024);
        msg = _s(
            context, 'Vidéo trop lourde (max $mb Mo)', 'Video too large (max $mb MB)');
      } else {
        msg = _s(context, 'Upload impossible : $e', 'Upload failed: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  BizExtra _build() {
    final out = <Map<String, String>>[];
    for (final m in _items) {
      final map = {
        for (final e in m.entries) e.key: e.value.text.trim(),
      };
      if ((map['title'] ?? '').isNotEmpty) out.add(map);
    }
    final e = widget.extra;
    e.title = _title.text.trim().isEmpty ? null : _title.text.trim();
    e.items = out;
    return e;
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: _P.bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _P.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _P.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: ThixPolicy.primary, width: 2)),
      );

  Widget _tf(TextEditingController c, String label, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
            controller: c, maxLines: maxLines, decoration: _deco(label)),
      );

  Widget _mediaField(
      TextEditingController c, String label, String key, bool video) {
    final uploading = _uploadingKey == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: c,
        builder: (context, value, _) {
          final url = value.text.trim();
          final hasUrl = url.startsWith('http');
          return Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: (!video && hasUrl)
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const ColoredBox(color: _P.border),
                          errorWidget: (_, __, ___) => const ColoredBox(
                              color: _P.border,
                              child: Icon(Icons.broken_image_outlined,
                                  size: 18, color: _P.inkMuted)),
                        )
                      : ColoredBox(
                          color: _P.border,
                          child: Icon(
                              video
                                  ? (hasUrl
                                      ? Icons.videocam_rounded
                                      : Icons.videocam_outlined)
                                  : Icons.image_outlined,
                              size: 20,
                              color:
                                  hasUrl && video ? ThixPolicy.primary : _P.inkMuted),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(controller: c, decoration: _deco(label))),
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
                    tooltip: video
                        ? _s(context, 'Uploader une vidéo', 'Upload a video')
                        : _s(context, 'Uploader une photo', 'Upload a photo'),
                    icon: uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            video
                                ? Icons.videocam_rounded
                                : Icons.photo_camera_rounded,
                            size: 20,
                            color: Colors.white),
                    onPressed: uploading ? null : () => _pick(c, key, video),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _fieldsFor(int i) {
    return [
      for (final f in widget.spec.fields)
        if (f == 'image')
          _mediaField(
              _items[i][f]!, widget.spec.labelOf(f), '$i-$f', false)
        else if (f == 'video')
          _mediaField(_items[i][f]!, widget.spec.labelOf(f), '$i-$f', true)
        else
          _tf(_items[i][f]!, widget.spec.labelOf(f),
              maxLines: f == 'text' ? 3 : 1),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isFr = _lang(context) == 'fr';
    final specName = isFr ? widget.spec.fr : widget.spec.en;
    final titleHint = _s(
      context,
      'Titre de la rubrique (vide = "${widget.spec.fr}" / "${widget.spec.en}")',
      'Section title (empty = "${widget.spec.fr}" / "${widget.spec.en}")',
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                    color: _P.border,
                    borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Icon(widget.spec.icon, color: ThixPolicy.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(specName,
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
                  _tf(_title, titleHint),
                  for (var i = 0; i < _items.length; i++)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: _P.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _P.border),
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
                                onPressed: () => setState(() {
                                  for (final c in _items[i].values) {
                                    c.dispose();
                                  }
                                  _items.removeAt(i);
                                }),
                              ),
                            ],
                          ),
                          ..._fieldsFor(i),
                        ],
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _items.add(_ctrls(const {}))),
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
}
